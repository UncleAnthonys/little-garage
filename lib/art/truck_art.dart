import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../data/models.dart';

/// Placeholder vector art for the tow truck.
///
/// Everything is drawn in a 400 x 250 "vehicle unit" box. When final art
/// arrives, each [PartKind] maps to a PNG layer placed at [TruckGeo.bounds];
/// silhouettes can stay generated from the same shapes.

const double kVehicleW = 400;
const double kVehicleH = 250;
const Color kInk = Color(0xFF2B2D42);

Color fade(Color c, double opacity) =>
    c.withAlpha((opacity.clamp(0.0, 1.0) * 255).round());

Color shade(Color c, double delta) {
  final hsl = HSLColor.fromColor(c);
  return hsl.withLightness((hsl.lightness + delta).clamp(0.0, 1.0)).toColor();
}

/// Maps vehicle units into a widget's local pixels.
class Fit {
  final double scale;
  final Offset offset;
  const Fit(this.scale, this.offset);

  static Fit contain(Size size, {double padding = 0}) {
    final s = math.min((size.width - 2 * padding) / kVehicleW,
        (size.height - 2 * padding) / kVehicleH);
    return Fit(
        s,
        Offset((size.width - kVehicleW * s) / 2,
            (size.height - kVehicleH * s) / 2));
  }

  Offset toLocal(Offset v) => offset + v * scale;
  Offset toVehicle(Offset local) => (local - offset) / scale;
  Rect rectToLocal(Rect r) => Rect.fromLTWH(offset.dx + r.left * scale,
      offset.dy + r.top * scale, r.width * scale, r.height * scale);
}

/// The shapes of the tow truck, shared by the finished truck, silhouettes,
/// tray thumbnails, hit-testing and the wash mask.
class TruckGeo {
  static const rearWheel = Offset(110, 200);
  static const frontWheel = Offset(300, 200);
  static const headlight = Offset(368, 150);
  static const steering = Offset(300, 108);
  static const driverHead = Offset(286, 100);
  static const exhaustTop = Offset(239, 36);
  static const nameplate = Rect.fromLTRB(256, 136, 334, 158);
  static const engineRect = Rect.fromLTRB(190, 104, 230, 140);
  static const exhaustRect = Rect.fromLTRB(234, 40, 244, 140);
  static const cranePivot = Offset(170, 112);
  static const double craneLength = 130;
  static final double craneBaseAngle = math.atan2(-78, -104);

  static double wheelRadius(WheelStyle w) =>
      w == WheelStyle.monster ? 38 : 30;

  static Path chassis() {
    final base = Path()
      ..addRRect(RRect.fromLTRBR(36, 140, 262, 190, const Radius.circular(10)));
    final arch = Path()
      ..addOval(Rect.fromCircle(center: rearWheel, radius: 40));
    return Path.combine(PathOperation.difference, base, arch);
  }

  static Path cab() {
    final p = Path()
      ..moveTo(248, 190)
      ..lineTo(248, 74)
      ..quadraticBezierTo(248, 62, 260, 62)
      ..lineTo(318, 62)
      ..lineTo(354, 126)
      ..lineTo(366, 130)
      ..quadraticBezierTo(376, 132, 376, 142)
      ..lineTo(376, 190)
      ..close();
    final arch = Path()
      ..addOval(Rect.fromCircle(center: frontWheel, radius: 40));
    return Path.combine(PathOperation.difference, p, arch);
  }

  static Path cabWindow() => Path()
    ..moveTo(262, 76)
    ..lineTo(312, 76)
    ..lineTo(342, 124)
    ..lineTo(262, 124)
    ..close();

  static Path craneBase() => Path()
    ..moveTo(140, 140)
    ..lineTo(198, 140)
    ..lineTo(188, 102)
    ..quadraticBezierTo(170, 92, 152, 102)
    ..close();

  static Offset craneTip(double lift) {
    final a = craneBaseAngle + lift;
    return cranePivot + Offset(math.cos(a), math.sin(a)) * craneLength;
  }

  static Path craneBoom(double lift) {
    final a = craneBaseAngle + lift;
    final dir = Offset(math.cos(a), math.sin(a));
    final n = Offset(-dir.dy, dir.dx) * 8;
    final tip = craneTip(lift);
    return Path()
      ..moveTo(cranePivot.dx + n.dx, cranePivot.dy + n.dy)
      ..lineTo(tip.dx + n.dx, tip.dy + n.dy)
      ..lineTo(tip.dx - n.dx, tip.dy - n.dy)
      ..lineTo(cranePivot.dx - n.dx, cranePivot.dy - n.dy)
      ..close();
  }

