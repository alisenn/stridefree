// Uygulama durumu: ayarlar, programlar, geçmiş, cihazlar ve aktif antrenman.
import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart' show AppLifecycleListener;
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import 'background.dart';
import 'devices.dart';
import 'models.dart';

late SharedPreferences prefs;

// ---------------------------------------------------------------------------
class SettingsStore extends ChangeNotifier {
  double weightKg = prefs.getDouble('weight') ?? 75;
  int age = prefs.getInt('age') ?? 30;
  double speedLimit = prefs.getDouble('speedLimit') ?? 16;
  double speedStep = prefs.getDouble('speedStep') ?? 0.5;
  double weeklyGoalKm = prefs.getDouble('weeklyGoal') ?? 20;
  bool fitshowMiles = prefs.getBool('fsMiles') ?? false;
  bool preferFitShow = prefs.getBool('fsPrefer') ?? false;

  /// Motorlu eğimi olmayan, ön ayakları kaldırılarak eğim verilen bantlar için.
  bool manualInclineEnabled = prefs.getBool('manIncEnabled') ?? false;

  /// Eğim ayakları şu an takılı mı (antrenman ekranından açılıp kapatılır).
  bool manualInclineActive = prefs.getBool('manIncActive') ?? true;

  /// Ayaklar takılıyken bandın eğimi (%).
  double manualInclinePct = prefs.getDouble('manIncPct') ?? 4;

  /// Manuel eğim kullanılıyorsa değeri, değilse null.
  double? get manualIncline =>
      manualInclineEnabled && manualInclineActive ? manualInclinePct : null;

  void setFitShow({bool? miles, bool? prefer}) {
    if (miles != null) prefs.setBool('fsMiles', fitshowMiles = miles);
    if (prefer != null) prefs.setBool('fsPrefer', preferFitShow = prefer);
    notifyListeners();
  }

  void setManualIncline({bool? enabled, bool? active, double? pct}) {
    if (enabled != null) {
      prefs.setBool('manIncEnabled', manualInclineEnabled = enabled);
    }
    if (active != null) {
      prefs.setBool('manIncActive', manualInclineActive = active);
    }
    if (pct != null) prefs.setDouble('manIncPct', manualInclinePct = pct);
    notifyListeners();
  }

  int get maxHr => 220 - age;

  Map<String, dynamic> toJson() => {
    'weight': weightKg,
    'age': age,
    'speedLimit': speedLimit,
    'speedStep': speedStep,
    'weeklyGoal': weeklyGoalKm,
    'manIncEnabled': manualInclineEnabled,
    'manIncPct': manualInclinePct,
  };

  void restore(Map<String, dynamic> j) {
    double? d(String k) => (j[k] as num?)?.toDouble();
    setManualIncline(enabled: j['manIncEnabled'] as bool?, pct: d('manIncPct'));
    update(
      weight: d('weight'),
      age: (j['age'] as num?)?.toInt(),
      limit: d('speedLimit'),
      step: d('speedStep'),
      weekly: d('weeklyGoal'),
    );
  }

  void update({
    double? weight,
    int? age,
    double? limit,
    double? step,
    double? weekly,
  }) {
    if (weight != null) prefs.setDouble('weight', weightKg = weight);
    if (age != null) prefs.setInt('age', this.age = age);
    if (limit != null) prefs.setDouble('speedLimit', speedLimit = limit);
    if (step != null) prefs.setDouble('speedStep', speedStep = step);
    if (weekly != null) prefs.setDouble('weeklyGoal', weeklyGoalKm = weekly);
    notifyListeners();
  }

  /// Nabız bölgesi 1..5 (0 = veri yok)
  int hrZone(int? hr) {
    if (hr == null || hr <= 0) return 0;
    final p = hr / maxHr;
    if (p < 0.6) return 1;
    if (p < 0.7) return 2;
    if (p < 0.8) return 3;
    if (p < 0.9) return 4;
    return 5;
  }
}

// ---------------------------------------------------------------------------
class ProgramStore extends ChangeNotifier {
  final List<WorkoutProgram> custom = [];

  ProgramStore() {
    final raw = prefs.getString('programs');
    if (raw != null) {
      custom.addAll(
        (jsonDecode(raw) as List).map(
          (e) => WorkoutProgram.fromJson(Map<String, dynamic>.from(e as Map)),
        ),
      );
    }
  }

