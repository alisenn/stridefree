// Geçmiş ve istatistikler (sınırsız, ücretsiz).
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models.dart';
import '../state.dart';
import '../stats.dart';
import '../widgets.dart';
import 'import.dart';

String fmtDate(DateTime d) =>
    '${d.day} ${monthShort[d.month - 1]} ${d.year} · ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

String _fmtMetric(Metric m, double v) => switch (m) {
  Metric.distance => '${v.toStringAsFixed(v >= 100 ? 0 : 1)} km',
  Metric.time =>
    v >= 120 ? '${(v / 60).toStringAsFixed(1)} sa' : '${v.round()} dk',
  Metric.calories => '${v.round()} kcal',
  Metric.count => '${v.round()} antrenman',
};

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  Period period = Period.week;
  Metric metric = Metric.distance;
  int offset = 0;

  @override
  Widget build(BuildContext context) {
    final h = context.watch<HistoryStore>();
    final cs = Theme.of(context).colorScheme;
    final st = computePeriod(h.sessions, period, offset);
    final prev = period == Period.all
        ? null
        : computePeriod(h.sessions, period, offset - 1);
    final canGoBack =
        period != Period.all &&
        h.sessions.any((s) => s.start.isBefore(st.start));
    final best = h.longestRun;

    // Devam eden dönemde önceki dönemin aynı noktasına kadar karşılaştır.
    final ongoing = offset == 0 && period != Period.all;
    final span = DateTime.now().difference(st.start);
    final before = prev == null
        ? 0.0
        : ongoing
        ? prev.totalWithin(metric, span)
        : prev.total(metric);
    final prevName = switch (period) {
      Period.week => ongoing ? 'geçen haftanın bu zamanına' : 'önceki haftaya',
      Period.month => ongoing ? 'geçen ayın bu zamanına' : 'önceki aya',
      Period.year => ongoing ? 'geçen yılın bu zamanına' : 'önceki yıla',
      Period.all => '',
    };

    Widget delta(double now) {
      if (prev == null || before <= 0) return const SizedBox();
      final pct = ((now - before) / before * 100).round();
      final up = pct >= 0;
      return Text(
        '${up ? '▲' : '▼'} %${pct.abs()} · $prevName göre',
        style: TextStyle(fontSize: 12, color: up ? cs.primary : cs.error),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Geçmiş & İstatistik')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        children: [
          SegmentedButton<Period>(
            segments: const [
              ButtonSegment(value: Period.week, label: Text('Hafta')),
              ButtonSegment(value: Period.month, label: Text('Ay')),
              ButtonSegment(value: Period.year, label: Text('Yıl')),
              ButtonSegment(value: Period.all, label: Text('Tümü')),
            ],
            showSelectedIcon: false,
            selected: {period},
            onSelectionChanged: (v) => setState(() {
              period = v.first;
              offset = 0;
            }),
          ),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.chevron_left),
                        onPressed: canGoBack
                            ? () => setState(() => offset--)
                            : null,
                      ),
                      Expanded(
                        child: Column(
                          children: [
                            Text(
                              st.title,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            Text(
                              _fmtMetric(metric, st.total(metric)),
                              style: Theme.of(context).textTheme.headlineSmall
                                  ?.copyWith(fontWeight: FontWeight.w800),
                            ),
                            delta(st.total(metric)),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.chevron_right),
                        onPressed: offset < 0
                            ? () => setState(() => offset++)
                            : null,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: PeriodBarChart(
                      values: st.values(metric),
                      labels: st.labels,
                      highlight: st.todayIndex,
                      format: (v) => _fmtMetric(metric, v),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Center(
                    child: Wrap(
                      spacing: 6,
                      children: [
                        for (final m in Metric.values)
                          ChoiceChip(
                            label: Text(switch (m) {
                              Metric.distance => 'Mesafe',
                              Metric.time => 'Süre',
                              Metric.calories => 'Kalori',
                              Metric.count => 'Adet',
                            }),
                            selected: metric == m,
                            onSelected: (_) => setState(() => metric = m),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          GridView(
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 150,
              mainAxisExtent: 80,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
            ),
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              MetricTile(
                label: 'Mesafe',
                value: st.km().toStringAsFixed(1),
                unit: 'km',
                icon: Icons.straighten,
              ),
              MetricTile(
                label: 'Süre',
                value: (st.sec() / 3600).toStringAsFixed(1),
                unit: 'sa',
                icon: Icons.timer,
              ),
              MetricTile(
                label: 'Kalori',
                value: st.kcal().toStringAsFixed(0),
                unit: 'kcal',
                icon: Icons.local_fire_department,
              ),
              MetricTile(
                label: 'Antrenman',
                value: '${st.count}',
                icon: Icons.fitness_center,
              ),
              MetricTile(
                label: 'Aktif gün',
                value: '${st.activeDays}',
                unit: 'gün',
                icon: Icons.event_available,
              ),
              MetricTile(
                label: 'Ort. tempo',
                value: fmtPace(st.avgPace),
                unit: '/km',
                icon: Icons.speed,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: _Record(
                      icon: Icons.whatshot,
                      label: 'Seri',
                      value: '${h.streakDays} gün',
                    ),
                  ),
                  Expanded(
                    child: _Record(
                      icon: Icons.emoji_events,
                      label: 'En uzun koşu',
                      value: best == null
                          ? '--'
                          : '${best.distanceKm.toStringAsFixed(2)} km',
                    ),
                  ),
                  Expanded(
                    child: _Record(
                      icon: Icons.all_inclusive,
                      label: 'Toplam',
                      value: '${h.totalKm.toStringAsFixed(0)} km',
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            '${st.title} · ${st.count} antrenman',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 4),
          if (st.sessions.isEmpty)
            Padding(
              padding: const EdgeInsets.all(32),
              child: Center(
                child: Text(
                  h.sessions.isEmpty
                      ? 'Henüz antrenman yok. İlk koşunu yap!'
                      : 'Bu dönemde antrenman yok.',
                  style: TextStyle(color: cs.onSurfaceVariant),
                ),
              ),
            ),
          for (final s in st.sessions) _SessionTile(s: s, h: h),
        ],
      ),
    );
  }
}

class _Record extends StatelessWidget {
  final IconData icon;
  final String label, value;
  const _Record({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      children: [
        Icon(icon, size: 20, color: cs.primary),
        const SizedBox(height: 2),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
        Text(label, style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
      ],
    );
  }
}

class _SessionTile extends StatelessWidget {
  final WorkoutSession s;
  final HistoryStore h;
  const _SessionTile({required this.s, required this.h});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Dismissible(
      key: ValueKey(s.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        color: cs.errorContainer,
        child: Icon(Icons.delete, color: cs.onErrorContainer),
      ),
      confirmDismiss: (_) async =>
          await showDialog<bool>(
            context: context,
            builder: (c) => AlertDialog(
              title: const Text('Antrenman silinsin mi?'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(c, false),
                  child: const Text('Vazgeç'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(c, true),
                  child: const Text('Sil'),
                ),
              ],
            ),
          ) ??
          false,
      onDismissed: (_) => h.remove(s.id),
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        leading: CircleAvatar(
          backgroundColor: cs.primaryContainer,
          child: Icon(Icons.directions_run, color: cs.onPrimaryContainer),
        ),
        title: Text(
          '${s.distanceKm.toStringAsFixed(2)} km · ${fmtDuration(s.durationSec)}',
        ),
        subtitle: Text('${s.title} · ${fmtDate(s.start)}'),
        trailing: Text('${s.kcal.toStringAsFixed(0)} kcal'),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => SessionDetailScreen(session: s)),
        ),
      ),
    );
  }
}

class SessionDetailScreen extends StatelessWidget {
  final WorkoutSession session;
  final bool isSummary;
  const SessionDetailScreen({
    super.key,
    required this.session,
    this.isSummary = false,
  });

  @override
  Widget build(BuildContext context) {
    final s = session;
    final cs = Theme.of(context).colorScheme;
    final hrVals = s.hrSamples.map((e) => e.toDouble()).toList();
    final hasHr = hrVals.any((v) => v > 0);
    return Scaffold(
      appBar: AppBar(
        title: Text(isSummary ? 'Tebrikler!' : s.title),
        actions: [
          IconButton(
            tooltip: 'TCX olarak kaydet (Strava / Garmin)',
            icon: const Icon(Icons.ios_share),
            onPressed: () => exportSessionTcx(context, s),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            children: [
              Text(
                fmtDate(s.start),
                style: TextStyle(color: cs.onSurfaceVariant),
              ),
              if (isSummary)
                Text(s.title, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 12),
              GridView(
                gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 150,
                  mainAxisExtent: 80,
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                ),
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  MetricTile(
                    label: 'Mesafe',
                    value: s.distanceKm.toStringAsFixed(2),
                    unit: 'km',
                    icon: Icons.straighten,
                  ),
                  MetricTile(
                    label: 'Süre',
                    value: fmtDuration(s.durationSec),
                    icon: Icons.timer,
                  ),
                  MetricTile(
                    label: 'Kalori',
                    value: s.kcal.toStringAsFixed(0),
                    unit: 'kcal',
                    icon: Icons.local_fire_department,
                  ),
                  MetricTile(
                    label: 'Ort. hız',
                    value: s.avgSpeed.toStringAsFixed(1),
                    unit: 'km/s',
                    icon: Icons.speed,
                  ),
                  MetricTile(
                    label: 'Ort. tempo',
                    value: fmtPace(s.paceMinPerKm),
                    unit: '/km',
                    icon: Icons.av_timer,
                  ),
                  MetricTile(
                    label: 'Maks hız',
                    value: s.maxSpeed.toStringAsFixed(1),
                    unit: 'km/s',
                    icon: Icons.bolt,
                  ),
                  MetricTile(
                    label: 'Ort. nabız',
                    value: s.avgHr?.toString() ?? '--',
                    unit: 'bpm',
                    icon: Icons.favorite,
                  ),
                  MetricTile(
                    label: 'Maks nabız',
                    value: s.maxHr?.toString() ?? '--',
                    unit: 'bpm',
                    icon: Icons.monitor_heart,
                  ),
                  MetricTile(
                    label: 'Tırmanış',
                    value: s.elevationM.toStringAsFixed(0),
                    unit: 'm',
                    icon: Icons.landscape,
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Text(
                'Hız (km/s)',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              SampleLineChart(
                values: s.speedSamples,
                color: cs.primary,
                unit: 'km/s',
              ),
              if (hasHr) ...[
                const SizedBox(height: 20),
                Text(
                  'Nabız (bpm)',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                SampleLineChart(
                  values: hrVals,
                  color: Colors.redAccent,
                  unit: 'bpm',
                ),
              ],
              if (isSummary) ...[
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Padding(
                    padding: EdgeInsets.all(12),
                    child: Text('Tamam'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
