// Programlar: hazır antrenmanlar + sınırsız özel program editörü.
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n.dart';
import '../models.dart';
import '../state.dart';
import '../widgets.dart';
import 'workout.dart';

class ProgramsScreen extends StatelessWidget {
  const ProgramsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<ProgramStore>();
    return Scaffold(
      appBar: AppBar(title: Text(tx('Programlar', 'Programs'))),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: Text(tx('Yeni program', 'New program')),
        onPressed: () => _openEditor(context, null),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
        children: [
          if (store.custom.isNotEmpty) ...[
            _Header(tx('Programlarım', 'My programs')),
            for (final p in store.custom) _ProgramCard(p),
          ],
          _Header(tx('Hazır programlar', 'Built-in programs')),
          for (final p in builtInPrograms) _ProgramCard(p),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final String text;
  const _Header(this.text);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 16, 4, 8),
    child: Text(text, style: Theme.of(context).textTheme.titleMedium),
  );
}

class _ProgramCard extends StatelessWidget {
  final WorkoutProgram p;
  const _ProgramCard(this.p);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _showDetail(context, p),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      p.name,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  Text(
                    tx(
                      '${(p.totalSec / 60).round()} dk · ~${p.estimatedKm.toStringAsFixed(1)} km',
                      '${(p.totalSec / 60).round()} min · ~${p.estimatedKm.toStringAsFixed(1)} km',
                    ),
                    style: TextStyle(color: cs.onSurfaceVariant),
                  ),
                ],
              ),
              if (p.description.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  p.description,
                  style: TextStyle(color: cs.onSurfaceVariant),
                ),
              ],
              const SizedBox(height: 12),
              ProgramChart(program: p, height: 40),
            ],
          ),
        ),
      ),
    );
  }
}

void _showDetail(BuildContext context, WorkoutProgram p) {
  showModalBottomSheet(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (c) {
      final cs = Theme.of(c).colorScheme;
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(p.name, style: Theme.of(c).textTheme.headlineSmall),
              if (p.description.isNotEmpty)
                Text(
                  p.description,
                  style: TextStyle(color: cs.onSurfaceVariant),
                ),
              const SizedBox(height: 16),
              ProgramChart(program: p, height: 90),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                children: [
                  Chip(
                    avatar: const Icon(Icons.timer, size: 16),
                    label: Text(
                      tx(
                        '${(p.totalSec / 60).round()} dk',
                        '${(p.totalSec / 60).round()} min',
                      ),
                    ),
                  ),
                  Chip(
                    avatar: const Icon(Icons.straighten, size: 16),
                    label: Text('~${p.estimatedKm.toStringAsFixed(1)} km'),
                  ),
                  Chip(
                    avatar: const Icon(Icons.bolt, size: 16),
                    label: Text(
                      tx(
                        'maks ${p.maxSpeed.toStringAsFixed(1)} km/s',
                        'max ${p.maxSpeed.toStringAsFixed(1)} km/h',
                      ),
                    ),
                  ),
                  Chip(
                    avatar: const Icon(Icons.view_week, size: 16),
                    label: Text(
                      tx(
                        '${p.segments.length} bölüm',
                        '${p.segments.length} segments',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                icon: const Icon(Icons.play_arrow_rounded),
                label: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(tx('Programı başlat', 'Start program')),
                ),
                onPressed: () {
                  Navigator.pop(c);
                  startWorkout(context, program: p);
                },
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: Icon(p.builtIn ? Icons.copy : Icons.edit),
                      label: Text(
                        p.builtIn
                            ? tx('Kopyala & düzenle', 'Copy & edit')
                            : tx('Düzenle', 'Edit'),
                      ),
                      onPressed: () {
                        Navigator.pop(c);
                        _openEditor(context, p);
                      },
                    ),
                  ),
                  if (!p.builtIn) ...[
                    const SizedBox(width: 8),
                    IconButton.outlined(
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () {
                        context.read<ProgramStore>().remove(p.id);
                        Navigator.pop(c);
                      },
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      );
    },
  );
}

void _openEditor(BuildContext context, WorkoutProgram? source) {
  final WorkoutProgram draft;
  if (source == null) {
    draft = WorkoutProgram(
      id: 'c_${DateTime.now().microsecondsSinceEpoch}',
      name: tx('Yeni program', 'New program'),
      segments: [
        Segment(durationSec: 300, speed: 5.0),
        Segment(durationSec: 600, speed: 8.0),
        Segment(durationSec: 300, speed: 5.0),
      ],
    );
  } else {
    draft = WorkoutProgram(
      id: source.builtIn
          ? 'c_${DateTime.now().microsecondsSinceEpoch}'
          : source.id,
      name: source.builtIn
          ? tx('${source.name} (kopya)', '${source.name} (copy)')
          : source.name,
      description: source.description,
      segments: source.segments.map((s) => s.copy()).toList(),
    );
  }
  Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => ProgramEditor(draft: draft)),
  );
}

