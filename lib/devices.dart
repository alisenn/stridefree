// Bluetooth cihaz katmanı: FTMS koşu bandı, nabız bandı ve demo (simülasyon) bandı.
import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import 'models.dart';

/// flutter_blue_plus lisansı: kişisel / kâr amacı gütmeyen kullanım ücretsiz.
/// Uygulamayı ticari bir şirket olarak yayınlarsanız [License.commercial] gerekir.
const kBleLicense = License.nonprofit;

// Bluetooth SIG standart UUID'leri
final ftmsService = Guid('1826');
final treadmillDataChar = Guid('2ACD');
final controlPointChar = Guid('2AD9');
final speedRangeChar = Guid('2AD4');
final inclineRangeChar = Guid('2AD5');
final hrService = Guid('180D');
final hrMeasurementChar = Guid('2A37');

abstract class Treadmill {
  String get name;
  bool get isDemo => false;
  Stream<TreadmillData> get data;
  Stream<bool> get connection;

  double minSpeed = 1.0;
  double maxSpeed = 16.0;
  double minIncline = 0;
  double maxIncline = 15;
  bool supportsIncline = true;

  Future<void> start();
  Future<void> pause();
  Future<void> stop();
  Future<void> setSpeed(double kmh);
  Future<void> setIncline(double pct);
  Future<void> disconnect();
}

// ---------------------------------------------------------------------------
// FTMS ayrıştırıcı (Fitness Machine Service, Treadmill Data 0x2ACD)
// ---------------------------------------------------------------------------

class _Reader {
  final List<int> b;
  int i = 0;
  _Reader(this.b);
  bool has(int n) => i + n <= b.length;
  int u8() => b[i++];
  int u16() {
    final v = b[i] | (b[i + 1] << 8);
    i += 2;
    return v;
  }

  int s16() {
    final v = u16();
    return v >= 0x8000 ? v - 0x10000 : v;
  }

  int u24() {
    final v = b[i] | (b[i + 1] << 8) | (b[i + 2] << 16);
    i += 3;
    return v;
  }
}

@visibleForTesting
TreadmillData parseTreadmillData(List<int> bytes) {
  if (bytes.length < 2) return const TreadmillData();
  final r = _Reader(bytes);
  final flags = r.u16();
  bool f(int bit) => (flags & (1 << bit)) != 0;

  double? speed, incline;
  int? dist, kcal, hr, elapsed;
  try {
    if (!f(0) && r.has(2)) speed = r.u16() / 100.0; // bit0=0 → anlık hız var
    if (f(1) && r.has(2)) r.u16(); // ortalama hız
    if (f(2) && r.has(3)) dist = r.u24();
    if (f(3) && r.has(4)) {
      incline = r.s16() / 10.0;
      r.s16(); // rampa açısı
    }
    if (f(4) && r.has(4)) {
      r.u16();
      r.u16(); // yükseklik kazancı +/-
    }
    if (f(5) && r.has(1)) r.u8(); // anlık tempo
    if (f(6) && r.has(1)) r.u8(); // ortalama tempo
    if (f(7) && r.has(5)) {
      kcal = r.u16();
      r.u16();
      r.u8();
    }
    if (f(8) && r.has(1)) hr = r.u8();
    if (f(9) && r.has(1)) r.u8(); // MET
    if (f(10) && r.has(2)) elapsed = r.u16();
  } catch (_) {
    // Kısa / standart dışı paketlerde elde edilenle devam
  }
  return TreadmillData(
    speedKmh: speed,
    inclinePct: incline,
    totalDistanceM: dist,
    kcal: (kcal != null && kcal != 0xFFFF) ? kcal : null,
    heartRate: (hr != null && hr > 0) ? hr : null,
    elapsedS: elapsed,
  );
}

