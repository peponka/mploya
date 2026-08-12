import 'dart:math' as math;

import 'package:flutter/cupertino.dart';

import '../../theme/mploya_tokens.dart';
import 'mp_surface.dart';

/// Un tramo de la dona.
class MpDonutSlice {
  final String label;
  final double value;
  final Color color;

  const MpDonutSlice({
    required this.label,
    required this.value,
    required this.color,
  });
}

/// Dona con leyenda al costado.
/// → "Fuentes de candidatos" de `dashboard empresa.png` y "Fuentes de tráfico"
///   de `analytics de vacantes.png`.
class MpDonutChart extends StatelessWidget {
  final List<MpDonutSlice> slices;
  final double size;
  final double thickness;

  /// Texto dentro del agujero (total).
  final Widget? center;

  /// Leyenda apretada, para cuando la dona vive en media tarjeta de móvil.
  final bool compact;

  const MpDonutChart({
    super.key,
    required this.slices,
    this.size = 132,
    this.thickness = 26,
    this.center,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final s = context.mp;
    final total = slices.fold<double>(0, (sum, slice) => sum + slice.value);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: size,
          height: size,
          child: CustomPaint(
            painter: _DonutPainter(
              slices: slices,
              thickness: thickness,
              empty: s.fill,
            ),
            child: center == null ? null : Center(child: center),
          ),
        ),
        SizedBox(width: compact ? MpTokens.space8 : MpTokens.space16),
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final slice in slices)
                Padding(
                  padding: EdgeInsets.only(bottom: compact ? 6 : 9),
                  child: Row(
                    children: [
                      Container(
                        width: compact ? 7 : 9,
                        height: compact ? 7 : 9,
                        decoration: BoxDecoration(
                          color: slice.color,
                          shape: BoxShape.circle,
                        ),
                      ),
                      SizedBox(width: compact ? 5 : MpTokens.space8),
                      Expanded(
                        child: Text(
                          slice.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: MpTokens.caption.copyWith(
                            color: s.text,
                            fontSize: compact ? 9.5 : null,
                          ),
                        ),
                      ),
                      SizedBox(width: compact ? 3 : 6),
                      Text(
                        total == 0
                            ? '—'
                            : '${(slice.value / total * 100).toStringAsFixed(0)}%',
                        style: MpTokens.label.copyWith(
                          color: s.textSecondary,
                          fontSize: compact ? 10 : null,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DonutPainter extends CustomPainter {
  final List<MpDonutSlice> slices;
  final double thickness;
  final Color empty;

  const _DonutPainter({
    required this.slices,
    required this.thickness,
    required this.empty,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(
      thickness / 2,
      thickness / 2,
      size.width - thickness,
      size.height - thickness,
    );
    final total = slices.fold<double>(0, (sum, slice) => sum + slice.value);

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = thickness;

    if (total <= 0) {
      paint.color = empty;
      canvas.drawArc(rect, 0, math.pi * 2, false, paint);
      return;
    }

    // Arranca arriba y avanza en sentido horario, como en los mockups.
    var start = -math.pi / 2;
    for (final slice in slices) {
      final sweep = (slice.value / total) * math.pi * 2;
      paint.color = slice.color;
      canvas.drawArc(rect, start, sweep, false, paint);
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutPainter old) =>
      old.slices != slices || old.thickness != thickness;
}

/// Serie de una línea.
class MpLineSeries {
  final List<double> values;
  final Color color;

  /// Relleno degradado bajo la línea.
  final bool filled;

  const MpLineSeries({
    required this.values,
    required this.color,
    this.filled = false,
  });
}

/// Gráfico de líneas con ejes suaves y puntos.
/// → "Evolución de contrataciones" de `dashboard empresa.png`.
class MpLineChart extends StatelessWidget {
  final List<MpLineSeries> series;
  final List<String> labels;
  final double height;

  /// Muestra el valor sobre cada punto (el mockup lo hace en la evolución).
  final bool showPointValues;

  /// Dibuja el eje Y con 0 / mitad / máximo a la izquierda, y la grilla
  /// punteada, como en `dashboard empresa.png`.
  final bool showAxis;

  const MpLineChart({
    super.key,
    required this.series,
    required this.labels,
    this.height = 170,
    this.showPointValues = false,
    this.showAxis = false,
  });

  /// Máximo redondeado hacia arriba para que el eje dé números limpios
  /// (el mockup marca 0 / 20 / 40).
  double get _axisMax {
    var maxValue = 0.0;
    for (final serie in series) {
      for (final value in serie.values) {
        if (value > maxValue) maxValue = value;
      }
    }
    if (maxValue <= 0) return 4;
    final step = maxValue <= 8 ? 2.0 : (maxValue <= 40 ? 10.0 : 20.0);
    return (maxValue / step).ceil() * step;
  }

  @override
  Widget build(BuildContext context) {
    final s = context.mp;
    final axisMax = _axisMax;
    const axisWidth = 30.0;

    final chart = SizedBox(
      height: height,
      child: CustomPaint(
        size: Size.infinite,
        painter: _LinePainter(
          series: series,
          grid: s.borderStrong,
          labelColor: s.text,
          showPointValues: showPointValues,
          axisMax: axisMax,
          dashedGrid: showAxis,
          // El TextPainter del lienzo no hereda estilo: hay que pasarle la
          // familia a mano o los números salen con otra tipografía.
          fontFamily: DefaultTextStyle.of(context).style.fontFamily,
        ),
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (showAxis)
              SizedBox(
                width: axisWidth,
                height: height,
                child: _AxisLabels(
                  max: axisMax,
                  color: s.textTertiary,
                  topInset: showPointValues ? 18 : 6,
                ),
              ),
            Expanded(child: chart),
          ],
        ),
        if (labels.isNotEmpty) ...[
          const SizedBox(height: MpTokens.space8),
          Padding(
            padding: EdgeInsets.only(left: showAxis ? axisWidth : 0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                for (final label in labels)
                  Text(
                    label,
                    style: MpTokens.caption.copyWith(color: s.textSecondary),
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

/// Rótulos del eje Y: máximo arriba, mitad al medio, 0 abajo.
class _AxisLabels extends StatelessWidget {
  final double max;
  final Color color;
  final double topInset;

  const _AxisLabels({
    required this.max,
    required this.color,
    required this.topInset,
  });

  @override
  Widget build(BuildContext context) {
    String fmt(double value) =>
        value == value.roundToDouble() ? value.round().toString() : value.toStringAsFixed(1);

    return Padding(
      padding: EdgeInsets.only(top: topInset),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          for (final value in [max, max / 2, 0.0])
            Transform.translate(
              offset: const Offset(0, -6),
              child: Padding(
                padding: const EdgeInsets.only(right: 6),
                child: Text(
                  fmt(value),
                  style: MpTokens.micro.copyWith(color: color),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _LinePainter extends CustomPainter {
  final List<MpLineSeries> series;
  final Color grid;
  final Color labelColor;
  final bool showPointValues;

  /// Tope del eje. Si es null se usa el máximo de los datos.
  final double? axisMax;

  /// Grilla punteada (horizontal y vertical), como en el mockup.
  final bool dashedGrid;

  /// Familia tipográfica de los valores sobre los puntos.
  final String? fontFamily;

  const _LinePainter({
    required this.series,
    required this.grid,
    required this.labelColor,
    required this.showPointValues,
    this.axisMax,
    this.dashedGrid = false,
    this.fontFamily,
  });

  void _dashedLine(Canvas canvas, Offset from, Offset to, Paint paint) {
    const dash = 4.0;
    const gap = 4.0;
    final total = (to - from).distance;
    if (total <= 0) return;
    final dir = (to - from) / total;
    var travelled = 0.0;
    while (travelled < total) {
      final end = (travelled + dash).clamp(0.0, total);
      canvas.drawLine(from + dir * travelled, from + dir * end, paint);
      travelled = end + gap;
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (series.isEmpty) return;

    var maxValue = axisMax ?? 0.0;
    if (axisMax == null) {
      for (final serie in series) {
        for (final value in serie.values) {
          if (value > maxValue) maxValue = value;
        }
      }
    }
    if (maxValue <= 0) maxValue = 1;

    final top = showPointValues ? 18.0 : 6.0;
    final chartHeight = size.height - top;

    final gridPaint = Paint()
      ..color = grid
      ..strokeWidth = 1;

    // Horizontales: 3 líneas (0, mitad, máximo) para coincidir con el eje.
    for (var i = 0; i <= 2; i++) {
      final y = top + chartHeight * (i / 2);
      if (dashedGrid) {
        _dashedLine(canvas, Offset(0, y), Offset(size.width, y), gridPaint);
      } else {
        canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
      }
    }

    final pointCount = series.first.values.length;

    // Verticales bajo cada punto.
    if (dashedGrid && pointCount > 1) {
      final step = size.width / (pointCount - 1);
      for (var i = 0; i < pointCount; i++) {
        _dashedLine(
          canvas,
          Offset(step * i, top),
          Offset(step * i, top + chartHeight),
          gridPaint,
        );
      }
    }

    for (final serie in series) {
      if (serie.values.length < 2) continue;
      final step = size.width / (serie.values.length - 1);

      final points = <Offset>[
        for (var i = 0; i < serie.values.length; i++)
          Offset(
            step * i,
            top + chartHeight * (1 - (serie.values[i] / maxValue)),
          ),
      ];

      // Curva suave (Catmull-Rom → Bézier cúbica). El mockup no traza rectas
      // entre puntos: la serie es una curva continua.
      final path = Path()..moveTo(points.first.dx, points.first.dy);
      for (var i = 0; i < points.length - 1; i++) {
        final p0 = i == 0 ? points[i] : points[i - 1];
        final p1 = points[i];
        final p2 = points[i + 1];
        final p3 = i + 2 < points.length ? points[i + 2] : p2;

        path.cubicTo(
          p1.dx + (p2.dx - p0.dx) / 6,
          p1.dy + (p2.dy - p0.dy) / 6,
          p2.dx - (p3.dx - p1.dx) / 6,
          p2.dy - (p3.dy - p1.dy) / 6,
          p2.dx,
          p2.dy,
        );
      }

      if (serie.filled) {
        final area = Path.from(path)
          ..lineTo(points.last.dx, top + chartHeight)
          ..lineTo(points.first.dx, top + chartHeight)
          ..close();
        canvas.drawPath(
          area,
          Paint()
            ..shader = LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                serie.color.withValues(alpha: 0.20),
                serie.color.withValues(alpha: 0.02),
              ],
            ).createShader(Rect.fromLTWH(0, top, size.width, chartHeight)),
        );
      }

      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..color = serie.color,
      );

      final dot = Paint()..color = serie.color;
      for (var i = 0; i < points.length; i++) {
        // Punto grueso con halo del color del fondo, como en el mockup.
        canvas.drawCircle(points[i], 5.5, dot);

        if (!showPointValues) continue;
        final painter = TextPainter(
          text: TextSpan(
            text: serie.values[i].round().toString(),
            style: TextStyle(
              color: labelColor,
              fontSize: 12,
              fontWeight: FontWeight.w800,
              fontFamily: fontFamily,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        painter.paint(
          canvas,
          Offset(points[i].dx - painter.width / 2, points[i].dy - 22),
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _LinePainter old) =>
      old.series != series || old.axisMax != axisMax;
}

/// Micro-gráfico sin ejes para las tarjetas KPI de escritorio.
/// → las curvitas bajo cada KPI de `analytics de vacantes.png`.
class MpSparkline extends StatelessWidget {
  final List<double> values;
  final Color color;
  final double height;

  const MpSparkline({
    super.key,
    required this.values,
    required this.color,
    this.height = 40,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      width: double.infinity,
      child: CustomPaint(
        painter: _LinePainter(
          series: [MpLineSeries(values: values, color: color, filled: true)],
          grid: const Color(0x00000000),
          labelColor: color,
          showPointValues: false,
        ),
      ),
    );
  }
}
