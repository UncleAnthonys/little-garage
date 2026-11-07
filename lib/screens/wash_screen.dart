import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../art/scenery.dart';
import '../art/truck_art.dart';
import '../data/models.dart';
import '../services/voice.dart';
import '../state/game_state.dart';
import '../widgets/ui.dart';

enum _Tool { sponge, hose, dryer }

const _toolInfo = <_Tool, (IconData, Color, String)>{
  _Tool.sponge: (Icons.cleaning_services_rounded, Color(0xFFFFB703),
      'Scrub scrub! Soap lifts the mud off.'),
  _Tool.hose: (Icons.shower_rounded, Color(0xFF4CC9F0),
      'Rinse! Water washes the soap away.'),
  _Tool.dryer: (Icons.air_rounded, Color(0xFF9B5DE5),
      'Dry it so it shines!'),
};

/// Three-step wash: soap, rinse, dry. Each tool scrubs a layer off the truck.
class WashScreen extends StatefulWidget {
  const WashScreen({super.key});

  @override
  State<WashScreen> createState() => _WashScreenState();
}

class _WashScreenState extends State<WashScreen>
    with SingleTickerProviderStateMixin {
  // Cell states: 1 dirt, 2 soap, 3 wet, 0 clean.
  final List<Offset> _cells = [];
  final List<int> _state = [];
  int _stage = 0;
  bool _done = false;
  Offset? _cursor;
  int _burst = 0;

  late final AnimationController _wobble = AnimationController(
      vsync: this, duration: const Duration(seconds: 2))
    ..repeat();

  static const double _brush = 26;

  @override
  void initState() {
    super.initState();
    _buildCells();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Voice.instance.say('Your truck is muddy! ${_toolInfo[_Tool.sponge]!.$3}');
    });
  }

  @override
  void dispose() {
    _wobble.dispose();
    super.dispose();
  }

  void _buildCells() {
    final body = <Path>[
      TruckGeo.chassis(),
      TruckGeo.cab(),
      TruckGeo.craneOutline(0),
    ];
    final rnd = math.Random(11);
    for (var y = 30.0; y < 236; y += 11) {
      for (var x = 34.0; x < 384; x += 11) {
        final p = Offset(x, y);
        final onBody = body.any((b) => b.contains(p)) ||
            TruckGeo.engineRect.contains(p) ||
            (p - TruckGeo.rearWheel).distance < 30 ||
            (p - TruckGeo.frontWheel).distance < 30;
        if (!onBody) continue;
        final dirtyChance = y > 150 ? 0.9 : 0.55;
        if (rnd.nextDouble() < dirtyChance) {
          _cells.add(p + Offset(rnd.nextDouble() * 4 - 2, rnd.nextDouble() * 4 - 2));
          _state.add(1);
        }
      }
    }
  }

  int get _goal => const [2, 3, 0][_stage];

  Rect _area(Size s) =>
      Rect.fromLTRB(s.width * 0.12, s.height * 0.06, s.width * 0.88, s.height * 0.74);

  void _scrub(Offset local, Fit fit) {
    if (_done) return;
    final v = fit.toVehicle(local);
    var changed = false;
    for (var i = 0; i < _cells.length; i++) {
      if ((_cells[i] - v).distance > _brush) continue;
      final st = _state[i];
      final next = switch (_stage) {
        0 => st == 1 ? 2 : st,
        1 => (st == 1 || st == 2) ? 3 : st,
        _ => 0,
      };
      if (next != st) {
        _state[i] = next;
        changed = true;
      }
    }
    setState(() => _cursor = local);
    if (changed) _checkStage();
  }

  void _checkStage() {
    final total = _state.length;
    if (total == 0) return;
    final reached = _state.where((s) => s == _goal).length;
    if (reached / total < 0.9) return;
    for (var i = 0; i < total; i++) {
      _state[i] = _goal;
    }
    Sfx.snap();
    if (_stage < 2) {
      _stage++;
      Voice.instance.say(_toolInfo[_Tool.values[_stage]]!.$3);
      setState(() {});
    } else {
      _finish();
    }
  }

  Future<void> _finish() async {
    final s = GameScope.read(context);
    s.setDirty(false);
    s.addStars(2);
    setState(() {
      _done = true;
      _cursor = null;
      _burst++;
    });
    Voice.instance.say('Squeaky clean! Two stars!');
    await Future<void>.delayed(const Duration(milliseconds: 2800));
    if (mounted) Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    final s = GameScope.of(context);
    final tool = _Tool.values[_stage];
    final info = _toolInfo[tool]!;
    return Scaffold(
      body: LayoutBuilder(builder: (context, c) {
        final size = Size(c.maxWidth, c.maxHeight);
        final area = _area(size);
        final fit = Fit.contain(area.size);
        return Stack(children: [
          const Positioned.fill(child: CustomPaint(painter: GaragePainter())),
          Positioned.fromRect(
            rect: area,
            child: GestureDetector(
              onPanStart: (d) => _scrub(d.localPosition, fit),
              onPanUpdate: (d) => _scrub(d.localPosition, fit),
              onPanEnd: (_) => setState(() => _cursor = null),
              child: AnimatedBuilder(
                animation: _wobble,
                builder: (context, _) => Stack(children: [
                  Positioned.fill(
                    child: CustomPaint(
                        painter: VehiclePainter(lookFrom(s,
                            built: allParts,
                            highlight: _done ? PartKind.headlights : null,
                            t: _wobble.value))),
                  ),
                  Positioned.fill(
                    child: CustomPaint(
                        painter: _WashPainter(_cells, _state, fit, _wobble.value, _done)),
                  ),
                  if (_cursor != null)
                    Positioned(
                      left: _cursor!.dx - 34,
                      top: _cursor!.dy - 34,
                      child: IgnorePointer(
                        child: Icon(info.$1, size: 68, color: info.$2, shadows: const [
                          Shadow(color: Colors.black45, blurRadius: 6),
                        ]),
                      ),
                    ),
                ]),
              ),
            ),
          ),
          // Tools, in order; only the current one is lit.
          Positioned(
            left: 0,
            right: 0,
            bottom: 18,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (final t in _Tool.values) ...[
                  IconBubble(_toolInfo[t]!.$1,
                      size: 84,
                      color: _toolInfo[t]!.$2,
                      glow: t == tool && !_done,
                      dimmed: t != tool || _done,
                      onTap: () => Voice.instance.say(_toolInfo[t]!.$3)),
                  const SizedBox(width: 22),
                ],
              ],
            ),
          ),
          Positioned(
            top: 14,
            left: 0,
            right: 0,
            child: Center(
              child: PartBanner(
                title: _done ? 'Squeaky clean!' : const ['Soap', 'Rinse', 'Dry'][_stage],
                line: _done ? null : 'Rub the truck with your finger',
              ),
            ),
          ),
          const Positioned(left: 20, top: 20, child: BackBubble()),
          const Positioned(right: 20, top: 20, child: StarCounter()),
          Positioned.fill(child: StarBurst(trigger: _burst)),
        ]);
      }),
    );
  }
}

