// FitShow özel Bluetooth protokolü (FTMS desteklemeyen FitShow modüllü bantlar).
//
// Paket:   0x02 | payload... | XOR(payload) | 0x03
// Servis:  0xFFF0 (yazma 0xFFF2, bildirim 0xFFF1) — bazı modellerde 0xFFE0 (0xFFE1 / 0xFFE4)
// Uygulama bant durumunu ~0.5 sn'de bir sorgular (0x51); bant hız/eğim/süre/nabız ile yanıt verir.
//
// Protokol bilgileri topluluk tarafından belgelenmiş davranışa dayanır; kod bu proje için
// sıfırdan yazılmıştır.
import 'dart:async';
import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import 'devices.dart';
import 'l10n.dart';
import 'models.dart';

// Komut grupları
const fsInfo = 0x50;
const fsStatus = 0x51;
const fsControl = 0x53;

// fsInfo alt komutları
const fsInfoModel = 0x00;
const fsInfoSpeed = 0x02;
const fsInfoIncline = 0x03;

// fsControl alt komutları
const fsCtrlUser = 0x00;
const fsCtrlStart = 0x01;
const fsCtrlTarget = 0x02;
const fsCtrlStop = 0x03;
const fsCtrlPause = 0x06;

// Bant durumları
const fsStateNormal = 0;
const fsStateEnd = 1;
const fsStateStarting = 2;
const fsStateRunning = 3;
const fsStateStopping = 4;
const fsStateError = 5;
const fsStateSafety = 6;
const fsStatePaused = 10;

final fitshowServices = [Guid('FFF0'), Guid('FFE0')];
final _writeChars = [Guid('FFF2'), Guid('FFE1')];
final _notifyChars = [Guid('FFF1'), Guid('FFE4')];

/// Bir payload'u FitShow çerçevesine sarar.
List<int> fsFrame(List<int> payload) {
  var x = 0;
  for (final b in payload) {
    x ^= b;
  }
  return [0x02, ...payload.map((b) => b & 0xFF), x & 0xFF, 0x03];
}

/// Geçerli bir çerçeveyse payload'u döndürür, değilse null.
List<int>? fsUnframe(List<int> data) {
  if (data.length < 4 || data.first != 0x02 || data.last != 0x03) return null;
  final payload = data.sublist(1, data.length - 2);
  var x = 0;
  for (final b in payload) {
    x ^= b;
  }
  return x == data[data.length - 2] ? payload : null;
}

class FitShowStatus {
  final int state;
  final double speedKmh;
  final double incline;
  final int elapsedS;
  final int kcal;
  final int steps;
  final int heartRate;
  final int countdown;

  const FitShowStatus({
    required this.state,
    this.speedKmh = 0,
    this.incline = 0,
    this.elapsedS = 0,
    this.kcal = 0,
    this.steps = 0,
    this.heartRate = 0,
    this.countdown = 0,
  });
}

/// 0x51 durum yanıtını çözer. [speedFactor] mil→km dönüşümü için (1 veya 1.609).
FitShowStatus? parseFitShowStatus(List<int> p, {double speedFactor = 1}) {
  if (p.length < 2 || p[0] != fsStatus) return null;
  final state = p[1];
  if (state == fsStateStarting) {
    return FitShowStatus(state: state, countdown: p.length > 2 ? p[2] : 0);
  }
  if (p.length < 13) return FitShowStatus(state: state);
  final inc = p[3] >= 128 ? p[3] - 256 : p[3];
  return FitShowStatus(
    state: state,
    speedKmh: state == fsStateRunning ? p[2] / 10 * speedFactor : 0,
    incline: inc.toDouble(),
    elapsedS: p[4] | (p[5] << 8),
    kcal: p[8] | (p[9] << 8),
    steps: p[10] | (p[11] << 8),
    heartRate: p[12],
  );
}

class FitShowTreadmill extends Treadmill {
  final BluetoothDevice device;
  final double speedFactor; // bant mil gönderiyorsa 1.609
  late BluetoothCharacteristic _tx;
  late BluetoothCharacteristic _rx;
  final _data = StreamController<TreadmillData>.broadcast();
  final _conn = StreamController<bool>.broadcast();
  final List<StreamSubscription> _subs = [];
  final Queue<List<int>> _queue = Queue();
  Timer? _pump;
  bool _writing = false;

  int state = fsStateNormal;
  double _targetSpeed = 0;
  double _targetIncline = 0;
  bool _pendingTarget = false;

  FitShowTreadmill._(this.device, this.speedFactor);

  @override
  String get name => device.platformName.isNotEmpty
      ? device.platformName
      : tx('FitShow bandı', 'FitShow treadmill');
  @override
  Stream<TreadmillData> get data => _data.stream;
  @override
  Stream<bool> get connection => _conn.stream;

  /// Zaten bağlı ve servisleri keşfedilmiş cihaz üzerinde kurulur.
  static Future<FitShowTreadmill?> tryAttach(
    BluetoothDevice device,
    List<BluetoothService> services, {
    required int age,
    required double weightKg,
    bool miles = false,
  }) async {
    BluetoothCharacteristic? tx, rx;
    for (final s in services) {
      for (final c in s.characteristics) {
        if (tx == null && _writeChars.contains(c.uuid)) tx = c;
        if (rx == null && _notifyChars.contains(c.uuid)) rx = c;
      }
    }
    if (tx == null || rx == null) return null;
    final t = FitShowTreadmill._(device, miles ? 1.60934 : 1);
    t._tx = tx;
    t._rx = rx;
    await t._setup(age: age, weightKg: weightKg);
    return t;
  }

