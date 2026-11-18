// Ana ekran: cihaz bağlantısı, haftalık hedef, hızlı başlat.
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models.dart';
import '../state.dart';
import 'scan.dart';
import 'workout.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  GoalType goalType = GoalType.none;
  final Map<GoalType, double> goalValues = {
    GoalType.time: 30,
    GoalType.distance: 5,
    GoalType.calories: 300,
  };

  @override
  Widget build(BuildContext context) {
    final dev = context.watch<DeviceManager>();
    final hist = context.watch<HistoryStore>();
    final settings = context.watch<SettingsStore>();
    final cs = Theme.of(context).colorScheme;
    final weekKm = hist.thisWeekKm().fold(0.0, (a, b) => a + b);

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            Row(
              children: [
                Text(
                  'StrideFree',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: cs.primaryContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'TÜM ÖZELLİKLER ÜCRETSİZ',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: cs.onPrimaryContainer,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // ------- Haftalık hedef -------
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    SizedBox(
                      width: 72,
                      height: 72,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          CircularProgressIndicator(
                            value: (weekKm / settings.weeklyGoalKm).clamp(0, 1),
                            strokeWidth: 8,
                            backgroundColor: cs.surfaceContainerHighest,
                            strokeCap: StrokeCap.round,
                          ),
                          Center(
                            child: Text(
                              '${(weekKm / settings.weeklyGoalKm * 100).clamp(0, 999).round()}%',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Bu hafta',
                            style: TextStyle(color: cs.onSurfaceVariant),
                          ),
                          Text(
                            '${weekKm.toStringAsFixed(1)} / ${settings.weeklyGoalKm.toStringAsFixed(0)} km',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(
                                Icons.local_fire_department,
                                size: 16,
                                color: hist.streakDays > 0
                                    ? Colors.orangeAccent
                                    : cs.onSurfaceVariant,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '${hist.streakDays} günlük seri',
                                style: TextStyle(color: cs.onSurfaceVariant),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            // ------- Cihazlar -------
            _DeviceCard(dev: dev),
            if (dev.error != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(dev.error!, style: TextStyle(color: cs.error)),
              ),
            const SizedBox(height: 20),

            // ------- Hızlı başlat -------
            Text(
              'Hızlı başlat',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            SegmentedButton<GoalType>(
              segments: const [
                ButtonSegment(value: GoalType.none, label: Text('Serbest')),
                ButtonSegment(value: GoalType.time, label: Text('Süre')),
                ButtonSegment(value: GoalType.distance, label: Text('Mesafe')),
                ButtonSegment(value: GoalType.calories, label: Text('Kalori')),
              ],
              showSelectedIcon: false,
              selected: {goalType},
              onSelectionChanged: (s) => setState(() => goalType = s.first),
            ),
            if (goalType != GoalType.none) ...[
              const SizedBox(height: 12),
              _GoalSlider(
                type: goalType,
                value: goalValues[goalType]!,
                onChanged: (v) => setState(() => goalValues[goalType] = v),
              ),
            ],
            const SizedBox(height: 16),
            SizedBox(
              height: 64,
              child: FilledButton.icon(
                icon: const Icon(Icons.play_arrow_rounded, size: 32),
                label: Text(
                  dev.connected ? 'Başla' : 'Önce koşu bandına bağlan',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                onPressed: dev.connected
                    ? () => startWorkout(
                        context,
                        goal: goalType == GoalType.none
                            ? Goal.none
                            : Goal(goalType, goalValues[goalType]!),
                      )
                    : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GoalSlider extends StatelessWidget {
  final GoalType type;
  final double value;
  final ValueChanged<double> onChanged;
  const _GoalSlider({
    required this.type,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final (min, max, div, unit) = switch (type) {
      GoalType.time => (5.0, 120.0, 23, 'dk'),
      GoalType.distance => (0.5, 42.0, 83, 'km'),
      GoalType.calories => (50.0, 1500.0, 29, 'kcal'),
      GoalType.none => (0.0, 1.0, 1, ''),
    };
    return Row(
      children: [
        Expanded(
          child: Slider(
            min: min,
            max: max,
            divisions: div,
            value: value.clamp(min, max),
            onChanged: onChanged,
          ),
        ),
        SizedBox(
          width: 84,
          child: Text(
            '${type == GoalType.distance ? value.toStringAsFixed(1) : value.toStringAsFixed(0)} $unit',
            textAlign: TextAlign.end,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }
}

class _DeviceCard extends StatelessWidget {
  final DeviceManager dev;
  const _DeviceCard({required this.dev});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final t = dev.treadmill;
    return Card(
      child: Column(
        children: [
          ListTile(
            leading: CircleAvatar(
              backgroundColor: t != null
                  ? cs.primary
                  : cs.surfaceContainerHighest,
              child: Icon(
                Icons.directions_run,
                color: t != null ? cs.onPrimary : cs.onSurfaceVariant,
              ),
            ),
            title: Text(t?.name ?? 'Koşu bandı bağlı değil'),
            subtitle: Text(
              t == null
                  ? 'FTMS ve FitShow modüllü bantlar desteklenir'
                  : '${(dev.last.speedKmh ?? 0).toStringAsFixed(1)} km/s · '
                        'maks ${t.maxSpeed.toStringAsFixed(0)} km/s'
                        '${t.supportsIncline ? ' · eğim %${t.maxIncline.toStringAsFixed(0)}' : ''}',
            ),
            trailing: dev.busy
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : t != null
                ? TextButton(
                    onPressed: dev.disconnectTreadmill,
                    child: const Text('Ayır'),
                  )
                : null,
          ),
          if (t == null && !dev.busy)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Row(
                children: [
                  Expanded(
                    child: FilledButton.tonalIcon(
                      icon: const Icon(Icons.bluetooth_searching),
                      label: const Text('Bağlan'),
                      onPressed: () async {
                        final d = await showScanSheet(
                          context,
                          ScanKind.treadmill,
                        );
                        if (d != null && context.mounted) {
                          await dev.connectTreadmill(
                            d,
                            context.read<SettingsStore>(),
                          );
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.science_outlined),
                    label: const Text('Demo'),
                    onPressed: dev.connectDemo,
                  ),
                ],
              ),
            ),
          const Divider(height: 1),
          ListTile(
            dense: true,
            leading: Icon(
              Icons.favorite,
              color: dev.hrm != null ? Colors.redAccent : cs.onSurfaceVariant,
            ),
            title: Text(dev.hrm?.name ?? 'Nabız bandı (isteğe bağlı)'),
            subtitle: dev.hrm != null
                ? Text('${dev.strapHr ?? '--'} bpm')
                : null,
            trailing: dev.hrm != null
                ? TextButton(
                    onPressed: dev.disconnectHrm,
                    child: const Text('Ayır'),
                  )
                : TextButton(
                    onPressed: () async {
                      final d = await showScanSheet(
                        context,
                        ScanKind.heartRate,
                      );
                      if (d != null) await dev.connectHrm(d);
                    },
                    child: const Text('Bağlan'),
                  ),
          ),
        ],
      ),
    );
  }
}
