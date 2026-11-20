import 'package:flutter_test/flutter_test.dart';
import 'package:stride_free/devices.dart';
import 'package:stride_free/models.dart';

void main() {
  test('FTMS treadmill data: hız + mesafe + eğim', () {
    // flags = 0x000C (bit2 mesafe, bit3 eğim), hız 850 => 8.50 km/s,
    // mesafe 1234 m (u24), eğim 25 => %2.5, rampa 0
    final d = parseTreadmillData([
      0x0C,
      0x00,
      0x52,
      0x03,
      0xD2,
      0x04,
      0x00,
      0x19,
      0x00,
      0x00,
      0x00,
    ]);
    expect(d.speedKmh, 8.5);
    expect(d.totalDistanceM, 1234);
    expect(d.inclinePct, 2.5);
  });

  test('FTMS: bit0=1 iken hız alanı yok, nabız okunur', () {
    // flags = 0x0101 (more data + heart rate), HR=142
    final d = parseTreadmillData([0x01, 0x01, 142]);
    expect(d.speedKmh, isNull);
    expect(d.heartRate, 142);
  });

  test('FTMS: bölünmüş paketler birleşince hız kaybolmaz', () {
    // 1. paket: hız 3.00 km/s (flags 0x0000)
    // 2. paket: more data + mesafe 60 m (flags 0x0005), hız alanı yok
    var d = const TreadmillData();
    d = d.merge(parseTreadmillData([0x00, 0x00, 0x2C, 0x01]));
    d = d.merge(parseTreadmillData([0x05, 0x00, 0x3C, 0x00, 0x00]));
    expect(d.speedKmh, 3.0);
    expect(d.totalDistanceM, 60);
  });

  test('Adım: boy ve hıza göre adım uzunluğu, kayıt ve biçim', () {
    // 170 cm, 5 km/s yürüyüş → ~0,71 m adım → 1 km ≈ 1417 adım
    expect(strideLengthM(170, 5), closeTo(0.7055, 0.001));
    expect((1000 / strideLengthM(170, 5)).round(), 1417);
    // Koşuda adım uzar
    expect(strideLengthM(170, 10), greaterThan(strideLengthM(170, 5)));

    final s = WorkoutSession(
      id: '1',
      start: DateTime(2026, 11, 20),
      title: 'x',
      durationSec: 600,
      distanceKm: 1,
      kcal: 50,
      maxSpeed: 6,
      steps: 1417,
      stepsEstimated: true,
    );
    final back = WorkoutSession.fromJson(s.toJson());
    expect(back.steps, 1417);
    expect(back.stepsEstimated, true);
    expect(fmtSteps(4512), '4.512');
    expect(fmtSteps(4512, estimated: true), '≈4.512');
    // Eski kayıtlarda adım yok
    final old = Map<String, dynamic>.from(s.toJson())
      ..remove('steps')
      ..remove('stEst');
    expect(WorkoutSession.fromJson(old).steps, isNull);
  });

  test('Nabız ölçümü 8 ve 16 bit', () {
    expect(parseHeartRate([0x00, 75]), 75);
    expect(parseHeartRate([0x01, 0x2C, 0x01]), 300);
  });

  test('Biçimlendirme', () {
    expect(fmtDuration(65), '01:05');
    expect(fmtDuration(3725), '1:02:05');
    expect(fmtPace(6.0), '6:00');
  });
}
