import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../art/scenery.dart';
import '../art/town_art.dart';
import '../art/truck_art.dart';
import '../data/missions.dart';
import '../data/models.dart';
import '../services/voice.dart';
import '../state/game_state.dart';
import '../widgets/ui.dart';
import 'fix_screen.dart';

/// Driving along a road. The road reacts to what the child built and does:
/// small wheels stick in mud, stars hide in the dark without headlights,
/// red lights and crossings mean stop, and a tall crane won't fit under a
/// low bridge. Every hazard has a fix the child can work out.
class DriveScreen extends StatefulWidget {
  final DriveCourse? course;

  /// Mission mode: called once the finish line is reached.
  final VoidCallback? onFinished;

  const DriveScreen({super.key, this.course, this.onFinished});

  @override
  State<DriveScreen> createState() => _DriveScreenState();
}

class _Light {
  double? triggered; // time the light turned red
  double? stoppedAt; // time the truck stopped at the line
  bool green = true;
  bool done = false;
}

class _Crossing {
  double? started; // time the walker stepped out
  bool done = false;
  bool waited = false;
}

class _DriveScreenState extends State<DriveScreen>
    with SingleTickerProviderStateMixin {
  late final DriveCourse _course = widget.course ?? DriveCourse.free;
  late final Ticker _ticker = createTicker(_tick);
  Duration _last = Duration.zero;

  double _x = 0;
  double _speed = 0;
  double _time = 0;
  double _wheelTurn = 0;
  bool _holding = false;
  bool _lights = false;
  late bool _night = _course.night;
  double _hornUntil = 0;

  Breakdown? _broken;
  bool _brokeOnce = false;
  bool _finished = false;
  String? _message;
  double _messageUntil = 0;
  int _burst = 0;
  int _collectedCount = 0;

  final Set<int> _collected = {};
  final List<(Offset, double)> _pops = [];

  late final List<_Light> _lightState =
      List.generate(_course.trafficLights.length, (_) => _Light());
  late final List<_Crossing> _crossState =
      List.generate(_course.zebras.length, (_) => _Crossing());

  bool _saidMud = false;
  bool _saidDark = false;
  bool _wantLights = false;
  bool _stuck = false;
  bool _bridgeBlocked = false;
  bool _saidBridge = false;
  bool _saidRed = false;

  Size _size = Size.zero;

  static const double _walkSeconds = 4.0;

  @override
  void initState() {
    super.initState();
    _ticker.start();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Voice.instance.say(_night
          ? 'It\'s night time! Press and hold to drive. What will help you see?'
          : 'Press and hold to drive. Collect the stars!');
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
  double get _front => _x + 376 * _scale;
  double get _craneTipX => _x + TruckGeo.craneTip(0).dx * _scale;

  bool _darkAt(double worldX) => _night || _course.inTunnel(worldX);

  void _say(String text, {String? banner, double seconds = 3}) {
    Voice.instance.say(text);
    if (banner != null) {
      _message = banner;
      _messageUntil = _time + seconds;
    }
  }

  /// Stops the truck so that [point] (a world x on the truck) stays behind
  /// [line]. Returns true when it had to stop.
  bool _clamp(double point, double line, double step) {
    if (point <= line + 1 && point + step > line) {
      _x += line - point;
      _speed = 0;
      return true;
    }
    return false;
  }

  void _tick(Duration elapsed) {
    final dt = ((elapsed - _last).inMicroseconds / 1e6).clamp(0.0, 0.05);
    _last = elapsed;
    if (_size == Size.zero || !mounted) return;
    _time += dt;
    final s = GameScope.read(context);

    final canDrive = _broken == null && !_finished;
    final mud = _course.inMud(_truckCentre);
    final monster = s.wheels == WheelStyle.monster;
    final maxSpeed = mud && !monster ? 70.0 : 440.0;

    if (_holding && canDrive) {
      _speed = math.min(maxSpeed, _speed + 520 * dt);
    } else {
      _speed = math.max(0, _speed - 640 * dt);
    }
    if (_speed > maxSpeed) _speed = math.max(maxSpeed, _speed - 900 * dt);
    var step = _speed * dt;

    // --- Traffic lights: red means stop. ---------------------------------
    for (var i = 0; i < _course.trafficLights.length; i++) {
      final line = _course.trafficLights[i];
      final l = _lightState[i];
      if (l.done) continue;
      if (l.triggered == null && _front > line - 900) {
        l.triggered = _time;
        l.green = false;
        _say('Look, a traffic light! It\'s red.', banner: 'Red light');
      }
      if (!l.green) {
        if (_clamp(_front, line - 6, step)) {
          step = 0;
          if (_holding && !_saidRed) {
            _saidRed = true;
            _say('Red means stop! We wait for green.', banner: 'Red means stop');
          }
        }
        if (_speed == 0 && (line - _front).abs() < 120) l.stoppedAt ??= _time;
        final t0 = l.triggered!;
        final st = l.stoppedAt;
        if (st != null && _time - t0 > 3.5 && _time - st > 1.8) {
          l.green = true;
          l.done = true;
          s.addStars(1);
          _say('Green means go! Well waited. Here\'s a star!', banner: 'Green means go');
        }
      }
    }

    // --- Zebra crossings: stop for people crossing. -----------------------
    for (var i = 0; i < _course.zebras.length; i++) {
      final z = _course.zebras[i];
      final c = _crossState[i];
      if (c.done) continue;
      if (c.started == null && _front > z - 450) {
        c.started = _time;
        _say('Look! Someone is crossing the road. Stop and wait.', banner: 'Stop!');
      }
      final st = c.started;
      if (st != null) {
        final p = (_time - st) / _walkSeconds;
        if (p < 1) {
          if (_clamp(_front, z - 10, step)) {
            step = 0;
            c.waited = true;
          }
        } else {
          c.done = true;
          if (c.waited) {
            s.addStars(1);
            _say('Thank you for waiting! Safe driving gets a star.', banner: 'Safe driving!');
          }
        }
      }
    }

    // --- Low bridges: a raised crane won't fit. ----------------------------
    _bridgeBlocked = false;
    if (!s.craneDown) {
      for (final b in _course.lowBridges) {
        if (_clamp(_craneTipX, b - 46, step)) {
          step = 0;
          _bridgeBlocked = true;
          if (!_saidBridge) {
            _saidBridge = true;
            _say('Stop! The crane is too tall to fit under the bridge. How can we make the truck shorter?',
                banner: 'Too tall!', seconds: 5);
          }
        }
      }
    }

    _x += step;

    // --- Mud: small wheels slip. -------------------------------------------
    final r = TruckGeo.wheelRadius(s.wheels) * _scale;
    final slip = mud && !monster && _holding && canDrive;
    _stuck = mud && !monster;
    _wheelTurn += (slip ? 380 : _speed) * dt / r;

    if (mud && _holding && !_saidMud) {
      _saidMud = true;
      _say(
          monster
              ? 'Splash! Big monster tyres grip the mud.'
              : 'Oh no, the wheels are spinning in the mud! What tyres would grip better?',
          banner: monster ? 'Splash!' : 'Stuck in the mud!');
    }
    if (!mud) _saidMud = false;

    // --- Darkness. ---------------------------------------------------------
    final dark = _darkAt(_truckCentre);
    if (dark && !_lights && _speed > 0 && !_saidDark) {
      _saidDark = true;
      _wantLights = true;
      _say("It's too dark to see the stars! What could help us see?", banner: 'Too dark!');
    }
    if (_lights) _wantLights = false;

    // --- Stars. --------------------------------------------------------------
    for (var i = 0; i < _course.stars.length; i++) {
      if (_collected.contains(i)) continue;
      final sx = _course.stars[i].$1;
      if (sx < _x + _truckW * 0.1 || sx > _x + _truckW * 0.95) continue;
      if (_darkAt(sx) && !_lights) continue;
      _collected.add(i);
      _collectedCount++;
      s.addStars(1);
      Sfx.tap();
      _pops.add((Offset(_truckLeft + (sx - _x), _laneY - _truckW * 0.5), _time));
    }
    _pops.removeWhere((p) => _time - p.$2 > 0.8);

    // --- Breakdown, once per drive. ------------------------------------------
    final bAt = _course.breakdownAt;
    if (bAt != null && !_brokeOnce && _x > bAt) {
      _brokeOnce = true;
      _broken = Breakdown.values[math.Random().nextInt(Breakdown.values.length)];
      _speed = 0;
      _message = 'Uh oh!';
      _messageUntil = _time + 999;
      Sfx.bump();
      Voice.instance.say("Uh oh! The truck broke down. Tap the toolbox and let's fix it!");
    }

    // --- Finish. ---------------------------------------------------------------
    if (!_finished && _x > _course.length) {
      _finished = true;
      _speed = 0;
      _message = 'You made it!';
      _messageUntil = _time + 999;
      _burst++;
      s.setDirty(true);
      final done = widget.onFinished;
      if (done != null) {
        Voice.instance.say('You made it! You found $_collectedCount stars on the way.');
        Future<void>.delayed(const Duration(milliseconds: 2400), () {
          if (mounted) done();
        });
      } else {
        s.addStars(3);
        Voice.instance.say(
            'You made it! You found $_collectedCount stars. Now your truck is muddy. Time for a wash!');
      }
    }

    if (_message != null && _time > _messageUntil) _message = null;
    setState(() {});
  }

  double get _laneY => RoadLayout.lane(_size);

  void _horn() {
    _hornUntil = _time + 0.7;
    Sfx.bump();
    Voice.instance.say('Beep beep!');
  }

  void _toggleCrane() {
    final s = GameScope.read(context);
    final underBridge =
        _course.lowBridges.any((b) => _x < b + 260 && _front > b - 40);
    if (s.craneDown && underBridge) {
      Voice.instance.say('Wait until we are out from under the bridge!');
      return;
    }
    s.setCraneDown(!s.craneDown);
    if (s.craneDown) {
      _say(
          _bridgeBlocked
              ? 'Crane down! Now the truck is short enough to fit under the bridge.'
              : 'Crane down!',
          banner: 'Crane down');
    } else {
      Voice.instance.say('Crane up!');
    }
  }

  void _monsterTyres() {
    GameScope.read(context).setWheels(WheelStyle.monster);
    _say('Monster tyres on! Big bumpy tyres grip the mud.', banner: 'Monster tyres!');
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
      _saidBridge = false;
      _saidRed = false;
      for (var i = 0; i < _lightState.length; i++) {
        _lightState[i] = _Light();
      }
      for (var i = 0; i < _crossState.length; i++) {
        _crossState[i] = _Crossing();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = GameScope.of(context);
    final mission = widget.onFinished != null;
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
                  course: _course,
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
                  lightsGreen: [for (final l in _lightState) l.green],
                  walkers: [
                    for (final cr in _crossState)
                      cr.started == null
                          ? -1.0
                          : ((_time - cr.started!) / _walkSeconds).clamp(0.0, 1.0),
                  ],
                ),
              ),
            ),
          ),

          Positioned(
            top: 14,
            left: 0,
            right: 0,
            child: Center(child: PartBanner(title: _message)),
          ),
          const Positioned(left: 20, top: 20, child: BackBubble()),
          const Positioned(right: 20, top: 20, child: StarCounter()),

          // Truck controls. Buttons glow when they are the answer.
          Positioned(
            left: 20,
            bottom: 18,
            child: Row(children: [
              IconBubble(Icons.campaign_rounded,
                  size: 64, color: const Color(0xFFFF8C42), onTap: _horn),
              const SizedBox(width: 12),
              IconBubble(
                  _lights ? Icons.highlight_rounded : Icons.highlight_off_rounded,
                  size: 64,
                  color: const Color(0xFFFFB703),
                  glow: _wantLights,
                  onTap: () {
                    setState(() => _lights = !_lights);
                    Voice.instance.say(_lights ? 'Headlights on!' : 'Headlights off.');
                  }),
              if (_course.lowBridges.isNotEmpty) ...[
                const SizedBox(width: 12),
                IconBubble(
                    s.craneDown ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
                    size: 64,
                    color: const Color(0xFF7B4FD6),
                    glow: _bridgeBlocked,
                    onTap: _toggleCrane),
              ],
              if (_stuck && !_finished) ...[
                const SizedBox(width: 12),
                IconBubble(Icons.tire_repair,
                    size: 64,
                    color: const Color(0xFF9B5DE5),
                    glow: true,
                    onTap: _monsterTyres),
              ],
              if (!mission) ...[
                const SizedBox(width: 12),
                IconBubble(_night ? Icons.wb_sunny_rounded : Icons.nightlight_round,
                    size: 64,
                    color: const Color(0xFF4C6EF5),
                    onTap: () => setState(() {
                          _night = !_night;
                          _saidDark = false;
                        })),
              ],
            ]),
          ),

          // Go pedal: the press falls through to the full-screen Listener.
          if (!_finished && _broken == null)
            Positioned(
              right: 24,
              bottom: 18,
              child: IgnorePointer(
                child: IconBubble(Icons.speed_rounded,
                    size: 112,
                    color: const Color(0xFF2DC653),
                    glow: _speed == 0,
                    onTap: () {}),
              ),
            ),

          if (_broken != null)
            Center(
              child: IconBubble(Icons.home_repair_service_rounded,
                  size: 130, color: const Color(0xFFE63946), glow: true, onTap: _fix),
            ),

          if (_finished && !mission)
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
  final DriveCourse course;
  final double x, time, speed, scale, truckLeft;
  final bool night, lights, hornOn, broken;
  final VehicleLook look;
  final Set<int> collected;
  final List<(Offset, double)> pops;
  final List<bool> lightsGreen;
  final List<double> walkers;

  _DrivePainter({
    required this.course,
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
    required this.lightsGreen,
    required this.walkers,
  });

  double sx(double worldX) => truckLeft + (worldX - x);
  bool visible(double p, Size size, [double margin = 200]) =>
      p > -margin && p < size.width + margin;

  @override
  void paint(Canvas c, Size size) {
    SceneryPainter(scroll: x, night: night).paint(c, size);
    final roadTop = RoadLayout.top(size);
    final roadH = RoadLayout.height(size);
    final lane = RoadLayout.lane(size);
    final truckW = kVehicleW * scale;
    final truckCentre = x + truckW * 0.55;

    // Mud patches.
    for (final m in course.mud) {
      final a = sx(m.$1), b = sx(m.$2);
      if (b < 0 || a > size.width) continue;
      c.drawRRect(
          RRect.fromLTRBR(a, lane + roadH * 0.02, b, lane + roadH * 0.3,
              Radius.circular(roadH * 0.14)),
          Paint()..color = const Color(0xFF7A5230));
      for (var i = 0; i < (b - a) / 60; i++) {
        c.drawCircle(Offset(a + 30 + i * 60, lane + roadH * 0.06), 10,
            Paint()..color = const Color(0xFF5E3D22));
      }
    }

    // Bumps.
    for (final bx in course.bumps) {
      final p = sx(bx);
      if (!visible(p, size)) continue;
      c.drawArc(Rect.fromCenter(center: Offset(p, lane + 20), width: 180, height: 46),
          math.pi, math.pi, true, Paint()..color = const Color(0xFF6B6880));
    }

    // Zebra crossings and walkers (walkers are drawn after the truck).
    for (final z in course.zebras) {
      final p = sx(z);
      if (!visible(p, size)) continue;
      for (var i = 0; i < 6; i++) {
        c.drawRect(Rect.fromLTWH(p, roadTop + 8 + i * (roadH - 16) / 6, 90, (roadH - 16) / 12),
            Paint()..color = fade(Colors.white, night ? 0.7 : 0.95));
      }
      // Belisha beacon.
      c.drawLine(Offset(p - 14, roadTop), Offset(p - 14, roadTop - size.height * 0.2),
          Paint()
            ..color = kInk
            ..strokeWidth = 4);
      final on = (math.sin(time * 6) + 1) / 2;
      c.drawCircle(Offset(p - 14, roadTop - size.height * 0.2), 10,
          Paint()..color = Color.lerp(const Color(0xFFB35C00), const Color(0xFFFFB703), on)!);
    }

    // Traffic lights.
    for (var i = 0; i < course.trafficLights.length; i++) {
      final p = sx(course.trafficLights[i]);
      if (!visible(p, size)) continue;
      c.drawRect(Rect.fromLTWH(p - 4, roadTop + 4, 8, roadH - 8),
          Paint()..color = fade(Colors.white, 0.9));
      final poleX = p + 20;
      final h = size.height * 0.26;
      c.drawLine(Offset(poleX, roadTop), Offset(poleX, roadTop - h),
          Paint()
            ..color = kInk
            ..strokeWidth = 6);
      final box = RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset(poleX, roadTop - h - 40), width: 36, height: 92),
          const Radius.circular(8));
      c.drawRRect(box, Paint()..color = const Color(0xFF2B2D42));
      final green = lightsGreen[i];
      final lamps = [
        (const Color(0xFFE63946), !green),
        (const Color(0xFFFFB703), false),
        (const Color(0xFF2DC653), green),
      ];
      for (var j = 0; j < 3; j++) {
        final (col, onLamp) = lamps[j];
        final ctr = Offset(poleX, roadTop - h - 68 + j * 28);
        if (onLamp) {
          c.drawCircle(ctr, 18, Paint()..color = fade(col, 0.35));
        }
        c.drawCircle(ctr, 11, Paint()..color = onLamp ? col : fade(col, 0.25));
      }
    }

    // Finish flag.
    final fx = sx(course.length + truckW);
    if (visible(fx, size, 40)) {
      c.drawLine(Offset(fx, roadTop - size.height * 0.3), Offset(fx, roadTop),
          Paint()
            ..color = kInk
            ..strokeWidth = 6);
      final cell = size.height * 0.03;
      for (var i = 0; i < 4; i++) {
        for (var j = 0; j < 3; j++) {
          c.drawRect(
              Rect.fromLTWH(fx + i * cell, roadTop - size.height * 0.3 + j * cell, cell, cell),
              Paint()..color = (i + j).isEven ? Colors.white : kInk);
        }
      }
    }

    // Tunnel darkness.
    final tun = course.tunnel;
    if (tun != null) {
      final ta = sx(tun.$1), tb = sx(tun.$2);
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
    }

    // Stars (hidden in the dark unless the headlights are on).
    for (var i = 0; i < course.stars.length; i++) {
      if (collected.contains(i)) continue;
      final (wx, hFrac) = course.stars[i];
      final p = sx(wx);
      if (!visible(p, size, 40)) continue;
      final dark = night || course.inTunnel(wx);
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
    for (final bx in course.bumps) {
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
            style: TextStyle(fontSize: 34, fontWeight: FontWeight.w900, color: Color(0xFFFF8C42))),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(c, const Offset(330, 10));
    }
    c.restore();

    // Low bridges, drawn over the truck so it passes underneath.
    final underside = lane - (TruckGeo.rearWheel.dy + 30 - kLowBridgeY) * scale;
    for (final b in course.lowBridges) {
      final p = sx(b);
      final w = 220.0;
      if (!visible(p, size, 300)) continue;
      final stone = Paint()..color = const Color(0xFFB08968);
      final dark = Paint()..color = const Color(0xFF8D6E63);
      c.drawRect(Rect.fromLTRB(p - 40, underside - 60, p + w + 40, underside), stone);
      for (var i = 0; i < 9; i++) {
        c.drawRect(Rect.fromLTWH(p - 36 + i * 34.0, underside - 56 + (i % 2) * 22.0, 26, 16), dark);
      }
      c.drawRect(Rect.fromLTRB(p - 40, underside - 4, p + w + 40, underside),
          Paint()..color = const Color(0xFF6B4F3A));
      // Pillars on the far verge.
      c.drawRect(Rect.fromLTRB(p - 40, underside, p - 10, roadTop), stone);
      c.drawRect(Rect.fromLTRB(p + w + 10, underside, p + w + 40, roadTop), stone);
      // Warning sign before the bridge.
      final signX = p - 300;
      if (visible(signX, size, 60)) {
        c.drawLine(Offset(signX, roadTop), Offset(signX, roadTop - size.height * 0.18),
            Paint()
              ..color = kInk
              ..strokeWidth = 4);
        final tri = Path()
          ..moveTo(signX, roadTop - size.height * 0.18 - 52)
          ..lineTo(signX - 30, roadTop - size.height * 0.18)
          ..lineTo(signX + 30, roadTop - size.height * 0.18)
          ..close();
        c.drawPath(tri, Paint()..color = Colors.white);
        c.drawPath(
            tri,
            Paint()
              ..color = const Color(0xFFE63946)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 6);
        final arrow = Paint()
          ..color = kInk
          ..strokeWidth = 3;
        final cy = roadTop - size.height * 0.18 - 20;
        c.drawLine(Offset(signX, cy - 14), Offset(signX, cy + 10), arrow);
        c.drawLine(Offset(signX - 6, cy - 8), Offset(signX, cy - 14), arrow);
        c.drawLine(Offset(signX + 6, cy - 8), Offset(signX, cy - 14), arrow);
        c.drawLine(Offset(signX - 6, cy + 4), Offset(signX, cy + 10), arrow);
        c.drawLine(Offset(signX + 6, cy + 4), Offset(signX, cy + 10), arrow);
      }
    }

    // People on zebra crossings, walking towards the viewer.
    for (var i = 0; i < course.zebras.length; i++) {
      final w = walkers[i];
      if (w < 0 || w >= 1) continue;
      final p = sx(course.zebras[i]) + 45;
      final feetY = roadTop + 6 + w * (roadH + 10);
      final h = truckW * 0.3;
      final stepBob = math.sin(time * 14).abs() * 4;
      paintFigure(c, granny, Offset(p, feetY - stepBob), h, mood: 1, shirt: const Color(0xFF9B5DE5));
    }

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
    if (course.inMud(truckCentre) && speed > 50 && look.wheels == WheelStyle.monster) {
      final rnd = math.Random((time * 20).floor());
      for (var i = 0; i < 10; i++) {
        final wheel = Offset(truckLeft, top) +
            (i.isEven ? TruckGeo.rearWheel : TruckGeo.frontWheel) * scale;
        c.drawCircle(wheel + Offset(-rnd.nextDouble() * 60, -rnd.nextDouble() * 50),
            3 + rnd.nextDouble() * 5, Paint()..color = const Color(0xFF7A5230));
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
