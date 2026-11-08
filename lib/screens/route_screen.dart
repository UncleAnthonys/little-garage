import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../art/town_art.dart';
import '../art/truck_art.dart';
import '../data/missions.dart';
import '../data/models.dart';
import '../services/voice.dart';
import '../state/game_state.dart';
import '../widgets/ui.dart';
import 'mission_flow.dart';

/// Before a drive: pick a road that isn't closed, then look at the clues
/// for what's ahead (mud, dark, a low bridge) and get the truck ready.
class RouteScreen extends StatefulWidget {
  final Mission mission;
  const RouteScreen({super.key, required this.mission});

  @override
  State<RouteScreen> createState() => _RouteScreenState();
}

class _RouteScreenState extends State<RouteScreen> with TickerProviderStateMixin {
  late final AnimationController _clock = AnimationController(
      vsync: this, duration: const Duration(seconds: 10))
    ..repeat();
  late final AnimationController _travel = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 2400));

  late final bool _topClosed = math.Random().nextBool();
  late bool _routeDone = !widget.mission.routeChoice;
  bool? _chosenTop;
  int _wrong = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_routeDone) {
        _sayClues();
      } else {
        Voice.instance.say(
            'Here\'s the map. One road is closed! Tap the road that is open to get to ${widget.mission.caller.name}.');
      }
    });
  }

  @override
  void dispose() {
    _clock.dispose();
    _travel.dispose();
    super.dispose();
  }

  void _sayClues() {
    final clues = widget.mission.clues;
    if (clues.isEmpty) {
      Voice.instance.say('Ready? Let\'s drive!');
      return;
    }
    final parts = <String>[];
    for (final c in clues) {
      parts.add(switch (c) {
        Prep.monsterTyres => 'There\'s lots of mud on the way. Which wheels grip best in mud?',
        Prep.headlights => 'It\'s dark outside. What will help you see?',
        Prep.lowerCrane => 'There\'s a very low bridge. Your crane is tall!',
        Prep.roadSense => 'Watch out for traffic lights and people crossing.',
      });
    }
    Voice.instance.say('Look at the clues! ${parts.join(' ')}');
  }

  Future<void> _pickRoad(bool top) async {
    if (_routeDone || _chosenTop != null) return;
    if (top == _topClosed) {
      _wrong++;
      Voice.instance.say('That road is closed! Look for the cones and the sign. Try the other road.');
      setState(() {});
      return;
    }
    Sfx.snap();
    setState(() => _chosenTop = top);
    Voice.instance.say('Good thinking! That road is open.');
    await _travel.forward();
    if (!mounted) return;
    setState(() => _routeDone = true);
    _sayClues();
  }

  @override
  Widget build(BuildContext context) {
    final s = GameScope.of(context);
    final m = widget.mission;
    return Scaffold(
      body: LayoutBuilder(builder: (context, c) {
        final size = Size(c.maxWidth, c.maxHeight);
        final map = Rect.fromLTWH(size.width * 0.08, size.height * 0.16, size.width * 0.84, size.height * 0.62);
        return AnimatedBuilder(
          animation: Listenable.merge([_clock, _travel]),
          builder: (context, _) {
            return Stack(children: [
              const Positioned.fill(child: ColoredBox(color: Color(0xFFBDE0A8))),
              if (!_routeDone)
                Positioned.fromRect(
                  rect: map,
                  child: GestureDetector(
                    onTapUp: (d) => _pickRoad(d.localPosition.dy < map.height / 2),
                    child: CustomPaint(
                      painter: _MapPainter(
                        caller: m.caller,
                        topClosed: _topClosed,
                        chosenTop: _chosenTop,
                        travel: _travel.value,
                        hintClosed: _wrong > 0,
                        t: _clock.value * 10,
                      ),
                    ),
                  ),
                )
              else
                Positioned.fromRect(
                  rect: map,
                  child: _Clues(mission: m, state: s),
                ),
              Positioned(
                top: 14,
                left: 0,
                right: 0,
                child: Center(
                  child: PartBanner(
                    title: _routeDone ? 'Get ready!' : 'Which way?',
                    line: _routeDone ? 'Look at the clues' : 'Tap the road that is open',
                  ),
                ),
              ),
              const Positioned(left: 20, top: 20, child: BackBubble()),
              const Positioned(right: 20, top: 20, child: StarCounter()),
              if (_routeDone)
                Positioned(
                  right: 24,
                  bottom: 18,
                  child: IconBubble(Icons.flag_rounded,
                      size: 100,
                      color: const Color(0xFF2DC653),
                      glow: true,
                      onTap: () => openMissionDrive(context, m)),
                ),
              Positioned(
                left: 20,
                bottom: 20,
                child: IconBubble(Icons.replay_rounded,
                    size: 56,
                    color: const Color(0xFF4C6EF5),
                    onTap: _routeDone
                        ? _sayClues
                        : () => Voice.instance.say('Tap the road that is open.')),
              ),
            ]);
          },
        );
      }),
    );
  }
}

