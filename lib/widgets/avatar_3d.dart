import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/profile.dart';
import '../theme.dart';

/// Avatar corporal paramétrico con efecto 3D.
///
/// La silueta se dibuja con curvas y cambia en tiempo real según:
/// - [sex]: proporciones de hombros/cintura/cadera distintas.
/// - [bmi]: el índice de masa corporal ensancha o afina el cuerpo.
/// El efecto 3D se logra con sombreado cilíndrico + rotación en Y animada.
class Avatar3D extends StatefulWidget {
  final Sex sex;
  final double bmi;
  final double height;
  final bool animate;

  const Avatar3D({
    super.key,
    required this.sex,
    required this.bmi,
    this.height = 260,
    this.animate = true,
  });

  @override
  State<Avatar3D> createState() => _Avatar3DState();
}

class _Avatar3DState extends State<Avatar3D>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
        vsync: this, duration: const Duration(seconds: 4));
    if (widget.animate) _controller.repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: widget.height,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (_, _) {
          final angle =
              widget.animate ? math.sin(_controller.value * math.pi) * 0.6 - 0.3 : 0.0;
          return Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.0012)
              ..rotateY(angle),
            child: CustomPaint(
              size: Size(widget.height * 0.62, widget.height),
              painter: _BodyPainter(sex: widget.sex, bmi: widget.bmi),
            ),
          );
        },
      ),
    );
  }
}

class _BodyPainter extends CustomPainter {
  final Sex sex;
  final double bmi;

  _BodyPainter({required this.sex, required this.bmi});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final cx = w / 2;

    // Factor corporal: IMC 22 = 1.0; se ensancha/afina con límites sanos.
    final f = (bmi / 22.0).clamp(0.78, 1.45);

    final isF = sex == Sex.female;
    // Semianchos como fracción del ancho del lienzo.
    final shoulder = w * (isF ? 0.240 : 0.300) * f;
    final waist = w * (isF ? 0.150 : 0.195) * f;
    final hip = w * (isF ? 0.235 : 0.205) * f;
    final thigh = w * (isF ? 0.105 : 0.100) * math.sqrt(f);
    final calf = thigh * 0.62;

    // Alturas clave (fracción de h).
    final headR = h * 0.062;
    final headCy = h * 0.075;
    final neckY = h * 0.135;
    final shoulderY = h * 0.185;
    final chestY = h * 0.30;
    final waistY = h * 0.42;
    final hipY = h * 0.52;
    final kneeY = h * 0.74;
    final ankleY = h * 0.965;

    final bodyGradient = LinearGradient(
      begin: Alignment.centerLeft,
      end: Alignment.centerRight,
      colors: const [
        Color(0xFF232B3B),
        Color(0xFF56637C),
        Color(0xFF232B3B),
      ],
      stops: const [0.05, 0.5, 0.95],
    );
    final fill = Paint()
      ..shader =
          bodyGradient.createShader(Rect.fromLTWH(0, 0, w, h))
      ..style = PaintingStyle.fill;
    final rim = Paint()
      ..color = AppColors.accent.withValues(alpha: 0.55)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2;

    // ---- Torso ----
    final torso = Path()
      ..moveTo(cx - shoulder * 0.55, neckY)
      // hombro izquierdo
      ..quadraticBezierTo(cx - shoulder, neckY + h * 0.012,
          cx - shoulder, shoulderY)
      // costado izquierdo: pecho -> cintura
      ..cubicTo(cx - shoulder * (isF ? 1.02 : 0.98), chestY,
          cx - waist * 1.12, waistY - h * 0.03, cx - waist, waistY)
      // cintura -> cadera
      ..quadraticBezierTo(
          cx - hip * 1.06, hipY - h * 0.035, cx - hip, hipY)
      // bajo de cadera
      ..quadraticBezierTo(cx, hipY + h * 0.045, cx + hip, hipY)
      // costado derecho: cadera -> cintura -> pecho
      ..quadraticBezierTo(
          cx + hip * 1.06, hipY - h * 0.035, cx + waist, waistY)
      ..cubicTo(cx + waist * 1.12, waistY - h * 0.03,
          cx + shoulder * (isF ? 1.02 : 0.98), chestY, cx + shoulder,
          shoulderY)
      // hombro derecho
      ..quadraticBezierTo(cx + shoulder, neckY + h * 0.012,
          cx + shoulder * 0.55, neckY)
      ..close();
    canvas.drawPath(torso, fill);
    canvas.drawPath(torso, rim);

