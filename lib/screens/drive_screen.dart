import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../art/scenery.dart';
import '../art/truck_art.dart';
import '../data/models.dart';
import '../services/voice.dart';
import '../state/game_state.dart';
import '../widgets/ui.dart';
import 'fix_screen.dart';

/// World layout of one drive, in world pixels.
class _Course {
  static const double length = 9000;
  static const double breakdownAt = 3600;
  static const mud = <(double, double)>[(2100.0, 2700.0), (6500.0, 7100.0)];
  static const tunnel = (5100.0, 6100.0);
  static const bumps = <double>[1500.0, 3100.0, 7800.0];

  static final List<(double, double)> stars = [
    for (var i = 0; i < 25; i++) (700.0 + i * 320, (i % 3) / 2),
  ];

  static bool inMud(double x) => mud.any((m) => x > m.$1 && x < m.$2);
  static bool inTunnel(double x) => x > tunnel.$1 && x < tunnel.$2;
}

class DriveScreen extends StatefulWidget {
  const DriveScreen({super.key});

  @override
  State<DriveScreen> createState() => _DriveScreenState();
}

class _DriveScreenState extends State<DriveScreen>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker = createTicker(_tick);
  Duration _last = Duration.zero;

  double _x = 0;
  double _speed = 0;
  double _time = 0;
  double _wheelTurn = 0;
  bool _holding = false;
  bool _lights = false;
  bool _night = false;
  double _hornUntil = 0;

  Breakdown? _broken;
  bool _brokeOnce = false;
  bool _finished = false;
  String? _message;
  int _burst = 0;
  int _collectedCount = 0;

  final Set<int> _collected = {};
  final List<(Offset, double)> _pops = [];

  bool _saidMud = false;
  bool _saidDark = false;
  bool _wantLights = false;

  Size _size = Size.zero;

  @override
  void initState() {
    super.initState();
    _ticker.start();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Voice.instance.say('Press and hold to drive. Collect the stars!');
    });
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  double get _scale => _size.height * 0.34 / kVehicleH;
  double get _truckW => kVehicleW * _scale;
  double get _truckLeft => _size.width * 0.16;
  double get _truckCentre => _x + _truckW * 0.55;

  bool _darkAt(double worldX) => _night || _Course.inTunnel(worldX);

  void _tick(Duration elapsed) {
    final dt = ((elapsed - _last).inMicroseconds / 1e6).clamp(0.0, 0.05);
    _last = elapsed;
    if (_size == Size.zero) return;
    _time += dt;
    final s = GameScope.read(context);

    final canDrive = _broken == null && !_finished;
    final mud = _Course.inMud(_truckCentre);
    final monster = s.wheels == WheelStyle.monster;
    final maxSpeed = mud && !monster ? 90.0 : 440.0;

    if (_holding && canDrive) {
      _speed = math.min(maxSpeed, _speed + 520 * dt);
    } else {
      _speed = math.max(0, _speed - 640 * dt);
    }
    if (_speed > maxSpeed) _speed = math.max(maxSpeed, _speed - 900 * dt);
    _x += _speed * dt;

    final r = TruckGeo.wheelRadius(s.wheels) * _scale;
    final slip = mud && !monster && _holding && canDrive;
    _wheelTurn += (slip ? 380 : _speed) * dt / r;

    if (mud && _holding && !_saidMud) {
      _saidMud = true;
      Voice.instance.say(monster
          ? 'Splash! Big monster tyres grip the mud.'
          : 'Oh no, small wheels get stuck in mud! Monster tyres grip better.');
      _message = monster ? 'Splash!' : 'Stuck in the mud!';
    }
    if (!mud && _saidMud && _message != null && _message!.contains('mud')) {
      _message = null;
    }
    if (!mud && (_message == 'Splash!')) _message = null;

    // Darkness.
    final dark = _darkAt(_truckCentre);
    if (dark && !_lights && _speed > 0 && !_saidDark) {
      _saidDark = true;
      _wantLights = true;
      Voice.instance.say("It's too dark to see the stars! Turn on your headlights.");
    }
    if (_lights) _wantLights = false;

    // Stars.
    for (var i = 0; i < _Course.stars.length; i++) {
      if (_collected.contains(i)) continue;
      final sx = _Course.stars[i].$1;
      if (sx < _x + _truckW * 0.1 || sx > _x + _truckW * 0.95) continue;
      if (_darkAt(sx) && !_lights) continue;
      _collected.add(i);
      _collectedCount++;
      s.addStars(1);
      Sfx.tap();
      _pops.add((Offset(_truckLeft + (sx - _x), _laneY - _truckW * 0.5), _time));
    }
    _pops.removeWhere((p) => _time - p.$2 > 0.8);

    // Breakdown, once per drive.
    if (!_brokeOnce && _x > _Course.breakdownAt) {
      _brokeOnce = true;
      _broken = Breakdown.values[math.Random().nextInt(Breakdown.values.length)];
      _speed = 0;
      _message = 'Uh oh!';
      Sfx.bump();
      Voice.instance.say("Uh oh! The truck broke down. Tap the toolbox and let's fix it!");
    }

    // Finish.
    if (!_finished && _x > _Course.length) {
      _finished = true;
      _speed = 0;
      _message = 'You made it!';
      _burst++;
      s.setDirty(true);
      s.addStars(3);
      Voice.instance.say(
          'You made it! You found $_collectedCount stars. Now your truck is muddy. Time for a wash!');
    }

    setState(() {});
  }

  double get _laneY => RoadLayout.lane(_size);

  void _horn() {
    _hornUntil = _time + 0.7;
    Sfx.bump();
    Voice.instance.say('Beep beep!');
  }

  Future<void> _fix() async {
    final b = _broken;
    if (b == null) return;
    final fixed = await Navigator.of(context)
        .push<bool>(MaterialPageRoute(builder: (_) => FixScreen(problem: b)));
    if (!mounted) return;
    if (fixed == true) {
      setState(() {
        _broken = null;
        _message = null;
      });
      Voice.instance.say('All fixed! Off we go!');
    }
  }

  void _restart() {
    setState(() {
      _x = 0;
      _speed = 0;
      _collected.clear();
      _collectedCount = 0;
      _brokeOnce = false;
      _finished = false;
      _broken = null;
      _message = null;
      _saidMud = false;
      _saidDark = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = GameScope.of(context);
    return Scaffold(
      body: LayoutBuilder(builder: (context, c) {
        _size = Size(c.maxWidth, c.maxHeight);
        final look = lookFrom(s,
            built: allParts,
            wheelTurn: _wheelTurn,
            lightsOn: _lights,
            breakdown: _broken);
        return Stack(children: [
          Positioned.fill(
            child: Listener(
              onPointerDown: (_) => _holding = true,
              onPointerUp: (_) => _holding = false,
              onPointerCancel: (_) => _holding = false,
              child: CustomPaint(
                painter: _DrivePainter(
                  x: _x,
                  time: _time,
                  speed: _speed,
                  night: _night,
                  lights: _lights,
                  hornOn: _time < _hornUntil,
                  look: look,
                  collected: _collected,
                  pops: _pops,
                  scale: _scale,
                  truckLeft: _truckLeft,
                  broken: _broken != null,
                ),
              ),
            ),
          ),

          // Message banner.
          Positioned(
            top: 14,
            left: 0,
            right: 0,
            child: Center(child: PartBanner(title: _message)),
          ),
          const Positioned(left: 20, top: 20, child: BackBubble()),
          const Positioned(right: 20, top: 20, child: StarCounter()),

          // Truck controls.
          Positioned(
            left: 20,
            bottom: 18,
            child: Row(children: [
              IconBubble(Icons.campaign_rounded,
                  color: const Color(0xFFFF8C42), onTap: _horn),
              const SizedBox(width: 14),
              IconBubble(
                  _lights ? Icons.highlight_rounded : Icons.highlight_off_rounded,
                  color: const Color(0xFFFFB703),
                  glow: _wantLights,
                  onTap: () {
                    setState(() => _lights = !_lights);
                    if (_lights) Voice.instance.say('Headlights on!');
                  }),
              const SizedBox(width: 14),
              IconBubble(_night ? Icons.wb_sunny_rounded : Icons.nightlight_round,
                  color: const Color(0xFF4C6EF5),
                  onTap: () => setState(() {
                        _night = !_night;
                        _saidDark = false;
                      })),
            ]),
          ),

          // Go pedal: press and hold.
          if (!_finished && _broken == null)
            Positioned(
              right: 24,
              bottom: 18,
              // Ignores the pointer so the press falls through to the
              // full-screen Listener, which handles press-and-hold.
              child: IgnorePointer(
                child: IconBubble(Icons.speed_rounded,
                    size: 112,
                    color: const Color(0xFF2DC653),
                    glow: _speed == 0,
                    onTap: () {}),
              ),
            ),

          // Breakdown: open the fix-it mission.
          if (_broken != null)
            Center(
              child: IconBubble(Icons.home_repair_service_rounded,
                  size: 130, color: const Color(0xFFE63946), glow: true, onTap: _fix),
            ),

          // Finish.
          if (_finished)
            Align(
              alignment: const Alignment(0, 0.15),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                IconBubble(Icons.replay_rounded,
                    size: 90, color: const Color(0xFF2DC653), onTap: _restart),
                const SizedBox(width: 24),
                IconBubble(Icons.water_drop_rounded,
                    size: 90,
                    color: const Color(0xFF4CC9F0),
                    glow: true,
                    onTap: () => Navigator.of(context).maybePop()),
              ]),
            ),
          Positioned.fill(child: StarBurst(trigger: _burst)),
        ]);
      }),
    );
  }
}

