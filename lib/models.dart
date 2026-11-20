// Veri modelleri: cihaz verisi, program segmentleri, antrenman kayıtları.

import 'l10n.dart';

class TreadmillData {
  final double? speedKmh;
  final double? inclinePct;
  final int? totalDistanceM;
  final int? kcal;
  final int? heartRate;
  final int? elapsedS;

  const TreadmillData({
    this.speedKmh,
    this.inclinePct,
    this.totalDistanceM,
    this.kcal,
    this.heartRate,
    this.elapsedS,
  });

  /// [next]'te olmayan alanları bu paketten tamamlar.
  /// FTMS bantları veriyi "More Data" bayrağıyla birden fazla pakete bölebilir
  /// (ör. biri hız, diğeri mesafe); son paketi tek başına almak hızı kaybettirir.
  TreadmillData merge(TreadmillData next) => TreadmillData(
    speedKmh: next.speedKmh ?? speedKmh,
    inclinePct: next.inclinePct ?? inclinePct,
    totalDistanceM: next.totalDistanceM ?? totalDistanceM,
    kcal: next.kcal ?? kcal,
    heartRate: next.heartRate ?? heartRate,
    elapsedS: next.elapsedS ?? elapsedS,
  );
}

class Segment {
  int durationSec;
  double speed; // km/h
  double incline; // %

  Segment({required this.durationSec, required this.speed, this.incline = 0});

  Segment copy() =>
      Segment(durationSec: durationSec, speed: speed, incline: incline);

  Map<String, dynamic> toJson() => {'d': durationSec, 's': speed, 'i': incline};

  factory Segment.fromJson(Map<String, dynamic> j) => Segment(
    durationSec: (j['d'] as num).toInt(),
    speed: (j['s'] as num).toDouble(),
    incline: (j['i'] as num?)?.toDouble() ?? 0,
  );
}

class WorkoutProgram {
  final String id;
  String name;
  String description;
  List<Segment> segments;
  final bool builtIn;

  WorkoutProgram({
    required this.id,
    required this.name,
    this.description = '',
    required this.segments,
    this.builtIn = false,
  });

  int get totalSec => segments.fold(0, (a, s) => a + s.durationSec);
  double get maxSpeed =>
      segments.fold(0.0, (a, s) => s.speed > a ? s.speed : a);
  double get estimatedKm =>
      segments.fold(0.0, (a, s) => a + s.speed * s.durationSec / 3600);

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'desc': description,
    'segments': segments.map((s) => s.toJson()).toList(),
  };

  factory WorkoutProgram.fromJson(Map<String, dynamic> j) => WorkoutProgram(
    id: j['id'] as String,
    name: j['name'] as String,
    description: (j['desc'] as String?) ?? '',
    segments: (j['segments'] as List)
        .map((e) => Segment.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList(),
  );
}

enum GoalType { none, time, distance, calories }

class Goal {
  final GoalType type;
  final double value; // dakika / km / kcal

  const Goal(this.type, this.value);
  static const none = Goal(GoalType.none, 0);

  String get label => switch (type) {
    GoalType.none => tx('Serbest', 'Free'),
    GoalType.time => '${value.toStringAsFixed(0)} ${tx('dk', 'min')}',
    GoalType.distance => '${value.toStringAsFixed(1)} km',
    GoalType.calories => '${value.toStringAsFixed(0)} kcal',
  };
}

class WorkoutSession {
  final String id;
  final DateTime start;
  final String title;
  final int durationSec;
  final double distanceKm;
  final double kcal;
  final double maxSpeed;
  final int? avgHr;
  final int? maxHr;
  final double elevationM;
  final List<double> speedSamples; // her 5 sn
  final List<int> hrSamples; // her 5 sn (0 = veri yok)
  final String?
  source; // içe aktarıldıysa kaynak: 'Strava', 'Apple Sağlık', 'TCX'...

