// Başka uygulamalardan (FitShow → Strava / Apple Sağlık, TCX, GPX, CSV) antrenman içe aktarma
// ve StrideFree yedek / TCX dışa aktarma.
import 'dart:convert';
import 'dart:math';

import 'package:xml/xml.dart';

import 'l10n.dart';
import 'models.dart';

class ImportResult {
  final String format;
  final List<WorkoutSession> sessions;
  final List<WorkoutProgram> programs;
  final Map<String, dynamic>? settings;

  /// Apple Sağlık için: kaynak uygulama adına göre sayılar
  final Map<String, int> sources;

  ImportResult(
    this.format,
    this.sessions, {
    this.programs = const [],
    this.settings,
    this.sources = const {},
  });
}

/// Dosya adına ve içeriğe bakarak biçimi tanır ve ayrıştırır.
ImportResult parseImportFile(String fileName, List<int> bytes) {
  final text = utf8.decode(bytes, allowMalformed: true);
  final lower = fileName.toLowerCase();
  final head = text.length > 4000 ? text.substring(0, 4000) : text;

  if (lower.endsWith('.json') || head.trimLeft().startsWith('{')) {
    return parseBackup(text);
  }
  if (head.contains('<HealthData') || head.contains('HKWorkoutActivityType')) {
    return parseAppleHealth(text);
  }
  if (lower.endsWith('.tcx') || head.contains('TrainingCenterDatabase')) {
    return ImportResult('TCX', parseTcx(text));
  }
  if (lower.endsWith('.gpx') || head.contains('<gpx')) {
    return ImportResult('GPX', parseGpx(text));
  }
  if (lower.endsWith('.csv') || head.contains(',')) {
    return parseCsv(text);
  }
  throw FormatException(
    tx('Dosya biçimi tanınmadı.', 'Unrecognized file format.'),
  );
}

String _id(DateTime t) => 'imp_${t.millisecondsSinceEpoch}';

bool _isRunWalk(String type) {
  final t = type.toLowerCase();
  return t.contains('run') ||
      t.contains('walk') ||
      t.contains('treadmill') ||
      t.contains('koşu') ||
      t.contains('yürü') ||
      t.contains('hike');
}

// ---------------------------------------------------------------------------
// CSV (Strava "activities.csv" veya basit tablo)
// ---------------------------------------------------------------------------

List<List<String>> _csvRows(String text) {
  // Ayırıcıyı ilk satırdan belirle: Türkçe Excel ';' kullanır ve ondalıkta ',' olur.
  final firstLine = text.split(RegExp(r'[\r\n]')).first;
  final delim =
      ';'.allMatches(firstLine).length > ','.allMatches(firstLine).length
      ? ';'
      : ',';
  final rows = <List<String>>[];
  var row = <String>[];
  final cell = StringBuffer();
  var inQuotes = false;
  for (var i = 0; i < text.length; i++) {
    final c = text[i];
    if (inQuotes) {
      if (c == '"') {
        if (i + 1 < text.length && text[i + 1] == '"') {
          cell.write('"');
          i++;
        } else {
          inQuotes = false;
        }
      } else {
        cell.write(c);
      }
    } else if (c == '"') {
      inQuotes = true;
    } else if (c == delim) {
      row.add(cell.toString());
      cell.clear();
    } else if (c == '\n' || c == '\r') {
      if (c == '\r' && i + 1 < text.length && text[i + 1] == '\n') i++;
      row.add(cell.toString());
      cell.clear();
      if (row.any((e) => e.trim().isNotEmpty)) rows.add(row);
      row = <String>[];
    } else {
      cell.write(c);
    }
  }
  row.add(cell.toString());
  if (row.any((e) => e.trim().isNotEmpty)) rows.add(row);
  return rows;
}

double? _num(String? s) {
  if (s == null) return null;
  var v = s.trim();
  if (v.isEmpty) return null;
  // "1,234.5" veya "3,25" biçimleri
  if (v.contains(',') && v.contains('.')) {
    v = v.replaceAll(',', '');
  } else if (v.contains(',')) {
    v = v.replaceAll(',', '.');
  }
  return double.tryParse(v);
}

/// "12:34" / "1:02:03" veya saniye
int? _duration(String? s) {
  if (s == null || s.trim().isEmpty) return null;
  final v = s.trim();
  if (v.contains(':')) {
    final parts = v.split(':').map((e) => int.tryParse(e.trim()) ?? 0).toList();
    var sec = 0;
    for (final p in parts) {
      sec = sec * 60 + p;
    }
    return sec;
  }
  return _num(v)?.round();
}

