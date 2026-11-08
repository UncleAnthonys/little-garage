import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../data/missions.dart';
import 'truck_art.dart';

// ---------------------------------------------------------------------------
// Townsfolk.
// ---------------------------------------------------------------------------

/// Draws a townsperson's head. [mood] -1 sad .. 0 calm .. 1 happy.
void paintTownsperson(Canvas c, Townsperson p, Offset ctr, double r,
    {double mood = 1, bool talking = false, double t = 0}) {
  final fur = Paint()..color = p.fur;
  final ink = Paint()..color = kInk;
  final outline = Paint()
    ..color = fade(kInk, 0.8)
    ..style = PaintingStyle.stroke
    ..strokeWidth = r * 0.06;

  // Ears behind the head.
  switch (p.ears) {
    case Ears.round:
      for (final sx in [-1.0, 1.0]) {
        final e = ctr + Offset(sx * r * 0.72, -r * 0.72);
        c.drawCircle(e, r * 0.34, fur);
        c.drawCircle(e, r * 0.34, outline);
        c.drawCircle(e, r * 0.18, Paint()..color = p.snout);
      }
      break;
    case Ears.pointy:
      for (final sx in [-1.0, 1.0]) {
        final ear = Path()
          ..moveTo(ctr.dx + sx * r * 0.85, ctr.dy - r * 0.2)
          ..lineTo(ctr.dx + sx * r * 0.75, ctr.dy - r * 1.25)
          ..lineTo(ctr.dx + sx * r * 0.2, ctr.dy - r * 0.8)
          ..close();
        c.drawPath(ear, fur);
        c.drawPath(ear, outline);
      }
      break;
    case Ears.long:
      for (final sx in [-1.0, 1.0]) {
        final ear = Rect.fromCenter(
            center: ctr + Offset(sx * r * 0.42, -r * 1.25), width: r * 0.5, height: r * 1.3);
        c.drawOval(ear, fur);
        c.drawOval(ear, outline);
      }
      break;
    case Ears.floppy:
      for (final sx in [-1.0, 1.0]) {
        final ear = Rect.fromCenter(
            center: ctr + Offset(sx * r * 1.0, -r * 0.1), width: r * 0.5, height: r * 0.85);
        c.save();
        c.translate(ear.center.dx, ear.center.dy);
        c.rotate(sx * 0.5);
        c.translate(-ear.center.dx, -ear.center.dy);
        c.drawOval(ear, Paint()..color = p.snout);
        c.drawOval(ear, outline);
        c.restore();
      }
      break;
    case Ears.none:
      break;
  }

  // Woolly sheep head gets a fluffy ring.
  if (p.ears == Ears.floppy) {
    for (var i = 0; i < 10; i++) {
      final a = i * math.pi * 2 / 10;
      c.drawCircle(ctr + Offset(math.cos(a), math.sin(a)) * r * 0.82, r * 0.3, fur);
    }
  }

  c.drawCircle(ctr, r, p.ears == Ears.floppy ? (Paint()..color = p.snout) : fur);
  c.drawCircle(ctr, r, outline);

  // Badger stripe.
  if (p.id == 'bramble') {
    c.drawOval(Rect.fromCenter(center: ctr + Offset(0, -r * 0.2), width: r * 0.42, height: r * 1.5),
        Paint()..color = Colors.white);
  }

  // Snout or beak.
  if (p.beak) {
    final beak = Path()
      ..moveTo(ctr.dx - r * 0.28, ctr.dy + r * 0.15)
      ..quadraticBezierTo(ctr.dx, ctr.dy + r * (talking ? 0.75 + 0.1 * math.sin(t * 20) : 0.6),
          ctr.dx + r * 0.28, ctr.dy + r * 0.15)
      ..close();
    c.drawPath(beak, Paint()..color = p.snout);
    c.drawPath(beak, outline);
  } else if (p.ears != Ears.floppy) {
    c.drawOval(
        Rect.fromCenter(center: ctr + Offset(0, r * 0.38), width: r * 0.9, height: r * 0.6),
        Paint()..color = p.snout);
  }

  // Eyes.
  final eyeY = ctr.dy - r * 0.12;
  for (final sx in [-1.0, 1.0]) {
    final e = Offset(ctr.dx + sx * r * 0.36, eyeY);
    c.drawCircle(e, r * 0.13, ink);
    c.drawCircle(e + Offset(r * 0.04, -r * 0.05), r * 0.045, Paint()..color = Colors.white);
    if (mood < 0) {
      // Worried brows.
      c.drawLine(e + Offset(-sx * r * 0.14, -r * 0.24), e + Offset(sx * r * 0.12, -r * 0.3),
          Paint()
            ..color = kInk
            ..strokeWidth = r * 0.07
            ..strokeCap = StrokeCap.round);
    }
  }

  if (!p.beak) {
    // Nose and mouth.
    c.drawOval(
        Rect.fromCenter(center: ctr + Offset(0, r * 0.22), width: r * 0.28, height: r * 0.18),
        ink);
    final mouth = Paint()
      ..color = kInk
      ..style = PaintingStyle.stroke
      ..strokeWidth = r * 0.07
      ..strokeCap = StrokeCap.round;
    final my = ctr.dy + r * 0.48;
    if (talking) {
      final open = r * (0.08 + 0.08 * (math.sin(t * 20) + 1) / 2);
      c.drawOval(Rect.fromCenter(center: Offset(ctr.dx, my), width: r * 0.3, height: open * 2),
          Paint()..color = const Color(0xFF8B1E3F));
    } else {
      final bend = r * 0.18 * mood;
      final path = Path()
        ..moveTo(ctr.dx - r * 0.22, my)
        ..quadraticBezierTo(ctr.dx, my + bend, ctr.dx + r * 0.22, my);
      c.drawPath(path, mouth);
    }
  }

  // Cheeks when happy.
  if (mood > 0.5) {
    for (final sx in [-1.0, 1.0]) {
      c.drawCircle(ctr + Offset(sx * r * 0.6, r * 0.28), r * 0.13,
          Paint()..color = fade(const Color(0xFFFF6FB5), 0.35));
    }
  }

  // Accessories.
  switch (p.hat) {
    case Hat.glasses:
      final g = Paint()
        ..color = kInk
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.06;
      c.drawCircle(Offset(ctr.dx - r * 0.36, eyeY), r * 0.24, g);
      c.drawCircle(Offset(ctr.dx + r * 0.36, eyeY), r * 0.24, g);
      c.drawLine(Offset(ctr.dx - r * 0.12, eyeY), Offset(ctr.dx + r * 0.12, eyeY), g);
      break;
    case Hat.chef:
      final hat = Paint()..color = Colors.white;
      c.drawRect(Rect.fromLTWH(ctr.dx - r * 0.55, ctr.dy - r * 1.15, r * 1.1, r * 0.4), hat);
      for (final dx in [-0.4, 0.0, 0.4]) {
        c.drawCircle(ctr + Offset(dx * r, -r * 1.35), r * 0.35, hat);
      }
      c.drawRect(Rect.fromLTWH(ctr.dx - r * 0.55, ctr.dy - r * 1.15, r * 1.1, r * 0.4), outline);
      break;
    case Hat.farmer:
      final straw = Paint()..color = const Color(0xFFE9C46A);
      c.drawOval(Rect.fromCenter(center: ctr + Offset(0, -r * 0.85), width: r * 2.4, height: r * 0.45), straw);
      c.drawRRect(
          RRect.fromRectAndRadius(
              Rect.fromCenter(center: ctr + Offset(0, -r * 1.1), width: r * 1.2, height: r * 0.6),
              Radius.circular(r * 0.2)),
          straw);
      c.drawRect(Rect.fromCenter(center: ctr + Offset(0, -r * 0.9), width: r * 1.2, height: r * 0.12),
          Paint()..color = const Color(0xFFE63946));
      break;
    case Hat.cap:
      final cap = Paint()..color = const Color(0xFF3A86FF);
      c.drawArc(Rect.fromCircle(center: ctr + Offset(0, -r * 0.5), radius: r * 0.75), math.pi, math.pi, true, cap);
      c.drawRRect(
          RRect.fromRectAndRadius(
              Rect.fromLTWH(ctr.dx, ctr.dy - r * 0.6, r * 1.0, r * 0.18), Radius.circular(r * 0.09)),
          cap);
      break;
    case Hat.topHat:
      final hat = Paint()..color = kInk;
      c.drawRect(Rect.fromCenter(center: ctr + Offset(0, -r * 1.3), width: r * 0.9, height: r * 0.9), hat);
      c.drawRect(Rect.fromCenter(center: ctr + Offset(0, -r * 0.88), width: r * 1.5, height: r * 0.14), hat);
      c.drawRect(Rect.fromCenter(center: ctr + Offset(0, -r * 1.05), width: r * 0.9, height: r * 0.14),
          Paint()..color = const Color(0xFFE63946));
      break;
    case Hat.bow:
      final bow = Paint()..color = const Color(0xFFFF6FB5);
      final b = ctr + Offset(r * 0.55, -r * 0.85);
      c.drawPath(
          Path()
            ..moveTo(b.dx, b.dy)
            ..lineTo(b.dx - r * 0.35, b.dy - r * 0.22)
            ..lineTo(b.dx - r * 0.35, b.dy + r * 0.22)
            ..close(),
          bow);
      c.drawPath(
          Path()
            ..moveTo(b.dx, b.dy)
            ..lineTo(b.dx + r * 0.35, b.dy - r * 0.22)
            ..lineTo(b.dx + r * 0.35, b.dy + r * 0.22)
            ..close(),
          bow);
      c.drawCircle(b, r * 0.1, bow);
      break;
    case Hat.none:
      break;
  }

  // Gus the owl gets big eye rings.
  if (p.id == 'gus') {
    final ring = Paint()
      ..color = const Color(0xFFF2D7B6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = r * 0.1;
    c.drawCircle(Offset(ctr.dx - r * 0.36, eyeY), r * 0.25, ring);
    c.drawCircle(Offset(ctr.dx + r * 0.36, eyeY), r * 0.25, ring);
  }
}

class TownspersonPainter extends CustomPainter {
  final Townsperson person;
  final double mood;
  final bool talking;
  final double t;
  TownspersonPainter(this.person, {this.mood = 1, this.talking = false, this.t = 0});

  @override
  void paint(Canvas canvas, Size size) {
    final r = size.shortestSide * 0.32;
    paintTownsperson(canvas, person, size.center(Offset(0, r * 0.25)), r,
        mood: mood, talking: talking, t: t);
  }

  @override
  bool shouldRepaint(covariant TownspersonPainter old) => true;
}

/// A whole little figure: head on a body, for scenes.
void paintFigure(Canvas c, Townsperson p, Offset feet, double h,
    {double mood = 1, Color shirt = const Color(0xFF4CC9F0), bool sitting = false}) {
  final r = h * 0.22;
  final bodyH = sitting ? h * 0.32 : h * 0.45;
  final body = RRect.fromRectAndRadius(
      Rect.fromLTWH(feet.dx - r * 0.75, feet.dy - bodyH, r * 1.5, bodyH), Radius.circular(r * 0.5));
  c.drawRRect(body, Paint()..color = shirt);
  c.drawRRect(
      body,
      Paint()
        ..color = fade(kInk, 0.8)
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.08);
  paintTownsperson(c, p, Offset(feet.dx, feet.dy - bodyH - r * 0.8), r, mood: mood);
}

// ---------------------------------------------------------------------------
// Simple vehicles, drawn in a 300 x 180 unit box, wheels resting at y=166.
// ---------------------------------------------------------------------------

const double kSimpleW = 300;
const double kSimpleH = 180;

class CarLook {
  final VehicleType type;
  final Color color;
  final Fault? fault;
  final Townsperson? driver;
  final double driverMood;
  final bool lightsOn;
  final double wheelTurn;
  final double t;

  /// 0..1: fix animation progress for the current fault.
  final double fixing;

  const CarLook({
    this.type = VehicleType.car,
    this.color = const Color(0xFF3A86FF),
    this.fault,
    this.driver,
    this.driverMood = 1,
    this.lightsOn = false,
    this.wheelTurn = 0,
    this.t = 0,
    this.fixing = 0,
  });
}

final Paint _ink = Paint()
  ..color = kInk
  ..style = PaintingStyle.stroke
  ..strokeWidth = 2.5
  ..strokeJoin = StrokeJoin.round;

void _fs(Canvas c, Path p, Color fill) {
  c.drawPath(p, Paint()..color = fill);
  c.drawPath(p, _ink);
}

void _wheel(Canvas c, Offset ctr, double r, double turn, {bool flat = false, bool loose = false, double t = 0}) {
  c.save();
  c.translate(ctr.dx, ctr.dy);
  if (flat) {
    c.translate(0, r * 0.22);
    c.scale(1.16, 0.74);
  }
  if (loose) c.translate(math.sin(t * 40) * 2, 0);
  c.drawCircle(Offset.zero, r, Paint()..color = const Color(0xFF353A4D));
  c.drawCircle(Offset.zero, r, _ink);
  c.rotate(turn);
  c.drawCircle(Offset.zero, r * 0.55, Paint()..color = const Color(0xFFCED4DA));
  c.drawCircle(Offset.zero, r * 0.55, _ink);
  for (var i = 0; i < 4; i++) {
    final a = i * math.pi / 2;
    final bolt = Offset(math.cos(a), math.sin(a)) * r * 0.3;
    if (loose && i == 0) {
      // A bolt sticking out.
      c.drawRect(Rect.fromCenter(center: bolt + Offset(r * 0.25, 0), width: r * 0.45, height: r * 0.16),
          Paint()..color = const Color(0xFF6C757D));
    } else {
      c.drawCircle(bolt, r * 0.08, Paint()..color = kInk);
    }
  }
  c.restore();
}

void _beacon(Canvas c, Offset at, double t, Color color) {
  c.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: at, width: 22, height: 12), const Radius.circular(4)),
      Paint()..color = color);
  final on = (math.sin(t * 12) + 1) / 2;
  c.drawCircle(at, 14 + 6 * on, Paint()..color = fade(color, 0.25 * on));
}

