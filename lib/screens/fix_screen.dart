import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../art/scenery.dart';
import '../art/truck_art.dart';
import '../data/models.dart';
import '../services/voice.dart';
import '../state/game_state.dart';
import '../widgets/ui.dart';

class _Problem {
  final String title;
  final String prompt;
  final String fixed;
  final Breakdown tool;
  final PartKind part;
  const _Problem(this.title, this.prompt, this.fixed, this.tool, this.part);
}

const _problems = <Breakdown, _Problem>{
  Breakdown.flatTyre: _Problem(
      'Flat tyre!',
      'Oh no, a flat tyre! The air leaked out. What can fix it?',
      'A new tyre full of air! Now the truck can roll.',
      Breakdown.flatTyre,
      PartKind.wheels),
  Breakdown.noFuel: _Problem(
      'Out of fuel!',
      'The fuel tank is empty. The engine has no food! What can fix it?',
      'Glug glug! Fuel gives the engine power to go.',
      Breakdown.noFuel,
      PartKind.engine),
  Breakdown.brokenLight: _Problem(
      'Broken headlight!',
      "The headlight bulb is broken, so we can't see in the dark. What can fix it?",
      'A new bulb! Now the headlight shines bright.',
      Breakdown.brokenLight,
      PartKind.headlights),
};

const _toolNames = <Breakdown, String>{
  Breakdown.flatTyre: 'new tyre',
  Breakdown.noFuel: 'fuel can',
  Breakdown.brokenLight: 'light bulb',
};

/// The truck has broken down. The child works out which tool fixes it and
/// hears why. Wrong picks get a gentle explanation, never a fail.
class FixScreen extends StatefulWidget {
  final Breakdown problem;
  const FixScreen({super.key, required this.problem});

  @override
  State<FixScreen> createState() => _FixScreenState();
}