  List<WorkoutProgram> get all => [...builtInPrograms, ...custom];

  void _save() {
    prefs.setString(
      'programs',
      jsonEncode(custom.map((p) => p.toJson()).toList()),
    );
    notifyListeners();
  }

  void upsert(WorkoutProgram p) {
    final i = custom.indexWhere((e) => e.id == p.id);
    i >= 0 ? custom[i] = p : custom.add(p);
    _save();
  }

  void remove(String id) {
    custom.removeWhere((p) => p.id == id);
    _save();
  }

  int importMany(Iterable<WorkoutProgram> incoming) {
    var added = 0;
    for (final p in incoming) {
      if (custom.any((e) => e.id == p.id)) continue;
      custom.add(p);
      added++;
    }
    _save();
    return added;
  }
}

// ---------------------------------------------------------------------------
class HistoryStore extends ChangeNotifier {
  final List<WorkoutSession> sessions = [];

  HistoryStore() {
    final raw = prefs.getString('history');
    if (raw != null) {
      sessions.addAll(
        (jsonDecode(raw) as List).map(
          (e) => WorkoutSession.fromJson(Map<String, dynamic>.from(e as Map)),
        ),
      );
      sessions.sort((a, b) => b.start.compareTo(a.start));
    }
  }

  void _save() {
    prefs.setString(
      'history',
      jsonEncode(sessions.map((s) => s.toJson()).toList()),
    );
    notifyListeners();
  }

  void add(WorkoutSession s) {
    sessions.insert(0, s);
    _save();
  }

  void remove(String id) {
    sessions.removeWhere((s) => s.id == id);
    _save();
  }

  /// Aynı antrenman zaten varsa (başlangıç ±2 dk ve benzer süre) atlar.
  /// Eklenen sayısını döndürür.
  int importMany(Iterable<WorkoutSession> incoming) {
    var added = 0;
    for (final s in incoming) {
      final dup = sessions.any(
        (e) =>
            e.start.difference(s.start).inSeconds.abs() < 120 &&
            (e.durationSec - s.durationSec).abs() < 120,
      );
      if (dup) continue;
      sessions.add(s);
      added++;
    }
    sessions.sort((a, b) => b.start.compareTo(a.start));
    _save();
    return added;
  }

  /// Bu haftanın (Pazartesi başlangıçlı) günlük km toplamları
  List<double> thisWeekKm() {
    final now = DateTime.now();
    final monday = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(Duration(days: now.weekday - 1));
    final out = List<double>.filled(7, 0);
    for (final s in sessions) {
      final d = s.start.difference(monday).inDays;
      if (!s.start.isBefore(monday) && d < 7) out[d] += s.distanceKm;
    }
    return out;
  }

  double get totalKm => sessions.fold(0.0, (a, s) => a + s.distanceKm);
  double get totalKcal => sessions.fold(0.0, (a, s) => a + s.kcal);
  int get totalSec => sessions.fold(0, (a, s) => a + s.durationSec);

  /// Art arda antrenman yapılan gün serisi
  int get streakDays {
    if (sessions.isEmpty) return 0;
    final days = sessions
        .map((s) => DateTime(s.start.year, s.start.month, s.start.day))
        .toSet();
    var day = DateTime.now();
    day = DateTime(day.year, day.month, day.day);
    if (!days.contains(day)) day = day.subtract(const Duration(days: 1));
    var n = 0;
    while (days.contains(day)) {
      n++;
      day = day.subtract(const Duration(days: 1));
    }
    return n;
  }

  WorkoutSession? get longestRun => sessions.isEmpty
      ? null
      : sessions.reduce((a, b) => a.distanceKm >= b.distanceKm ? a : b);
}

// ---------------------------------------------------------------------------
class DeviceManager extends ChangeNotifier {
  Treadmill? treadmill;
  HeartRateMonitor? hrm;
  TreadmillData last = const TreadmillData();
  int? strapHr;
  String? error;
  bool busy = false;

  /// Antrenman sürerken true: bağlantı koparsa otomatik yeniden bağlanmayı dener.
  bool keepAlive = false;
  bool reconnecting = false;
  Future<Treadmill> Function()? _lastMake;

