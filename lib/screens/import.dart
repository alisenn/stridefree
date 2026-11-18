// FitShow'dan (veya başka uygulamadan) geçiş: içe aktarma + yedekleme ekranı.
import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../importer.dart';
import '../models.dart';
import '../state.dart';

Future<void> saveTextFile(
  BuildContext context,
  String fileName,
  String content,
  String mime,
) async {
  try {
    final uri = await FilePicker.saveFile(
      fileName: fileName,
      bytes: Uint8List.fromList(utf8.encode(content)),
      mimeType: mime,
    );
    if (uri != null && context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('$fileName kaydedildi')));
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Kaydedilemedi: $e')));
    }
  }
}

class ImportScreen extends StatefulWidget {
  const ImportScreen({super.key});

  @override
  State<ImportScreen> createState() => _ImportScreenState();
}

class _ImportScreenState extends State<ImportScreen> {
  bool busy = false;

  Future<void> _pick() async {
    final files = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv', 'xml', 'tcx', 'gpx', 'json'],
    );
    if (files.isEmpty) return;
    setState(() => busy = true);
    final results = <ImportResult>[];
    final errors = <String>[];
    for (final f in files) {
      try {
        final bytes = await f.xFile.readAsBytes();
        results.add(parseImportFile(f.name, bytes));
      } catch (e) {
        errors.add('${f.name}: ${e is FormatException ? e.message : e}');
      }
    }
    setState(() => busy = false);
    if (!mounted) return;
    if (results.isEmpty) {
      _snack(errors.isEmpty ? 'Dosya okunamadı.' : errors.join('\n'));
      return;
    }
    await _confirm(results, errors);
  }

  void _snack(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  Future<void> _confirm(List<ImportResult> results, List<String> errors) async {
    final all = results.expand((r) => r.sessions).toList();
    final sources = <String, int>{};
    for (final r in results) {
      r.sources.forEach((k, v) => sources[k] = (sources[k] ?? 0) + v);
    }
    final programs = results.expand((r) => r.programs).toList();
    final settings = results
        .map((r) => r.settings)
        .whereType<Map<String, dynamic>>()
        .firstOrNull;

    // Apple Sağlık: hangi uygulamaların kayıtları alınsın?
    final selected = sources.keys.toSet();

    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, setD) {
          final chosen = all
              .where((s) => sources.isEmpty || selected.contains(s.source))
              .toList();
          final km = chosen.fold(0.0, (a, s) => a + s.distanceKm);
          final dates = chosen.map((s) => s.start).toList()..sort();
          String d(DateTime t) => '${t.day}.${t.month}.${t.year}';
          return AlertDialog(
            title: Text(
              '${results.map((r) => r.format).toSet().join(', ')} içe aktar',
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${chosen.length} koşu/yürüyüş · ${km.toStringAsFixed(1)} km'
                    '${dates.isEmpty ? '' : '\n${d(dates.first)} – ${d(dates.last)}'}',
                  ),
                  if (programs.isNotEmpty)
                    Text('${programs.length} özel program'),
                  if (settings != null) const Text('Profil ayarları'),
                  if (sources.length > 1) ...[
                    const SizedBox(height: 12),
                    const Text(
                      'Kaynak uygulamalar:',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    for (final e in sources.entries)
                      CheckboxListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        value: selected.contains(e.key),
                        title: Text('${e.key} (${e.value})'),
                        onChanged: (v) => setD(
                          () => v == true
                              ? selected.add(e.key)
                              : selected.remove(e.key),
                        ),
                      ),
                  ],
                  if (errors.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(
                      'Okunamayan: ${errors.join(', ')}',
                      style: TextStyle(color: Theme.of(c).colorScheme.error),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Text(
                    'Zaten kayıtlı olan antrenmanlar atlanır.',
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(c).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(c, false),
                child: const Text('Vazgeç'),
              ),
              FilledButton(
                onPressed:
                    chosen.isEmpty && programs.isEmpty && settings == null
                    ? null
                    : () => Navigator.pop(c, true),
                child: const Text('İçe aktar'),
              ),
            ],
          );
        },
      ),
    );
    if (ok != true || !mounted) return;

    final chosen = all.where(
      (s) => sources.isEmpty || selected.contains(s.source),
    );
    final added = context.read<HistoryStore>().importMany(chosen);
    final pAdded = context.read<ProgramStore>().importMany(programs);
    if (settings != null) context.read<SettingsStore>().restore(settings);
    _snack(
      '$added antrenman${pAdded > 0 ? ', $pAdded program' : ''} eklendi'
      '${chosen.length - added > 0 ? ' (${chosen.length - added} tekrar atlandı)' : ''}.',
    );
  }

  void _backup() {
    final json = buildBackup(
      sessions: context.read<HistoryStore>().sessions,
      programs: context.read<ProgramStore>().custom,
      settings: context.read<SettingsStore>().toJson(),
    );
    final n = DateTime.now();
    saveTextFile(
      context,
      'stridefree-yedek-${n.year}-${n.month.toString().padLeft(2, '0')}-${n.day.toString().padLeft(2, '0')}.json',
      json,
      'application/json',
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    Widget step(IconData icon, String title, String body) => ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundColor: cs.secondaryContainer,
        child: Icon(icon, color: cs.onSecondaryContainer),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(body),
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Verileri aktar')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 700),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "FitShow'dan geçiş",
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "FitShow'u Strava'ya veya Apple Sağlık'a bağladıysanız koşularınız oralarda da durur; "
                        "buradan tek seferde alabilirsiniz:",
                        style: TextStyle(color: cs.onSurfaceVariant),
                      ),
                      const SizedBox(height: 8),
                      step(
                        Icons.directions_run,
                        'Strava üzerinden',
                        'strava.com → Ayarlar → Hesabım → "Hesabınızı indirin". '
                            'Gelen zip içindeki activities.csv dosyasını seçin.',
                      ),
                      step(
                        Icons.favorite,
                        'Apple Sağlık üzerinden (iPhone)',
                        'Sağlık → profil resmi → "Tüm sağlık verilerini dışa aktar". '
                            'export.zip içindeki export.xml dosyasını seçin; FitShow kayıtlarını ayrıca seçebilirsiniz.',
                      ),
                      step(
                        Icons.description,
                        'TCX / GPX dosyaları',
                        'FitShow, Garmin, Zwift vb. uygulamalardan dışa aktarılan dosyalar.',
                      ),
                      step(
                        Icons.table_chart,
                        'Elle tablo (CSV)',
                        'Sütunlar: tarih, süre, mesafe, kalori (ör. "05.11.2025 07:30, 32:10, 5.2, 310").',
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          icon: busy
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.file_open),
                          label: const Padding(
                            padding: EdgeInsets.all(12),
                            child: Text('Dosya seç ve içe aktar'),
                          ),
                          onPressed: busy ? null : _pick,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Yedekleme',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Verileriniz yalnızca bu cihazda durur. Telefon değiştirirken yedek alın, '
                        'yeni cihazda yukarıdaki "Dosya seç" ile geri yükleyin.',
                        style: TextStyle(color: cs.onSurfaceVariant),
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        icon: const Icon(Icons.save_alt),
                        label: const Text('Yedek al (.json)'),
                        onPressed: _backup,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Antrenman detayında: Strava / Garmin'e yüklemek için TCX kaydet.
void exportSessionTcx(BuildContext context, WorkoutSession s) {
  final t = s.start;
  saveTextFile(
    context,
    'stridefree-${t.year}${t.month.toString().padLeft(2, '0')}${t.day.toString().padLeft(2, '0')}-'
        '${t.hour.toString().padLeft(2, '0')}${t.minute.toString().padLeft(2, '0')}.tcx',
    buildTcx(s),
    'application/vnd.garmin.tcx+xml',
  );
}