  static Path hookBlock(double lift) {
    final c = craneTip(lift) + const Offset(0, 56);
    final p = Path();
    for (var i = 0; i < 6; i++) {
      final a = math.pi / 6 + i * math.pi / 3;
      final pt = c + Offset(math.cos(a), math.sin(a)) * 11;
      if (i == 0) {
        p.moveTo(pt.dx, pt.dy);
      } else {
        p.lineTo(pt.dx, pt.dy);
      }
    }
    return p..close();
  }

  static Path craneOutline(double lift) {
    var p = Path.combine(PathOperation.union, craneBase(), craneBoom(lift));
    p = Path.combine(PathOperation.union, p, hookBlock(lift));
    return p;
  }

  /// Bounds of a part in vehicle units. Used for drag targets and thumbnails.
  static Rect bounds(PartKind k, WheelStyle w) {
    switch (k) {
      case PartKind.chassis:
        return chassis().getBounds();
      case PartKind.cab:
        return cab().getBounds();
      case PartKind.wheels:
        final r = wheelRadius(w);
        return Rect.fromLTRB(rearWheel.dx - r, rearWheel.dy - r,
            frontWheel.dx + r, frontWheel.dy + r);
      case PartKind.engine:
        return engineRect.inflate(4);
      case PartKind.exhaust:
        return const Rect.fromLTRB(230, 32, 248, 140);
      case PartKind.crane:
        return craneOutline(0).getBounds().inflate(6);
      case PartKind.headlights:
        return Rect.fromCircle(center: headlight, radius: 10);
      case PartKind.steering:
        return Rect.fromCircle(center: steering, radius: 12);
    }
  }

  /// Painting order, back to front.
  static const paintOrder = [
    PartKind.exhaust,
    PartKind.crane,
    PartKind.chassis,
    PartKind.engine,
    PartKind.cab,
    PartKind.steering,
    PartKind.headlights,
    PartKind.wheels,
  ];

  /// Which part sits under a point (front-most first), for Mechanic Mode taps.
  static PartKind? hitTest(Offset v, WheelStyle w, Set<PartKind> built) {
    for (final k in paintOrder.reversed) {
      if (!built.contains(k)) continue;
      final hit = switch (k) {
        PartKind.wheels =>
          (v - rearWheel).distance < wheelRadius(w) + 6 ||
              (v - frontWheel).distance < wheelRadius(w) + 6,
        PartKind.chassis => chassis().contains(v),
        PartKind.cab => cab().contains(v),
        PartKind.crane => craneOutline(0).contains(v) ||
            bounds(PartKind.crane, w).contains(v) && v.dy < 140,
        _ => bounds(k, w).inflate(10).contains(v),
      };
      if (hit) return k;
    }
    return null;
  }
}

/// How the truck looks right now.
class VehicleLook {
  final Set<PartKind> built;
  final Color body;
  final WheelStyle wheels;
  final DriverKind driver;
  final String name;
  final List<PlacedSticker> stickers;

  /// Unbuilt part to show as a white silhouette target.
  final PartKind? target;

  /// 0..1 pulse used to make the target glow.
  final double pulse;

  /// Part playing its "what it does" animation, and its progress 0..1.
  final PartKind? highlight;
  final double t;

  final double wheelTurn;
  final bool lightsOn;
  final Breakdown? breakdown;
  final bool sleeping;

  const VehicleLook({
    required this.built,
    required this.body,
    required this.wheels,
    required this.driver,
    this.name = '',
    this.stickers = const [],
    this.target,
    this.pulse = 0,
    this.highlight,
    this.t = 0,
    this.wheelTurn = 0,
    this.lightsOn = false,
    this.breakdown,
    this.sleeping = false,
  });
}

final Paint _stroke = Paint()
  ..color = kInk
  ..style = PaintingStyle.stroke
  ..strokeWidth = 2.5
  ..strokeJoin = StrokeJoin.round;

void _fillStroke(Canvas c, Path p, Color fill, bool silhouette) {
  c.drawPath(p, Paint()..color = silhouette ? Colors.white : fill);
  c.drawPath(p, _stroke);
}