@visibleForTesting
int parseHeartRate(List<int> b) {
  if (b.length < 2) return 0;
  final is16 = (b[0] & 0x01) != 0;
  if (is16 && b.length >= 3) return b[1] | (b[2] << 8);
  return b[1];
}

// ---------------------------------------------------------------------------
// Gerçek FTMS koşu bandı
// ---------------------------------------------------------------------------

class FtmsTreadmill extends Treadmill {
  final BluetoothDevice device;
  BluetoothCharacteristic? _cp;
  final _data = StreamController<TreadmillData>.broadcast();
  final _conn = StreamController<bool>.broadcast();
  final List<StreamSubscription> _subs = [];

  FtmsTreadmill._(this.device);

  @override
  String get name => device.platformName.isNotEmpty
      ? device.platformName
      : (device.advName.isNotEmpty ? device.advName : device.remoteId.str);

  @override
  Stream<TreadmillData> get data => _data.stream;
  @override
  Stream<bool> get connection => _conn.stream;

  static Future<FtmsTreadmill> connect(BluetoothDevice device) async {
    final t = FtmsTreadmill._(device);
    await t._setup();
    return t;
  }

  Future<void> _setup() async {
    await device.connect(
      license: kBleLicense,
      timeout: const Duration(seconds: 15),
    );
    _subs.add(
      device.connectionState.listen((s) {
        _conn.add(s == BluetoothConnectionState.connected);
      }),
    );

    final services = await device.discoverServices();
    final ftms = services.where((s) => s.uuid == ftmsService).firstOrNull;
    if (ftms == null) {
      await device.disconnect();
      throw Exception(
        'Bu cihaz standart FTMS desteklemiyor. Bandınızın Bluetooth FTMS uyumlu olduğundan emin olun.',
      );
    }

    BluetoothCharacteristic? find(Guid g) =>
        ftms.characteristics.where((c) => c.uuid == g).firstOrNull;

    final dataC = find(treadmillDataChar);
    if (dataC != null) {
      _subs.add(
        dataC.onValueReceived.listen((v) => _data.add(parseTreadmillData(v))),
      );
      await dataC.setNotifyValue(true);
    }

    final sr = find(speedRangeChar);
    if (sr != null) {
      try {
        final r = _Reader(await sr.read());
        if (r.has(4)) {
          minSpeed = r.u16() / 100;
          maxSpeed = r.u16() / 100;
        }
      } catch (_) {}
    }
    final ir = find(inclineRangeChar);
    supportsIncline = ir != null;
    if (ir != null) {
      try {
        final r = _Reader(await ir.read());
        if (r.has(4)) {
          minIncline = r.s16() / 10;
          maxIncline = r.s16() / 10;
        }
      } catch (_) {}
    }

    _cp = find(controlPointChar);
    if (_cp != null) {
      try {
        await _cp!.setNotifyValue(true); // indication
      } catch (_) {}
      await _write([0x00]); // Request Control
    }
  }

  Future<void> _write(List<int> bytes) async {
    final cp = _cp;
    if (cp == null) return;
    try {
      await cp.write(bytes, withoutResponse: false);
    } catch (e) {
      debugPrint('FTMS yazma hatası: $e');
    }
  }

  @override
  Future<void> start() => _write([0x07]);
  @override
  Future<void> pause() => _write([0x08, 0x02]);
  @override
  Future<void> stop() => _write([0x08, 0x01]);

  @override
  Future<void> setSpeed(double kmh) {
    final v = (kmh.clamp(minSpeed, maxSpeed) * 100).round();
    return _write([0x02, v & 0xFF, (v >> 8) & 0xFF]);
  }

  @override
  Future<void> setIncline(double pct) {
    if (!supportsIncline) return Future.value();
    var v = (pct.clamp(minIncline, maxIncline) * 10).round();
    if (v < 0) v += 0x10000;
    return _write([0x03, v & 0xFF, (v >> 8) & 0xFF]);
  }