class _DrivePainter extends CustomPainter {
  final double x, time, speed, scale, truckLeft;
  final bool night, lights, hornOn, broken;
  final VehicleLook look;
  final Set<int> collected;
  final List<(Offset, double)> pops;

  _DrivePainter({
    required this.x,
    required this.time,
    required this.speed,
    required this.night,
    required this.lights,
    required this.hornOn,
    required this.look,
    required this.collected,
    required this.pops,
    required this.scale,
    required this.truckLeft,
    required this.broken,
  });

  double sx(double worldX) => truckLeft + (worldX - x);

  @override
  void paint(Canvas c, Size size) {
    SceneryPainter(scroll: x, night: night).paint(c, size);
    final roadTop = RoadLayout.top(size);
    final roadH = RoadLayout.height(size);
    final lane = RoadLayout.lane(size);
    final truckW = kVehicleW * scale;
    final truckCentre = x + truckW * 0.55;

    // Mud patches.
    for (final m in _Course.mud) {
      final a = sx(m.$1), b = sx(m.$2);
      if (b < 0 || a > size.width) continue;
      final mud = Paint()..color = const Color(0xFF7A5230);
      c.drawRRect(
          RRect.fromLTRBR(a, lane + roadH * 0.02, b, lane + roadH * 0.3,
              Radius.circular(roadH * 0.14)),
          mud);
      for (var i = 0; i < (b - a) / 60; i++) {
        c.drawCircle(Offset(a + 30 + i * 60, lane + roadH * 0.06), 10,
            Paint()..color = const Color(0xFF5E3D22));
      }
    }

    // Bumps.
    for (final bx in _Course.bumps) {
      final p = sx(bx);
      if (p < -150 || p > size.width + 150) continue;
      c.drawArc(Rect.fromCenter(center: Offset(p, lane + 20), width: 180, height: 46),
          math.pi, math.pi, true, Paint()..color = const Color(0xFF6B6880));
    }

    // Finish flag.
    final fx = sx(_Course.length + truckW);
    if (fx > -40 && fx < size.width + 40) {
      c.drawLine(Offset(fx, roadTop - size.height * 0.3), Offset(fx, roadTop),
          Paint()
            ..color = kInk
            ..strokeWidth = 6);
      const n = 4;
      final cell = size.height * 0.03;
      for (var i = 0; i < n; i++) {
        for (var j = 0; j < 3; j++) {
          c.drawRect(
              Rect.fromLTWH(fx + i * cell, roadTop - size.height * 0.3 + j * cell, cell, cell),
              Paint()..color = (i + j).isEven ? Colors.white : kInk);
        }
      }
    }

    // Tunnel darkness.
    final ta = sx(_Course.tunnel.$1), tb = sx(_Course.tunnel.$2);
    if (tb > 0 && ta < size.width) {
      c.drawRect(Rect.fromLTRB(ta, 0, tb, size.height),
          Paint()..color = fade(const Color(0xFF0B0D2A), 0.82));
      final stone = Paint()
        ..color = const Color(0xFF8D6E63)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 18;
      for (final edge in [ta, tb]) {
        c.drawLine(Offset(edge, size.height * 0.08), Offset(edge, roadTop + roadH), stone);
      }
      c.drawLine(Offset(ta, size.height * 0.08), Offset(tb, size.height * 0.08), stone);
    }

    // Stars (hidden in the dark unless the headlights are on).
    for (var i = 0; i < _Course.stars.length; i++) {
      if (collected.contains(i)) continue;
      final (wx, hFrac) = _Course.stars[i];
      final p = sx(wx);
      if (p < -40 || p > size.width + 40) continue;
      final dark = night || _Course.inTunnel(wx);
      if (dark && !lights) continue;
      final y = lane - truckW * (0.25 + 0.25 * hFrac) + math.sin(time * 3 + i) * 6;
      final star = starPath(Offset(p, y), 22);
      c.drawPath(
          star,
          Paint()
            ..color = fade(const Color(0xFFFFE066), 0.6)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8));
      c.drawPath(star, Paint()..color = const Color(0xFFFFD23F));
      c.drawPath(
          star,
          Paint()
            ..color = const Color(0xFFE09F00)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2);
    }

