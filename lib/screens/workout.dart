// Aktif antrenman ekranı.
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models.dart';
import '../state.dart';
import '../widgets.dart';
import 'history.dart';

Future<void> startWorkout(
  BuildContext context, {
  WorkoutProgram? program,
  Goal goal = Goal.none,
}) async {
  final wc = context.read<WorkoutController>();
  if (!context.read<DeviceManager>().connected) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Önce bir koşu bandına bağlanın (veya Demo modunu açın).',
        ),
      ),
    );
    return;
  }
  await wc.begin(program: program, goal: goal);
  if (!context.mounted) return;
  await Navigator.of(context).push(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => const WorkoutScreen(),
    ),
  );
}

class WorkoutScreen extends StatefulWidget {
  const WorkoutScreen({super.key});

  @override
  State<WorkoutScreen> createState() => _WorkoutScreenState();
}

class _WorkoutScreenState extends State<WorkoutScreen> {
  bool _leaving = false;

  Future<void> _confirmStop(BuildContext context) async {
    final wc = context.read<WorkoutController>();
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Antrenmanı bitir?'),
        content: const Text('Bant durdurulacak ve antrenman kaydedilecek.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Devam et'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Bitir'),
          ),
        ],
      ),
    );
    if (ok == true) wc.finish();
  }

  @override
  Widget build(BuildContext context) {
    final wc = context.watch<WorkoutController>();
    final dev = context.watch<DeviceManager>();
    final settings = context.watch<SettingsStore>();
    final cs = Theme.of(context).colorScheme;

    // Antrenman bittiğinde özete geç
    if (wc.state == RunState.idle) {
      if (_leaving) return const Scaffold();
      _leaving = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!context.mounted) return;
        final s = wc.lastFinished;
        if (s != null) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (_) => SessionDetailScreen(session: s, isSummary: true),
            ),
          );
        } else {
          Navigator.of(context).maybePop();
        }
      });
      return const Scaffold();
    }

    if (wc.state == RunState.countdown) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(wc.title, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 16),
              Text(
                '${wc.countdown}',
                style: TextStyle(
                  fontSize: 160,
                  fontWeight: FontWeight.w900,
                  color: cs.primary,
                ),
              ),
              TextButton(onPressed: wc.finish, child: const Text('İptal')),
            ],
          ),
        ),
      );
    }

    final hr = wc.hr;
    final zone = settings.hrZone(hr);
    final paused = wc.state == RunState.paused;
    final seg = wc.currentSegment;
    final next = wc.nextSegment;
    final remainingTotal = wc.program != null
        ? wc.program!.totalSec - wc.elapsed
        : (wc.goal.type == GoalType.time
              ? (wc.goal.value * 60).round() - wc.elapsed
              : null);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmStop(context);
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(wc.title),
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => _confirmStop(context),
          ),
        ),
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, c) {
              final wide = c.maxWidth > 700;
              final metrics = _Metrics(wc: wc, hr: hr, zone: zone);
              final controls = _Controls(wc: wc);
              return ListView(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                children: [
                  // ---- ilerleme ----
                  if (wc.program != null) ...[
                    ProgramChart(
                      program: wc.program!,
                      elapsedSec: wc.elapsed,
                      height: 56,
                    ),
                    const SizedBox(height: 8),
                    if (seg != null)
                      Row(
                        children: [
                          Text(
                            'Bölüm ${wc.segmentIndex + 1}/${wc.program!.segments.length}',
                            style: TextStyle(color: cs.onSurfaceVariant),
                          ),
                          const Spacer(),
                          Text(
                            next != null
                                ? 'Sonraki: ${next.speed.toStringAsFixed(1)} km/s'
                                      '${next.incline > 0 ? ' · %${next.incline.toStringAsFixed(0)}' : ''}'
                                      ' — ${fmtDuration(wc.segmentRemaining)}'
                                : 'Son bölüm — ${fmtDuration(wc.segmentRemaining)}',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: wc.segmentRemaining <= 5
                                  ? cs.tertiary
                                  : cs.onSurface,
                            ),
                          ),
                        ],
                      ),
                  ] else if (wc.progress != null) ...[
                    LinearProgressIndicator(
                      value: wc.progress,
                      minHeight: 10,
                      borderRadius: BorderRadius.circular(5),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Hedef: ${wc.goal.label} — %${(wc.progress! * 100).round()}',
                      style: TextStyle(color: cs.onSurfaceVariant),
                    ),
                  ],
                  const SizedBox(height: 12),

                  if (wc.pausedByDisconnect || dev.reconnecting)
                    Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: cs.errorContainer,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            dev.reconnecting
                                ? Icons.bluetooth_searching
                                : Icons.bluetooth_disabled,
                            color: cs.onErrorContainer,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              dev.reconnecting
                                  ? 'Bant bağlantısı koptu. Antrenman duraklatıldı ve kaydedildi; yeniden bağlanılıyor…'
                                  : dev.connected
                                  ? 'Bağlantı geri geldi. Devam etmek için "Devam"a basın.'
                                  : 'Banda bağlanılamadı. Antrenmanınız kayıtlı; "Bitir" ile kaydedebilirsiniz.',
                              style: TextStyle(color: cs.onErrorContainer),
                            ),
                          ),
                        ],
                      ),
                    ),
                  // ---- büyük göstergeler ----
                  Row(
                    children: [
                      Expanded(
                        child: _Hero(
                          label: paused ? 'DURAKLATILDI' : 'SÜRE',
                          value: fmtDuration(wc.elapsed),
                          sub: remainingTotal != null
                              ? 'kalan ${fmtDuration(remainingTotal.clamp(0, 99999))}'
                              : null,
                          color: paused ? cs.tertiary : null,
                        ),
                      ),
                      Expanded(
                        child: _Hero(
                          label: 'HIZ km/s',
                          value: wc.speed.toStringAsFixed(1),
                          sub: 'hedef ${wc.targetSpeed.toStringAsFixed(1)}',
                          color: cs.primary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (wide)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: metrics),
                        const SizedBox(width: 16),
                        Expanded(child: controls),
                      ],
                    )
                  else ...[
                    metrics,
                    const SizedBox(height: 16),
                    controls,
                  ],
                ],
              );
            },
          ),
        ),
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 60,
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: paused
                            ? cs.primary
                            : cs.secondaryContainer,
                        foregroundColor: paused
                            ? cs.onPrimary
                            : cs.onSecondaryContainer,
                      ),
                      icon: Icon(
                        paused ? Icons.play_arrow_rounded : Icons.pause_rounded,
                        size: 30,
                      ),
                      label: Text(
                        paused ? 'Devam' : 'Duraklat',
                        style: const TextStyle(fontSize: 18),
                      ),
                      onPressed: () async {
                        final ok = await wc.togglePause();
                        if (!ok && context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Koşu bandı bağlı değil. Bağlantı gelince devam edebilirsiniz.',
                              ),
                            ),
                          );
                        }
                      },
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  height: 60,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: cs.errorContainer,
                      foregroundColor: cs.onErrorContainer,
                    ),
                    icon: const Icon(Icons.stop_rounded, size: 30),
                    label: const Text('Bitir', style: TextStyle(fontSize: 18)),
                    onPressed: () => _confirmStop(context),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  final String label, value;
  final String? sub;
  final Color? color;
  const _Hero({required this.label, required this.value, this.sub, this.color});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            letterSpacing: 1.5,
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: color ?? cs.onSurfaceVariant,
          ),
        ),
        FittedBox(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 64,
              height: 1.1,
              fontWeight: FontWeight.w800,
              color: color,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ),
        if (sub != null)
          Text(sub!, style: TextStyle(color: cs.onSurfaceVariant)),
      ],
    );
  }
}