/// Draws the whole vehicle in vehicle units.
void paintVehicle(Canvas c, VehicleLook look) {
  for (final k in TruckGeo.paintOrder) {
    final isBuilt = look.built.contains(k);
    if (!isBuilt && look.target != k) continue;

    if (!isBuilt) {
      // Glowing target outline behind the white silhouette.
      final glow = Paint()
        ..color = fade(const Color(0xFFFFE066), 0.45 + 0.45 * look.pulse)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 10
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
      final r = TruckGeo.bounds(k, look.wheels);
      c.drawRRect(RRect.fromRectAndRadius(r.inflate(6), const Radius.circular(14)),
          glow);
    }

    paintPart(c, k, look, silhouette: !isBuilt);

    if (isBuilt && k == PartKind.cab) {
      _paintDriverInCab(c, look);
      if (look.name.isNotEmpty) _paintNameplate(c, look);
    }
    if (isBuilt && k == PartKind.headlights) {
      for (final s in look.stickers) {
        paintSticker(c, s.kind, Offset(s.x, s.y), 34);
      }
    }
  }
  // Stickers still show if headlights are not yet built.
  if (!look.built.contains(PartKind.headlights)) {
    for (final s in look.stickers) {
      paintSticker(c, s.kind, Offset(s.x, s.y), 34);
    }
  }
}

void _paintDriverInCab(Canvas c, VehicleLook look) {
  c.save();
  c.clipPath(TruckGeo.cabWindow());
  paintDriver(c, look.driver, TruckGeo.driverHead, 15, sleeping: look.sleeping);
  c.restore();
}

void _paintNameplate(Canvas c, VehicleLook look) {
  const r = TruckGeo.nameplate;
  c.drawRRect(RRect.fromRectAndRadius(r, const Radius.circular(6)),
      Paint()..color = Colors.white);
  c.drawRRect(RRect.fromRectAndRadius(r, const Radius.circular(6)),
      Paint()
        ..color = kInk
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5);
  final tp = TextPainter(
    text: TextSpan(
        text: look.name,
        style: const TextStyle(
            color: kInk, fontSize: 14, fontWeight: FontWeight.w900)),
    textDirection: TextDirection.ltr,
    maxLines: 1,
    ellipsis: '…',
  )..layout(maxWidth: r.width - 6);
  tp.paint(c, Offset(r.center.dx - tp.width / 2, r.center.dy - tp.height / 2));
}