class _FixScreenState extends State<FixScreen> with TickerProviderStateMixin {
  late final AnimationController _action = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 2200));
  late final AnimationController _shake = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 500));
  late final List<Breakdown> _tools = Breakdown.values.toList()..shuffle(math.Random());
  bool _fixed = false;
  int _burst = 0;
  Breakdown? _wrong;

  _Problem get _p => _problems[widget.problem]!;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => Voice.instance.say(_p.prompt));
  }

  @override
  void dispose() {
    _action.dispose();
    _shake.dispose();
    super.dispose();
  }

  Future<void> _pick(Breakdown tool) async {
    if (_fixed) return;
    if (tool != widget.problem) {
      setState(() => _wrong = tool);
      _shake.forward(from: 0);
      final hint = switch (widget.problem) {
        Breakdown.flatTyre => 'Look at the wheel. It is all squashed!',
        Breakdown.noFuel => 'Look at the fuel gauge. It is empty!',
        Breakdown.brokenLight => 'Look at the headlight. It is cracked!',
      };
      Voice.instance.say("That's the ${_toolNames[tool]}. $hint");
      return;
    }
    Sfx.snap();
    final s = GameScope.read(context);
    s.addStars(2);
    setState(() {
      _fixed = true;
      _wrong = null;
      _burst++;
    });
    Voice.instance.say(_p.fixed);
    await _action.forward(from: 0);
    await Future<void>.delayed(const Duration(milliseconds: 600));
    if (mounted) Navigator.of(context).pop(true);
  }

  Widget _toolIcon(Breakdown t, double size) {
    switch (t) {
      case Breakdown.flatTyre:
        return SizedBox(
            width: size,
            height: size,
            child: CustomPaint(painter: WheelThumbPainter(WheelStyle.classic)));
      case Breakdown.noFuel:
        return Icon(Icons.local_gas_station_rounded, size: size, color: Colors.white);
      case Breakdown.brokenLight:
        return Icon(Icons.lightbulb_rounded, size: size, color: const Color(0xFFFFE066));
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = GameScope.of(context);
    return Scaffold(
      body: LayoutBuilder(builder: (context, c) {
        final size = Size(c.maxWidth, c.maxHeight);
        final area = Rect.fromLTRB(
            size.width * 0.04, size.height * 0.14, size.width * 0.66, size.height * 0.8);
        return Stack(children: [
          const Positioned.fill(child: CustomPaint(painter: GaragePainter())),
          Positioned.fromRect(
            rect: area,
            child: AnimatedBuilder(
              animation: Listenable.merge([_action, _shake]),
              builder: (context, _) => Transform.translate(
                offset: Offset(math.sin(_shake.value * math.pi * 6) * 6 * (1 - _shake.value), 0),
                child: CustomPaint(
                  painter: VehiclePainter(lookFrom(s,
                      built: allParts,
                      breakdown: _fixed ? null : widget.problem,
                      highlight: _fixed ? _p.part : null,
                      t: _action.value,
                      lightsOn: _fixed && widget.problem == Breakdown.brokenLight)),
                ),
              ),
            ),
          ),

          // Fuel gauge for the empty-tank problem.
          if (widget.problem == Breakdown.noFuel)
            Positioned(
              left: area.left + area.width * 0.38,
              top: area.top - 10,
              child: AnimatedBuilder(
                animation: _action,
                builder: (context, _) => SizedBox(
                  width: 130,
                  height: 80,
                  child: CustomPaint(
                      painter: _GaugePainter(_fixed ? Curves.easeOut.transform(_action.value) : 0)),
                ),
              ),
            ),

          // Toolbox.
          Positioned(
            right: size.width * 0.03,
            top: size.height * 0.18,
            bottom: size.height * 0.08,
            child: Container(
              width: size.width * 0.26,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFE63946),
                borderRadius: BorderRadius.circular(26),
                border: Border.all(color: Colors.white, width: 5),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  const Text('Toolbox',
                      style: TextStyle(
                          fontSize: 24, fontWeight: FontWeight.w900, color: Colors.white)),
                  for (final t in _tools)
                    BubbleButton(
                      size: (size.height * 0.16).clamp(52.0, 84.0),
                      color: _wrong == t ? const Color(0xFF8D99AE) : const Color(0xFF4C6EF5),
                      glow: _fixed && t == widget.problem,
                      onTap: () => _pick(t),
                      child: _toolIcon(t, (size.height * 0.1).clamp(30.0, 50.0)),
                    ),
                ],
              ),
            ),
          ),

          Positioned(
            top: 14,
            left: 0,
            right: size.width * 0.3,
            child: Center(
              child: PartBanner(
                title: _fixed ? 'Fixed it!' : _p.title,
                line: _fixed ? null : 'Which tool fixes it?',
              ),
            ),
          ),
          Positioned(
              left: 20,
              top: 20,
              child: BackBubble(onTap: () => Navigator.of(context).pop(false))),
          Positioned.fill(child: StarBurst(trigger: _burst)),
        ]);
      }),
    );
  }
}

class _GaugePainter extends CustomPainter {
  final double level;
  _GaugePainter(this.level);

  @override
  void paint(Canvas c, Size s) {
    final ctr = Offset(s.width / 2, s.height * 0.92);
    final r = s.width * 0.42;
    final rect = Rect.fromCircle(center: ctr, radius: r);
    c.drawArc(rect, math.pi, math.pi, true, Paint()..color = Colors.white);
    c.drawArc(rect.deflate(6), math.pi, math.pi * 0.25, false,
        Paint()
          ..color = const Color(0xFFE63946)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 8);
    c.drawArc(rect.deflate(6), math.pi * 1.75, math.pi * 0.25, false,
        Paint()
          ..color = const Color(0xFF2DC653)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 8);
    c.drawArc(rect, math.pi, math.pi, true,
        Paint()
          ..color = kInk
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3);
    final a = math.pi + level * math.pi;
    c.drawLine(ctr, ctr + Offset(math.cos(a), math.sin(a)) * r * 0.8,
        Paint()
          ..color = kInk
          ..strokeWidth = 4
          ..strokeCap = StrokeCap.round);
    c.drawCircle(ctr, 6, Paint()..color = kInk);
    for (final (label, x) in const [('E', 0.12), ('F', 0.88)]) {
      final tp = TextPainter(
          text: TextSpan(
              text: label,
              style: const TextStyle(
                  fontSize: 16, fontWeight: FontWeight.w900, color: kInk)),
          textDirection: TextDirection.ltr)
        ..layout();
      tp.paint(c, Offset(s.width * x - tp.width / 2, ctr.dy - tp.height - 2));
    }
  }

  @override
  bool shouldRepaint(covariant _GaugePainter old) => old.level != level;
}
