// Ortak görsel bileşenler: metrik kutuları, artı/eksi kontrol, grafikler.
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import 'models.dart';

const zoneColors = [
  Color(0xFF616161), // veri yok
  Color(0xFF64B5F6), // 1 ısınma
  Color(0xFF4DB6AC), // 2 yağ yakımı
  Color(0xFFFFD54F), // 3 aerobik
  Color(0xFFFF8A65), // 4 anaerobik
  Color(0xFFE57373), // 5 maksimum
];
const zoneNames = [
  '—',
  'Isınma',
  'Yağ yakımı',
  'Aerobik',
  'Anaerobik',
  'Maksimum',
];

class MetricTile extends StatelessWidget {
  final String label;
  final String value;
  final String? unit;
  final IconData icon;
  final Color? color;

  const MetricTile({
    super.key,
    required this.label,
    required this.value,
    this.unit,
    required this.icon,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(16),
        border: color != null ? Border.all(color: color!, width: 2) : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: color ?? cs.onSurfaceVariant),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          // Flexible: kutu yüksekliği sabit (grid), büyük yazı boyutunda taşmak yerine küçülür.
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: value,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                    if (unit != null)
                      TextSpan(
                        text: ' $unit',
                        style: TextStyle(
                          fontSize: 13,
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// – değer + kontrolü
class AdjustControl extends StatelessWidget {
  final String label;
  final String value;
  final VoidCallback onMinus;
  final VoidCallback onPlus;
  final bool compact;

  const AdjustControl({
    super.key,
    required this.label,
    required this.value,
    required this.onMinus,
    required this.onPlus,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final size = compact ? 36.0 : 56.0;
    Widget btn(IconData i, VoidCallback f) => SizedBox(
      width: size,
      height: size,
      child: IconButton.filledTonal(
        padding: EdgeInsets.zero,
        onPressed: f,
        icon: Icon(i, size: compact ? 18 : 28),
      ),
    );
    return Container(
      padding: EdgeInsets.all(compact ? 4 : 8),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(compact ? 12 : 20),
      ),
      child: Row(
        mainAxisSize: compact ? MainAxisSize.min : MainAxisSize.max,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          btn(Icons.remove, onMinus),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: compact ? 15 : 22,
                    fontWeight: FontWeight.w700,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                Text(
                  label,
                  style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
                ),
              ],
            ),
          ),
          btn(Icons.add, onPlus),
        ],
      ),
    );
  }
}

/// Programın segment profilini çizer: genişlik = süre, yükseklik = hız.
class ProgramChart extends StatelessWidget {
  final WorkoutProgram program;
  final int? elapsedSec;
  final double height;

  const ProgramChart({
    super.key,
    required this.program,
    this.elapsedSec,
    this.height = 70,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SizedBox(
      height: height,
      width: double.infinity,
      child: CustomPaint(
        painter: _ProgramPainter(
          program,
          elapsedSec,
          cs.primary,
          cs.tertiary,
          cs.onSurface.withValues(alpha: 0.15),
        ),
      ),
    );
  }
}

class _ProgramPainter extends CustomPainter {
  final WorkoutProgram p;
  final int? elapsed;
  final Color active, incline, idle;
  _ProgramPainter(this.p, this.elapsed, this.active, this.incline, this.idle);