/// Draws a single part. [silhouette] draws it as a white shape with an outline.
void paintPart(Canvas c, PartKind k, VehicleLook look,
    {bool silhouette = false}) {
  final active = look.highlight == k && !silhouette;
  final t = active ? look.t : 0.0;
  c.save();
  switch (k) {
    case PartKind.chassis:
      _fillStroke(c, TruckGeo.chassis(), shade(look.body, -0.08), silhouette);
      if (!silhouette) {
        c.drawRRect(
            RRect.fromLTRBR(46, 146, 246, 151, const Radius.circular(3)),
            Paint()..color = fade(Colors.white, 0.35));
      }
      break;

    case PartKind.cab:
      _fillStroke(c, TruckGeo.cab(), look.body, silhouette);
      final w = TruckGeo.cabWindow();
      _fillStroke(c, w, const Color(0xFFBDE8F5), silhouette);
      if (!silhouette) {
        c.drawLine(const Offset(270, 84), const Offset(282, 84),
            Paint()
              ..color = fade(Colors.white, 0.8)
              ..strokeWidth = 4
              ..strokeCap = StrokeCap.round);
        final grille = Paint()
          ..color = shade(look.body, -0.2)
          ..strokeWidth = 4
          ..strokeCap = StrokeCap.round;
        c.drawLine(const Offset(362, 160), const Offset(374, 160), grille);
        c.drawLine(const Offset(362, 168), const Offset(374, 168), grille);
      }
      break;

    case PartKind.engine:
      if (active) c.translate(math.sin(t * 70) * 1.6, 0);
      final body = RRect.fromRectAndRadius(
          TruckGeo.engineRect, const Radius.circular(6));
      c.drawRRect(body,
          Paint()..color = silhouette ? Colors.white : const Color(0xFF9AA5B8));
      c.drawRRect(body, _stroke);
      for (var i = 0; i < 3; i++) {
        final lift = active ? math.sin(t * 40 + i * 2.1).abs() * 5 : 0.0;
        final r = RRect.fromLTRBR(194 + i * 12.0, 96 - lift, 202 + i * 12.0,
            106 - lift, const Radius.circular(2));
        c.drawRRect(r,
            Paint()..color = silhouette ? Colors.white : const Color(0xFF6C7A93));
        c.drawRRect(r, _stroke);
      }
      if (!silhouette) {
        c.drawCircle(const Offset(200, 122), 3, Paint()..color = kInk);
        c.drawCircle(const Offset(220, 122), 3, Paint()..color = kInk);
      }
      break;

    case PartKind.exhaust:
      final pipe = RRect.fromRectAndRadius(
          TruckGeo.exhaustRect, const Radius.circular(3));
      c.drawRRect(pipe,
          Paint()..color = silhouette ? Colors.white : const Color(0xFF8D99AE));
      c.drawRRect(pipe, _stroke);
      final cap = RRect.fromLTRBR(231, 34, 247, 42, const Radius.circular(3));
      c.drawRRect(cap,
          Paint()..color = silhouette ? Colors.white : const Color(0xFF5C677D));
      c.drawRRect(cap, _stroke);
      if (active) paintPuffs(c, TruckGeo.exhaustTop, t * 3);
      break;

    case PartKind.crane:
      final lift = active ? math.sin(t * math.pi) * 0.38 : 0.0;
      _fillStroke(c, TruckGeo.craneBase(), const Color(0xFF7B4FD6), silhouette);
      final boom = TruckGeo.craneBoom(lift);
      _fillStroke(c, boom, const Color(0xFFFFD60A), silhouette);
      if (!silhouette) {
        c.save();
        c.clipPath(boom);
        final a = TruckGeo.craneBaseAngle + lift;
        final dir = Offset(math.cos(a), math.sin(a));
        final n = Offset(-dir.dy, dir.dx) * 12;
        final stripe = Paint()
          ..color = const Color(0xFF3D3B8E)
          ..strokeWidth = 7;
        for (var i = 1; i < 9; i++) {
          final p = TruckGeo.cranePivot + dir * (i * 15.0);
          c.drawLine(p + n + dir * 6, p - n - dir * 6, stripe);
        }
        c.restore();
        c.drawPath(boom, _stroke);
      }
      final tip = TruckGeo.craneTip(lift);
      c.drawLine(tip, tip + const Offset(0, 46),
          Paint()
            ..color = kInk
            ..strokeWidth = 2.5);
      _fillStroke(c, TruckGeo.hookBlock(lift), const Color(0xFFFFD60A), silhouette);
      final hookC = tip + const Offset(0, 76);
      c.drawArc(Rect.fromCircle(center: hookC, radius: 8), -0.3, math.pi + 1.2,
          false,
          Paint()
            ..color = silhouette ? kInk : const Color(0xFF3A86FF)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 4
            ..strokeCap = StrokeCap.round);
      c.drawCircle(tip, 4, Paint()..color = const Color(0xFF7B4FD6));
      break;

    case PartKind.headlights:
      final broken = look.breakdown == Breakdown.brokenLight && !silhouette;
      final on = (look.lightsOn || active) && !broken;
      if (on) {
        c.drawCircle(TruckGeo.headlight, 12 + (active ? 8 * math.sin(t * math.pi) : 2),
            Paint()
              ..color = fade(const Color(0xFFFFF3B0), 0.7)
              ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6));
      }
      c.drawCircle(
          TruckGeo.headlight,
          7,
          Paint()
            ..color = silhouette
                ? Colors.white
                : broken
                    ? const Color(0xFF9E9E9E)
                    : const Color(0xFFFFE066));
      c.drawCircle(TruckGeo.headlight, 7, _stroke);
      if (broken) {
        final crack = Paint()
          ..color = kInk
          ..strokeWidth = 1.5;
        c.drawLine(TruckGeo.headlight + const Offset(-4, -4),
            TruckGeo.headlight + const Offset(1, 0), crack);
        c.drawLine(TruckGeo.headlight + const Offset(1, 0),
            TruckGeo.headlight + const Offset(-1, 5), crack);
      }
      break;

    case PartKind.steering:
      const ctr = TruckGeo.steering;
      c.drawLine(ctr, const Offset(296, 124),
          Paint()
            ..color = kInk
            ..strokeWidth = 3);
      c.translate(ctr.dx, ctr.dy);
      if (active) c.rotate(math.sin(t * math.pi * 3) * 0.8);
      if (silhouette) c.drawCircle(Offset.zero, 9, Paint()..color = Colors.white);
      c.drawCircle(Offset.zero, 9,
          Paint()
            ..color = silhouette ? kInk : const Color(0xFF3D405B)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3.5);
      if (!silhouette) {
        final spoke = Paint()
          ..color = const Color(0xFF3D405B)
          ..strokeWidth = 2.5;
        c.drawLine(Offset.zero, const Offset(0, -8), spoke);
        c.drawLine(Offset.zero, const Offset(-7, 4), spoke);
        c.drawLine(Offset.zero, const Offset(7, 4), spoke);
      }
      break;

    case PartKind.wheels:
      final r = TruckGeo.wheelRadius(look.wheels);
      final turn = look.wheelTurn + (active ? t * math.pi * 4 : 0);
      paintWheel(c, TruckGeo.rearWheel, r, look.wheels, turn,
          silhouette: silhouette);
      paintWheel(c, TruckGeo.frontWheel, r, look.wheels, turn,
          silhouette: silhouette,
          flat: look.breakdown == Breakdown.flatTyre && !silhouette);
      break;
  }
  c.restore();
}