/// Draws a vehicle of [look.type] inside the 300 x 180 box.
void paintSimpleVehicle(Canvas c, CarLook look) {
  switch (look.type) {
    case VehicleType.car:
    case VehicleType.electricCar:
      _car(c, look);
      break;
    case VehicleType.fireEngine:
      _truck(c, look, const Color(0xFFE63946), long: true);
      final ladder = Paint()
        ..color = const Color(0xFFCED4DA)
        ..strokeWidth = 5;
      c.drawLine(const Offset(30, 58), const Offset(200, 46), ladder);
      c.drawLine(const Offset(30, 70), const Offset(200, 58), ladder);
      for (var x = 40.0; x < 200; x += 18) {
        c.drawLine(Offset(x, 57 - (x - 30) * 0.07), Offset(x, 69 - (x - 30) * 0.07),
            ladder..strokeWidth = 3);
      }
      c.drawCircle(const Offset(120, 112), 16, Paint()..color = const Color(0xFFFFD23F));
      c.drawCircle(const Offset(120, 112), 16, _ink);
      _beacon(c, const Offset(250, 40), look.t, const Color(0xFF4C6EF5));
      break;
    case VehicleType.ambulance:
      _van(c, Colors.white);
      c.drawRect(const Rect.fromLTWH(22, 112, 262, 10), Paint()..color = const Color(0xFF2DC653));
      final cross = Paint()..color = const Color(0xFFE63946);
      c.drawRect(const Rect.fromLTWH(88, 64, 12, 36), cross);
      c.drawRect(const Rect.fromLTWH(76, 76, 36, 12), cross);
      _beacon(c, const Offset(200, 36), look.t, const Color(0xFF4C6EF5));
      _wheel(c, const Offset(70, 150), 22, look.wheelTurn);
      _wheel(c, const Offset(232, 150), 22, look.wheelTurn);
      break;
    case VehicleType.bus:
      final body = Path()
        ..addRRect(RRect.fromLTRBR(8, 34, 292, 148, const Radius.circular(16)));
      _fs(c, body, const Color(0xFFFFB703));
      c.drawRect(const Rect.fromLTWH(8, 116, 284, 10), Paint()..color = const Color(0xFFE63946));
      for (var i = 0; i < 5; i++) {
        final w = RRect.fromLTRBR(22 + i * 46.0, 48, 58 + i * 46.0, 92, const Radius.circular(6));
        c.drawRRect(w, Paint()..color = const Color(0xFFBDE8F5));
        c.drawRRect(w, _ink);
      }
      final door = RRect.fromLTRBR(252, 48, 282, 140, const Radius.circular(5));
      c.drawRRect(door, Paint()..color = const Color(0xFFBDE8F5));
      c.drawRRect(door, _ink);
      _wheel(c, const Offset(62, 150), 22, look.wheelTurn);
      _wheel(c, const Offset(222, 150), 22, look.wheelTurn);
      break;
    case VehicleType.dumpTruck:
      final bed = Path()
        ..moveTo(10, 60)
        ..lineTo(190, 60)
        ..lineTo(180, 128)
        ..lineTo(24, 128)
        ..close();
      _fs(c, bed, const Color(0xFF8D99AE));
      for (var i = 0; i < 6; i++) {
        c.drawCircle(Offset(40 + i * 24.0, 58 - (i % 2) * 6.0), 14,
            Paint()..color = const Color(0xFF9C6B4E));
      }
      _cab(c, const Color(0xFFFF8C42), 196);
      c.drawRect(const Rect.fromLTWH(10, 128, 280, 16), Paint()..color = const Color(0xFF495057));
      _wheel(c, const Offset(66, 150), 24, look.wheelTurn);
      _wheel(c, const Offset(240, 150), 24, look.wheelTurn);
      break;
    case VehicleType.craneTruck:
      c.drawRect(const Rect.fromLTWH(10, 110, 280, 26), Paint()..color = const Color(0xFF495057));
      final arm = Paint()
        ..color = const Color(0xFFFFD23F)
        ..strokeWidth = 14
        ..strokeCap = StrokeCap.round;
      c.drawLine(const Offset(110, 104), const Offset(30, 6), arm);
      c.drawLine(const Offset(30, 6), const Offset(30, 60),
          Paint()
            ..color = kInk
            ..strokeWidth = 2.5);
      c.drawCircle(const Offset(30, 66), 7, Paint()..color = const Color(0xFF3A86FF));
      _fs(c, Path()..addRRect(RRect.fromLTRBR(80, 82, 150, 112, const Radius.circular(6))), const Color(0xFF7B4FD6));
      _cab(c, const Color(0xFFFFD23F), 196);
      _wheel(c, const Offset(66, 150), 22, look.wheelTurn);
      _wheel(c, const Offset(130, 150), 22, look.wheelTurn);
      _wheel(c, const Offset(244, 150), 22, look.wheelTurn);
      break;
    case VehicleType.digger:
      _digger(c, look);
      break;
    case VehicleType.mixer:
      _mixer(c, look);
      break;
    case VehicleType.towTruck:
      // Drawn with the child's own truck elsewhere; fall back to a plain one.
      _truck(c, look, const Color(0xFF9B5DE5));
      break;
  }
}