  final _dataCtrl = StreamController<TreadmillData>.broadcast();
  Stream<TreadmillData> get data => _dataCtrl.stream;

  StreamSubscription? _dataSub, _connSub, _hrSub;

  bool get connected => treadmill != null;
  int? get heartRate => strapHr ?? last.heartRate;

  Future<void> connectDemo() => _attach(() async => SimulatedTreadmill());

  Future<void> connectTreadmill(BluetoothDevice d, SettingsStore s) => _attach(
    () => connectAnyTreadmill(
      d,
      age: s.age,
      weightKg: s.weightKg,
      fitshowMiles: s.fitshowMiles,
      preferFitShow: s.preferFitShow,
    ),
  );

  Future<bool> _attach(Future<Treadmill> Function() make) async {
    busy = true;
    error = null;
    notifyListeners();
    var ok = false;
    try {
      await disconnectTreadmill();
      final t = await make();
      treadmill = t;
      _lastMake = t.isDemo ? null : make;
      _dataSub = t.data.listen((d) {
        last = d;
        _dataCtrl.add(d);
        notifyListeners();
      });
      _connSub = t.connection.listen((connected) {
        if (!connected && treadmill == t) {
          _clearTreadmill();
          if (keepAlive && _lastMake != null) {
            _reconnectLoop();
          } else {
            error = 'Koşu bandı bağlantısı koptu.';
            notifyListeners();
          }
        }
      });
      ok = true;
    } catch (e) {
      error = e.toString().replaceFirst('Exception: ', '');
    }
    busy = false;
    notifyListeners();
    return ok;
  }

  /// Antrenman sırasında bağlantı koparsa 2 dakika boyunca 5 sn arayla yeniden dener.
  Future<void> _reconnectLoop() async {
    if (reconnecting) return;
    reconnecting = true;
    error = 'Bağlantı koptu, yeniden bağlanılıyor…';
    notifyListeners();
    final make = _lastMake!;
    for (var i = 0; i < 24 && keepAlive && treadmill == null; i++) {
      await Future.delayed(const Duration(seconds: 5));
      if (!keepAlive || treadmill != null) break;
      if (await _attach(make)) break;
    }
    reconnecting = false;
    error = treadmill == null ? 'Koşu bandına yeniden bağlanılamadı.' : null;
    notifyListeners();
  }

  void _clearTreadmill() {
    _dataSub?.cancel();
    _connSub?.cancel();
    treadmill = null;
    last = const TreadmillData();
    notifyListeners();
  }

  Future<void> disconnectTreadmill() async {
    final t = treadmill;
    _clearTreadmill();
    await t?.disconnect();
  }

  Future<void> connectHrm(BluetoothDevice d) async {
    busy = true;
    error = null;
    notifyListeners();
    try {
      await disconnectHrm();
      final m = await HeartRateMonitor.connect(d);
      hrm = m;
      _hrSub = m.heartRate.listen((v) {
        strapHr = v > 0 ? v : null;
        notifyListeners();
      });
    } catch (e) {
      error = e.toString().replaceFirst('Exception: ', '');
    }
    busy = false;
    notifyListeners();
  }

  Future<void> disconnectHrm() async {
    await _hrSub?.cancel();
    await hrm?.disconnect();
    hrm = null;
    strapHr = null;
    notifyListeners();
  }
}

// ---------------------------------------------------------------------------
enum RunState { idle, countdown, running, paused }

const _kActiveWorkout = 'activeWorkout';

class WorkoutController extends ChangeNotifier {
  final DeviceManager dev;
  final SettingsStore settings;
  final HistoryStore history;
  late final AppLifecycleListener _lifecycle;

  WorkoutController(this.dev, this.settings, this.history) {
    // Uygulama arka plana giderken anında kaydet.
    _lifecycle = AppLifecycleListener(
      onHide: _autosave,
      onPause: _autosave,
      onDetach: _autosave,
    );
  }

  RunState state = RunState.idle;
  int countdown = 0;
  WorkoutProgram? program;
  Goal goal = Goal.none;

