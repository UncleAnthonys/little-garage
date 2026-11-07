import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../data/models.dart';
import 'truck_art.dart';

/// Where the road sits on screen, as fractions of height. Shared so the
/// truck can be placed on the lane.
class RoadLayout {
  static double top(Size s) => s.height * 0.64;
  static double height(Size s) => s.height * 0.24;
  static double lane(Size s) => top(s) + height(s) * 0.42;
}

/// Outdoor scene with parallax. [scroll] is world pixels travelled.
class SceneryPainter extends CustomPainter {
  final double scroll;
  final bool night;
  SceneryPainter({this.scroll = 0, this.night = false});

  @override
  void paint(Canvas c, Size s) {
    final w = s.width, h = s.height;
    final roadTop = RoadLayout.top(s);
    final roadH = RoadLayout.height(s);

    // Sky.
    c.drawRect(
        Offset.zero & s,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: night
                ? const [Color(0xFF1B1F5E), Color(0xFF3B3F9E)]
                : const [Color(0xFF56CCF2), Color(0xFFC6F4E4)],
          ).createShader(Offset.zero & s));

    // Sun or moon.
    final orb = Offset(w * 0.84, h * 0.2);
    if (night) {
      c.drawCircle(orb, h * 0.07, Paint()..color = const Color(0xFFFFF3B0));
      c.drawCircle(orb + Offset(h * 0.03, -h * 0.015), h * 0.06,
          Paint()..color = const Color(0xFF262B78));
      final rnd = math.Random(7);
      for (var i = 0; i < 40; i++) {
        final p = Offset(rnd.nextDouble() * w, rnd.nextDouble() * h * 0.45);
        c.drawPath(starPath(p, 2 + rnd.nextDouble() * 3),
            Paint()..color = const Color(0xFFFFE066));
      }
    } else {
      c.drawCircle(orb, h * 0.09,
          Paint()
            ..color = fade(const Color(0xFFFFE066), 0.35)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18));
      c.drawCircle(orb, h * 0.07, Paint()..color = const Color(0xFFFFD23F));
    }

    // Clouds (slow parallax).
    if (!night) {
      final cloud = Paint()..color = fade(Colors.white, 0.9);
      for (var i = 0; i < 4; i++) {
        final x = ((i * w * 0.33 - scroll * 0.05) % (w * 1.3)) - w * 0.15;
        final y = h * (0.1 + 0.07 * (i % 2));
        c.drawCircle(Offset(x, y), h * 0.035, cloud);
        c.drawCircle(Offset(x + h * 0.04, y - h * 0.02), h * 0.045, cloud);
        c.drawCircle(Offset(x + h * 0.09, y), h * 0.035, cloud);
        c.drawRRect(
            RRect.fromLTRBR(x - h * 0.03, y, x + h * 0.12, y + h * 0.03,
                Radius.circular(h * 0.015)),
            cloud);
      }
    }

    // Far hills.
    final hill = Path()..moveTo(0, roadTop);
    for (var x = 0.0; x <= w + 10; x += 10) {
      final wx = x + scroll * 0.2;
      hill.lineTo(x, roadTop - h * 0.14 - math.sin(wx / 140) * h * 0.04);
    }
    hill
      ..lineTo(w, roadTop)
      ..close();
    c.drawPath(hill,
        Paint()..color = night ? const Color(0xFF2F6B3A) : const Color(0xFF8BC34A));

    // Trees (mid parallax).
    const spacing = 150.0;
    final treeOffset = scroll * 0.5;
    final first = (treeOffset / spacing).floor() - 1;
    for (var i = first; i < first + w / spacing + 3; i++) {
      final x = i * spacing - treeOffset;
      final tall = h * (0.16 + 0.06 * ((i * 7) % 3) / 2);
      final base = roadTop - h * 0.02;
      final green = i % 3 != 0;
      final leaf = night
          ? (green ? const Color(0xFF1E5631) : const Color(0xFF8A4B2A))
          : (green ? const Color(0xFF2E9E46) : const Color(0xFFF08A4B));
      c.drawRect(Rect.fromLTWH(x - 3, base - tall * 0.3, 6, tall * 0.3),
          Paint()..color = const Color(0xFF7A5230));
      final tree = Path()
        ..moveTo(x, base - tall)
        ..quadraticBezierTo(x + tall * 0.32, base - tall * 0.35, x, base - tall * 0.22)
        ..quadraticBezierTo(x - tall * 0.32, base - tall * 0.35, x, base - tall)
        ..close();
      c.drawPath(tree, Paint()..color = leaf);
    }

    // Verge.
    c.drawRect(Rect.fromLTWH(0, roadTop - h * 0.03, w, h * 0.03),
        Paint()..color = night ? const Color(0xFF3E7A2E) : const Color(0xFF7CB342));

    // Road.
    c.drawRect(Rect.fromLTWH(0, roadTop, w, roadH),
        Paint()..color = night ? const Color(0xFF55536A) : const Color(0xFF7D7A91));
    final edge = Paint()
      ..color = night ? const Color(0xFFB0A65A) : const Color(0xFFE8D86A)
      ..strokeWidth = 3;
    c.drawLine(Offset(0, roadTop + 6), Offset(w, roadTop + 6), edge);
    c.drawLine(Offset(0, roadTop + roadH - 6), Offset(w, roadTop + roadH - 6), edge);
    final dash = Paint()..color = fade(Colors.white, night ? 0.6 : 0.95);
    const dashW = 60.0, gap = 50.0;
    final start = -(scroll % (dashW + gap));
    for (var x = start; x < w; x += dashW + gap) {
      c.drawRect(Rect.fromLTWH(x, roadTop + roadH / 2 - 3, dashW, 6), dash);
    }

    // Grass below.
    c.drawRect(Rect.fromLTWH(0, roadTop + roadH, w, h - roadTop - roadH),
        Paint()..color = night ? const Color(0xFF3E7A2E) : const Color(0xFF8BC34A));
  }

  @override
  bool shouldRepaint(covariant SceneryPainter old) =>
      old.scroll != scroll || old.night != night;
}