const _monthNames = {
  'jan': 1, 'feb': 2, 'mar': 3, 'apr': 4, 'may': 5, 'jun': 6, //
  'jul': 7, 'aug': 8, 'sep': 9, 'oct': 10, 'nov': 11, 'dec': 12,
  'oca': 1, 'şub': 2, 'nis': 4, 'haz': 6, 'tem': 7, 'ağu': 8, //
  'eyl': 9, 'eki': 10, 'kas': 11, 'ara': 12,
};

/// ISO, "2023-11-05 07:45:12", "05.11.2023 07:45", "Nov 5, 2023, 7:45:12 AM"
DateTime? parseFlexibleDate(String s) {
  final v = s.trim();
  final iso = DateTime.tryParse(v.replaceFirst(' ', 'T'));
  if (iso != null) return iso;

  final dmy = RegExp(
    r'^(\d{1,2})[./](\d{1,2})[./](\d{4})(?:[ T,]+(\d{1,2}):(\d{2})(?::(\d{2}))?)?',
  ).firstMatch(v);
  if (dmy != null) {
    return DateTime(
      int.parse(dmy[3]!),
      int.parse(dmy[2]!),
      int.parse(dmy[1]!),
      int.tryParse(dmy[4] ?? '') ?? 0,
      int.tryParse(dmy[5] ?? '') ?? 0,
      int.tryParse(dmy[6] ?? '') ?? 0,
    );
  }

  final strava = RegExp(
    r'^([A-Za-zçğıöşüÇĞİÖŞÜ]{3})[a-zçğıöşü]*\.? (\d{1,2}), (\d{4}),? (\d{1,2}):(\d{2}):?(\d{2})? ?([AP]M)?',
    caseSensitive: false,
  ).firstMatch(v);
  if (strava != null) {
    final m = _monthNames[strava[1]!.toLowerCase()];
    if (m == null) return null;
    var h = int.parse(strava[4]!);
    final ampm = strava[7]?.toUpperCase();
    if (ampm == 'PM' && h < 12) h += 12;
    if (ampm == 'AM' && h == 12) h = 0;
    // Strava dışa aktarımı UTC'dir
    return DateTime.utc(
      int.parse(strava[3]!),
      m,
      int.parse(strava[2]!),
      h,
      int.parse(strava[5]!),
      int.tryParse(strava[6] ?? '') ?? 0,
    ).toLocal();
  }
  return null;
}

ImportResult parseCsv(String text) {
  final rows = _csvRows(text);
  if (rows.length < 2) return ImportResult('CSV', []);
  final header = rows.first.map((e) => e.trim().toLowerCase()).toList();
  final isStrava =
      header.contains('activity date') && header.contains('activity type');

  List<int> cols(List<String> names) => [
    for (var i = 0; i < header.length; i++)
      if (names.any((n) => header[i] == n || header[i].startsWith('$n '))) i,
  ];
  int? col(List<String> names) {
    final c = cols(names);
    return c.isEmpty ? null : c.first;
  }

  final cDate = col([
    'activity date',
    'date',
    'tarih',
    'start time',
    'start',
    'başlangıç',
  ]);
  final cType = col(['activity type', 'type', 'tür', 'sport']);
  final cName = col(['activity name', 'name', 'ad', 'title']);
  final cTime = col([
    'elapsed time',
    'moving time',
    'duration',
    'süre',
    'time',
  ]);
  final distCols = cols(['distance', 'mesafe', 'distance (km)', 'km']);
  final cKcal = col(['calories', 'kalori', 'kcal']);
  final cAvgHr = col(['average heart rate', 'avg hr', 'ortalama nabız']);
  final cMaxHr = col(['max heart rate', 'max hr', 'maks nabız']);
  final cMaxSpeed = col(['max speed']);
  final cElev = col(['elevation gain', 'tırmanış']);

  if (cDate == null || cTime == null) {
    throw FormatException(
      tx(
        'CSV başlıkları tanınmadı. En az "date" ve "duration" (veya "tarih", "süre") sütunları gerekli.',
        'CSV headers not recognized. At least "date" and "duration" (or "tarih", "süre") columns are required.',
      ),
    );
  }

  final out = <WorkoutSession>[];
  for (final r in rows.skip(1)) {
    String? at(int? i) => (i != null && i < r.length) ? r[i] : null;
    final type = at(cType) ?? 'Run';
    if (cType != null && !_isRunWalk(type)) continue;
    final start = parseFlexibleDate(at(cDate) ?? '');
    final dur = _duration(at(cTime));
    if (start == null || dur == null || dur <= 0) continue;

    // Strava'da ilk "Distance" km, sondaki "Distance" metre cinsindendir.
    double km = 0;
    if (isStrava && distCols.length >= 2) {
      km = (_num(at(distCols.last)) ?? 0) / 1000;
    } else if (distCols.isNotEmpty) {
      final v = _num(at(distCols.first)) ?? 0;
      km = v > 200 ? v / 1000 : v; // 200'den büyükse metre kabul et
    }
    double maxSpeed = (_num(at(cMaxSpeed)) ?? 0);
    if (isStrava) maxSpeed *= 3.6; // m/s → km/s

    out.add(
      WorkoutSession(
        id: _id(start),
        start: start,
        title: (at(cName)?.trim().isNotEmpty ?? false)
            ? at(cName)!.trim()
            : tx('İçe aktarılan koşu', 'Imported run'),
        durationSec: dur,
        distanceKm: km,
        kcal: _num(at(cKcal)) ?? _estimateKcal(km, dur),
        maxSpeed: maxSpeed,
        avgHr: _num(at(cAvgHr))?.round(),
        maxHr: _num(at(cMaxHr))?.round(),
        elevationM: _num(at(cElev)) ?? 0,
        source: isStrava ? 'Strava' : 'CSV',
      ),
    );
  }
  return ImportResult(isStrava ? 'Strava' : 'CSV', out);
}

