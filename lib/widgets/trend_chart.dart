import 'package:flutter/material.dart';

import '../theme.dart';

/// Punto de una serie temporal para [TrendChart].
class TrendPoint {
  final DateTime date;
  final double value;
  const TrendPoint(this.date, this.value);
}

/// Gráfica de línea minimalista para medidas y cargas: área suave, puntos,
/// último valor resaltado y etiquetas de mínimo/máximo. Sin dependencias.
class TrendChart extends StatelessWidget {
  final List<TrendPoint> points;
  final String unit;
  final double height;

  const TrendChart({
    super.key,
    required this.points,
    required this.unit,
    this.height = 180,
  });

  @override
  Widget build(BuildContext context) {
    if (points.length < 2) {
      return SizedBox(
        height: height,
        child: Center(
          child: Text(
            points.isEmpty
                ? 'Sin datos todavía'
                : 'Registra una segunda toma para ver la tendencia',
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.textSecondary),
          ),
        ),
      );
    }
    final sorted = [...points]..sort((a, b) => a.date.compareTo(b.date));
    return SizedBox(
      height: height,
      child: CustomPaint(
        painter: _TrendPainter(sorted, unit),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _TrendPainter extends CustomPainter {
  final List<TrendPoint> pts;
  final String unit;
  _TrendPainter(this.pts, this.unit);

  static const _padL = 8.0, _padR = 44.0, _padT = 18.0, _padB = 22.0;

  @override
  void paint(Canvas canvas, Size size) {
    final minV = pts.map((p) => p.value).reduce((a, b) => a < b ? a : b);
    final maxV = pts.map((p) => p.value).reduce((a, b) => a > b ? a : b);
    final span = (maxV - minV).abs() < 0.01 ? 1.0 : maxV - minV;
    final lo = minV - span * 0.15, hi = maxV + span * 0.15;
    final t0 = pts.first.date.millisecondsSinceEpoch.toDouble();
    final t1 = pts.last.date.millisecondsSinceEpoch.toDouble();
    final tSpan = t1 - t0 == 0 ? 1.0 : t1 - t0;
    final w = size.width - _padL - _padR;
    final h = size.height - _padT - _padB;

    Offset at(TrendPoint p) => Offset(
          _padL + (p.date.millisecondsSinceEpoch - t0) / tSpan * w,
          _padT + (1 - (p.value - lo) / (hi - lo)) * h,
        );

    // Rejilla ligera.
    final grid = Paint()
      ..color = AppColors.surfaceHigh
      ..strokeWidth = 1;
    for (var i = 0; i <= 3; i++) {
      final y = _padT + h * i / 3;
      canvas.drawLine(Offset(_padL, y), Offset(_padL + w, y), grid);
    }

    // Área + línea.
    final path = Path()..moveTo(at(pts.first).dx, at(pts.first).dy);
    for (final p in pts.skip(1)) {
      path.lineTo(at(p).dx, at(p).dy);
    }
    final area = Path.from(path)
      ..lineTo(at(pts.last).dx, _padT + h)
      ..lineTo(at(pts.first).dx, _padT + h)
      ..close();
    canvas.drawPath(
        area,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppColors.accent.withValues(alpha: 0.28),
              AppColors.accent.withValues(alpha: 0.0),
            ],
          ).createShader(Rect.fromLTWH(0, _padT, size.width, h)));
    canvas.drawPath(
        path,
        Paint()
          ..color = AppColors.accent
          ..strokeWidth = 2.5
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round);

    // Puntos.
    final dot = Paint()..color = AppColors.accent;
    final dotBg = Paint()..color = AppColors.surface;
    for (final p in pts) {
      canvas.drawCircle(at(p), 4, dotBg);
      canvas.drawCircle(at(p), 3, dot);
    }
    canvas.drawCircle(at(pts.last), 6, dot);
    canvas.drawCircle(at(pts.last), 3, dotBg);

    // Etiquetas: último valor a la derecha, min/max, fechas extremas.
    _label(canvas, '${_fmt(pts.last.value)} $unit',
        Offset(at(pts.last).dx + 8, at(pts.last).dy - 7),
        color: AppColors.textPrimary, bold: true);
    _label(canvas, _fmt(maxV), Offset(_padL, _padT - 16),
        color: AppColors.textSecondary);
    _label(canvas, _fmt(minV), Offset(_padL, _padT + h + 2),
        color: AppColors.textSecondary);
    final d0 = _date(pts.first.date), d1 = _date(pts.last.date);
    _label(canvas, d0, Offset(_padL + 34, _padT + h + 2),
        color: AppColors.textSecondary);
    _label(canvas, d1, Offset(_padL + w - 36, _padT + h + 2),
        color: AppColors.textSecondary);
  }

  static String _fmt(double v) =>
      v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(1);
  static String _date(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}';

  void _label(Canvas c, String text, Offset o,
      {required Color color, bool bold = false}) {
    final tp = TextPainter(
      text: TextSpan(
          text: text,
          style: TextStyle(
              fontSize: 11,
              color: color,
              fontWeight: bold ? FontWeight.w800 : FontWeight.w500)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(c, o);
  }

  @override
  bool shouldRepaint(covariant _TrendPainter old) =>
      old.pts != pts || old.unit != unit;
}