  @override
  void paint(Canvas canvas, Size size) {
    final total = p.totalSec;
    if (total == 0) return;
    final maxS = p.maxSpeed <= 0 ? 1 : p.maxSpeed;
    var x = 0.0, t = 0;
    for (final s in p.segments) {
      final w = size.width * s.durationSec / total;
      final h = size.height * (0.15 + 0.85 * s.speed / maxS);
      final done = elapsed != null && t + s.durationSec <= elapsed!;
      final current =
          elapsed != null && elapsed! >= t && elapsed! < t + s.durationSec;
      final paint = Paint()
        ..color = current
            ? active
            : done
            ? active.withValues(alpha: 0.45)
            : (elapsed == null ? active.withValues(alpha: 0.75) : idle);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(
            x + 0.5,
            size.height - h,
            (w - 1).clamp(0.5, double.infinity),
            h,
          ),
          const Radius.circular(2),
        ),
        paint,
      );
      if (s.incline > 0) {
        final ih = 3.0;
        canvas.drawRect(
          Rect.fromLTWH(
            x + 0.5,
            size.height - h - ih - 1,
            (w - 1).clamp(0.5, double.infinity),
            ih,
          ),
          Paint()
            ..color = incline.withValues(
              alpha: 0.4 + 0.6 * (s.incline / 15).clamp(0, 1),
            ),
        );
      }
      x += w;
      t += s.durationSec;
    }
    if (elapsed != null) {
      final ex = size.width * (elapsed! / total).clamp(0, 1);
      canvas.drawLine(
        Offset(ex, 0),
        Offset(ex, size.height),
        Paint()
          ..color = Colors.white
          ..strokeWidth = 2,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ProgramPainter old) =>
      old.elapsed != elapsed || old.p != p;
}

/// 5 sn aralıklı örneklerden çizgi grafik
/// Uzun antrenmanlarda grafiği okunur kılmak için örnekleri en fazla [maxPoints]
/// noktaya ortalayarak indirir (0 = veri yok, ortalamaya katılmaz).
List<FlSpot> _downsample(List<double> v, int maxPoints) {
  if (v.length <= maxPoints) {
    return [for (var i = 0; i < v.length; i++) FlSpot(i.toDouble(), v[i])];
  }
  final step = v.length / maxPoints;
  final out = <FlSpot>[];
  for (var b = 0; b < maxPoints; b++) {
    final from = (b * step).floor(),
        to = ((b + 1) * step).floor().clamp(from + 1, v.length);
    var sum = 0.0, n = 0;
    for (var i = from; i < to; i++) {
      if (v[i] > 0) {
        sum += v[i];
        n++;
      }
    }
    out.add(FlSpot((from + to - 1) / 2, n == 0 ? 0 : sum / n));
  }
  return out;
}

class SampleLineChart extends StatelessWidget {
  final List<double> values;
  final Color color;
  final String unit;
  const SampleLineChart({
    super.key,
    required this.values,
    required this.color,
    required this.unit,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    if (values.length < 2) {
      return SizedBox(
        height: 160,
        child: Center(
          child: Text(
            'Grafik için yeterli veri yok',
            style: TextStyle(color: cs.onSurfaceVariant),
          ),
        ),
      );
    }
    final maxY = values.reduce((a, b) => a > b ? a : b);
    // Eksen etiketleri tam sayı ve tekrarsız olsun: aralığı yuvarla, tepeyi aralığın katına çek.
    final raw = maxY * 1.15 + 1;
    final step = _niceStep(raw / 4);
    final top = (raw / step).ceil() * step;
    return SizedBox(
      height: 180,
      child: LineChart(
        LineChartData(
          minY: 0,
          maxY: top,
          gridData: FlGridData(
            drawVerticalLine: false,
            horizontalInterval: step,
            getDrawingHorizontalLine: (_) => FlLine(
              color: cs.outlineVariant.withValues(alpha: 0.4),
              strokeWidth: 1,
            ),
          ),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 34,
                interval: step,
                getTitlesWidget: (v, m) => Text(
                  v.toStringAsFixed(0),
                  style: TextStyle(fontSize: 10, color: cs.onSurfaceVariant),
                ),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 22,
                interval: (values.length / 4).ceilToDouble().clamp(
                  1,
                  double.infinity,
                ),
                getTitlesWidget: (v, m) => Text(
                  values.length * 5 < 180
                      ? '${(v * 5).round()}sn'
                      : '${(v * 5 / 60).round()}dk',
                  style: TextStyle(fontSize: 10, color: cs.onSurfaceVariant),
                ),
              ),
            ),
          ),
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipItems: (spots) => spots
                  .map(
                    (s) => LineTooltipItem(
                      '${s.y.toStringAsFixed(1)} $unit',
                      TextStyle(color: color, fontWeight: FontWeight.w600),
                    ),
                  )
                  .toList(),
            ),
          ),
          lineBarsData: [
            LineChartBarData(
              spots: _downsample(values, 90),
              isCurved: true,
              preventCurveOverShooting: true,
              color: color,
              barWidth: 2.5,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                color: color.withValues(alpha: 0.15),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 1, 2, 5, 10, 20, 50… dizisinden [x]'e eşit ya da büyük ilk tam sayı adım.
double _niceStep(double x) {
  if (x <= 1) return 1;
  var mag = 1.0;
  while (mag * 10 <= x) {
    mag *= 10;
  }
  for (final m in [1, 2, 5, 10]) {
    if (m * mag >= x) return m * mag;
  }
  return 10 * mag;
}

/// Dönem grafiği: her çubuk bir gün / ay / yıl.
class PeriodBarChart extends StatelessWidget {
  final List<double> values;
  final List<String> labels;
  final int highlight; // bugünün çubuğu (-1 yok)
  final String Function(double) format;

  const PeriodBarChart({
    super.key,
    required this.values,
    required this.labels,
    this.highlight = -1,
    required this.format,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final n = values.length;
    final maxY = values.fold(0.0, (a, b) => b > a ? b : a);
    final top = maxY <= 0 ? 1.0 : maxY * 1.2;
    // Çok çubuk varsa etiketleri seyrelt (ay görünümünde 1, 5, 10, ...)
    final every = n > 20 ? 5 : (n > 12 ? 2 : 1);
    return LayoutBuilder(
      builder: (context, c) {
        final barW = ((c.maxWidth / n) * 0.6).clamp(3.0, 22.0);
        return SizedBox(
          height: 160,
          child: BarChart(
            BarChartData(
              maxY: top,
              gridData: const FlGridData(show: false),
              borderData: FlBorderData(show: false),
              alignment: BarChartAlignment.spaceAround,
              barTouchData: BarTouchData(
                touchTooltipData: BarTouchTooltipData(
                  getTooltipItem: (g, gi, rod, ri) => BarTooltipItem(
                    '${labels[g.x]}\n${format(rod.toY)}',
                    TextStyle(color: cs.primary, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              titlesData: FlTitlesData(
                topTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                rightTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                leftTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 22,
                    getTitlesWidget: (v, m) {
                      final i = v.toInt();
                      if (i < 0 || i >= n) return const SizedBox();
                      final show =
                          every == 1 ||
                          i == 0 ||
                          (i + 1) % every == 0 ||
                          i == highlight;
                      if (!show) return const SizedBox();
                      return Text(
                        labels[i],
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: i == highlight
                              ? FontWeight.w700
                              : FontWeight.w400,
                          color: i == highlight
                              ? cs.primary
                              : cs.onSurfaceVariant,
                        ),
                      );
                    },
                  ),
                ),
              ),
              barGroups: [
                for (var i = 0; i < n; i++)
                  BarChartGroupData(
                    x: i,
                    barRods: [
                      BarChartRodData(
                        toY: values[i],
                        width: barW,
                        color: i == highlight
                            ? cs.primary
                            : cs.primary.withValues(alpha: 0.55),
                        borderRadius: BorderRadius.circular(barW / 3),
                        backDrawRodData: BackgroundBarChartRodData(
                          show: true,
                          toY: top,
                          color: cs.surfaceContainerHighest,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