/// Kalori bilinmiyorsa kabaca 70 kg için tahmin
double _estimateKcal(double km, int sec) =>
    km * 70 * (km / (sec / 3600) > 7.5 ? 1.0 : 0.75);

// ---------------------------------------------------------------------------
// Apple Sağlık (export.xml)
// ---------------------------------------------------------------------------

Map<String, String> _attrs(String s) => {
  for (final m in RegExp(r'(\w+)="([^"]*)"').allMatches(s)) m[1]!: m[2]!,
};

DateTime? _appleDate(String? s) {
  if (s == null) return null;
  // "2023-11-05 07:45:12 +0300"
  final m = RegExp(
    r'^(\d{4}-\d{2}-\d{2}) (\d{2}:\d{2}:\d{2}) ([+-]\d{2})(\d{2})$',
  ).firstMatch(s.trim());
  if (m != null) {
    return DateTime.tryParse('${m[1]}T${m[2]}${m[3]}:${m[4]}')?.toLocal();
  }
  return DateTime.tryParse(s);
}

ImportResult parseAppleHealth(String text) {
  final out = <WorkoutSession>[];
  final sources = <String, int>{};
  final re = RegExp(r'<Workout\s([^>]*?)(/>|>([\s\S]*?)</Workout>)');
  for (final m in re.allMatches(text)) {
    final a = _attrs(m[1]!);
    final type = a['workoutActivityType'] ?? '';
    if (!_isRunWalk(type)) continue;
    final start = _appleDate(a['startDate']);
    if (start == null) continue;
    final durRaw = double.tryParse(a['duration'] ?? '') ?? 0;
    final durSec = switch (a['durationUnit']) {
      'min' => durRaw * 60,
      'hr' || 'h' => durRaw * 3600,
      _ => durRaw,
    }.round();
    if (durSec <= 0) continue;

    double km = 0, kcal = 0;
    int? avgHr, maxHr;
    double toKm(double v, String? unit) => switch (unit) {
      'mi' => v * 1.60934,
      'm' => v / 1000,
      _ => v,
    };
    if (a['totalDistance'] != null) {
      km = toKm(
        double.tryParse(a['totalDistance']!) ?? 0,
        a['totalDistanceUnit'],
      );
    }
    if (a['totalEnergyBurned'] != null) {
      kcal = double.tryParse(a['totalEnergyBurned']!) ?? 0;
      if (a['totalEnergyBurnedUnit'] == 'kJ') kcal /= 4.184;
    }
    final body = m[3] ?? '';
    for (final st in RegExp(
      r'<WorkoutStatistics\s([^>]*)/?>',
    ).allMatches(body)) {
      final s = _attrs(st[1]!);
      final t = s['type'] ?? '';
      if (t.contains('DistanceWalkingRunning') && km == 0) {
        km = toKm(double.tryParse(s['sum'] ?? '') ?? 0, s['unit']);
      } else if (t.contains('ActiveEnergyBurned') && kcal == 0) {
        kcal = double.tryParse(s['sum'] ?? '') ?? 0;
      } else if (t.contains('HeartRate')) {
        avgHr = double.tryParse(s['average'] ?? '')?.round();
        maxHr = double.tryParse(s['maximum'] ?? '')?.round();
      }
    }
    final src = a['sourceName'] ?? tx('Apple Sağlık', 'Apple Health');
    sources[src] = (sources[src] ?? 0) + 1;
    out.add(
      WorkoutSession(
        id: _id(start),
        start: start,
        title: type.contains('Walking')
            ? tx('Yürüyüş ($src)', 'Walk ($src)')
            : tx('Koşu ($src)', 'Run ($src)'),
        durationSec: durSec,
        distanceKm: km,
        kcal: kcal > 0 ? kcal : _estimateKcal(km, durSec),
        maxSpeed: 0,
        avgHr: avgHr,
        maxHr: maxHr,
        source: src,
      ),
    );
  }
  return ImportResult(
    tx('Apple Sağlık', 'Apple Health'),
    out,
    sources: sources,
  );
}