/// Indoor garage: brick wall, shelves, floor and a lift platform.
class GaragePainter extends CustomPainter {
  const GaragePainter();

  @override
  void paint(Canvas c, Size s) {
    final w = s.width, h = s.height;
    final floorY = h * 0.72;
    c.drawRect(Rect.fromLTWH(0, 0, w, floorY),
        Paint()..color = const Color(0xFFF2C6A8));
    final brick = Paint()..color = const Color(0xFFE29C7E);
    final bw = h * 0.12, bh = h * 0.045;
    for (var row = 0; row * bh * 1.6 < floorY; row++) {
      final y = row * bh * 1.6 + bh * 0.4;
      final shift = row.isEven ? 0.0 : bw * 0.6;
      for (var x = -bw + shift; x < w; x += bw * 2.2) {
        if ((row * 5 + (x ~/ bw)) % 3 == 0) continue;
        c.drawRRect(
            RRect.fromRectAndRadius(Rect.fromLTWH(x, y, bw, bh), const Radius.circular(3)),
            brick);
      }
    }
    // Shelf with tyres.
    final shelf = Rect.fromLTWH(w * 0.78, h * 0.18, w * 0.17, h * 0.03);
    c.drawRect(shelf, Paint()..color = const Color(0xFF9C6B4E));
    for (var i = 0; i < 3; i++) {
      paintWheel(c, Offset(shelf.left + shelf.width * (0.2 + i * 0.3), shelf.top - h * 0.05),
          h * 0.045, WheelStyle.values[i], 0);
    }
    // Hanging lamps.
    for (final x in [w * 0.22, w * 0.62]) {
      c.drawLine(Offset(x, 0), Offset(x, h * 0.1), Paint()..color = kInk);
      final shadeP = Path()
        ..moveTo(x - h * 0.04, h * 0.14)
        ..lineTo(x - h * 0.015, h * 0.1)
        ..lineTo(x + h * 0.015, h * 0.1)
        ..lineTo(x + h * 0.04, h * 0.14)
        ..close();
      c.drawPath(shadeP, Paint()..color = const Color(0xFF3D405B));
      final beam = Path()
        ..moveTo(x - h * 0.04, h * 0.14)
        ..lineTo(x - h * 0.2, floorY)
        ..lineTo(x + h * 0.2, floorY)
        ..lineTo(x + h * 0.04, h * 0.14)
        ..close();
      c.drawPath(beam, Paint()..color = fade(const Color(0xFFFFF3B0), 0.25));
    }
    // Floor.
    c.drawRect(Rect.fromLTWH(0, floorY, w, h - floorY),
        Paint()..color = const Color(0xFFE8D5CC));
    c.drawLine(Offset(0, floorY), Offset(w, floorY),
        Paint()
          ..color = const Color(0xFFC9AFA3)
          ..strokeWidth = 3);
  }

  @override
  bool shouldRepaint(covariant GaragePainter old) => false;
}
