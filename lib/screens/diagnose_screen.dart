import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../art/scenery.dart';
import '../art/town_art.dart';
import '../art/truck_art.dart';
import '../data/missions.dart';
import '../services/voice.dart';
import '../state/game_state.dart';
import '../widgets/ui.dart';
import 'mission_flow.dart';

enum _Step { arriving, look, tools, fixing, done }

/// Diagnose and fix: look for the clue, find what's wrong, pick the tool.
/// Wrong guesses explain what that tool is for. Nothing is ever a fail.
class DiagnoseScreen extends StatefulWidget {
  final Mission mission;
  const DiagnoseScreen({super.key, required this.mission});

  /// Where the customer's car sits: below the banner, left of the toolbox.
  static Rect carBoxFor(Size size) {
    const bannerSpace = 104.0;
    final maxH = size.height * 0.9 - bannerSpace;
    final carW = math.min(size.width * 0.58, maxH * kSimpleW / kSimpleH);
    final carH = carW * kSimpleH / kSimpleW;
    final left = (size.width * 0.66 - carW) / 2;
    return Rect.fromLTWH(left, bannerSpace + (maxH - carH) / 2 + 8, carW, carH);
  }

  @override
  State<DiagnoseScreen> createState() => _DiagnoseScreenState();
}

class _DiagnoseScreenState extends State<DiagnoseScreen> with TickerProviderStateMixin {
  late final AnimationController _clock = AnimationController(
      vsync: this, duration: const Duration(seconds: 10))
    ..repeat();
  late final AnimationController _arrive = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1600));
  late final AnimationController _fix = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 2400));
  late final AnimationController _shake = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 450));

  _Step _step = _Step.arriving;
  bool _hint = false;
  Timer? _hintTimer;
  late List<Tool> _choices;
  final Set<Tool> _tried = {};
  String? _banner;
  String? _bannerLine;

  Fault get _fault => widget.mission.fault!;
  FaultInfo get _info => faults[_fault]!;

  static const _carColors = [
    Color(0xFF3A86FF),
    Color(0xFFE63946),
    Color(0xFF8AC926),
    Color(0xFFFFB703),
    Color(0xFF9B5DE5),
  ];
  Color get _carColor => _carColors[widget.mission.id.length % _carColors.length];

  @override
  void initState() {
    super.initState();
    final s = GameScope.read(context);
    final rnd = math.Random();
    final others = Tool.values.where((t) => t != _info.tool).toList()..shuffle(rnd);
    _choices = [_info.tool, ...others.take(choicesFor(s.ageBand) - 1)]..shuffle(rnd);
    _arrive.forward().then((_) {
      if (!mounted) return;
      setState(() {
        _step = _Step.look;
        _banner = 'What\'s wrong?';
        _bannerLine = 'Look for a clue and tap it';
      });
      Voice.instance.say(_info.symptom);
      _startHint();
    });
  }

  @override
  void dispose() {
    _hintTimer?.cancel();
    _clock.dispose();
    _arrive.dispose();
    _fix.dispose();
    _shake.dispose();
    super.dispose();
  }

  void _startHint() {
    _hintTimer?.cancel();
    setState(() => _hint = false);
    _hintTimer = Timer(hintDelayFor(GameScope.read(context).ageBand), () {
      if (mounted) setState(() => _hint = true);
    });
  }

  void _tapCar(Offset local, Size box) {
    if (_step != _Step.look) return;
    final spot = Offset(_info.spot.dx * box.width, _info.spot.dy * box.height);
    if ((local - spot).distance < box.width * 0.13) {
      Sfx.snap();
      _hintTimer?.cancel();
      setState(() {
        _step = _Step.tools;
        _hint = false;
        _banner = 'Found it!';
        _bannerLine = 'Which tool will fix it?';
      });
      Voice.instance.say('${_info.found} Which tool will fix it?');
      _startHint();
    } else {
      Voice.instance.say('That part looks fine. Look again!');
      _shake.forward(from: 0);
    }
  }

  Future<void> _pickTool(Tool t) async {
    if (_step != _Step.tools) return;
    if (t != _info.tool) {
      setState(() => _tried.add(t));
      final job = tools[t]!.job;
      final extra = _fault == Fault.noCharge && t == Tool.fuelCan
          ? ' But electric cars don\'t use fuel!'
          : ' That won\'t fix this problem.';
      Voice.instance.say('$job$extra Try another one!');
      return;
    }
    _hintTimer?.cancel();
    Sfx.snap();
    setState(() {
      _step = _Step.fixing;
      _hint = false;
      _banner = tools[t]!.name;
      _bannerLine = null;
    });
    Voice.instance.say(_info.fixed);
    await _fix.forward();
    if (!mounted) return;
    setState(() {
      _step = _Step.done;
      _banner = 'Fixed it!';
    });
    await Future<void>.delayed(const Duration(milliseconds: 1400));
    if (mounted) finishMission(context, widget.mission);
  }

  @override
  Widget build(BuildContext context) {
    final m = widget.mission;
    return Scaffold(
      body: LayoutBuilder(builder: (context, c) {
        final size = Size(c.maxWidth, c.maxHeight);
        final carBox = DiagnoseScreen.carBoxFor(size);
        final toolsOpen = _step == _Step.tools || _step == _Step.fixing;

        return AnimatedBuilder(
          animation: Listenable.merge([_clock, _arrive, _fix, _shake]),
          builder: (context, _) {
            final t = _clock.value * 10;
            final arriveDx = (1 - Curves.easeOutCubic.transform(_arrive.value)) * -size.width * 0.8;
            final shakeDx = math.sin(_shake.value * math.pi * 6) * 8 * (1 - _shake.value);
            final fixing = _step == _Step.done ? 1.0 : (_step == _Step.fixing ? _fix.value : 0.0);
            final mood = _step == _Step.done ? 1.0 : (fixing > 0.5 ? 0.5 : -1.0);
            final look = CarLook(
              type: m.carType,
              color: _carColor,
              fault: _fault,
              driver: m.caller,
              driverMood: mood,
              t: t,
              fixing: fixing,
              lightsOn: _step == _Step.done,
              wheelTurn: _arrive.value * 12,
            );
            final spot = Offset(carBox.left + _info.spot.dx * carBox.width,
                carBox.top + _info.spot.dy * carBox.height);

            return Stack(children: [
              const Positioned.fill(child: CustomPaint(painter: GaragePainter())),

              // The customer's car.
              Positioned.fromRect(
                rect: carBox.shift(Offset(arriveDx + shakeDx, 0)),
                child: GestureDetector(
                  onTapUp: (d) => _tapCar(d.localPosition, carBox.size),
                  child: CustomPaint(painter: SimpleVehiclePainter(look)),
                ),
              ),

              // Hint: a pulsing ring around the clue.
              if (_hint && _step == _Step.look)
                Positioned(
                  left: spot.dx - 50,
                  top: spot.dy - 50,
                  width: 100,
                  height: 100,
                  child: IgnorePointer(
                    child: CustomPaint(painter: _RingPainter((t * 1.5) % 1.0)),
                  ),
                ),

              // Tool flying to the problem while fixing.
              if (_step == _Step.fixing)
                Positioned(
                  left: Offset.lerp(Offset(size.width * 0.82, size.height * 0.5), spot,
                              Curves.easeOut.transform((_fix.value * 2).clamp(0.0, 1.0)))!
                          .dx -
                      36,
                  top: Offset.lerp(Offset(size.width * 0.82, size.height * 0.5), spot,
                              Curves.easeOut.transform((_fix.value * 2).clamp(0.0, 1.0)))!
                          .dy -
                      36 +
                      math.sin(_fix.value * math.pi * 10) * 6,
                  child: IgnorePointer(
                    child: Icon(tools[_info.tool]!.icon,
                        size: 72,
                        color: tools[_info.tool]!.color,
                        shadows: const [Shadow(color: Colors.white, blurRadius: 12)]),
                  ),
                ),

              // Toolbox.
              AnimatedPositioned(
                duration: const Duration(milliseconds: 400),
                curve: Curves.easeOutBack,
                right: toolsOpen ? size.width * 0.03 : -size.width * 0.4,
                top: size.height * 0.18,
                bottom: size.height * 0.06,
                width: size.width * 0.3,
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE63946),
                    borderRadius: BorderRadius.circular(26),
                    border: Border.all(color: Colors.white, width: 5),
                  ),
                  child: Column(children: [
                    const Text('Toolbox',
                        style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.white)),
                    Expanded(
                      child: Center(
                        child: Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          alignment: WrapAlignment.center,
                          children: [
                            for (final tool in _choices)
                              Column(mainAxisSize: MainAxisSize.min, children: [
                                IconBubble(tools[tool]!.icon,
                                    size: 76,
                                    color: tools[tool]!.color,
                                    dimmed: _tried.contains(tool),
                                    glow: _hint && tool == _info.tool,
                                    onTap: () => _pickTool(tool)),
                                const SizedBox(height: 2),
                                Text(tools[tool]!.name,
                                    style: const TextStyle(
                                        fontSize: 13, fontWeight: FontWeight.w800, color: Colors.white)),
                              ]),
                          ],
                        ),
                      ),
                    ),
                  ]),
                ),
              ),

              Positioned(
                top: 14,
                left: 0,
                right: toolsOpen ? size.width * 0.3 : 0,
                child: Center(child: PartBanner(title: _banner, line: _bannerLine)),
              ),
              const Positioned(left: 20, top: 20, child: BackBubble()),
              if (!toolsOpen) const Positioned(right: 20, top: 20, child: StarCounter()),
              Positioned(
                left: 20,
                bottom: 20,
                child: IconBubble(Icons.replay_rounded,
                    size: 56,
                    color: const Color(0xFF4C6EF5),
                    onTap: () => Voice.instance.say(_step == _Step.tools
                        ? '${_info.found} Which tool will fix it?'
                        : _info.symptom)),
              ),
            ]);
          },
        );
      }),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double p;
  _RingPainter(this.p);

  @override
  void paint(Canvas c, Size s) {
    final ctr = s.center(Offset.zero);
    c.drawCircle(
        ctr,
        s.shortestSide * (0.25 + 0.25 * p),
        Paint()
          ..color = fade(const Color(0xFFFFD23F), 1 - p)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 8);
    c.drawCircle(
        ctr,
        s.shortestSide * 0.22,
        Paint()
          ..color = fade(const Color(0xFFFFD23F), 0.8)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 5);
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) => old.p != p;
}