// ---------------------------------------------------------------------------
// TCX / GPX
// ---------------------------------------------------------------------------

Iterable<XmlElement> _all(XmlNode n, String local) =>
    n.descendants.whereType<XmlElement>().where((e) => e.name.local == local);

String? _text(XmlElement e, String local) =>
    _all(e, local).firstOrNull?.innerText.trim();

List<WorkoutSession> parseTcx(String text) {
  final doc = XmlDocument.parse(text);
  final out = <WorkoutSession>[];
  for (final act in _all(doc, 'Activity')) {
    final sport = act.getAttribute('Sport') ?? 'Running';
    if (sport.toLowerCase() == 'biking') continue;
    final laps = _all(act, 'Lap').toList();
    if (laps.isEmpty) continue;
    final start = DateTime.tryParse(
      laps.first.getAttribute('StartTime') ?? _text(act, 'Id') ?? '',
    )?.toLocal();
    if (start == null) continue;
    double sec = 0, m = 0, kcal = 0, maxMs = 0;
    int maxHr = 0;
    final hrAvgs = <int>[];
    for (final l in laps) {
      sec += double.tryParse(_text(l, 'TotalTimeSeconds') ?? '') ?? 0;
      m += double.tryParse(_text(l, 'DistanceMeters') ?? '') ?? 0;
      kcal += double.tryParse(_text(l, 'Calories') ?? '') ?? 0;
      maxMs = max(maxMs, double.tryParse(_text(l, 'MaximumSpeed') ?? '') ?? 0);
      final avg = _all(l, 'AverageHeartRateBpm').firstOrNull;
      if (avg != null) hrAvgs.add(int.tryParse(_text(avg, 'Value') ?? '') ?? 0);
      final mx = _all(l, 'MaximumHeartRateBpm').firstOrNull;
      if (mx != null) {
        maxHr = max(maxHr, int.tryParse(_text(mx, 'Value') ?? '') ?? 0);
      }
    }
    // Trackpoint'lerden 5 sn'lik hız/nabız örnekleri
    final speeds = <double>[];
    final hrs = <int>[];
    DateTime? lastT;
    double? lastD;
    var nextSample = 0.0;
    for (final tp in _all(act, 'Trackpoint')) {
      final t = DateTime.tryParse(_text(tp, 'Time') ?? '');
      if (t == null) continue;
      final rel = t.difference(start.toUtc()).inMilliseconds / 1000;
      final d = double.tryParse(_text(tp, 'DistanceMeters') ?? '');
      final sp = double.tryParse(
        _all(tp, 'Speed').firstOrNull?.innerText ?? '',
      );
      double kmh = 0;
      if (sp != null) {
        kmh = sp * 3.6;
      } else if (d != null && lastD != null && lastT != null) {
        final dt = t.difference(lastT).inMilliseconds / 1000;
        if (dt > 0) kmh = (d - lastD) / dt * 3.6;
      }
      if (d != null) lastD = d;
      lastT = t;
      if (rel >= nextSample) {
        speeds.add(double.parse(kmh.toStringAsFixed(2)));
        final hrEl = _all(tp, 'HeartRateBpm').firstOrNull;
        hrs.add(
          hrEl == null ? 0 : int.tryParse(_text(hrEl, 'Value') ?? '') ?? 0,
        );
        nextSample += 5;
      }
    }
    final validHr = hrAvgs.where((h) => h > 0).toList();
    final km = m / 1000;
    out.add(
      WorkoutSession(
        id: _id(start),
        start: start,
        title: tx('İçe aktarılan koşu', 'Imported run'),
        durationSec: sec.round(),
        distanceKm: km,
        kcal: kcal > 0 ? kcal : _estimateKcal(km, sec.round()),
        maxSpeed: maxMs > 0
            ? maxMs * 3.6
            : (speeds.isEmpty ? 0 : speeds.reduce(max)),
        avgHr: validHr.isEmpty
            ? null
            : (validHr.reduce((a, b) => a + b) / validHr.length).round(),
        maxHr: maxHr > 0 ? maxHr : null,
        speedSamples: speeds,
        hrSamples: hrs,
        source: 'TCX',
      ),
    );
  }
  return out;
}

