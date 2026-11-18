// Uygulama durumu: ayarlar, programlar, geçmiş, cihazlar ve aktif antrenman.
import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

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

  int get maxHr => 220 - age;

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

  final _dataCtrl = StreamController<TreadmillData>.broadcast();
  Stream<TreadmillData> get data => _dataCtrl.stream;

  StreamSubscription? _dataSub, _connSub, _hrSub;

  bool get connected => treadmill != null;
  int? get heartRate => strapHr ?? last.heartRate;

  Future<void> connectDemo() => _attach(() async => SimulatedTreadmill());

  Future<void> connectTreadmill(BluetoothDevice d) =>
      _attach(() => FtmsTreadmill.connect(d));

  Future<void> _attach(Future<Treadmill> Function() make) async {
    busy = true;
    error = null;
    notifyListeners();
    try {
      await disconnectTreadmill();
      final t = await make();
      treadmill = t;
      _dataSub = t.data.listen((d) {
        last = d;
        _dataCtrl.add(d);
        notifyListeners();
      });
      _connSub = t.connection.listen((ok) {
        if (!ok && treadmill == t) {
          error = 'Koşu bandı bağlantısı koptu.';
          _clearTreadmill();
        }
      });
    } catch (e) {
      error = e.toString().replaceFirst('Exception: ', '');
    }
    busy = false;
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

class WorkoutController extends ChangeNotifier {
  final DeviceManager dev;
  final SettingsStore settings;
  final HistoryStore history;

  WorkoutController(this.dev, this.settings, this.history);

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
  int _hrSum = 0, _hrCount = 0, _maxHr = 0;

  Timer? _timer;
  StreamSubscription? _dataSub;
  int? _lastDeviceDist;
  bool _usingDeviceDist = false;
  DateTime? _startTime;

  double get speed => dev.last.speedKmh ?? 0;
  double get incline => dev.last.inclinePct ?? targetIncline;
  int? get hr => dev.heartRate;
  bool get active => state != RunState.idle;

  double? get paceMinPerKm => speed < 0.5 ? null : 60 / speed;

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
    _hrSum = _hrCount = _maxHr = 0;
    _lastDeviceDist = null;
    _usingDeviceDist = false;
  }

  Future<void> _startRunning() async {
    final t = dev.treadmill!;
    _startTime = DateTime.now();
    state = RunState.running;
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
        if (delta >= 0 && delta < 60) {
          distanceM += delta;
          elevationM += delta * (incline / 100);
          _usingDeviceDist = true;
        }
      }
      _lastDeviceDist = dist;
    }
  }

  void _tick() {
    if (state != RunState.running) return;
    elapsed++;
    final v = speed;
    if (!_usingDeviceDist) {
      distanceM += v / 3.6;
      elevationM += v / 3.6 * (incline / 100);
    }
    kcal += _kcalPerSec(v, incline);
    if (v > maxSpeed) maxSpeed = v;
    final h = hr;
    if (h != null && h > 0) {
      _hrSum += h;
      _hrCount++;
      if (h > _maxHr) _maxHr = h;
    }
    if (elapsed % 5 == 0) {
      speedSamples.add(v);
      hrSamples.add(h ?? 0);
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

  Future<void> togglePause() async {
    final t = dev.treadmill;
    if (t == null) return;
    if (state == RunState.running) {
      state = RunState.paused;
      await t.pause();
    } else if (state == RunState.paused) {
      state = RunState.running;
      await t.start();
      await t.setSpeed(targetSpeed);
    }
    notifyListeners();
  }

  /// Bitirir, kaydeder ve oturumu döndürür (çok kısa ise kaydetmez).
  WorkoutSession? finish() {
    if (state == RunState.idle) return null;
    _timer?.cancel();
    _dataSub?.cancel();
    dev.treadmill?.stop();
    WakelockPlus.disable().catchError((_) {});
    WorkoutSession? s;
    if (elapsed >= 20 && _startTime != null) {
      s = WorkoutSession(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        start: _startTime!,
        title: title,
        durationSec: elapsed,
        distanceKm: distanceM / 1000,
        kcal: kcal,
        maxSpeed: maxSpeed,
        avgHr: _hrCount > 0 ? (_hrSum / _hrCount).round() : null,
        maxHr: _maxHr > 0 ? _maxHr : null,
        elevationM: elevationM,
        speedSamples: List.of(speedSamples),
        hrSamples: List.of(hrSamples),
      );
      history.add(s);
    }
    lastFinished = s;
    state = RunState.idle;
    targetSpeed = 0;
    targetIncline = 0;
    notifyListeners();
    return s;
  }

  WorkoutSession? lastFinished;

  @override
  void dispose() {
    _timer?.cancel();
    _dataSub?.cancel();
    super.dispose();
  }
}
