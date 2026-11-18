import 'package:flutter_test/flutter_test.dart';
import 'package:stride_free/devices.dart';
import 'package:stride_free/models.dart';

void main() {
  test('FTMS treadmill data: hız + mesafe + eğim', () {
    // flags = 0x000C (bit2 mesafe, bit3 eğim), hız 850 => 8.50 km/s,
    // mesafe 1234 m (u24), eğim 25 => %2.5, rampa 0
    final d = parseTreadmillData(
        [0x0C, 0x00, 0x52, 0x03, 0xD2, 0x04, 0x00, 0x19, 0x00, 0x00, 0x00]);
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
