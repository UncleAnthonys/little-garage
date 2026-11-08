import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../data/missions.dart';
import '../data/projects.dart';
import 'town_art.dart';
import 'truck_art.dart';

// The town map is drawn in map units: 2400 wide, 450 tall.
const double kMapW = 2400;
const double kMapH = 450;
const double kGroundY = 320; // where buildings stand
const double kRoadTop = 330;
const double kRoadBottom = 382;
const double kRiverLeft = 1120;
const double kRiverRight = 1360;

final Paint _ink = Paint()
  ..color = kInk
  ..style = PaintingStyle.stroke
  ..strokeWidth = 2.5
  ..strokeJoin = StrokeJoin.round;

// ---------------------------------------------------------------------------
// Project sites. Drawn around an origin at ground level, centre of the site.
// [done] = steps finished, [p] = progress through the current step (0..1).
// ---------------------------------------------------------------------------

void paintProjectSite(Canvas c, TownProject project, int done, double p, double t) {
  switch (project.id) {
    case 'bramble_house':
      _brambleSite(c, done, p, t);
      break;
    case 'river_bridge':
      _bridgeSite(c, done, p, t);
      break;
    case 'riverside_park':
      _parkSite(c, done, p, t);
      break;
  }
}

void _rock(Canvas c, Offset at, double r, double alpha) {
  if (alpha <= 0 || r <= 0) return;
  c.drawCircle(at, r, Paint()..color = fade(const Color(0xFF8D99AE), alpha));
  c.drawCircle(at + Offset(-r * 0.3, -r * 0.3), r * 0.35, Paint()..color = fade(const Color(0xFFADB5BD), alpha));
  c.drawCircle(at, r, Paint()
    ..color = fade(kInk, alpha * 0.6)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2);
}

void _brambleSite(Canvas c, int done, double p, double t) {
  // Plot of dirt.
  c.drawRRect(RRect.fromLTRBR(-150, -8, 150, 6, const Radius.circular(6)),
      Paint()..color = const Color(0xFFC9A66B));
  if (done >= 3) {
    _bigHouse(c, const Offset(0, 0), const Color(0xFFBDE0FE), const Color(0xFF5C677D));
    paintFigure(c, bramble, const Offset(110, 0), 70, mood: 1, shirt: const Color(0xFFFFB703));
    return;
  }
  if (done == 0) {
    // Big rocks breaking into small ones.
    const big = [(-60.0, -34.0, 34.0), (0.0, -40.0, 42.0), (60.0, -32.0, 32.0), (-26.0, -86.0, 30.0), (30.0, -84.0, 28.0)];
    for (final (x, y, r) in big) {
      _rock(c, Offset(x, y), r, 1 - p);
    }
    _smallRocks(c, p, 1);
  } else if (done == 1) {
    _smallRocks(c, 1, 1 - p);
  } else if (done == 2) {
    // Digging the foundation hole.
    final depth = 30 * p;
    c.drawRect(Rect.fromLTRB(-110, -2, 110, depth), Paint()..color = const Color(0xFF7A5230));
    // Dirt heap beside it.
    c.drawOval(Rect.fromCenter(center: const Offset(150, -6), width: 70 * p + 1, height: 34 * p + 1),
        Paint()..color = const Color(0xFF9C6B4E));
  }
}

void _smallRocks(Canvas c, double alpha, double amount) {
  final rnd = math.Random(4);
  final n = (24 * amount).round();
  for (var i = 0; i < n; i++) {
    final x = -110 + rnd.nextDouble() * 220;
    final y = -10 - rnd.nextDouble() * 36;
    _rock(c, Offset(x, y), 9 + rnd.nextDouble() * 8, alpha);
  }
}