void _digger(Canvas c, CarLook look) {
  // Tracks.
  final track = RRect.fromLTRBR(56, 132, 262, 168, const Radius.circular(18));
  c.drawRRect(track, Paint()..color = const Color(0xFF353A4D));
  c.drawRRect(track, _ink);
  for (var i = 0; i < 5; i++) {
    final w = Offset(78 + i * 40.0, 150);
    c.save();
    c.translate(w.dx, w.dy);
    c.rotate(look.wheelTurn);
    c.drawCircle(Offset.zero, 12, Paint()..color = const Color(0xFF8D99AE));
    c.drawLine(const Offset(-8, 0), const Offset(8, 0), Paint()..color = kInk..strokeWidth = 2);
    c.restore();
  }
  // Body and cab.
  final body = Path()..addRRect(RRect.fromLTRBR(110, 92, 262, 132, const Radius.circular(10)));
  _fs(c, body, const Color(0xFFFFB703));
  final cab = Path()
    ..moveTo(176, 92)
    ..lineTo(180, 40)
    ..lineTo(240, 40)
    ..lineTo(252, 92)
    ..close();
  _fs(c, cab, const Color(0xFFFFB703));
  final win = Path()
    ..moveTo(190, 50)
    ..lineTo(234, 50)
    ..lineTo(242, 86)
    ..lineTo(188, 86)
    ..close();
  _fs(c, win, const Color(0xFFBDE8F5));
  // Arm: boom up from the body, stick down to the bucket.
  final arm = Paint()
    ..color = const Color(0xFFFFB703)
    ..strokeWidth = 16
    ..strokeCap = StrokeCap.round;
  const shoulder = Offset(150, 96), elbow = Offset(80, 34), wrist = Offset(40, 104);
  c.drawLine(shoulder, elbow, arm);
  c.drawLine(elbow, wrist, arm);
  final armInk = Paint()
    ..color = kInk
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2;
  c.drawCircle(elbow, 8, armInk);
  c.drawLine(shoulder + const Offset(-10, -14), elbow + const Offset(4, 12),
      Paint()..color = const Color(0xFF8D99AE)..strokeWidth = 5);
  // Bucket with teeth.
  final bucket = Path()
    ..moveTo(26, 98)
    ..lineTo(58, 98)
    ..quadraticBezierTo(58, 130, 34, 136)
    ..lineTo(18, 136)
    ..close();
  _fs(c, bucket, const Color(0xFF6C757D));
  for (var i = 0; i < 3; i++) {
    c.drawRect(Rect.fromLTWH(18 + i * 7.0, 136, 4, 6), Paint()..color = kInk);
  }
}