  int elapsed = 0;
  double distanceM = 0;
  double kcal = 0;
  double elevationM = 0;
  double maxSpeed = 0;
  double targetSpeed = 0;
  double targetIncline = 0;
  int segmentIndex = -1;
  final List<double> speedSamples = [];
  final List<int> hrSamples = [];
  double _hrSum = 0, _hrWeight = 0;
  int _maxHr = 0;

  /// Bağlantı kopması yüzünden otomatik duraklatıldı
  bool pausedByDisconnect = false;

  Timer? _timer;
  StreamSubscription? _dataSub;
  int? _lastDeviceDist;
  bool _usingDeviceDist = false;
  DateTime? _startTime;

  // Süre gerçek saatten hesaplanır: uygulama bir süre uyusa bile kayma olmaz.
  double _accumSec = 0;
  DateTime? _runningSince;
  DateTime? _lastTick;
  int _nextSampleAt = 5;
  int _lastSavedAt = 0;

  double get speed => dev.last.speedKmh ?? 0;

  /// Manuel eğim açıksa bandın bildirdiği değer yerine onu kullan
  /// (bu tür bantlar eğimi bilmez, genelde 0 bildirir).
  double get incline =>
      settings.manualIncline ?? dev.last.inclinePct ?? targetIncline;
  int? get hr => dev.heartRate;
  bool get active => state != RunState.idle;

  double? get paceMinPerKm => speed < 0.5 ? null : 60 / speed;

  int _elapsedNow() {
    final run = _runningSince == null
        ? 0.0
        : DateTime.now().difference(_runningSince!).inMilliseconds / 1000;
    return (_accumSec + run).floor();
  }

  Segment? get currentSegment =>
      (program != null &&
          segmentIndex >= 0 &&
          segmentIndex < program!.segments.length)
      ? program!.segments[segmentIndex]
      : null;

  Segment? get nextSegment =>
      (program != null && segmentIndex + 1 < program!.segments.length)
      ? program!.segments[segmentIndex + 1]
      : null;

  int get segmentRemaining {
    if (program == null || segmentIndex < 0) return 0;
    var end = 0;
    for (var i = 0; i <= segmentIndex; i++) {
      end += program!.segments[i].durationSec;
    }
    return end - elapsed;
  }

  /// 0..1 – hedefe / programa göre ilerleme (serbest koşuda null)
  double? get progress {
    if (program != null) return (elapsed / program!.totalSec).clamp(0, 1);
    return switch (goal.type) {
      GoalType.none => null,
      GoalType.time => (elapsed / (goal.value * 60)).clamp(0, 1),
      GoalType.distance => (distanceM / 1000 / goal.value).clamp(0, 1),
      GoalType.calories => (kcal / goal.value).clamp(0, 1),
    };
  }

  String get title =>
      program?.name ??
      (goal.type == GoalType.none ? 'Serbest Koşu' : 'Hedef: ${goal.label}');

  // ---------------- akış ----------------