void _bridgeSite(Canvas c, int done, double p, double t) {
  const half = (kRiverRight - kRiverLeft) / 2;
  // Water.
  c.drawRect(const Rect.fromLTRB(-half, 4, half, 130), Paint()..color = const Color(0xFF4CC9F0));
  for (var i = 0; i < 6; i++) {
    final x = -half + 20 + ((t * 30 + i * 40) % (2 * half - 40));
    c.drawLine(Offset(x, 40 + (i % 3) * 25.0), Offset(x + 18, 40 + (i % 3) * 25.0),
        Paint()
          ..color = fade(Colors.white, 0.7)
          ..strokeWidth = 3
          ..strokeCap = StrokeCap.round);
  }
  // Banks.
  final bank = Paint()..color = const Color(0xFF9C6B4E);
  c.drawRect(const Rect.fromLTRB(-half - 30, -6, -half, 130), bank);
  c.drawRect(const Rect.fromLTRB(half, -6, half + 30, 130), bank);

  // Holes for the legs.
  final holeDepth = done >= 1 ? 1.0 : (done == 0 ? p : 0.0);
  for (final x in [-half + 40, half - 40]) {
    if (holeDepth > 0) {
      c.drawRect(Rect.fromCenter(center: Offset(x, 10 + 14 * holeDepth), width: 34, height: 28 * holeDepth),
          Paint()..color = const Color(0xFF5E3D22));
    }
  }
  // Concrete legs.
  final legs = done >= 2 ? 1.0 : (done == 1 ? p : 0.0);
  if (legs > 0) {
    for (final x in [-half + 40, half - 40]) {
      final h = 60 * legs;
      c.drawRect(Rect.fromLTRB(x - 14, 24 - h, x + 14, 24), Paint()..color = const Color(0xFFCED4DA));
      c.drawRect(Rect.fromLTRB(x - 14, 24 - h, x + 14, 24), _ink);
    }
  }
  // The deck.
  final deck = done >= 3 ? 1.0 : (done == 2 ? p : 0.0);
  if (deck > 0) {
    final y = -36 - (1 - deck) * 80;
    final r = Rect.fromLTRB(-half - 20, y, half + 20, y + 18);
    c.drawRect(r, Paint()..color = fade(const Color(0xFFB08968), math.min(1, deck * 2)));
    c.drawRect(r, _ink);
    if (deck >= 1) {
      for (var x = -half; x <= half; x += 24) {
        c.drawLine(Offset(x, y), Offset(x, y - 16), Paint()
          ..color = kInk
          ..strokeWidth = 2);
      }
      c.drawLine(Offset(-half - 20, y - 16), Offset(half + 20, y - 16), Paint()
        ..color = kInk
        ..strokeWidth = 3);
    }
  }
}

void _parkSite(Canvas c, int done, double p, double t) {
  if (done == 0) {
    final flat = 1 - p;
    c.drawRect(const Rect.fromLTRB(-160, -6, 160, 6), Paint()..color = const Color(0xFF7A5230));
    for (final (x, w, h) in const [(-100.0, 90.0, 40.0), (0.0, 110.0, 54.0), (100.0, 80.0, 36.0)]) {
      c.drawOval(Rect.fromCenter(center: Offset(x, 0), width: w, height: h * 2 * flat + 2),
          Paint()..color = const Color(0xFF7A5230));
    }
    for (var i = 0; i < 5; i++) {
      c.drawCircle(Offset(-120 + i * 60.0, -6 * flat), 8, Paint()..color = const Color(0xFF5E3D22));
    }
    return;
  }
  // Flat ground, then sand.
  c.drawRect(const Rect.fromLTRB(-160, -6, 160, 6), Paint()..color = const Color(0xFF9C6B4E));
  final sand = done >= 2 ? 1.0 : (done == 1 ? p : 0.0);
  if (sand > 0) {
    c.drawRRect(RRect.fromLTRBR(-150, -10, 150, 6, const Radius.circular(8)),
        Paint()..color = fade(const Color(0xFFF2D7B6), sand));
  }
  final slide = done >= 3 ? 1.0 : (done == 2 ? p : 0.0);
  if (slide > 0) {
    c.save();
    c.translate(0, (1 - slide) * -120);
    final post = Paint()
      ..color = const Color(0xFFE63946)
      ..strokeWidth = 7
      ..strokeCap = StrokeCap.round;
    c.drawLine(const Offset(-60, -8), const Offset(-60, -110), post);
    c.drawLine(const Offset(-30, -8), const Offset(-30, -110), post);
    c.drawLine(const Offset(-60, -110), const Offset(-30, -110), post);
    c.drawLine(const Offset(-30, -110), const Offset(70, -10),
        Paint()
          ..color = const Color(0xFFFFB703)
          ..strokeWidth = 14
          ..strokeCap = StrokeCap.round);
    c.restore();
  }
  if (done >= 3) {
    // Swings and happy friends.
    final frame = Paint()
      ..color = const Color(0xFF3A86FF)
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round;
    c.drawLine(const Offset(100, -8), const Offset(118, -100), frame);
    c.drawLine(const Offset(150, -8), const Offset(132, -100), frame);
    c.drawLine(const Offset(104, -100), const Offset(146, -100), frame);
    final swing = math.sin(t * 3) * 10;
    c.drawLine(const Offset(125, -100), Offset(125 + swing, -40), Paint()
      ..color = kInk
      ..strokeWidth = 2);
    paintFigure(c, kit, Offset(-110, -8 + math.sin(t * 6).abs() * -6), 60, mood: 1);
    paintFigure(c, ella, Offset(125 + swing, -30), 44, mood: 1, shirt: const Color(0xFFFF6FB5), sitting: true);
  }
}