void _mixer(Canvas c, CarLook look) {
  c.drawRect(const Rect.fromLTWH(14, 120, 280, 16), Paint()..color = const Color(0xFF495057));
  // Drum, tilted, with a spinning stripe.
  c.save();
  c.translate(104, 82);
  c.rotate(-0.18);
  final drum = Rect.fromCenter(center: Offset.zero, width: 176, height: 84);
  c.drawOval(drum, Paint()..color = const Color(0xFFE9ECEF));
  c.clipPath(Path()..addOval(drum));
  final spin = (look.t * 40) % 60;
  for (var x = -120.0 + spin; x < 120; x += 60) {
    c.drawPath(
        Path()
          ..moveTo(x, -44)
          ..lineTo(x + 26, -44)
          ..lineTo(x - 4, 44)
          ..lineTo(x - 30, 44)
          ..close(),
        Paint()..color = const Color(0xFFFF8C42));
  }
  c.restore();
  c.save();
  c.translate(104, 82);
  c.rotate(-0.18);
  c.drawOval(Rect.fromCenter(center: Offset.zero, width: 176, height: 84), _ink);
  c.restore();
  // Chute at the back.
  c.drawLine(const Offset(18, 92), const Offset(4, 122),
      Paint()..color = const Color(0xFF6C757D)..strokeWidth = 8..strokeCap = StrokeCap.round);
  _cab(c, const Color(0xFF3A86FF), 196);
  _wheel(c, const Offset(66, 150), 22, look.wheelTurn);
  _wheel(c, const Offset(130, 150), 22, look.wheelTurn);
  _wheel(c, const Offset(244, 150), 22, look.wheelTurn);
}