  WorkoutSession({
    required this.id,
    required this.start,
    required this.title,
    required this.durationSec,
    required this.distanceKm,
    required this.kcal,
    required this.maxSpeed,
    this.avgHr,
    this.maxHr,
    this.elevationM = 0,
    this.speedSamples = const [],
    this.hrSamples = const [],
    this.source,
  });

  double get avgSpeed =>
      durationSec == 0 ? 0 : distanceKm / (durationSec / 3600);

  /// Ortalama tempo (dk/km)
  double? get paceMinPerKm =>
      distanceKm < 0.01 ? null : (durationSec / 60) / distanceKm;

  Map<String, dynamic> toJson() => {
    'id': id,
    'start': start.toIso8601String(),
    'title': title,
    'dur': durationSec,
    'km': distanceKm,
    'kcal': kcal,
    'max': maxSpeed,
    'ahr': avgHr,
    'mhr': maxHr,
    'elev': elevationM,
    'ss': speedSamples,
    'hs': hrSamples,
    if (source != null) 'src': source,
  };

  factory WorkoutSession.fromJson(Map<String, dynamic> j) => WorkoutSession(
    id: j['id'] as String,
    start: DateTime.parse(j['start'] as String),
    title: j['title'] as String,
    durationSec: (j['dur'] as num).toInt(),
    distanceKm: (j['km'] as num).toDouble(),
    kcal: (j['kcal'] as num).toDouble(),
    maxSpeed: (j['max'] as num).toDouble(),
    avgHr: (j['ahr'] as num?)?.toInt(),
    maxHr: (j['mhr'] as num?)?.toInt(),
    elevationM: (j['elev'] as num?)?.toDouble() ?? 0,
    speedSamples: ((j['ss'] as List?) ?? [])
        .map((e) => (e as num).toDouble())
        .toList(),
    hrSamples: ((j['hs'] as List?) ?? [])
        .map((e) => (e as num).toInt())
        .toList(),
    source: j['src'] as String?,
  );
}

// ---------- Biçimlendirme yardımcıları ----------

String fmtDuration(int sec) {
  final h = sec ~/ 3600, m = (sec % 3600) ~/ 60, s = sec % 60;
  String two(int v) => v.toString().padLeft(2, '0');
  return h > 0 ? '$h:${two(m)}:${two(s)}' : '${two(m)}:${two(s)}';
}

String fmtPace(double? minPerKm) {
  if (minPerKm == null ||
      minPerKm.isInfinite ||
      minPerKm.isNaN ||
      minPerKm > 60) {
    return '--:--';
  }
  final total = (minPerKm * 60).round();
  return '${total ~/ 60}:${(total % 60).toString().padLeft(2, '0')}';
}

// ---------- Hazır programlar (hepsi ücretsiz) ----------

List<Segment> _intervals(
  int reps,
  int fastSec,
  double fast,
  int slowSec,
  double slow, {
  double incline = 0,
}) {
  return [
    for (var i = 0; i < reps; i++) ...[
      Segment(durationSec: fastSec, speed: fast, incline: incline),
      Segment(durationSec: slowSec, speed: slow, incline: incline),
    ],
  ];
}