class _WashPainter extends CustomPainter {
  final List<Offset> cells;
  final List<int> state;
  final Fit fit;
  final double t;
  final bool done;
  _WashPainter(this.cells, this.state, this.fit, this.t, this.done);

  @override
  void paint(Canvas c, Size size) {
    c.save();
    c.translate(fit.offset.dx, fit.offset.dy);
    c.scale(fit.scale);
    final mud = Paint()..color = fade(const Color(0xFF7A5230), 0.85);
    final soap = Paint()..color = fade(Colors.white, 0.92);
    final soapRim = Paint()
      ..color = fade(const Color(0xFF9AD4F5), 0.9)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    final drop = Paint()..color = fade(const Color(0xFF4CC9F0), 0.55);
    for (var i = 0; i < cells.length; i++) {
      final p = cells[i];
      switch (state[i]) {
        case 1:
          c.drawCircle(p, 7.5, mud);
          break;
        case 2:
          final w = math.sin(t * math.pi * 2 + i) * 1.2;
          c.drawCircle(p + Offset(w, 0), 6, soap);
          c.drawCircle(p + Offset(w, 0), 6, soapRim);
          c.drawCircle(p + Offset(4 - w, -5), 3.5, soap);
          break;
        case 3:
          c.drawOval(Rect.fromCenter(center: p, width: 4, height: 6), drop);
          break;
      }
    }
    if (done) {
      // Sparkles.
      for (var i = 0; i < 6; i++) {
        final ph = (t + i / 6) % 1.0;
        final pos = Offset(60 + i * 55.0, 60 + (i % 3) * 40.0);
        c.drawPath(starPath(pos, 4 + 8 * math.sin(ph * math.pi), innerRatio: 0.3),
            Paint()..color = fade(Colors.white, math.sin(ph * math.pi)));
      }
    }
    c.restore();
  }

  @override
  bool shouldRepaint(covariant _WashPainter old) => true;
}
