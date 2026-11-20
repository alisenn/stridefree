// Dönem bazlı istatistikler: hafta / ay / yıl / tümü.
import 'l10n.dart';
import 'models.dart';

enum Period { week, month, year, all }

enum Metric { distance, time, calories, count }

List<String> get monthShort => isEn
    ? const [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec',
      ]
    : const [
        'Oca',
        'Şub',
        'Mar',
        'Nis',
        'May',
        'Haz',
        'Tem',
        'Ağu',
        'Eyl',
        'Eki',
        'Kas',
        'Ara',
      ];
List<String> get monthLong => isEn
    ? const [
        'January', 'February', 'March', 'April', 'May', 'June', //
        'July', 'August', 'September', 'October', 'November', 'December',
      ]
    : const [
        'Ocak', 'Şubat', 'Mart', 'Nisan', 'Mayıs', 'Haziran', //
        'Temmuz', 'Ağustos', 'Eylül', 'Ekim', 'Kasım', 'Aralık',
      ];
List<String> get dayShort => isEn
    ? const ['Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa', 'Su']
    : const ['Pt', 'Sa', 'Ça', 'Pe', 'Cu', 'Ct', 'Pz'];

class PeriodStats {
  final Period period;
  final DateTime start; // dahil
  final DateTime end; // hariç
  final String title;
  final List<String> labels;
  final List<List<WorkoutSession>> buckets;
  final List<WorkoutSession> sessions;
  final int todayIndex; // -1: bu dönemde değil

  PeriodStats({
    required this.period,
    required this.start,
    required this.end,
    required this.title,
    required this.labels,
    required this.buckets,
    required this.sessions,
    required this.todayIndex,
  });

  double km() => sessions.fold(0.0, (a, s) => a + s.distanceKm);
  int sec() => sessions.fold(0, (a, s) => a + s.durationSec);
  double kcal() => sessions.fold(0.0, (a, s) => a + s.kcal);
  int get count => sessions.length;

  double total(Metric m) => _value(sessions, m);

  /// Dönem başından itibaren [span] süresi içindeki toplam
  /// (devam eden dönemi önceki dönemin aynı noktasıyla karşılaştırmak için).
  double totalWithin(Metric m, Duration span) => _value(
    sessions.where((s) => s.start.difference(start) < span).toList(),
    m,
  );
  List<double> values(Metric m) => [for (final b in buckets) _value(b, m)];

  /// En iyi (en uzun mesafeli) antrenman
  WorkoutSession? get best => sessions.isEmpty
      ? null
      : sessions.reduce((a, b) => a.distanceKm >= b.distanceKm ? a : b);

  /// Ortalama tempo dk/km
  double? get avgPace {
    final k = km();
    return k < 0.01 ? null : sec() / 60 / k;
  }

  int get activeDays => sessions
      .map((s) => DateTime(s.start.year, s.start.month, s.start.day))
      .toSet()
      .length;
}

double _value(List<WorkoutSession> list, Metric m) => switch (m) {
  Metric.distance => list.fold(0.0, (a, s) => a + s.distanceKm),
  Metric.time => list.fold(0.0, (a, s) => a + s.durationSec / 60),
  Metric.calories => list.fold(0.0, (a, s) => a + s.kcal),
  Metric.count => list.length.toDouble(),
};

DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

/// [offset] 0 = içinde bulunulan dönem, -1 = bir önceki, ...
PeriodStats computePeriod(
  List<WorkoutSession> all,
  Period p,
  int offset, {
  DateTime? now,
}) {
  final today = _day(now ?? DateTime.now());
  late DateTime start, end;
  late String title;
  final labels = <String>[];
  final bucketStarts = <DateTime>[];

  switch (p) {
    case Period.week:
      final monday = today.subtract(Duration(days: today.weekday - 1));
      start = DateTime(monday.year, monday.month, monday.day + 7 * offset);
      end = DateTime(start.year, start.month, start.day + 7);
      for (var i = 0; i < 7; i++) {
        bucketStarts.add(DateTime(start.year, start.month, start.day + i));
        labels.add(dayShort[i]);
      }
      final last = DateTime(end.year, end.month, end.day - 1);
      title = offset == 0
          ? tx('Bu hafta', 'This week')
          : offset == -1
          ? tx('Geçen hafta', 'Last week')
          : '${start.day} ${monthShort[start.month - 1]} – ${last.day} ${monthShort[last.month - 1]}'
                '${last.year != today.year ? ' ${last.year}' : ''}';
    case Period.month:
      start = DateTime(today.year, today.month + offset, 1);
      end = DateTime(start.year, start.month + 1, 1);
      final days = end.difference(start).inDays;
      for (var i = 0; i < days; i++) {
        bucketStarts.add(DateTime(start.year, start.month, i + 1));
        labels.add('${i + 1}');
      }
      title = offset == 0
          ? tx('Bu ay', 'This month')
          : '${monthLong[start.month - 1]}${start.year != today.year ? ' ${start.year}' : ''}';
    case Period.year:
      start = DateTime(today.year + offset, 1, 1);
      end = DateTime(start.year + 1, 1, 1);
      for (var i = 0; i < 12; i++) {
        bucketStarts.add(DateTime(start.year, i + 1, 1));
        labels.add(monthShort[i]);
      }
      title = offset == 0 ? tx('Bu yıl', 'This year') : '${start.year}';
    case Period.all:
      final firstYear = all.isEmpty
          ? today.year
          : all.map((s) => s.start.year).reduce((a, b) => a < b ? a : b);
      start = DateTime(firstYear, 1, 1);
      end = DateTime(today.year + 1, 1, 1);
      for (var y = firstYear; y <= today.year; y++) {
        bucketStarts.add(DateTime(y, 1, 1));
        labels.add('$y');
      }
      title = tx('Tüm zamanlar', 'All time');
  }

  final inRange =
      all
          .where((s) => !s.start.isBefore(start) && s.start.isBefore(end))
          .toList()
        ..sort((a, b) => b.start.compareTo(a.start));
  final buckets = List.generate(bucketStarts.length, (_) => <WorkoutSession>[]);
  for (final s in inRange) {
    var idx = bucketStarts.length - 1;
    for (var i = 0; i < bucketStarts.length - 1; i++) {
      if (s.start.isBefore(bucketStarts[i + 1])) {
        idx = i;
        break;
      }
    }
    buckets[idx].add(s);
  }

  var todayIdx = -1;
  if (!today.isBefore(start) && today.isBefore(end)) {
    for (var i = bucketStarts.length - 1; i >= 0; i--) {
      if (!today.isBefore(bucketStarts[i])) {
        todayIdx = i;
        break;
      }
    }
  }

  return PeriodStats(
    period: p,
    start: start,
    end: end,
    title: title,
    labels: labels,
    buckets: buckets,
    sessions: inRange,
    todayIndex: todayIdx,
  );
}