/// Exhaust smoke puffs rising from [origin]. [phase] loops every 1.0.
void paintPuffs(Canvas c, Offset origin, double phase) {
  for (var i = 0; i < 3; i++) {
    final p = (phase + i / 3) % 1.0;
    c.drawCircle(origin + Offset(-p * 26, -p * 40), 5 + p * 9,
        Paint()..color = fade(const Color(0xFFB8BDC9), (1 - p) * 0.8));
  }
}

void paintWheel(Canvas c, Offset ctr, double r, WheelStyle w, double turn,
    {bool silhouette = false, bool flat = false}) {
  c.save();
  c.translate(ctr.dx, ctr.dy);
  if (flat) {
    c.translate(0, r * 0.2);
    c.scale(1.14, 0.76);
  }
  final tyreColor =
      w == WheelStyle.flower ? const Color(0xFF6A4C93) : const Color(0xFF353A4D);
  final tyre = Paint()..color = silhouette ? Colors.white : tyreColor;

  if (w == WheelStyle.monster && !silhouette) {
    c.save();
    c.rotate(turn);
    for (var i = 0; i < 14; i++) {
      c.save();
      c.rotate(i * 2 * math.pi / 14);
      c.drawRRect(
          RRect.fromRectAndRadius(
              Rect.fromCenter(center: Offset(0, -r), width: 9, height: 9),
              const Radius.circular(2)),
          tyre);
      c.restore();
    }
    c.restore();
  }
  c.drawCircle(Offset.zero, r, tyre);
  c.drawCircle(Offset.zero, r, _stroke);
  if (silhouette) {
    c.restore();
    return;
  }

  c.rotate(turn);
  switch (w) {
    case WheelStyle.classic:
      c.drawCircle(Offset.zero, r * 0.6, Paint()..color = const Color(0xFF4CC9F0));
      c.drawCircle(Offset.zero, r * 0.6, _stroke);
      c.drawCircle(Offset.zero, r * 0.3, Paint()..color = const Color(0xFF1D3557));
      c.drawCircle(Offset(0, -r * 0.45), r * 0.08, Paint()..color = Colors.white);
      break;
    case WheelStyle.monster:
      c.drawCircle(Offset.zero, r * 0.55, Paint()..color = const Color(0xFFFF8C42));
      c.drawCircle(Offset.zero, r * 0.55, _stroke);
      for (var i = 0; i < 5; i++) {
        final a = i * 2 * math.pi / 5;
        c.drawCircle(Offset(math.cos(a), math.sin(a)) * r * 0.32, r * 0.07,
            Paint()..color = kInk);
      }
      break;
    case WheelStyle.racing:
      c.drawCircle(Offset.zero, r * 0.62, Paint()..color = Colors.white);
      c.drawCircle(Offset.zero, r * 0.62, _stroke);
      final spoke = Paint()
        ..color = const Color(0xFFE63946)
        ..strokeWidth = 3.5
        ..strokeCap = StrokeCap.round;
      for (var i = 0; i < 5; i++) {
        final a = i * 2 * math.pi / 5;
        c.drawLine(Offset.zero, Offset(math.cos(a), math.sin(a)) * r * 0.56, spoke);
      }
      c.drawCircle(Offset.zero, r * 0.15, Paint()..color = const Color(0xFFE63946));
      break;
    case WheelStyle.flower:
      c.drawCircle(Offset.zero, r * 0.6, Paint()..color = const Color(0xFFFFAFCC));
      c.drawCircle(Offset.zero, r * 0.6, _stroke);
      for (var i = 0; i < 6; i++) {
        final a = i * 2 * math.pi / 6;
        c.drawCircle(Offset(math.cos(a), math.sin(a)) * r * 0.32, r * 0.16,
            Paint()..color = Colors.white);
      }
      c.drawCircle(Offset.zero, r * 0.17, Paint()..color = const Color(0xFFFFD23F));
      break;
  }
  c.restore();
}