void _bigHouse(Canvas c, Offset base, Color wall, Color roof) {
  const w = 190.0, h = 120.0;
  final r = Rect.fromLTWH(base.dx - w / 2, base.dy - h, w, h);
  c.drawRect(r, Paint()..color = wall);
  c.drawRect(r, _ink);
  final rf = Path()
    ..moveTo(r.left - 14, r.top)
    ..lineTo(base.dx, r.top - 58)
    ..lineTo(r.right + 14, r.top)
    ..close();
  c.drawPath(rf, Paint()..color = roof);
  c.drawPath(rf, _ink);
  final door = RRect.fromLTRBR(base.dx - 18, base.dy - 54, base.dx + 18, base.dy, const Radius.circular(6));
  c.drawRRect(door, Paint()..color = const Color(0xFFE63946));
  c.drawRRect(door, _ink);
  for (final dx in [-56.0, 56.0]) {
    final win = Rect.fromCenter(center: Offset(base.dx + dx, base.dy - 70), width: 38, height: 32);
    c.drawRect(win, Paint()..color = const Color(0xFFFFF3B0));
    c.drawRect(win, _ink);
  }
}

class ProjectSitePainter extends CustomPainter {
  final TownProject project;
  final int done;
  final double p;
  final double t;
  ProjectSitePainter(this.project, this.done, this.p, this.t);

  @override
  void paint(Canvas c, Size size) {
    // Frame a 400 x 230 unit window around the site, ground low down.
    final s = math.min(size.width / 400, size.height / 230);
    c.save();
    c.translate(size.width / 2, size.height * 0.72);
    c.scale(s);
    c.drawRect(const Rect.fromLTRB(-2000, 0, 2000, 400), Paint()..color = const Color(0xFF8BC34A));
    paintProjectSite(c, project, done, p, t);
    c.restore();
  }

  @override
  bool shouldRepaint(covariant ProjectSitePainter old) => true;
}

// ---------------------------------------------------------------------------
// The whole town.
// ---------------------------------------------------------------------------

class TownState {
  final Map<String, int> steps;
  final bool riversideOpen;
  final String garageName;
  const TownState({required this.steps, required this.riversideOpen, required this.garageName});
}

class TownPainter extends CustomPainter {
  final TownState town;
  final double t;
  TownPainter(this.town, this.t);