/// Getter: dil değişince adlar ve açıklamalar da değişir.
List<WorkoutProgram> get builtInPrograms => [
  WorkoutProgram(
    id: 'b_walk',
    name: tx('Tempolu Yürüyüş', 'Brisk Walk'),
    description: tx(
      'Başlangıç için 30 dk düşük tempolu yürüyüş, hafif eğim.',
      '30 min easy-paced walk with a slight incline. Great for beginners.',
    ),
    builtIn: true,
    segments: [
      Segment(durationSec: 300, speed: 4.0),
      Segment(durationSec: 600, speed: 5.5, incline: 2),
      Segment(durationSec: 600, speed: 6.0, incline: 3),
      Segment(durationSec: 300, speed: 5.5, incline: 1),
      Segment(durationSec: 300, speed: 4.0),
    ],
  ),
  WorkoutProgram(
    id: 'b_hiit',
    name: 'HIIT 20',
    description: tx(
      '8 tur 30 sn sprint / 90 sn toparlanma. Yağ yakımı için ideal.',
      '8 rounds of 30 s sprint / 90 s recovery. Ideal for burning fat.',
    ),
    builtIn: true,
    segments: [
      Segment(durationSec: 180, speed: 5.0),
      ..._intervals(8, 30, 12.0, 90, 5.5),
      Segment(durationSec: 120, speed: 4.5),
    ],
  ),
  WorkoutProgram(
    id: 'b_hill',
    name: tx('Tepe Tırmanışı', 'Hill Climb'),
    description: tx(
      'Eğimi kademeli artıran, bacak kuvveti odaklı 25 dk.',
      '25 min of gradually rising incline, focused on leg strength.',
    ),
    builtIn: true,
    segments: [
      Segment(durationSec: 180, speed: 5.0),
      Segment(durationSec: 180, speed: 5.5, incline: 3),
      Segment(durationSec: 180, speed: 5.5, incline: 5),
      Segment(durationSec: 180, speed: 5.5, incline: 7),
      Segment(durationSec: 180, speed: 5.0, incline: 9),
      Segment(durationSec: 180, speed: 5.0, incline: 11),
      Segment(durationSec: 180, speed: 5.5, incline: 6),
      Segment(durationSec: 240, speed: 4.5),
    ],
  ),
  WorkoutProgram(
    id: 'b_12330',
    name: tx('Eğimli 30', 'Incline 30'),
    description: tx(
      '%12 eğim, 4.8 km/s, 30 dakika. Klasik eğimli yürüyüş.',
      '12% incline, 4.8 km/h, 30 minutes. The classic incline walk.',
    ),
    builtIn: true,
    segments: [
      Segment(durationSec: 120, speed: 4.0, incline: 4),
      Segment(durationSec: 1800, speed: 4.8, incline: 12),
      Segment(durationSec: 120, speed: 4.0, incline: 2),
    ],
  ),
  WorkoutProgram(
    id: 'b_c25k',
    name: tx('5K Hazırlık – 1. Hafta', '5K Prep – Week 1'),
    description: tx(
      '60 sn koşu / 90 sn yürüyüş × 8. Sıfırdan 5K koşusuna giden plan.',
      '60 s run / 90 s walk × 8. The plan that takes you from zero to 5K.',
    ),
    builtIn: true,
    segments: [
      Segment(durationSec: 300, speed: 5.0),
      ..._intervals(8, 60, 8.0, 90, 5.5),
      Segment(durationSec: 300, speed: 4.5),
    ],
  ),
  WorkoutProgram(
    id: 'b_pyramid',
    name: tx('Piramit Koşu', 'Pyramid Run'),
    description: tx(
      'Hız 7→11→7 km/s, her basamak 2 dk.',
      'Speed 7→11→7 km/h, 2 min per step.',
    ),
    builtIn: true,
    segments: [
      Segment(durationSec: 180, speed: 5.0),
      for (final s in [7.0, 8.0, 9.0, 10.0, 11.0, 10.0, 9.0, 8.0, 7.0])
        Segment(durationSec: 120, speed: s),
      Segment(durationSec: 180, speed: 5.0),
    ],
  ),
  WorkoutProgram(
    id: 'b_fatburn',
    name: tx('Yağ Yakım Bölgesi', 'Fat Burn Zone'),
    description: tx(
      '40 dk orta tempo, nabzı %60-70 bölgesinde tutar.',
      '40 min at a moderate pace, keeps heart rate in the 60–70% zone.',
    ),
    builtIn: true,
    segments: [
      Segment(durationSec: 300, speed: 5.0),
      Segment(durationSec: 600, speed: 6.5, incline: 2),
      Segment(durationSec: 600, speed: 7.0, incline: 3),
      Segment(durationSec: 600, speed: 6.5, incline: 4),
      Segment(durationSec: 300, speed: 5.0),
    ],
  ),
];