double _haversine(double lat1, double lon1, double lat2, double lon2) {
  const r = 6371000.0;
  double rad(double d) => d * pi / 180;
  final dLat = rad(lat2 - lat1), dLon = rad(lon2 - lon1);
  final a =
      sin(dLat / 2) * sin(dLat / 2) +
      cos(rad(lat1)) * cos(rad(lat2)) * sin(dLon / 2) * sin(dLon / 2);
  return 2 * r * asin(sqrt(a));
}

List<WorkoutSession> parseGpx(String text) {
  final doc = XmlDocument.parse(text);
  final out = <WorkoutSession>[];
  for (final trk in _all(doc, 'trk')) {
    final pts = _all(trk, 'trkpt').toList();
    if (pts.length < 2) continue;
    DateTime? first, last;
    double dist = 0;
    double? pLat, pLon;
    final hr = <int>[];
    for (final p in pts) {
      final t = DateTime.tryParse(_text(p, 'time') ?? '');
      if (t != null) {
        first ??= t;
        last = t;
      }
      final lat = double.tryParse(p.getAttribute('lat') ?? '');
      final lon = double.tryParse(p.getAttribute('lon') ?? '');
      if (lat != null && lon != null) {
        if (pLat != null && pLon != null) {
          dist += _haversine(pLat, pLon, lat, lon);
        }
        pLat = lat;
        pLon = lon;
      }
      final h = int.tryParse(_all(p, 'hr').firstOrNull?.innerText ?? '');
      if (h != null && h > 0) hr.add(h);
    }
    if (first == null || last == null) continue;
    final sec = last.difference(first).inSeconds;
    if (sec <= 0) continue;
    final km = dist / 1000;
    out.add(
      WorkoutSession(
        id: _id(first),
        start: first.toLocal(),
        title: _text(trk, 'name') ?? tx('İçe aktarılan koşu', 'Imported run'),
        durationSec: sec,
        distanceKm: km,
        kcal: _estimateKcal(km, sec),
        maxSpeed: 0,
        avgHr: hr.isEmpty
            ? null
            : (hr.reduce((a, b) => a + b) / hr.length).round(),
        maxHr: hr.isEmpty ? null : hr.reduce(max),
        source: 'GPX',
      ),
    );
  }
  return out;
}

// ---------------------------------------------------------------------------
// StrideFree yedeği
// ---------------------------------------------------------------------------

String buildBackup({
  required List<WorkoutSession> sessions,
  required List<WorkoutProgram> programs,
  required Map<String, dynamic> settings,
}) => const JsonEncoder.withIndent(' ').convert({
  'app': 'StrideFree',
  'version': 1,
  'exported': DateTime.now().toIso8601String(),
  'settings': settings,
  'programs': programs.map((p) => p.toJson()).toList(),
  'sessions': sessions.map((s) => s.toJson()).toList(),
});