class _Metrics extends StatelessWidget {
  final WorkoutController wc;
  final int? hr;
  final int zone;
  const _Metrics({required this.wc, required this.hr, required this.zone});

  @override
  Widget build(BuildContext context) {
    final tiles = [
      MetricTile(
        label: 'Mesafe',
        value: (wc.distanceM / 1000).toStringAsFixed(2),
        unit: 'km',
        icon: Icons.straighten,
      ),
      MetricTile(
        label: 'Kalori',
        value: wc.kcal.toStringAsFixed(0),
        unit: 'kcal',
        icon: Icons.local_fire_department,
      ),
      MetricTile(
        label: 'Tempo',
        value: fmtPace(wc.paceMinPerKm),
        unit: '/km',
        icon: Icons.speed,
      ),
      MetricTile(
        label: 'Eğim',
        value: wc.incline.toStringAsFixed(1),
        unit: '%',
        icon: Icons.terrain,
      ),
      MetricTile(
        label: zone > 0 ? 'Nabız · ${zoneNames[zone]}' : 'Nabız',
        value: hr?.toString() ?? '--',
        unit: 'bpm',
        icon: Icons.favorite,
        color: zone > 0 ? zoneColors[zone] : null,
      ),
      MetricTile(
        label: 'Tırmanış',
        value: wc.elevationM.toStringAsFixed(0),
        unit: 'm',
        icon: Icons.landscape,
      ),
    ];
    return GridView(
      gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 150,
        mainAxisExtent: 80,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
      ),
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: tiles,
    );
  }
}

class _Controls extends StatelessWidget {
  final WorkoutController wc;
  const _Controls({required this.wc});

  @override
  Widget build(BuildContext context) {
    final t = wc.dev.treadmill;
    final s = context.watch<SettingsStore>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AdjustControl(
          label: 'Hız (km/s)',
          value: wc.targetSpeed.toStringAsFixed(1),
          onMinus: () => wc.nudgeSpeed(-1),
          onPlus: () => wc.nudgeSpeed(1),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          alignment: WrapAlignment.center,
          children: [
            for (final s in [3.0, 5.0, 6.5, 8.0, 10.0, 12.0])
              ActionChip(
                label: Text(s.toStringAsFixed(s % 1 == 0 ? 0 : 1)),
                onPressed: () => wc.setSpeed(s),
              ),
          ],
        ),
        if (s.manualInclineEnabled) ...[
          const SizedBox(height: 12),
          Card(
            margin: EdgeInsets.zero,
            child: SwitchListTile(
              secondary: const Icon(Icons.terrain),
              title: Text(
                'Eğim ayakları takılı (%${s.manualInclinePct.toStringAsFixed(1)})',
              ),
              subtitle: const Text(
                'Kalori ve tırmanış bu eğime göre hesaplanır',
              ),
              value: s.manualInclineActive,
              onChanged: (v) => s.setManualIncline(active: v),
            ),
          ),
        ] else if (t?.supportsIncline ?? false) ...[
          const SizedBox(height: 12),
          AdjustControl(
            label: 'Eğim (%)',
            value: wc.targetIncline.toStringAsFixed(0),
            onMinus: () => wc.nudgeIncline(-1),
            onPlus: () => wc.nudgeIncline(1),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            alignment: WrapAlignment.center,
            children: [
              for (final i in [0.0, 3.0, 6.0, 9.0, 12.0])
                ActionChip(
                  label: Text('%${i.toStringAsFixed(0)}'),
                  onPressed: () => wc.setIncline(i),
                ),
            ],
          ),
        ],
      ],
    );
  }
}