/// Original driver characters (not Meemu's fox, giraffe or elephant).
void paintDriver(Canvas c, DriverKind d, Offset ctr, double r,
    {bool sleeping = false}) {
  final ink = Paint()..color = kInk;
  void eyes() {
    if (sleeping) {
      final p = Paint()
        ..color = kInk
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.1
        ..strokeCap = StrokeCap.round;
      c.drawArc(Rect.fromCircle(center: ctr + Offset(-r * 0.38, -r * 0.1), radius: r * 0.16),
          0, math.pi, false, p);
      c.drawArc(Rect.fromCircle(center: ctr + Offset(r * 0.38, -r * 0.1), radius: r * 0.16),
          0, math.pi, false, p);
    } else {
      c.drawCircle(ctr + Offset(-r * 0.38, -r * 0.12), r * 0.13, ink);
      c.drawCircle(ctr + Offset(r * 0.38, -r * 0.12), r * 0.13, ink);
      c.drawCircle(ctr + Offset(-r * 0.34, -r * 0.17), r * 0.05,
          Paint()..color = Colors.white);
      c.drawCircle(ctr + Offset(r * 0.42, -r * 0.17), r * 0.05,
          Paint()..color = Colors.white);
    }
  }

  switch (d) {
    case DriverKind.bear:
      const fur = Color(0xFFB07D4F);
      c.drawCircle(ctr + Offset(-r * 0.75, -r * 0.75), r * 0.38, Paint()..color = fur);
      c.drawCircle(ctr + Offset(r * 0.75, -r * 0.75), r * 0.38, Paint()..color = fur);
      c.drawCircle(ctr, r, Paint()..color = fur);
      c.drawCircle(ctr + Offset(0, r * 0.35), r * 0.45,
          Paint()..color = const Color(0xFFE8C9A0));
      eyes();
      c.drawOval(
          Rect.fromCenter(center: ctr + Offset(0, r * 0.22), width: r * 0.36, height: r * 0.24),
          ink);
      break;
    case DriverKind.bunny:
      const fur = Color(0xFFF4F1EE);
      const inner = Color(0xFFFFAFCC);
      for (final sx in [-1.0, 1.0]) {
        final ear = Rect.fromCenter(
            center: ctr + Offset(sx * r * 0.4, -r * 1.3), width: r * 0.55, height: r * 1.4);
        c.drawOval(ear, Paint()..color = fur);
        c.drawOval(
            ear,
            Paint()
              ..color = kInk
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1.5);
        c.drawOval(ear.deflate(r * 0.13), Paint()..color = inner);
      }
      c.drawCircle(ctr, r, Paint()..color = fur);
      c.drawCircle(ctr, r,
          Paint()
            ..color = kInk
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5);
      eyes();
      c.drawCircle(ctr + Offset(0, r * 0.22), r * 0.12, Paint()..color = inner);
      break;
    case DriverKind.robot:
      const metal = Color(0xFFB8C4D6);
      c.drawLine(ctr + Offset(0, -r), ctr + Offset(0, -r * 1.45),
          Paint()
            ..color = kInk
            ..strokeWidth = r * 0.12);
      c.drawCircle(ctr + Offset(0, -r * 1.5), r * 0.18,
          Paint()..color = const Color(0xFFE63946));
      final head = RRect.fromRectAndRadius(
          Rect.fromCenter(center: ctr, width: r * 2, height: r * 1.8),
          Radius.circular(r * 0.4));
      c.drawRRect(head, Paint()..color = metal);
      c.drawRRect(head,
          Paint()
            ..color = kInk
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5);
      if (sleeping) {
        eyes();
      } else {
        final eye = Paint()..color = const Color(0xFF00B4D8);
        c.drawRRect(
            RRect.fromRectAndRadius(
                Rect.fromCenter(center: ctr + Offset(-r * 0.4, -r * 0.15), width: r * 0.42, height: r * 0.3),
                Radius.circular(r * 0.08)),
            eye);
        c.drawRRect(
            RRect.fromRectAndRadius(
                Rect.fromCenter(center: ctr + Offset(r * 0.4, -r * 0.15), width: r * 0.42, height: r * 0.3),
                Radius.circular(r * 0.08)),
            eye);
      }
      c.drawLine(ctr + Offset(-r * 0.35, r * 0.45), ctr + Offset(r * 0.35, r * 0.45),
          Paint()
            ..color = kInk
            ..strokeWidth = r * 0.1
            ..strokeCap = StrokeCap.round);
      break;
  }
}

