import 'package:flutter_test/flutter_test.dart';
import 'package:stride_free/models.dart';
import 'package:stride_free/stats.dart';

WorkoutSession run(DateTime t, double km, {int sec = 1800}) => WorkoutSession(
  id: '${t.millisecondsSinceEpoch}',
  start: t,
  title: 't',
  durationSec: sec,
  distanceKm: km,
  kcal: km * 60,
  maxSpeed: 10,
);

void main() {
  // Çarşamba, 18 Kasım 2026
  final now = DateTime(2026, 11, 18, 12);
  final data = [
    run(DateTime(2026, 11, 16, 7), 5), // Pzt bu hafta
    run(DateTime(2026, 11, 18, 7), 3), // Çar bu hafta
    run(DateTime(2026, 11, 12, 7), 4), // geçen hafta
    run(DateTime(2026, 10, 31, 23, 30), 10), // ekim son gün
    run(DateTime(2025, 2, 1, 8), 2), // geçen yıl
  ];

  test('hafta', () {
    final w = computePeriod(data, Period.week, 0, now: now);
    expect(w.title, 'Bu hafta');
    expect(w.labels.length, 7);
    expect(w.values(Metric.distance), [5, 0, 3, 0, 0, 0, 0]);
    expect(w.todayIndex, 2);
    final prev = computePeriod(data, Period.week, -1, now: now);
    expect(prev.title, 'Geçen hafta');
    expect(prev.km(), 4);
    expect(prev.todayIndex, -1);
  });

  test('ay', () {
    final m = computePeriod(data, Period.month, 0, now: now);
    expect(m.labels.length, 30);
    expect(m.km(), 12);
    expect(m.values(Metric.count)[15], 1); // 16 Kasım
    final oct = computePeriod(data, Period.month, -1, now: now);
    expect(oct.title, 'Ekim');
    expect(oct.labels.length, 31);
    expect(oct.values(Metric.distance).last, 10);
  });

  test('yıl ve tümü', () {
    final y = computePeriod(data, Period.year, 0, now: now);
    expect(y.labels.length, 12);
    expect(y.values(Metric.distance)[10], 12); // Kasım
    expect(y.values(Metric.distance)[9], 10); // Ekim
    expect(computePeriod(data, Period.year, -1, now: now).title, '2025');
    final all = computePeriod(data, Period.all, 0, now: now);
    expect(all.labels, ['2025', '2026']);
    expect(all.values(Metric.distance), [2, 22]);
    expect(all.activeDays, 5);
  });

  test('ocak ayından geriye gitmek bir önceki yılın aralığı olur', () {
    final m = computePeriod(data, Period.month, -10, now: DateTime(2026, 1, 5));
    expect(m.start, DateTime(2025, 3, 1));
    expect(m.title, 'Mart 2025');
  });
}