  Future<void> _setup({required int age, required double weightKg}) async {
    maxSpeed = 12; // bant bildirene kadar güvenli varsayılan
    minSpeed = 1;
    maxIncline = 0;
    supportsIncline = false;

    _subs.add(
      device.connectionState.listen((s) {
        _conn.add(s == BluetoothConnectionState.connected);
        if (s == BluetoothConnectionState.disconnected) _pump?.cancel();
      }),
    );
    _subs.add(_rx.onValueReceived.listen(_onPacket));
    await _rx.setNotifyValue(true);

    final now = DateTime.now();
    _send([
      fsControl,
      fsCtrlUser,
      0,
      0,
      110,
      age.clamp(10, 99),
      weightKg.round().clamp(30, 250),
    ]);
    _send([
      fsInfo,
      fsInfoModel,
      now.year - 2000,
      now.month,
      now.day,
      now.hour,
      now.minute,
      now.second,
    ]);
    _send([fsInfo, fsInfoSpeed]);
    _send([fsInfo, fsInfoIncline]);

    // Kuyruktaki komutları gönder; boşsa durumu sorgula.
    _pump = Timer.periodic(const Duration(milliseconds: 250), (_) => _tick());
  }

  var _pollCounter = 0;
  Future<void> _tick() async {
    if (_writing) return;
    List<int>? next;
    if (_queue.isNotEmpty) {
      next = _queue.removeFirst();
    } else if (++_pollCounter % 2 == 0) {
      next = [fsStatus];
    }
    if (next == null) return;
    _writing = true;
    try {
      final frame = fsFrame(next);
      await _tx.write(
        frame,
        withoutResponse: _tx.properties.writeWithoutResponse,
      );
    } catch (e) {
      debugPrint('FitShow yazma hatası: $e');
    }
    _writing = false;
  }

  void _send(List<int> payload) {
    // Aynı türden bekleyen hedef komutu varsa yenisiyle değiştir (sürekli bip sesini önler).
    if (payload.length >= 2 &&
        payload[0] == fsControl &&
        payload[1] == fsCtrlTarget) {
      _queue.removeWhere(
        (p) => p.length >= 2 && p[0] == fsControl && p[1] == fsCtrlTarget,
      );
    }
    _queue.add(payload);
  }

  void _onPacket(List<int> raw) {
    final p = fsUnframe(raw);
    if (p == null || p.length < 2) return;
    if (p[0] == fsInfo) {
      if (p[1] == fsInfoSpeed && p.length >= 4) {
        maxSpeed = p[2] / 10 * speedFactor;
        minSpeed = (p[3] / 10 * speedFactor).clamp(0.5, maxSpeed);
      } else if (p[1] == fsInfoIncline && p.length >= 4) {
        final mx = p[2] >= 128 ? p[2] - 256 : p[2];
        final mn = p[3] >= 128 ? p[3] - 256 : p[3];
        maxIncline = mx.toDouble();
        minIncline = mn.toDouble();
        supportsIncline = mx > 0;
      }
      return;
    }
    final st = parseFitShowStatus(p, speedFactor: speedFactor);
    if (st == null) return;
    state = st.state;
    // Bant geri sayımdayken hız komutlarını yok sayar; RUNNING olunca hedefi uygula.
    if (state == fsStateRunning && _pendingTarget) {
      _pendingTarget = false;
      _sendTarget();
    }
    _data.add(
      TreadmillData(
        speedKmh: st.speedKmh,
        inclinePct: st.incline,
        heartRate: st.heartRate > 0 ? st.heartRate : null,
        elapsedS: st.elapsedS,
        // Bazı modüller adım saymaz ve hep 0 gönderir; o zaman tahmin kullanılır.
        steps: st.steps > 0 ? st.steps : null,
      ),
    );
  }

  void _sendTarget() {
    final s = (_targetSpeed / speedFactor * 10).round().clamp(0, 255);
    final i = _targetIncline.round();
    _send([fsControl, fsCtrlTarget, s, i < 0 ? i + 256 : i]);
  }

  @override
  Future<void> start() async {
    _pendingTarget = true;
    if (state == fsStateRunning) return;
    _send([fsControl, fsCtrlStart, 0, 0, 0, 0, 0, 0, 0, 0]);
  }

  @override
  Future<void> pause() async {
    _pendingTarget = false;
    _send([fsControl, fsCtrlPause]);
  }

  @override
  Future<void> stop() async {
    _pendingTarget = false;
    _send([fsControl, fsCtrlStop]);
  }

  @override
  Future<void> setSpeed(double kmh) async {
    _targetSpeed = kmh.clamp(minSpeed, maxSpeed);
    if (state == fsStateRunning) {
      _sendTarget();
    } else {
      _pendingTarget = true;
    }
  }

  @override
  Future<void> setIncline(double pct) async {
    if (!supportsIncline) return;
    _targetIncline = pct.clamp(minIncline, maxIncline);
    if (state == fsStateRunning) {
      _sendTarget();
    } else {
      _pendingTarget = true;
    }
  }

  @override
  Future<void> disconnect() async {
    _pump?.cancel();
    for (final s in _subs) {
      await s.cancel();
    }
    try {
      await device.disconnect();
    } catch (_) {}
    _conn.add(false);
  }
}