void _cab(Canvas c, Color color, double x) {
  final cab = Path()
    ..moveTo(x, 144)
    ..lineTo(x, 58)
    ..quadraticBezierTo(x, 48, x + 10, 48)
    ..lineTo(x + 52, 48)
    ..lineTo(x + 84, 100)
    ..lineTo(x + 92, 104)
    ..lineTo(x + 92, 144)
    ..close();
  _fs(c, cab, color);
  final win = Path()
    ..moveTo(x + 12, 60)
    ..lineTo(x + 48, 60)
    ..lineTo(x + 72, 98)
    ..lineTo(x + 12, 98)
    ..close();
  _fs(c, win, const Color(0xFFBDE8F5));
}

void _truck(Canvas c, CarLook look, Color color, {bool long = false}) {
  final body = Path()..addRRect(RRect.fromLTRBR(10, 74, 200, 140, const Radius.circular(10)));
  _fs(c, body, color);
  _cab(c, color, 196);
  _wheel(c, const Offset(62, 150), 24, look.wheelTurn);
  if (long) _wheel(c, const Offset(124, 150), 24, look.wheelTurn);
  _wheel(c, const Offset(240, 150), 24, look.wheelTurn);
}

void _van(Canvas c, Color color) {
  final p = Path()
    ..moveTo(14, 140)
    ..lineTo(14, 46)
    ..quadraticBezierTo(14, 34, 26, 34)
    ..lineTo(222, 34)
    ..lineTo(270, 92)
    ..quadraticBezierTo(290, 96, 290, 112)
    ..lineTo(290, 140)
    ..close();
  _fs(c, p, color);
  final win = Path()
    ..moveTo(212, 46)
    ..lineTo(226, 46)
    ..lineTo(262, 90)
    ..lineTo(212, 90)
    ..close();
  _fs(c, win, const Color(0xFFBDE8F5));
}