  @override
  Future<void> disconnect() async {
    for (final s in _subs) {
      await s.cancel();
    }
    try {
      await device.disconnect();
    } catch (_) {}
    _conn.add(false);
  }
}

// ---------------------------------------------------------------------------
// Demo bandı – cihaz olmadan uygulamayı denemek için
// ---------------------------------------------------------------------------

class SimulatedTreadmill extends Treadmill {
  final _data = StreamController<TreadmillData>.broadcast();
  final _conn = StreamController<bool>.broadcast();
  final _rnd = Random();
  Timer? _timer;
  double _speed = 0, _target = 0, _incline = 0, _targetIncline = 0, _dist = 0;
  bool _running = false;

  SimulatedTreadmill() {
    maxSpeed = 18;
    _timer = Timer.periodic(const Duration(milliseconds: 500), (_) => _tick());
  }

  @override
  String get name => 'Demo Koşu Bandı';
  @override
  bool get isDemo => true;
  @override
  Stream<TreadmillData> get data => _data.stream;
  @override
  Stream<bool> get connection => _conn.stream;

  void _tick() {
    final goal = _running ? _target : 0.0;
    final d = goal - _speed;
    _speed += d.abs() < 0.25 ? d : 0.25 * d.sign; // gerçekçi hızlanma
    final di = _targetIncline - _incline;
    _incline += di.abs() < 0.5 ? di : 0.5 * di.sign;
    _dist += _speed / 3.6 * 0.5;
    final hr = _speed < 0.5
        ? null
        : (70 + _speed * 8 + _incline * 2 + _rnd.nextInt(4)).round();
    _data.add(
      TreadmillData(
        speedKmh: double.parse(_speed.toStringAsFixed(2)),
        inclinePct: _incline,
        totalDistanceM: _dist.round(),
        heartRate: hr,
      ),
    );
  }

  @override
  Future<void> start() async {
    _running = true;
    if (_target < minSpeed) _target = 3.0;
  }

  @override
  Future<void> pause() async => _running = false;
  @override
  Future<void> stop() async {
    _running = false;
    _target = 0;
    _targetIncline = 0;
  }

  @override
  Future<void> setSpeed(double kmh) async =>
      _target = kmh.clamp(minSpeed, maxSpeed);
  @override
  Future<void> setIncline(double pct) async =>
      _targetIncline = pct.clamp(minIncline, maxIncline);

  @override
  Future<void> disconnect() async {
    _timer?.cancel();
    _conn.add(false);
  }
}

// ---------------------------------------------------------------------------
// Nabız bandı (standart Heart Rate Service 0x180D)
// ---------------------------------------------------------------------------

class HeartRateMonitor {
  final BluetoothDevice device;
  final _hr = StreamController<int>.broadcast();
  final List<StreamSubscription> _subs = [];

  HeartRateMonitor._(this.device);

  String get name =>
      device.platformName.isNotEmpty ? device.platformName : 'Nabız bandı';
  Stream<int> get heartRate => _hr.stream;

  static Future<HeartRateMonitor> connect(BluetoothDevice device) async {
    final m = HeartRateMonitor._(device);
    await device.connect(
      license: kBleLicense,
      timeout: const Duration(seconds: 15),
    );
    final services = await device.discoverServices();
    final svc = services.where((s) => s.uuid == hrService).firstOrNull;
    final c = svc?.characteristics
        .where((c) => c.uuid == hrMeasurementChar)
        .firstOrNull;
    if (c == null) {
      await device.disconnect();
      throw Exception('Bu cihazda nabız servisi bulunamadı.');
    }
    m._subs.add(c.onValueReceived.listen((v) => m._hr.add(parseHeartRate(v))));
    await c.setNotifyValue(true);
    return m;
  }

  Future<void> disconnect() async {
    for (final s in _subs) {
      await s.cancel();
    }
    try {
      await device.disconnect();
    } catch (_) {}
  }
}