class ProgramEditor extends StatefulWidget {
  final WorkoutProgram draft;
  const ProgramEditor({super.key, required this.draft});

  @override
  State<ProgramEditor> createState() => _ProgramEditorState();
}

class _ProgramEditorState extends State<ProgramEditor> {
  late final TextEditingController name = TextEditingController(
    text: widget.draft.name,
  );
  late final TextEditingController desc = TextEditingController(
    text: widget.draft.description,
  );
  WorkoutProgram get p => widget.draft;

  void _save() {
    p.name = name.text.trim().isEmpty
        ? tx('Programım', 'My program')
        : name.text.trim();
    p.description = desc.text.trim();
    context.read<ProgramStore>().upsert(p);
    Navigator.pop(context);
  }

  void _addIntervals() async {
    final res = await showDialog<(int, int, double, int, double)>(
      context: context,
      builder: (_) => const _IntervalDialog(),
    );
    if (res == null) return;
    final (reps, fastSec, fast, slowSec, slow) = res;
    setState(() {
      for (var i = 0; i < reps; i++) {
        p.segments.add(Segment(durationSec: fastSec, speed: fast));
        p.segments.add(Segment(durationSec: slowSec, speed: slow));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(tx('Program düzenle', 'Edit program')),
        actions: [
          TextButton(onPressed: _save, child: Text(tx('Kaydet', 'Save'))),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
        children: [
          TextField(
            controller: name,
            decoration: InputDecoration(labelText: tx('Ad', 'Name')),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: desc,
            decoration: InputDecoration(
              labelText: tx('Açıklama', 'Description'),
            ),
          ),
          const SizedBox(height: 16),
          ProgramChart(program: p, height: 70),
          const SizedBox(height: 4),
          Text(
            tx(
              'Toplam ${fmtDuration(p.totalSec)} · ~${p.estimatedKm.toStringAsFixed(2)} km',
              'Total ${fmtDuration(p.totalSec)} · ~${p.estimatedKm.toStringAsFixed(2)} km',
            ),
            style: TextStyle(color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: 12),
          for (var i = 0; i < p.segments.length; i++)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Text(
                          tx('Bölüm ${i + 1}', 'Segment ${i + 1}'),
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        const Spacer(),
                        IconButton(
                          tooltip: tx('Çoğalt', 'Duplicate'),
                          icon: const Icon(Icons.copy, size: 20),
                          onPressed: () => setState(
                            () =>
                                p.segments.insert(i + 1, p.segments[i].copy()),
                          ),
                        ),
                        IconButton(
                          tooltip: tx('Sil', 'Delete'),
                          icon: const Icon(Icons.delete_outline, size: 20),
                          onPressed: p.segments.length > 1
                              ? () => setState(() => p.segments.removeAt(i))
                              : null,
                        ),
                      ],
                    ),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        AdjustControl(
                          compact: true,
                          label: tx('süre', 'time'),
                          value: fmtDuration(p.segments[i].durationSec),
                          onMinus: () => setState(() {
                            final s = p.segments[i];
                            s.durationSec =
                                (s.durationSec -
                                        (s.durationSec > 120 ? 60 : 15))
                                    .clamp(15, 7200);
                          }),
                          onPlus: () => setState(() {
                            final s = p.segments[i];
                            s.durationSec =
                                (s.durationSec +
                                        (s.durationSec >= 120 ? 60 : 15))
                                    .clamp(15, 7200);
                          }),
                        ),
                        AdjustControl(
                          compact: true,
                          label: tx('km/s', 'km/h'),
                          value: p.segments[i].speed.toStringAsFixed(1),
                          onMinus: () => setState(
                            () => p.segments[i].speed =
                                (p.segments[i].speed - 0.5).clamp(1.0, 20.0),
                          ),
                          onPlus: () => setState(
                            () => p.segments[i].speed =
                                (p.segments[i].speed + 0.5).clamp(1.0, 20.0),
                          ),
                        ),
                        AdjustControl(
                          compact: true,
                          label: tx('eğim %', 'incline %'),
                          value: p.segments[i].incline.toStringAsFixed(0),
                          onMinus: () => setState(
                            () => p.segments[i].incline =
                                (p.segments[i].incline - 1).clamp(0.0, 15.0),
                          ),
                          onPlus: () => setState(
                            () => p.segments[i].incline =
                                (p.segments[i].incline + 1).clamp(0.0, 15.0),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.add),
                  label: Text(tx('Bölüm ekle', 'Add segment')),
                  onPressed: () => setState(
                    () => p.segments.add(
                      p.segments.isEmpty
                          ? Segment(durationSec: 300, speed: 5)
                          : p.segments.last.copy(),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.repeat),
                  label: Text(tx('Interval ekle', 'Add intervals')),
                  onPressed: _addIntervals,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _IntervalDialog extends StatefulWidget {
  const _IntervalDialog();
  @override
  State<_IntervalDialog> createState() => _IntervalDialogState();
}

class _IntervalDialogState extends State<_IntervalDialog> {
  int reps = 6, fastSec = 60, slowSec = 90;
  double fast = 10, slow = 5;

  @override
  Widget build(BuildContext context) {
    Widget row(String l, Widget w) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(child: Text(l)),
          w,
        ],
      ),
    );
    return AlertDialog(
      title: Text(tx('Interval blok ekle', 'Add interval block')),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          row(
            tx('Tekrar', 'Repeats'),
            AdjustControl(
              compact: true,
              label: tx('tur', 'reps'),
              value: '$reps',
              onMinus: () => setState(() => reps = (reps - 1).clamp(1, 30)),
              onPlus: () => setState(() => reps = (reps + 1).clamp(1, 30)),
            ),
          ),
          row(
            tx('Hızlı', 'Fast'),
            AdjustControl(
              compact: true,
              label: tx('km/s', 'km/h'),
              value: fast.toStringAsFixed(1),
              onMinus: () =>
                  setState(() => fast = (fast - 0.5).clamp(1.0, 20.0)),
              onPlus: () =>
                  setState(() => fast = (fast + 0.5).clamp(1.0, 20.0)),
            ),
          ),
          row(
            tx('Hızlı süre', 'Fast time'),
            AdjustControl(
              compact: true,
              label: tx('sn', 's'),
              value: '$fastSec',
              onMinus: () =>
                  setState(() => fastSec = (fastSec - 15).clamp(15, 600)),
              onPlus: () =>
                  setState(() => fastSec = (fastSec + 15).clamp(15, 600)),
            ),
          ),
          row(
            tx('Yavaş', 'Slow'),
            AdjustControl(
              compact: true,
              label: tx('km/s', 'km/h'),
              value: slow.toStringAsFixed(1),
              onMinus: () =>
                  setState(() => slow = (slow - 0.5).clamp(1.0, 20.0)),
              onPlus: () =>
                  setState(() => slow = (slow + 0.5).clamp(1.0, 20.0)),
            ),
          ),
          row(
            tx('Yavaş süre', 'Slow time'),
            AdjustControl(
              compact: true,
              label: tx('sn', 's'),
              value: '$slowSec',
              onMinus: () =>
                  setState(() => slowSec = (slowSec - 15).clamp(15, 600)),
              onPlus: () =>
                  setState(() => slowSec = (slowSec + 15).clamp(15, 600)),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(tx('Vazgeç', 'Cancel')),
        ),
        FilledButton(
          onPressed: () =>
              Navigator.pop(context, (reps, fastSec, fast, slowSec, slow)),
          child: Text(tx('Ekle', 'Add')),
        ),
      ],
    );
  }
}