void _car(Canvas c, CarLook look) {
  final f = look.fault;
  final fixing = look.fixing;
  final unfixed = f != null && fixing < 1;

  // Body.
  final body = Path()
    ..moveTo(18, 150)
    ..lineTo(18, 104)
    ..quadraticBezierTo(18, 84, 40, 82)
    ..lineTo(70, 80)
    ..lineTo(96, 40)
    ..quadraticBezierTo(102, 32, 114, 32)
    ..lineTo(186, 32)
    ..quadraticBezierTo(198, 32, 204, 40)
    ..lineTo(232, 80)
    ..lineTo(270, 86)
    ..quadraticBezierTo(290, 90, 290, 110)
    ..lineTo(290, 150)
    ..close();
  _fs(c, body, look.color);

  // Windows.
  final back = Path()
    ..moveTo(84, 80)
    ..lineTo(104, 46)
    ..lineTo(146, 46)
    ..lineTo(146, 80)
    ..close();
  final front = Path()
    ..moveTo(156, 80)
    ..lineTo(156, 46)
    ..lineTo(192, 46)
    ..lineTo(216, 80)
    ..close();
  _fs(c, back, const Color(0xFFBDE8F5));
  _fs(c, front, const Color(0xFFBDE8F5));

  // Driver in the back window.
  final d = look.driver;
  if (d != null) {
    c.save();
    c.clipPath(back);
    paintTownsperson(c, d, const Offset(124, 68), 16, mood: look.driverMood);
    c.restore();
  }

  // Muddy windscreen.
  if (f == Fault.dirtyWindscreen && unfixed) {
    c.save();
    c.clipPath(front);
    final mud = Paint()..color = fade(const Color(0xFF7A5230), 0.92 * (1 - fixing));
    for (final (x, y, r) in const [(168.0, 56.0, 12.0), (186.0, 64.0, 14.0), (200.0, 74.0, 10.0), (172.0, 74.0, 9.0), (190.0, 50.0, 8.0)]) {
      c.drawCircle(Offset(x, y), r, mud);
    }
    c.restore();
  }
  // Wiper sweep while fixing.
  if (f == Fault.dirtyWindscreen && fixing > 0 && fixing < 1) {
    final a = -math.pi / 2 + math.sin(fixing * math.pi * 6) * 1.0;
    c.drawLine(const Offset(186, 80), const Offset(186, 80) + Offset(math.cos(a), math.sin(a)) * 32,
        Paint()
          ..color = kInk
          ..strokeWidth = 3
          ..strokeCap = StrokeCap.round);
  }

  // Door line and handle.
  c.drawLine(const Offset(150, 82), const Offset(150, 140), _ink);
  c.drawRRect(RRect.fromLTRBR(160, 94, 176, 99, const Radius.circular(2)), Paint()..color = kInk);

  // Electric badge.
  if (look.type == VehicleType.electricCar) {
    final bolt = Path()
      ..moveTo(108, 96)
      ..lineTo(98, 114)
      ..lineTo(106, 114)
      ..lineTo(102, 128)
      ..lineTo(116, 106)
      ..lineTo(108, 106)
      ..close();
    c.drawCircle(const Offset(106, 112), 17, Paint()..color = const Color(0xFF2DC653));
    c.drawCircle(const Offset(106, 112), 17, _ink);
    c.drawPath(bolt, Paint()..color = Colors.white);
  }

  // Dashboard gauge (fuel or charge) inside the front window.
  if (f == Fault.noFuel || f == Fault.noCharge) {
    const g = Offset(150, 72);
    c.drawCircle(g, 15, Paint()..color = Colors.white);
    c.drawCircle(g, 15, _ink);
    if (f == Fault.noFuel) {
      final level = fixing;
      final a = math.pi + level * math.pi;
      c.drawLine(g, g + Offset(math.cos(a), math.sin(a)) * 11,
          Paint()
            ..color = unfixed ? const Color(0xFFE63946) : const Color(0xFF2DC653)
            ..strokeWidth = 3
            ..strokeCap = StrokeCap.round);
    } else {
      final bars = (fixing * 4).floor().clamp(0, 4);
      c.drawRect(Rect.fromCenter(center: g, width: 18, height: 10),
          Paint()
            ..color = kInk
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5);
      if (bars == 0) {
        c.drawRect(Rect.fromCenter(center: g, width: 15, height: 7),
            Paint()..color = fade(const Color(0xFFE63946), 0.5 + 0.5 * ((math.sin(look.t * 8) + 1) / 2)));
      }
      for (var i = 0; i < bars; i++) {
        c.drawRect(Rect.fromLTWH(g.dx - 8 + i * 4, g.dy - 3.5, 3, 7), Paint()..color = const Color(0xFF2DC653));
      }
    }
  }

  // Flat battery: a little battery on the bonnet, empty and blinking.
  if (f == Fault.flatBattery) {
    const b = Rect.fromLTWH(244, 72, 30, 18);
    c.drawRRect(RRect.fromRectAndRadius(b, const Radius.circular(3)), Paint()..color = const Color(0xFF495057));
    c.drawRRect(RRect.fromRectAndRadius(b, const Radius.circular(3)), _ink);
    c.drawRect(const Rect.fromLTWH(250, 68, 5, 4), Paint()..color = const Color(0xFFE63946));
    c.drawRect(const Rect.fromLTWH(263, 68, 5, 4), Paint()..color = kInk);
    final charge = unfixed ? 0.0 : 1.0;
    final level = math.max(charge, fixing);
    c.drawRect(Rect.fromLTWH(b.left + 4, b.top + 4, (b.width - 8) * level, b.height - 8),
        Paint()..color = const Color(0xFF2DC653));
    if (level == 0) {
      c.drawRect(Rect.fromLTWH(b.left + 4, b.top + 4, 5, b.height - 8),
          Paint()..color = fade(const Color(0xFFE63946), (math.sin(look.t * 8) + 1) / 2));
    }
  }

  // Headlight.
  final broken = f == Fault.brokenLight && unfixed;
  const hl = Offset(282, 100);
  if (look.lightsOn && !broken) {
    c.drawCircle(hl, 18,
        Paint()
          ..color = fade(const Color(0xFFFFF3B0), 0.7)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6));
  }
  c.drawCircle(hl, 8, Paint()..color = broken ? const Color(0xFF9E9E9E) : const Color(0xFFFFE066));
  c.drawCircle(hl, 8, _ink);
  if (broken) {
    final crack = Paint()
      ..color = kInk
      ..strokeWidth = 1.6;
    c.drawLine(hl + const Offset(-5, -5), hl + const Offset(1, 0), crack);
    c.drawLine(hl + const Offset(1, 0), hl + const Offset(-2, 6), crack);
  }
  // Tail light.
  c.drawRRect(RRect.fromLTRBR(18, 96, 26, 112, const Radius.circular(2)), Paint()..color = const Color(0xFFE63946));

  // Wheels.
  _wheel(c, const Offset(76, 148), 24, look.wheelTurn,
      loose: f == Fault.looseBolt && unfixed, t: look.t);
  _wheel(c, const Offset(226, 148), 24, look.wheelTurn,
      flat: f == Fault.flatTyre && fixing < 0.6);

  // Smoke for cough-cough cars.
  if ((f == Fault.noFuel) && unfixed) {
    paintPuffs(c, const Offset(14, 136), look.t * 0.8);
  }
}

class SimpleVehiclePainter extends CustomPainter {
  final CarLook look;
  final double padding;
  SimpleVehiclePainter(this.look, {this.padding = 0});

  @override
  void paint(Canvas canvas, Size size) {
    final s = math.min((size.width - 2 * padding) / kSimpleW, (size.height - 2 * padding) / kSimpleH);
    canvas.save();
    canvas.translate((size.width - kSimpleW * s) / 2, (size.height - kSimpleH * s) / 2);
    canvas.scale(s);
    paintSimpleVehicle(canvas, look);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant SimpleVehiclePainter old) => true;
}

// ---------------------------------------------------------------------------
// Rescue scenes, drawn in a 600 x 320 unit box. Ground line at y=280.
// ---------------------------------------------------------------------------