Path starPath(Offset c, double outer, {double innerRatio = 0.45}) {
  final p = Path();
  for (var i = 0; i < 10; i++) {
    final r = i.isEven ? outer : outer * innerRatio;
    final a = -math.pi / 2 + i * math.pi / 5;
    final pt = c + Offset(math.cos(a), math.sin(a)) * r;
    if (i == 0) {
      p.moveTo(pt.dx, pt.dy);
    } else {
      p.lineTo(pt.dx, pt.dy);
    }
  }
  return p..close();
}

/// Stickers: drawn with a white die-cut border like real stickers.
void paintSticker(Canvas c, StickerKind k, Offset ctr, double size) {
  final s = size / 2;
  late Path path;
  late Color color;
  switch (k) {
    case StickerKind.star:
      path = starPath(ctr, s);
      color = const Color(0xFFFFD23F);
      break;
    case StickerKind.heart:
      path = Path()
        ..moveTo(ctr.dx, ctr.dy + s * 0.85)
        ..cubicTo(ctr.dx - s * 1.3, ctr.dy - s * 0.1, ctr.dx - s * 0.6,
            ctr.dy - s * 1.1, ctr.dx, ctr.dy - s * 0.35)
        ..cubicTo(ctr.dx + s * 0.6, ctr.dy - s * 1.1, ctr.dx + s * 1.3,
            ctr.dy - s * 0.1, ctr.dx, ctr.dy + s * 0.85)
        ..close();
      color = const Color(0xFFE63946);
      break;
    case StickerKind.bolt:
      path = Path()
        ..moveTo(ctr.dx + s * 0.2, ctr.dy - s)
        ..lineTo(ctr.dx - s * 0.6, ctr.dy + s * 0.15)
        ..lineTo(ctr.dx - s * 0.05, ctr.dy + s * 0.15)
        ..lineTo(ctr.dx - s * 0.25, ctr.dy + s)
        ..lineTo(ctr.dx + s * 0.6, ctr.dy - s * 0.2)
        ..lineTo(ctr.dx + s * 0.05, ctr.dy - s * 0.2)
        ..close();
      color = const Color(0xFFFF8C42);
      break;
    case StickerKind.flower:
      path = Path();
      for (var i = 0; i < 5; i++) {
        final a = -math.pi / 2 + i * 2 * math.pi / 5;
        path.addOval(Rect.fromCircle(
            center: ctr + Offset(math.cos(a), math.sin(a)) * s * 0.5,
            radius: s * 0.45));
      }
      color = const Color(0xFFFF6FB5);
      break;
    case StickerKind.smile:
      path = Path()..addOval(Rect.fromCircle(center: ctr, radius: s * 0.9));
      color = const Color(0xFFFFD23F);
      break;
    case StickerKind.flame:
      path = Path()
        ..moveTo(ctr.dx, ctr.dy - s)
        ..quadraticBezierTo(ctr.dx + s * 0.9, ctr.dy - s * 0.1, ctr.dx + s * 0.55, ctr.dy + s * 0.6)
        ..quadraticBezierTo(ctr.dx, ctr.dy + s * 1.1, ctr.dx - s * 0.55, ctr.dy + s * 0.6)
        ..quadraticBezierTo(ctr.dx - s * 0.9, ctr.dy - s * 0.1, ctr.dx - s * 0.1, ctr.dy - s * 0.4)
        ..quadraticBezierTo(ctr.dx + s * 0.05, ctr.dy - s * 0.7, ctr.dx, ctr.dy - s)
        ..close();
      color = const Color(0xFFFF5D2E);
      break;
  }
  c.drawPath(
      path,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = size * 0.16
        ..strokeJoin = StrokeJoin.round);
  c.drawPath(path, Paint()..color = color);
  c.drawPath(
      path,
      Paint()
        ..color = kInk
        ..style = PaintingStyle.stroke
        ..strokeWidth = size * 0.04);
  if (k == StickerKind.flower) {
    c.drawCircle(ctr, s * 0.32, Paint()..color = const Color(0xFFFFD23F));
  }
  if (k == StickerKind.smile) {
    final ink = Paint()..color = kInk;
    c.drawCircle(ctr + Offset(-s * 0.3, -s * 0.2), s * 0.1, ink);
    c.drawCircle(ctr + Offset(s * 0.3, -s * 0.2), s * 0.1, ink);
    c.drawArc(Rect.fromCircle(center: ctr + Offset(0, s * 0.05), radius: s * 0.45),
        0.3, math.pi - 0.6, false,
        Paint()
          ..color = kInk
          ..style = PaintingStyle.stroke
          ..strokeWidth = s * 0.1
          ..strokeCap = StrokeCap.round);
  }
}