/// Picture clues for the drive ahead, with a quick fix for tyres.
class _Clues extends StatelessWidget {
  final Mission mission;
  final GameState state;
  const _Clues({required this.mission, required this.state});

  @override
  Widget build(BuildContext context) {
    final cards = <Widget>[];
    for (final c in mission.clues) {
      final (icon, color, label) = switch (c) {
        Prep.monsterTyres => (Icons.landscape_rounded, const Color(0xFF7A5230), 'Muddy road'),
        Prep.headlights => (Icons.nightlight_round, const Color(0xFF3B3F9E), 'Dark night'),
        Prep.lowerCrane => (Icons.vertical_align_bottom, const Color(0xFFB08968), 'Low bridge'),
        Prep.roadSense => (Icons.traffic, const Color(0xFFE63946), 'Lights and crossings'),
      };
      cards.add(Container(
        width: 170,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: color, width: 5),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 64, color: color),
          const SizedBox(height: 6),
          Text(label,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: kInk)),
        ]),
      ));
    }
    final needsTyres = mission.clues.contains(Prep.monsterTyres);
    return Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Wrap(spacing: 16, runSpacing: 16, alignment: WrapAlignment.center, children: cards),
      if (needsTyres) ...[
        const SizedBox(height: 18),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFF6C4AB6),
            borderRadius: BorderRadius.circular(26),
            border: Border.all(color: Colors.white, width: 4),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            for (final w in WheelStyle.values)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: BubbleButton(
                  size: 66,
                  color: state.wheels == w ? const Color(0xFFFFD23F) : const Color(0xFFBDE0FE),
                  glow: state.wheels == w,
                  onTap: () {
                    state.setWheels(w);
                    Voice.instance.say(wheelLines[w]!);
                  },
                  child: SizedBox(
                      width: 52, height: 52, child: CustomPaint(painter: WheelThumbPainter(w))),
                ),
              ),
          ]),
        ),
      ],
    ]);
  }
}

class _MapPainter extends CustomPainter {
  final Townsperson caller;
  final bool topClosed;
  final bool? chosenTop;
  final double travel;
  final bool hintClosed;
  final double t;
  _MapPainter({
    required this.caller,
    required this.topClosed,
    required this.chosenTop,
    required this.travel,
    required this.hintClosed,
    required this.t,
  });

  static const w = 600.0, h = 320.0;
  static const start = Offset(70, 160), end = Offset(530, 160);
  static const topCtl = Offset(300, -20), botCtl = Offset(300, 340);

  Offset _bez(Offset ctl, double p) {
    final a = Offset.lerp(start, ctl, p)!;
    final b = Offset.lerp(ctl, end, p)!;
    return Offset.lerp(a, b, p)!;
  }