const double kSceneW = 600;
const double kSceneH = 320;

/// [solved] 0..1 fades the problem away.
void paintRescueScene(Canvas c, Rescue r, double t, double solved) {
  final grass = Paint()..color = const Color(0xFF8BC34A);
  c.drawRect(const Rect.fromLTWH(0, 270, kSceneW, 50), grass);
  final problem = 1 - solved;
  switch (r) {
    case Rescue.fire:
      _house(c, const Offset(300, 270), const Color(0xFFFFE5EC), 'BAKERY');
      if (problem > 0) {
        for (var i = 0; i < 5; i++) {
          final x = 230 + i * 34.0;
          final h = 40 + 18 * math.sin(t * 9 + i * 1.7);
          final flame = Path()
            ..moveTo(x - 16, 130)
            ..quadraticBezierTo(x - 18, 130 - h * 0.6, x, 130 - h)
            ..quadraticBezierTo(x + 18, 130 - h * 0.6, x + 16, 130)
            ..close();
          c.drawPath(flame, Paint()..color = fade(const Color(0xFFFF5D2E), problem));
          c.drawPath(flame.shift(const Offset(0, 6)),
              Paint()..color = fade(const Color(0xFFFFD23F), problem * 0.8));
        }
        paintPuffs(c, const Offset(300, 80), t * 0.6);
      }
      if (solved > 0 && solved < 1) {
        for (var i = 0; i < 14; i++) {
          final p = ((t * 2 + i / 14) % 1.0);
          c.drawCircle(Offset(420 - p * 200, 60 + p * 60 + (i % 3) * 8), 4,
              Paint()..color = const Color(0xFF4CC9F0));
        }
      }
      break;
    case Rescue.tree:
      c.drawRect(const Rect.fromLTWH(0, 240, kSceneW, 40), Paint()..color = const Color(0xFF7D7A91));
      c.drawRect(const Rect.fromLTWH(0, 257, kSceneW, 4), Paint()..color = Colors.white);
      if (problem > 0) {
        c.save();
        c.translate(0, -solved * 160);
        c.drawRRect(RRect.fromLTRBR(150, 232, 470, 252, const Radius.circular(10)),
            Paint()..color = const Color(0xFF7A5230));
        for (var i = 0; i < 4; i++) {
          c.drawCircle(Offset(380 + i * 30.0, 222 - (i % 2) * 14.0), 34, Paint()..color = const Color(0xFF2E9E46));
        }
        c.restore();
      } else {
        c.drawRect(const Rect.fromLTWH(526, 160, 12, 80), Paint()..color = const Color(0xFF7A5230));
        c.drawCircle(const Offset(532, 140), 40, Paint()..color = const Color(0xFF2E9E46));
      }
      paintFigure(c, farmer, const Offset(80, 270), 90, mood: solved > 0.5 ? 1 : -1, shirt: const Color(0xFF6A994E));
      break;
    case Rescue.rocks:
      c.drawRect(const Rect.fromLTWH(0, 250, kSceneW, 30), Paint()..color = const Color(0xFFC9A66B));
      if (problem > 0) {
        final rock = Paint()..color = fade(const Color(0xFF8D99AE), problem);
        for (final (x, y, rr) in const [(250.0, 236.0, 30.0), (300.0, 230.0, 36.0), (350.0, 238.0, 28.0), (280.0, 200.0, 26.0), (326.0, 198.0, 24.0), (304.0, 172.0, 22.0)]) {
          c.drawCircle(Offset(x, y), rr, rock);
        }
      }
      // House frame appears once cleared.
      if (solved > 0) {
        final frame = Paint()
          ..color = fade(const Color(0xFF9C6B4E), solved)
          ..strokeWidth = 6;
        c.drawLine(const Offset(240, 250), const Offset(240, 170), frame);
        c.drawLine(const Offset(360, 250), const Offset(360, 170), frame);
        c.drawLine(const Offset(240, 170), const Offset(300, 120), frame);
        c.drawLine(const Offset(360, 170), const Offset(300, 120), frame);
      }
      paintFigure(c, bramble, const Offset(90, 270), 90, mood: solved > 0.5 ? 1 : -1, shirt: const Color(0xFFFFB703));
      break;
    case Rescue.hurt:
      // Playground slide.
      final slide = Paint()
        ..color = const Color(0xFFE63946)
        ..strokeWidth = 8
        ..strokeCap = StrokeCap.round;
      c.drawLine(const Offset(360, 270), const Offset(360, 150), slide);
      c.drawLine(const Offset(400, 270), const Offset(400, 150), slide);
      c.drawLine(const Offset(360, 150), const Offset(400, 150), slide);
      c.drawLine(const Offset(400, 150), const Offset(500, 262), Paint()
        ..color = const Color(0xFFFFB703)
        ..strokeWidth = 14
        ..strokeCap = StrokeCap.round);
      paintFigure(c, ella, const Offset(260, 274), 80, mood: solved > 0.5 ? 1 : -1, shirt: const Color(0xFFFF6FB5), sitting: true);
      // Plaster.
      c.drawRRect(RRect.fromLTRBR(276, 252, 292, 260, const Radius.circular(3)), Paint()..color = const Color(0xFFF2D7B6));
      paintFigure(c, kit, const Offset(160, 270), 90, mood: solved > 0.5 ? 1 : -0.5, shirt: const Color(0xFF4CC9F0));
      break;
    case Rescue.crowd:
      // Bus stop sign.
      c.drawLine(const Offset(110, 270), const Offset(110, 120),
          Paint()
            ..color = const Color(0xFF6C757D)
            ..strokeWidth = 6);
      c.drawCircle(const Offset(110, 110), 22, Paint()..color = const Color(0xFFE63946));
      c.drawCircle(const Offset(110, 110), 14, Paint()..color = Colors.white);
      c.drawRect(const Rect.fromLTWH(98, 106, 24, 8), Paint()..color = const Color(0xFF3A86FF));
      if (problem > 0) {
        final shirts = [const Color(0xFF4CC9F0), const Color(0xFFFF6FB5), const Color(0xFF8AC926), const Color(0xFFFFB703), const Color(0xFF9B5DE5)];
        final folk = [kit, ella, baker, farmer, granny];
        for (var i = 0; i < 5; i++) {
          c.save();
          c.translate(solved * 400, 0);
          paintFigure(c, folk[i], Offset(170 + i * 62.0, 272), 80 + (i % 2) * 8.0, mood: 0.3, shirt: shirts[i]);
          c.restore();
        }
      }
      break;
    case Rescue.brokenCar:
      c.drawRect(const Rect.fromLTWH(0, 240, kSceneW, 40), Paint()..color = const Color(0xFF7D7A91));
      if (problem > 0) {
        c.save();
        c.translate(200 + solved * 400, 110);
        c.scale(0.6);
        paintSimpleVehicle(c, CarLook(color: const Color(0xFF8AC926), t: t, fault: Fault.noFuel, driver: kit, driverMood: -1));
        c.restore();
      }
      break;
  }
}