    // ---- Brazos (cápsulas laterales) ----
    final armW = w * 0.075 * math.sqrt(f);
    for (final side in [-1.0, 1.0]) {
      final sx = cx + side * (shoulder + armW * 0.45);
      final arm = RRect.fromRectAndRadius(
        Rect.fromCenter(
            center: Offset(sx + side * armW * 0.2, (shoulderY + waistY) / 2 + h * 0.045),
            width: armW,
            height: waistY - shoulderY + h * 0.12),
        Radius.circular(armW),
      );
      canvas.drawRRect(arm, fill);
      canvas.drawRRect(arm, rim..strokeWidth = 1.6);
    }

    // ---- Piernas ----
    for (final side in [-1.0, 1.0]) {
      final legCx = cx + side * hip * 0.52;
      final leg = Path()
        ..moveTo(legCx - thigh, hipY)
        ..quadraticBezierTo(legCx - thigh * 0.92, (hipY + kneeY) / 2,
            legCx - calf, kneeY)
        ..quadraticBezierTo(legCx - calf * 0.9, (kneeY + ankleY) / 2,
            legCx - calf * 0.55, ankleY)
        ..lineTo(legCx + calf * 0.55, ankleY)
        ..quadraticBezierTo(legCx + calf * 0.9, (kneeY + ankleY) / 2,
            legCx + calf, kneeY)
        ..quadraticBezierTo(legCx + thigh * 0.92, (hipY + kneeY) / 2,
            legCx + thigh, hipY)
        ..close();
      canvas.drawPath(leg, fill);
      canvas.drawPath(leg, rim..strokeWidth = 1.8);
    }

    // ---- Cuello y cabeza ----
    final neck = Rect.fromCenter(
        center: Offset(cx, (headCy + headR + neckY) / 2),
        width: headR * 0.9,
        height: neckY - headCy - headR + h * 0.02);
    canvas.drawRect(neck, fill);
    canvas.drawCircle(Offset(cx, headCy + headR * 0.2), headR, fill);
    canvas.drawCircle(Offset(cx, headCy + headR * 0.2), headR,
        rim..strokeWidth = 2.0);

    // Cabello: melena para mujer, corte corto para hombre.
    final hair = Paint()..color = const Color(0xFF1A2130);
    if (isF) {
      final mane = Path()
        ..moveTo(cx - headR * 1.15, headCy + headR * 0.1)
        ..quadraticBezierTo(cx - headR * 1.3, shoulderY - h * 0.01,
            cx - headR * 0.85, shoulderY + h * 0.012)
        ..lineTo(cx + headR * 0.85, shoulderY + h * 0.012)
        ..quadraticBezierTo(cx + headR * 1.3, shoulderY - h * 0.01,
            cx + headR * 1.15, headCy + headR * 0.1)
        ..arcTo(
            Rect.fromCircle(
                center: Offset(cx, headCy + headR * 0.05),
                radius: headR * 1.15),
            0,
            -math.pi,
            false)
        ..close();
      canvas.drawPath(mane, hair);
    } else {
      canvas.drawArc(
          Rect.fromCircle(
              center: Offset(cx, headCy + headR * 0.15), radius: headR * 1.02),
          math.pi,
          math.pi,
          true,
          hair);
    }
  }

  @override
  bool shouldRepaint(_BodyPainter old) =>
      old.sex != sex || old.bmi != bmi;
}