  @override
  void paint(Canvas c, Size size) {
    final s = math.min(size.width / w, size.height / h);
    c.save();
    c.translate((size.width - w * s) / 2, (size.height - h * s) / 2);
    c.scale(s);

    c.drawRRect(RRect.fromLTRBR(0, 0, w, h, const Radius.circular(24)),
        Paint()..color = const Color(0xFFDDF2C5));
    // Pond and trees for a map feel.
    c.drawOval(const Rect.fromLTWH(250, 130, 100, 60), Paint()..color = const Color(0xFF8ED1F2));
    for (final p in const [Offset(200, 120), Offset(400, 200), Offset(420, 110), Offset(180, 210)]) {
      c.drawCircle(p, 16, Paint()..color = const Color(0xFF2E9E46));
    }

    for (final top in [true, false]) {
      final ctl = top ? topCtl : botCtl;
      final path = Path()
        ..moveTo(start.dx, start.dy)
        ..quadraticBezierTo(ctl.dx, ctl.dy, end.dx, end.dy);
      final closed = top == topClosed;
      c.drawPath(
          path,
          Paint()
            ..color = const Color(0xFF7D7A91)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 34
            ..strokeCap = StrokeCap.round);
      c.drawPath(
          path,
          Paint()
            ..color = Colors.white
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3);
      if (closed) {
        final mid = _bez(ctl, 0.5);
        final pulse = hintClosed ? 1 + 0.15 * math.sin(t * 8) : 1.0;
        for (var i = -1; i <= 1; i++) {
          final cp = mid + Offset(i * 26.0, 0);
          final cone = Path()
            ..moveTo(cp.dx, cp.dy - 22 * pulse)
            ..lineTo(cp.dx - 11, cp.dy + 10)
            ..lineTo(cp.dx + 11, cp.dy + 10)
            ..close();
          c.drawPath(cone, Paint()..color = const Color(0xFFFF8C42));
          c.drawRect(Rect.fromLTWH(cp.dx - 7, cp.dy - 6, 14, 5), Paint()..color = Colors.white);
        }
        // Road closed sign.
        final sign = mid + Offset(0, top ? 40 : -48);
        c.drawCircle(sign, 18, Paint()..color = const Color(0xFFE63946));
        c.drawRect(Rect.fromCenter(center: sign, width: 22, height: 7), Paint()..color = Colors.white);
      }
    }

    // Garage (start) and caller's house (end).
    c.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: start, width: 70, height: 56), const Radius.circular(8)),
        Paint()..color = const Color(0xFF9B5DE5));
    final g = TextPainter(
        text: const TextSpan(text: 'GARAGE', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: Colors.white)),
        textDirection: TextDirection.ltr)
      ..layout();
    g.paint(c, start - Offset(g.width / 2, g.height / 2));
    final roof = Path()
      ..moveTo(end.dx - 40, end.dy - 14)
      ..lineTo(end.dx, end.dy - 50)
      ..lineTo(end.dx + 40, end.dy - 14)
      ..close();
    c.drawRect(Rect.fromCenter(center: end + const Offset(0, 10), width: 64, height: 50),
        Paint()..color = const Color(0xFFFFE5EC));
    c.drawPath(roof, Paint()..color = const Color(0xFFB5524B));
    paintTownsperson(c, caller, end + const Offset(0, 12), 16, mood: -0.5);

    // The truck travelling along the chosen road.
    final chosen = chosenTop;
    final p = chosen == null ? 0.0 : travel;
    final pos = chosen == null ? start + const Offset(0, -46) : _bez(chosen ? topCtl : botCtl, p);
    c.drawCircle(pos, 16, Paint()..color = const Color(0xFFFF9F1C));
    c.drawCircle(
        pos,
        16,
        Paint()
          ..color = kInk
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3);
    final tp = TextPainter(
        text: const TextSpan(text: 'YOU', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: kInk)),
        textDirection: TextDirection.ltr)
      ..layout();
    tp.paint(c, pos - Offset(tp.width / 2, tp.height / 2));
    c.restore();
  }

  @override
  bool shouldRepaint(covariant _MapPainter old) => true;
}