  Future<void> begin({WorkoutProgram? program, Goal goal = Goal.none}) async {
    if (dev.treadmill == null || active) return;
    this.program = program;
    this.goal = goal;
    _reset();
    WakelockPlus.enable().catchError((_) {});
    state = RunState.countdown;
    countdown = 3;
    notifyListeners();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) async {
      if (state != RunState.countdown) return;
      countdown--;
      HapticFeedback.mediumImpact();
      if (countdown <= 0) {
        _timer?.cancel();
        await _startRunning();
      }
      notifyListeners();
    });
  }

  void _reset() {
    elapsed = 0;
    distanceM = 0;
    kcal = 0;
    elevationM = 0;
    maxSpeed = 0;
    segmentIndex = -1;
    speedSamples.clear();
    hrSamples.clear();
    _hrSum = _hrWeight = 0;
    _maxHr = 0;
    _lastDeviceDist = null;
    _usingDeviceDist = false;
    _accumSec = 0;
    _runningSince = null;
    _lastTick = null;
    _nextSampleAt = 5;
    _lastSavedAt = 0;
    pausedByDisconnect = false;
  }

  Future<void> _startRunning() async {
    final t = dev.treadmill;
    if (t == null) {
      finish();
      return;
    }
    _startTime = DateTime.now();
    _runningSince = _startTime;
    _lastTick = _startTime;
    state = RunState.running;
    dev.keepAlive = true;
    WorkoutBackground.start(title, 'Antrenman başladı');
    await t.start();
    if (program != null) {
      _applySegment(0);
    } else {
      targetSpeed = 3.0;
      await t.setSpeed(targetSpeed);
    }
    _dataSub = dev.data.listen(_onData);
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
    notifyListeners();
  }

  void _onData(TreadmillData d) {
    final dist = d.totalDistanceM;
    if (dist != null) {
      if (state == RunState.running && _lastDeviceDist != null) {
        final delta = dist - _lastDeviceDist!;
        if (delta >= 0 && delta < 5000) {
          distanceM += delta;
          elevationM += delta * (incline / 100);
          _usingDeviceDist = true;
        }
      }
      _lastDeviceDist = dist;
    }
  }

  void _tick() {
    if (state == RunState.paused) {
      notifyListeners();
      return;
    }
    if (state != RunState.running) return;

    // Bant bağlantısı koptuysa otomatik duraklat (süre ve mesafe saymayı bırak).
    if (dev.treadmill == null) {
      _pauseClock();
      state = RunState.paused;
      pausedByDisconnect = true;
      _autosave();
      HapticFeedback.heavyImpact();
      notifyListeners();
      return;
    }

    final now = DateTime.now();
    // Uygulama bir süre uyuduysa aradaki süreyi de hesaba kat (en fazla 10 dk).
    final dt = (now.difference(_lastTick ?? now).inMilliseconds / 1000).clamp(
      0.0,
      600.0,
    );
    _lastTick = now;
    elapsed = _elapsedNow();

    final v = speed;
    if (!_usingDeviceDist) {
      distanceM += v / 3.6 * dt;
      elevationM += v / 3.6 * dt * (incline / 100);
    }
    kcal += _kcalPerSec(v, incline) * dt;
    if (v > maxSpeed) maxSpeed = v;
    final h = hr;
    if (h != null && h > 0) {
      _hrSum += h * dt;
      _hrWeight += dt;
      if (h > _maxHr) _maxHr = h;
    }
    while (elapsed >= _nextSampleAt) {
      speedSamples.add(v);
      hrSamples.add(h ?? 0);
      _nextSampleAt += 5;
    }
    if (elapsed - _lastSavedAt >= 5) {
      _lastSavedAt = elapsed;
      _autosave();
      WorkoutBackground.update(
        title,
        '${fmtDuration(elapsed)} · ${(distanceM / 1000).toStringAsFixed(2)} km · ${kcal.round()} kcal',
      );
    }

    if (program != null) {
      var acc = 0, idx = program!.segments.length;
      for (var i = 0; i < program!.segments.length; i++) {
        acc += program!.segments[i].durationSec;
        if (elapsed < acc) {
          idx = i;
          break;
        }
      }
      if (idx >= program!.segments.length) {
        finish();
        return;
      }
      if (idx != segmentIndex) _applySegment(idx);
    } else {
      final done = switch (goal.type) {
        GoalType.none => false,
        GoalType.time => elapsed >= goal.value * 60,
        GoalType.distance => distanceM >= goal.value * 1000,
        GoalType.calories => kcal >= goal.value,
      };
      if (done) {
        finish();
        return;
      }
    }
    notifyListeners();
  }

  void _pauseClock() {
    if (_runningSince != null) {
      _accumSec +=
          DateTime.now().difference(_runningSince!).inMilliseconds / 1000;
      _runningSince = null;
    }
    elapsed = _accumSec.floor();
  }

  void _resumeClock() {
    _runningSince = DateTime.now();
    _lastTick = _runningSince;
  }

  /// ACSM metabolik denklemleri – kilonuza göre kalori
  double _kcalPerSec(double kmh, double inclinePct) {
    if (kmh < 0.5) return 0;
    final v = kmh * 1000 / 60; // m/dk
    final g = inclinePct / 100;
    final vo2 = kmh < 8
        ? 0.1 * v + 1.8 * v * g + 3.5
        : 0.2 * v + 0.9 * v * g + 3.5;
    return vo2 * settings.weightKg / 1000 * 5 / 60;
  }

  void _applySegment(int i) {
    segmentIndex = i;
    final s = program!.segments[i];
    HapticFeedback.heavyImpact();
    setSpeed(s.speed);
    setIncline(s.incline);
  }

  Future<void> setSpeed(double v) async {
    final t = dev.treadmill;
    if (t == null) return;
    final lim = settings.speedLimit < t.maxSpeed
        ? settings.speedLimit
        : t.maxSpeed;
    targetSpeed = double.parse(v.clamp(t.minSpeed, lim).toStringAsFixed(1));
    notifyListeners();
    await t.setSpeed(targetSpeed);
  }

  Future<void> setIncline(double v) async {
    final t = dev.treadmill;
    if (t == null) return;
    targetIncline = double.parse(
      v.clamp(t.minIncline, t.maxIncline).toStringAsFixed(1),
    );
    notifyListeners();
    await t.setIncline(targetIncline);
  }

  void nudgeSpeed(int dir) => setSpeed(targetSpeed + dir * settings.speedStep);
  void nudgeIncline(int dir) => setIncline(targetIncline + dir);

  /// Duraklat / devam. Bant bağlı değilse devam edemez (false döner).
  Future<bool> togglePause() async {
    final t = dev.treadmill;
    if (state == RunState.running) {
      _pauseClock();
      state = RunState.paused;
      _autosave();
      notifyListeners();
      await t?.pause();
      return true;
    }
    if (state == RunState.paused) {
      if (t == null) return false;
      pausedByDisconnect = false;
      state = RunState.running;
      _resumeClock();
      notifyListeners();
      await t.start();
      await t.setSpeed(targetSpeed);
      if (targetIncline != 0) await t.setIncline(targetIncline);
      return true;
    }
    return false;
  }

  WorkoutSession? _snapshot() {
    if (_startTime == null) return null;
    return WorkoutSession(
      id: _startTime!.microsecondsSinceEpoch.toString(),
      start: _startTime!,
      title: title,
      durationSec: elapsed,
      distanceKm: distanceM / 1000,
      kcal: kcal,
      maxSpeed: maxSpeed,
      avgHr: _hrWeight > 0 ? (_hrSum / _hrWeight).round() : null,
      maxHr: _maxHr > 0 ? _maxHr : null,
      elevationM: elevationM,
      speedSamples: List.of(speedSamples),
      hrSamples: List.of(hrSamples),
    );
  }

  /// Devam eden antrenmanı telefona yazar; uygulama öldürülse bile kaybolmaz.
  void _autosave() {
    if (state != RunState.running && state != RunState.paused) return;
    if (state == RunState.running) elapsed = _elapsedNow();
    final s = _snapshot();
    if (s == null || s.durationSec < 1) return;
    prefs.setString(_kActiveWorkout, jsonEncode(s.toJson()));
  }

  void _clearAutosave() => prefs.remove(_kActiveWorkout);

  /// Bitirir, kaydeder ve oturumu döndürür (çok kısa ise kaydetmez).
  WorkoutSession? finish() {
    if (state == RunState.idle) return null;
    if (state == RunState.running) _pauseClock();
    _timer?.cancel();
    _dataSub?.cancel();
    dev.keepAlive = false;
    dev.treadmill?.stop();
    WakelockPlus.disable().catchError((_) {});
    WorkoutBackground.stop();
    WorkoutSession? s;
    if (elapsed >= 20) {
      s = _snapshot();
      if (s != null) history.add(s);
    }
    _clearAutosave();
    lastFinished = s;
    state = RunState.idle;
    targetSpeed = 0;
    targetIncline = 0;
    pausedByDisconnect = false;
    notifyListeners();
    return s;
  }

  WorkoutSession? lastFinished;

  // ---------------- kurtarma ----------------

  /// Önceki çalıştırmada yarım kalmış (uygulama kapanmış) antrenman.
  WorkoutSession? get recoverable {
    if (active) return null;
    final raw = prefs.getString(_kActiveWorkout);
    if (raw == null) return null;
    try {
      final s = WorkoutSession.fromJson(
        Map<String, dynamic>.from(jsonDecode(raw) as Map),
      );
      return s.durationSec >= 20 ? s : null;
    } catch (_) {
      return null;
    }
  }

  void resolveRecovery({required bool save}) {
    final s = recoverable;
    if (save && s != null) history.importMany([s]);
    _clearAutosave();
    notifyListeners();
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    _timer?.cancel();
    _dataSub?.cancel();
    super.dispose();
  }
}