ImportResult parseBackup(String text) {
  final j = jsonDecode(text);
  if (j is! Map || j['app'] != 'StrideFree') {
    throw FormatException(
      tx(
        'Bu bir StrideFree yedek dosyası değil.',
        'This is not a StrideFree backup file.',
      ),
    );
  }
  return ImportResult(
    tx('StrideFree yedeği', 'StrideFree backup'),
    ((j['sessions'] as List?) ?? [])
        .map(
          (e) => WorkoutSession.fromJson(Map<String, dynamic>.from(e as Map)),
        )
        .toList(),
    programs: ((j['programs'] as List?) ?? [])
        .map(
          (e) => WorkoutProgram.fromJson(Map<String, dynamic>.from(e as Map)),
        )
        .toList(),
    settings: (j['settings'] is Map && (j['settings'] as Map).isNotEmpty)
        ? (j['settings'] as Map).cast<String, dynamic>()
        : null,
  );
}

// ---------------------------------------------------------------------------
// TCX dışa aktarma (Strava, Garmin Connect vb. yüklemek için)
// ---------------------------------------------------------------------------

String buildTcx(WorkoutSession s) {
  final startUtc = s.start.toUtc();
  String iso(DateTime t) => '${t.toUtc().toIso8601String().split('.').first}Z';
  final b = XmlBuilder();
  b.processing('xml', 'version="1.0" encoding="UTF-8"');
  b.element(
    'TrainingCenterDatabase',
    nest: () {
      b.attribute(
        'xmlns',
        'http://www.garmin.com/xmlschemas/TrainingCenterDatabase/v2',
      );
      b.attribute(
        'xmlns:ns3',
        'http://www.garmin.com/xmlschemas/ActivityExtension/v2',
      );
      b.element(
        'Activities',
        nest: () {
          b.element(
            'Activity',
            nest: () {
              b.attribute('Sport', 'Running');
              b.element('Id', nest: iso(startUtc));
              b.element(
                'Lap',
                nest: () {
                  b.attribute('StartTime', iso(startUtc));
                  b.element('TotalTimeSeconds', nest: s.durationSec.toString());
                  b.element(
                    'DistanceMeters',
                    nest: (s.distanceKm * 1000).toStringAsFixed(1),
                  );
                  if (s.maxSpeed > 0) {
                    b.element(
                      'MaximumSpeed',
                      nest: (s.maxSpeed / 3.6).toStringAsFixed(3),
                    );
                  }
                  b.element('Calories', nest: s.kcal.round().toString());
                  if (s.avgHr != null) {
                    b.element(
                      'AverageHeartRateBpm',
                      nest: () => b.element('Value', nest: '${s.avgHr}'),
                    );
                  }
                  if (s.maxHr != null) {
                    b.element(
                      'MaximumHeartRateBpm',
                      nest: () => b.element('Value', nest: '${s.maxHr}'),
                    );
                  }
                  b.element('Intensity', nest: 'Active');
                  b.element('TriggerMethod', nest: 'Manual');
                  if (s.speedSamples.isNotEmpty) {
                    b.element(
                      'Track',
                      nest: () {
                        // Örneklerden kümülatif mesafe; toplam mesafeye ölçeklenir.
                        final raw = <double>[0];
                        for (final v in s.speedSamples) {
                          raw.add(raw.last + v / 3.6 * 5);
                        }
                        final scale = raw.last > 0
                            ? s.distanceKm * 1000 / raw.last
                            : 1.0;
                        for (var i = 0; i < s.speedSamples.length; i++) {
                          b.element(
                            'Trackpoint',
                            nest: () {
                              b.element(
                                'Time',
                                nest: iso(
                                  startUtc.add(Duration(seconds: (i + 1) * 5)),
                                ),
                              );
                              b.element(
                                'DistanceMeters',
                                nest: (raw[i + 1] * scale).toStringAsFixed(1),
                              );
                              final h = i < s.hrSamples.length
                                  ? s.hrSamples[i]
                                  : 0;
                              if (h > 0) {
                                b.element(
                                  'HeartRateBpm',
                                  nest: () => b.element('Value', nest: '$h'),
                                );
                              }
                              b.element(
                                'Extensions',
                                nest: () {
                                  b.element(
                                    'ns3:TPX',
                                    nest: () {
                                      b.element(
                                        'ns3:Speed',
                                        nest: (s.speedSamples[i] / 3.6)
                                            .toStringAsFixed(3),
                                      );
                                    },
                                  );
                                },
                              );
                            },
                          );
                        }
                      },
                    );
                  }
                },
              );
              b.element('Notes', nest: '${s.title} — StrideFree');
            },
          );
        },
      );
    },
  );
  return b.buildDocument().toXmlString(pretty: true);
}