// --- Painters --------------------------------------------------------------

/// Paints a [VehicleLook] fitted into its widget.
class VehiclePainter extends CustomPainter {
  final VehicleLook look;
  final double padding;
  VehiclePainter(this.look, {this.padding = 0});

  @override
  void paint(Canvas canvas, Size size) {
    final fit = Fit.contain(size, padding: padding);
    canvas.save();
    canvas.translate(fit.offset.dx, fit.offset.dy);
    canvas.scale(fit.scale);
    paintVehicle(canvas, look);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant VehiclePainter old) => true;
}

/// Paints one part fitted into a thumbnail box.
class PartThumbPainter extends CustomPainter {
  final PartKind kind;
  final VehicleLook look;
  final double padding;
  PartThumbPainter(this.kind, this.look, {this.padding = 8});

  @override
  void paint(Canvas canvas, Size size) {
    final b = TruckGeo.bounds(kind, look.wheels);
    final s = math.min((size.width - 2 * padding) / b.width,
        (size.height - 2 * padding) / b.height);
    canvas.save();
    canvas.translate((size.width - b.width * s) / 2, (size.height - b.height * s) / 2);
    canvas.scale(s);
    canvas.translate(-b.left, -b.top);
    paintPart(canvas, kind, look);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant PartThumbPainter old) => true;
}

/// Paints one part at an exact scale (for the piece being dragged).
class PartPiecePainter extends CustomPainter {
  final PartKind kind;
  final VehicleLook look;
  final double scale;
  PartPiecePainter(this.kind, this.look, this.scale);

  @override
  void paint(Canvas canvas, Size size) {
    final b = TruckGeo.bounds(kind, look.wheels);
    canvas.save();
    canvas.scale(scale);
    canvas.translate(-b.left, -b.top);
    paintPart(canvas, kind, look);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant PartPiecePainter old) => true;
}

class StickerPainter extends CustomPainter {
  final StickerKind kind;
  StickerPainter(this.kind);

  @override
  void paint(Canvas canvas, Size size) =>
      paintSticker(canvas, kind, size.center(Offset.zero), size.shortestSide * 0.8);

  @override
  bool shouldRepaint(covariant StickerPainter old) => old.kind != kind;
}

class WheelThumbPainter extends CustomPainter {
  final WheelStyle style;
  final double turn;
  WheelThumbPainter(this.style, {this.turn = 0});

  @override
  void paint(Canvas canvas, Size size) => paintWheel(canvas,
      size.center(Offset.zero), size.shortestSide * 0.4, style, turn);

  @override
  bool shouldRepaint(covariant WheelThumbPainter old) => true;
}

class DriverPainter extends CustomPainter {
  final DriverKind kind;
  DriverPainter(this.kind);

  @override
  void paint(Canvas canvas, Size size) {
    final r = size.shortestSide * 0.3;
    paintDriver(canvas, kind, size.center(Offset(0, r * 0.35)), r);
  }

  @override
  bool shouldRepaint(covariant DriverPainter old) => old.kind != kind;
}