    // Truck.
    var bump = 0.0;
    for (final bx in _Course.bumps) {
      final d = (truckCentre - bx).abs();
      if (d < 120) bump = math.max(bump, 20 * math.cos(d / 120 * math.pi / 2));
    }
    final bob = speed > 0 ? math.sin(time * 18) * 1.5 : 0.0;
    final r = TruckGeo.wheelRadius(look.wheels);
    final top = lane - (TruckGeo.rearWheel.dy + r) * scale - bump + bob;
    c.save();
    c.translate(truckLeft, top);
    c.scale(scale);
    if (speed > 0 || broken) {
      paintPuffs(c, TruckGeo.exhaustTop, time * (broken ? 1.0 : 2.5));
    }
    paintVehicle(c, look);
    if (hornOn) {
      final tp = TextPainter(
        text: const TextSpan(
            text: 'BEEP!',
            style: TextStyle(
                fontSize: 34, fontWeight: FontWeight.w900, color: Color(0xFFFF8C42))),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(c, const Offset(330, 10));
    }
    c.restore();

    // Headlight beam.
    if (lights && look.breakdown != Breakdown.brokenLight) {
      final h = Offset(truckLeft, top) + TruckGeo.headlight * scale;
      final beam = Path()
        ..moveTo(h.dx, h.dy - 6)
        ..lineTo(h.dx + size.width * 0.45, h.dy - size.height * 0.16)
        ..lineTo(h.dx + size.width * 0.45, h.dy + size.height * 0.12)
        ..lineTo(h.dx, h.dy + 6)
        ..close();
      c.drawPath(
          beam,
          Paint()
            ..shader = LinearGradient(colors: [
              fade(const Color(0xFFFFF3B0), 0.55),
              fade(const Color(0xFFFFF3B0), 0.0),
            ]).createShader(Rect.fromLTWH(h.dx, h.dy - 100, size.width * 0.45, 200)));
    }

    // Mud splash for monster tyres.
    if (_Course.inMud(truckCentre) && speed > 50 && look.wheels == WheelStyle.monster) {
      final rnd = math.Random((time * 20).floor());
      for (var i = 0; i < 10; i++) {
        final wheel = Offset(truckLeft, top) +
            (i.isEven ? TruckGeo.rearWheel : TruckGeo.frontWheel) * scale;
        c.drawCircle(
            wheel + Offset(-rnd.nextDouble() * 60, -rnd.nextDouble() * 50),
            3 + rnd.nextDouble() * 5,
            Paint()..color = const Color(0xFF7A5230));
      }
    }

    // Collected star pops.
    for (final (pos, t0) in pops) {
      final p = ((time - t0) / 0.8).clamp(0.0, 1.0);
      c.drawPath(starPath(pos + Offset(0, -p * 80), 22 + p * 14),
          Paint()..color = fade(const Color(0xFFFFD23F), 1 - p));
    }
  }

  @override
  bool shouldRepaint(covariant _DrivePainter old) => true;
}