void _house(Canvas c, Offset base, Color wall, String sign) {
  final w = 200.0, h = 140.0;
  final r = Rect.fromLTWH(base.dx - w / 2, base.dy - h, w, h);
  c.drawRect(r, Paint()..color = wall);
  c.drawRect(r, _ink);
  final roof = Path()
    ..moveTo(r.left - 16, r.top)
    ..lineTo(base.dx, r.top - 60)
    ..lineTo(r.right + 16, r.top)
    ..close();
  _fs(c, roof, const Color(0xFFB5524B));
  final door = RRect.fromLTRBR(base.dx - 20, base.dy - 60, base.dx + 20, base.dy, const Radius.circular(6));
  c.drawRRect(door, Paint()..color = const Color(0xFF7A5230));
  c.drawRRect(door, _ink);
  for (final dx in [-60.0, 60.0]) {
    final win = Rect.fromCenter(center: Offset(base.dx + dx, base.dy - 80), width: 40, height: 34);
    c.drawRect(win, Paint()..color = const Color(0xFFBDE8F5));
    c.drawRect(win, _ink);
  }
  final tp = TextPainter(
    text: TextSpan(text: sign, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: kInk)),
    textDirection: TextDirection.ltr,
  )..layout();
  tp.paint(c, Offset(base.dx - tp.width / 2, r.top + 8));
}

class RescueScenePainter extends CustomPainter {
  final Rescue rescue;
  final double t;
  final double solved;
  RescueScenePainter(this.rescue, this.t, this.solved);

  @override
  void paint(Canvas canvas, Size size) {
    final s = math.min(size.width / kSceneW, size.height / kSceneH);
    canvas.save();
    canvas.translate((size.width - kSceneW * s) / 2, (size.height - kSceneH * s) / 2);
    canvas.scale(s);
    paintRescueScene(canvas, rescue, t, solved);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant RescueScenePainter old) => true;
}

// ---------------------------------------------------------------------------
// The garage phone.
// ---------------------------------------------------------------------------

class PhonePainter extends CustomPainter {
  final double ring; // 0 = still, otherwise animation phase
  final bool ringing;
  PhonePainter({required this.ring, required this.ringing});

  @override
  void paint(Canvas c, Size s) {
    final w = s.width, h = s.height;
    c.save();
    c.translate(w / 2, h / 2);
    if (ringing) c.rotate(math.sin(ring * math.pi * 16) * 0.12);
    c.translate(-w / 2, -h / 2);
    final base = RRect.fromLTRBR(w * 0.12, h * 0.45, w * 0.88, h * 0.95, Radius.circular(w * 0.12));
    c.drawRRect(base, Paint()..color = const Color(0xFFE63946));
    c.drawRRect(base, _ink);
    final handset = Path()
      ..addRRect(RRect.fromLTRBR(w * 0.05, h * 0.25, w * 0.95, h * 0.45, Radius.circular(w * 0.1)));
    c.drawPath(handset, Paint()..color = const Color(0xFFC1121F));
    c.drawPath(handset, _ink);
    c.drawCircle(Offset(w / 2, h * 0.7), w * 0.16, Paint()..color = Colors.white);
    c.drawCircle(Offset(w / 2, h * 0.7), w * 0.16, _ink);
    for (var i = 0; i < 8; i++) {
      final a = i * math.pi / 4;
      c.drawCircle(Offset(w / 2, h * 0.7) + Offset(math.cos(a), math.sin(a)) * w * 0.1, w * 0.025,
          Paint()..color = kInk);
    }
    c.restore();
    if (ringing) {
      final waves = Paint()
        ..color = const Color(0xFFFFB703)
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.05
        ..strokeCap = StrokeCap.round;
      for (var i = 1; i <= 2; i++) {
        final rr = w * (0.45 + i * 0.13);
        c.drawArc(Rect.fromCircle(center: Offset(w / 2, h * 0.5), radius: rr), -math.pi * 0.85, math.pi * 0.25, false, waves);
        c.drawArc(Rect.fromCircle(center: Offset(w / 2, h * 0.5), radius: rr), -math.pi * 0.4, math.pi * 0.25, false, waves);
      }
    }
  }

  @override
  bool shouldRepaint(covariant PhonePainter old) => true;
}