  @override
  void paint(Canvas c, Size size) {
    final s = size.height / kMapH;
    c.save();
    c.scale(s);

    // Sky and hills.
    c.drawRect(const Rect.fromLTWH(0, 0, kMapW, kMapH),
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF56CCF2), Color(0xFFC6F4E4)],
          ).createShader(const Rect.fromLTWH(0, 0, kMapW, kMapH)));
    c.drawCircle(const Offset(300, 70), 34, Paint()..color = const Color(0xFFFFD23F));
    final hills = Path()..moveTo(0, kGroundY);
    for (var x = 0.0; x <= kMapW; x += 20) {
      hills.lineTo(x, kGroundY - 70 - math.sin(x / 170) * 26);
    }
    hills
      ..lineTo(kMapW, kGroundY)
      ..close();
    c.drawPath(hills, Paint()..color = const Color(0xFF8BC34A));
    c.drawRect(const Rect.fromLTWH(0, kGroundY - 6, kMapW, kMapH), Paint()..color = const Color(0xFF7CB342));

    // Clouds drift.
    for (var i = 0; i < 7; i++) {
      final x = (i * 380.0 + t * 8) % (kMapW + 200) - 100;
      final y = 40.0 + (i % 3) * 26;
      final cl = Paint()..color = fade(Colors.white, 0.9);
      c.drawCircle(Offset(x, y), 18, cl);
      c.drawCircle(Offset(x + 20, y - 10), 22, cl);
      c.drawCircle(Offset(x + 44, y), 18, cl);
    }

    // Trees.
    for (final x in const [40.0, 340.0, 600.0, 960.0, 1060.0, 1420.0, 1560.0, 2020.0, 2340.0]) {
      c.drawRect(Rect.fromLTWH(x - 4, kGroundY - 40, 8, 40), Paint()..color = const Color(0xFF7A5230));
      c.drawCircle(Offset(x, kGroundY - 58), 28, Paint()..color = const Color(0xFF2E9E46));
    }

    // Road, broken by the river until the bridge is built.
    final road = Paint()..color = const Color(0xFF7D7A91);
    final bridgeDone = (town.steps['river_bridge'] ?? 0) >= projectById('river_bridge').steps.length;
    c.drawRect(const Rect.fromLTRB(0, kRoadTop, kRiverLeft, kRoadBottom), road);
    c.drawRect(const Rect.fromLTRB(kRiverRight, kRoadTop, kMapW, kRoadBottom), road);
    final dash = Paint()..color = Colors.white;
    for (var x = 10.0; x < kMapW; x += 70) {
      if (x > kRiverLeft - 40 && x < kRiverRight + 10 && !bridgeDone) continue;
      c.drawRect(Rect.fromLTWH(x, (kRoadTop + kRoadBottom) / 2 - 2, 36, 4), dash);
    }

    // The garage.
    _garage(c, const Offset(190, kGroundY), town.garageName, t);
    // The bakery.
    _shop(c, const Offset(470, kGroundY), const Color(0xFFFFE5EC), 'BAKERY');

    // The river.
    c.drawRect(const Rect.fromLTRB(kRiverLeft, kGroundY + 2, kRiverRight, kMapH),
        Paint()..color = const Color(0xFF4CC9F0));

    // Project sites.
    for (final p in projects) {
      final steps = town.steps[p.id] ?? 0;
      c.save();
      if (p.id == 'river_bridge') {
        // The deck sits level with the road once built.
        c.translate(p.x, kRoadTop + 36);
      } else {
        c.translate(p.x, kGroundY);
      }
      paintProjectSite(c, p, steps, 0, t);
      c.restore();
    }
    if (!bridgeDone) {
      // Cones at the river's edge.
      for (var i = 0; i < 3; i++) {
        final x = kRiverLeft - 60 + i * 18.0;
        c.drawPath(
            Path()
              ..moveTo(x, kRoadTop + 4)
              ..lineTo(x - 7, kRoadTop + 26)
              ..lineTo(x + 7, kRoadTop + 26)
              ..close(),
            Paint()..color = const Color(0xFFFF8C42));
      }
    }

    // Riverside neighbours' houses.
    if (town.riversideOpen) {
      _shop(c, const Offset(1500, kGroundY), const Color(0xFFE9F5DB), 'KIT\'S');
      paintFigure(c, kit, Offset(1590, kGroundY - math.sin(t * 5).abs() * 6), 60, mood: 1);
    }

    // Hill Farm is always "coming soon" for now.
    c.drawRect(const Rect.fromLTWH(2180, 0, 220, kMapH), Paint()..color = fade(Colors.white, 0.75));
    _sign(c, const Offset(2280, kGroundY), 'MORE\nSOON');

    // Fog over Riverside until the bridge opens it.
    if (!town.riversideOpen) {
      c.drawRect(const Rect.fromLTWH(kRiverRight + 10, 0, 2180 - kRiverRight - 10, kMapH),
          Paint()..color = fade(Colors.white, 0.72));
      _sign(c, const Offset(1760, kGroundY), 'BUILD A\nBRIDGE TO\nEXPLORE');
    }
    c.restore();
  }

  void _garage(Canvas c, Offset base, String name, double t) {
    const w = 230.0, h = 150.0;
    final r = Rect.fromLTWH(base.dx - w / 2, base.dy - h, w, h);
    c.drawRect(r, Paint()..color = const Color(0xFF9B5DE5));
    c.drawRect(r, _ink);
    final door = Rect.fromLTWH(base.dx - 70, base.dy - 90, 140, 90);
    c.drawRect(door, Paint()..color = const Color(0xFFCED4DA));
    for (var y = door.top + 12; y < door.bottom; y += 14) {
      c.drawLine(Offset(door.left, y), Offset(door.right, y), Paint()
        ..color = const Color(0xFFADB5BD)
        ..strokeWidth = 2);
    }
    c.drawRect(door, _ink);
    final sign = RRect.fromLTRBR(r.left + 10, r.top - 34, r.right - 10, r.top + 8, const Radius.circular(10));
    c.drawRRect(sign, Paint()..color = const Color(0xFFFFD23F));
    c.drawRRect(sign, _ink);
    final tp = TextPainter(
      text: TextSpan(
          text: name,
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: kInk)),
      textDirection: TextDirection.ltr,
      maxLines: 1,
      ellipsis: '…',
    )..layout(maxWidth: sign.width - 16);
    tp.paint(c, Offset(sign.center.dx - tp.width / 2, sign.center.dy - tp.height / 2));
  }

  void _shop(Canvas c, Offset base, Color wall, String label) {
    const w = 150.0, h = 110.0;
    final r = Rect.fromLTWH(base.dx - w / 2, base.dy - h, w, h);
    c.drawRect(r, Paint()..color = wall);
    c.drawRect(r, _ink);
    final roof = Path()
      ..moveTo(r.left - 12, r.top)
      ..lineTo(base.dx, r.top - 50)
      ..lineTo(r.right + 12, r.top)
      ..close();
    c.drawPath(roof, Paint()..color = const Color(0xFFB5524B));
    c.drawPath(roof, _ink);
    final door = RRect.fromLTRBR(base.dx - 16, base.dy - 50, base.dx + 16, base.dy, const Radius.circular(5));
    c.drawRRect(door, Paint()..color = const Color(0xFF7A5230));
    final tp = TextPainter(
      text: TextSpan(text: label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: kInk)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(c, Offset(base.dx - tp.width / 2, r.top + 10));
  }

  void _sign(Canvas c, Offset base, String text) {
    c.drawRect(Rect.fromLTWH(base.dx - 4, base.dy - 70, 8, 70), Paint()..color = const Color(0xFF7A5230));
    final tp = TextPainter(
      text: TextSpan(text: text, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: kInk, height: 1.1)),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    )..layout();
    final board = RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(base.dx, base.dy - 90), width: tp.width + 24, height: tp.height + 16),
        const Radius.circular(8));
    c.drawRRect(board, Paint()..color = const Color(0xFFFFF8E1));
    c.drawRRect(board, _ink);
    tp.paint(c, Offset(base.dx - tp.width / 2, base.dy - 90 - tp.height / 2));
  }

  @override
  bool shouldRepaint(covariant TownPainter old) => true;
}
