// Geçmiş ve istatistikler (sınırsız, ücretsiz).
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models.dart';
import '../state.dart';
import '../widgets.dart';

const _months = [
  'Oca',
  'Şub',
  'Mar',
  'Nis',
  'May',
  'Haz',
  'Tem',
  'Ağu',
  'Eyl',
  'Eki',
  'Kas',
  'Ara',
];
String fmtDate(DateTime d) =>
    '${d.day} ${_months[d.month - 1]} ${d.year} · ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final h = context.watch<HistoryStore>();
    final cs = Theme.of(context).colorScheme;
    final best = h.longestRun;
    return Scaffold(
      appBar: AppBar(title: const Text('Geçmiş & İstatistik')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Bu hafta',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 12),
                  WeeklyBarChart(km: h.thisWeekKm()),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          GridView.extent(
            maxCrossAxisExtent: 260,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 2.2,
            children: [
              MetricTile(
                label: 'Toplam mesafe',
                value: h.totalKm.toStringAsFixed(1),
                unit: 'km',
                icon: Icons.straighten,
              ),
              MetricTile(
                label: 'Toplam süre',
                value: (h.totalSec / 3600).toStringAsFixed(1),
                unit: 'saat',
                icon: Icons.timer,
              ),
              MetricTile(
                label: 'Toplam kalori',
                value: h.totalKcal.toStringAsFixed(0),
                unit: 'kcal',
                icon: Icons.local_fire_department,
              ),
              MetricTile(
                label: 'Antrenman',
                value: '${h.sessions.length}',
                icon: Icons.fitness_center,
              ),
              MetricTile(
                label: 'Seri',
                value: '${h.streakDays}',
                unit: 'gün',
                icon: Icons.whatshot,
              ),
              MetricTile(
                label: 'En uzun koşu',
                value: best?.distanceKm.toStringAsFixed(2) ?? '--',
                unit: 'km',
                icon: Icons.emoji_events,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text('Antrenmanlar', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          if (h.sessions.isEmpty)
            Padding(
              padding: const EdgeInsets.all(32),
              child: Center(
                child: Text(
                  'Henüz antrenman yok. İlk koşunu yap!',
                  style: TextStyle(color: cs.onSurfaceVariant),
                ),
              ),
            ),
          for (final s in h.sessions)
            Dismissible(
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
                  child: Icon(
                    Icons.directions_run,
                    color: cs.onPrimaryContainer,
                  ),
                ),
                title: Text(
                  '${s.distanceKm.toStringAsFixed(2)} km · ${fmtDuration(s.durationSec)}',
                ),
                subtitle: Text('${s.title} · ${fmtDate(s.start)}'),
                trailing: Text('${s.kcal.toStringAsFixed(0)} kcal'),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => SessionDetailScreen(session: s),
                  ),
                ),
              ),
            ),
        ],
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
      appBar: AppBar(title: Text(isSummary ? 'Tebrikler!' : s.title)),
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
              GridView.extent(
                maxCrossAxisExtent: 180,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                childAspectRatio: 1.5,
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
