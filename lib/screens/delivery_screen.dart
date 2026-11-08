import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../art/scenery.dart';
import '../art/town_art.dart';
import '../art/truck_art.dart';
import '../data/missions.dart';
import '../services/voice.dart';
import '../state/game_state.dart';
import '../widgets/ui.dart';
import 'mission_flow.dart';

const _numberWords = [
  'zero', 'one', 'two', 'three', 'four', 'five', 'six', 'seven', 'eight', 'nine', 'ten', 'eleven', 'twelve'
];
const _residents = [granny, bramble, ella, kit, mayor, baker];

class _House {
  final double x; // door position in world pixels
  final int number;
  final Townsperson who;
  bool delivered = false;
  _House(this.x, this.number, this.who);
}

/// Delivery runs that put learning into practice while driving.
/// Post round: stop at the house whose number matches the parcel.
/// Fragile load: slow down for bumps or an egg cracks.
class DeliveryScreen extends StatefulWidget {
  final Mission mission;
  const DeliveryScreen({super.key, required this.mission});

  @override
  State<DeliveryScreen> createState() => _DeliveryScreenState();
}

class _DeliveryScreenState extends State<DeliveryScreen> with SingleTickerProviderStateMixin {
  late final Ticker _ticker = createTicker(_tick);
  Duration _last = Duration.zero;
  Size _size = Size.zero;

  double _x = 0;
  double _speed = 0;
  int _dir = 0; // 1 forward, -1 reverse, 0 coasting
  double _time = 0;
  double _wheelTurn = 0;
  double _bumpLift = 0;
  String? _message;
  double _messageUntil = 0;
  int _burst = 0;
  bool _finished = false;

  bool get _fragile => widget.mission.delivery?.fragile ?? false;

  // Post round.
  final List<_House> _houses = [];
  final List<int> _parcels = [];
  int _parcel = 0;
  _House? _checked;
  double _stoppedFor = 0;
  final List<(Offset, double)> _flying = [];

  // Fragile load.
  static const _eggTotal = 6;
  int _eggs = _eggTotal;
  final List<double> _bumps = [];
  final Set<int> _bumpsDone = {};
  double _fragileEnd = 0;

  double get _unit => _size.height / 390; // world pixels scale with screen height
  double get _vanH => _size.height * 0.28;
  double get _vanW => _vanH * kSimpleW / kSimpleH;
  double get _vanLeft => _size.width * 0.14;
  double get _vanCentre => _x + _vanW * 0.5;
  double get _maxForward => 420 * _unit;
  double get _maxReverse => 220 * _unit;
  double get _gentle => 170 * _unit;

  @override
  void initState() {
    super.initState();
    _ticker.start();
    WidgetsBinding.instance.addPostFrameCallback((_) => _setUp());
  }

  void _setUp() {
    if (!mounted) return;
    final band = GameScope.read(context).ageBand;
    final rnd = math.Random();
    final u = _unit;
    if (_fragile) {
      _bumps.addAll([1300 * u, 2600 * u, 3900 * u]);
      _fragileEnd = 5000 * u;
      Voice.instance.say(
          'These eggs are fragile. That means they break easily! When you see the slow sign, drive slowly over the bump.');
    } else {
      final numbers = switch (band) {
        AgeBand.little => [1, 2, 3],
        AgeBand.middle => [1, 2, 3, 4, 5],
        AgeBand.big => [2, 4, 6, 8, 10, 12],
      };
      for (var i = 0; i < numbers.length; i++) {
        _houses.add(_House((900 + i * 640) * u, numbers[i], _residents[i % _residents.length]));
      }
      final pick = [...numbers]..shuffle(rnd);
      _parcels.addAll(pick.take(band == AgeBand.little ? 2 : 3));
      if (band == AgeBand.little) _parcels.sort();
      Voice.instance.say(
          'Your first parcel is for number ${_numberWords[_parcels.first]}. Drive to house number ${_numberWords[_parcels.first]} and stop outside.');
    }
    setState(() {});
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  void _say(String text, String banner, {double seconds = 3}) {
    Voice.instance.say(text);
    _message = banner;
    _messageUntil = _time + seconds;
  }

  void _tick(Duration elapsed) {
    final dt = ((elapsed - _last).inMicroseconds / 1e6).clamp(0.0, 0.05);
    _last = elapsed;
    if (_size == Size.zero || !mounted) return;
    _time += dt;

    final target = _finished ? 0.0 : (_dir > 0 ? _maxForward : (_dir < 0 ? -_maxReverse : 0.0));
    final accel = 520 * _unit * dt;
    if (_speed < target) {
      _speed = math.min(target, _speed + (target == 0 ? 2 * accel : accel));
    } else if (_speed > target) {
      _speed = math.max(target, _speed - (target == 0 ? 2 * accel : accel));
    }
    _x = math.max(0, _x + _speed * dt);
    if (_x == 0 && _speed < 0) _speed = 0;
    _wheelTurn += _speed * dt / (22 * _vanH / kSimpleH);
    _bumpLift = math.max(0, _bumpLift - dt * 60);

    if (_fragile) {
      _tickFragile();
    } else {
      _tickPost(dt);
    }
    _flying.removeWhere((f) => _time - f.$2 > 1.0);
    if (_message != null && _time > _messageUntil) _message = null;
    setState(() {});
  }

  void _tickPost(double dt) {
    if (_finished || _parcel >= _parcels.length) return;
    _House? near;
    for (final h in _houses) {
      if ((h.x - _vanCentre).abs() < 130 * _unit) near = h;
    }
    if (near == null || _speed.abs() > 1) {
      _stoppedFor = 0;
      if (near == null) _checked = null;
      return;
    }
    _stoppedFor += dt;
    if (_stoppedFor < 0.35 || identical(near, _checked)) return;
    _checked = near;
    final want = _parcels[_parcel];
    if (near.number == want && !near.delivered) {
      near.delivered = true;
      _parcel++;
      GameScope.read(context).addStars(1);
      Sfx.snap();
      _flying.add((Offset(_vanLeft + _vanW * 0.5, RoadLayout.lane(_size) - _vanH * 0.7), _time));
      if (_parcel >= _parcels.length) {
        _say('Number ${_numberWords[want]}, delivered! That\'s every parcel. Great driving!', 'All delivered!');
        _finish();
      } else {
        final next = _parcels[_parcel];
        final dirWord = next > want ? 'further along the street' : 'back the way you came';
        _say(
            'Delivered to number ${_numberWords[want]}! Thank you! Next parcel is for number ${_numberWords[next]}. That\'s $dirWord.',
            'Delivered!',
            seconds: 4);
      }
    } else {
      final hint = want > near.number
          ? '${_numberWords[want]} is bigger than ${_numberWords[near.number]}, so keep going!'
          : '${_numberWords[want]} is smaller than ${_numberWords[near.number]}, so go back!';
      _say('This is number ${_numberWords[near.number]}. Your parcel says ${_numberWords[want]}. $hint',
          'This is number ${near.number}',
          seconds: 4);
    }
  }

  void _tickFragile() {
    if (_finished) return;
    for (var i = 0; i < _bumps.length; i++) {
      if (_bumpsDone.contains(i)) continue;
      if (_vanCentre < _bumps[i]) continue;
      _bumpsDone.add(i);
      if (_speed > _gentle) {
        _bumpLift = 26;
        Sfx.bump();
        if (_eggs > 1) _eggs--;
        _say('Oh no, too fast over the bump! An egg cracked. Fragile things need gentle driving.', 'Crack!');
      } else {
        _bumpLift = 6;
        GameScope.read(context).addStars(1);
        _say('Nice and gentle! The eggs are safe.', 'Nice and gentle!');
      }
    }
    if (_vanCentre > _fragileEnd && _speed.abs() < 1) {
      _say(
          'You delivered ${_numberWords[_eggs]} eggs to the bakery! ${_eggs == _eggTotal ? 'Not one cracked. Amazing gentle driving!' : 'Next time, go slowly over every bump.'}',
          'Eggs delivered!',
          seconds: 6);
      _finish();
    }
  }

  void _finish() {
    _finished = true;
    _burst++;
    Future<void>.delayed(const Duration(milliseconds: 4200), () {
      if (mounted) finishMission(context, widget.mission);
    });
  }

  Widget _pedal(IconData icon, Color color, int dir, double size) => Listener(
        onPointerDown: (_) => _dir = dir,
        onPointerUp: (_) => _dir = 0,
        onPointerCancel: (_) => _dir = 0,
        child: IgnorePointer(
          child: IconBubble(icon, size: size, color: color, glow: _dir == dir, onTap: () {}),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LayoutBuilder(builder: (context, c) {
        _size = Size(c.maxWidth, c.maxHeight);
        final children = <Widget>[
          Positioned.fill(
            child: CustomPaint(
              painter: _DeliveryPainter(
                x: _x,
                time: _time,
                vanLeft: _vanLeft,
                vanW: _vanW,
                vanH: _vanH,
                wheelTurn: _wheelTurn,
                lift: _bumpLift,
                houses: _houses,
                bumps: _bumps,
                bakeryAt: _fragile ? _fragileEnd : null,
                flying: _flying,
                unit: _unit,
              ),
            ),
          ),
          Positioned(top: 14, left: 0, right: 0, child: Center(child: PartBanner(title: _message))),
          const Positioned(left: 20, top: 20, child: BackBubble()),
          const Positioned(right: 20, top: 20, child: StarCounter()),
        ];

        // What's in the van.
        if (!_fragile && _parcels.isNotEmpty) {
          children.add(Positioned(
            left: 96,
            top: 86,
            child: Row(children: [
              for (var i = 0; i < _parcels.length; i++)
                Container(
                  margin: const EdgeInsets.only(right: 8),
                  width: i == _parcel ? 74 : 54,
                  height: i == _parcel ? 74 : 54,
                  decoration: BoxDecoration(
                    color: i < _parcel ? const Color(0xFFCED4DA) : const Color(0xFFC9A66B),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: i == _parcel ? const Color(0xFFFFD23F) : kInk, width: i == _parcel ? 5 : 2),
                  ),
                  alignment: Alignment.center,
                  child: i < _parcel
                      ? const Icon(Icons.check_rounded, size: 34, color: Color(0xFF2DC653))
                      : Text('${_parcels[i]}',
                          style: TextStyle(
                              fontSize: i == _parcel ? 38 : 26, fontWeight: FontWeight.w900, color: kInk)),
                ),
            ]),
          ));
        }
        if (_fragile) {
          children.add(Positioned(
            left: 96,
            top: 86,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFC9A66B),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: kInk, width: 2),
              ),
              child: Row(children: [
                for (var i = 0; i < _eggTotal; i++)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: Icon(i < _eggs ? Icons.egg_rounded : Icons.heart_broken_rounded,
                        size: 30, color: i < _eggs ? const Color(0xFFFFF8E1) : const Color(0xFFFFB703)),
                  ),
              ]),
            ),
          ));
          // Speedometer: green is gentle, red is too fast for bumps.
          children.add(Positioned(
            right: 24,
            top: 86,
            width: 120,
            height: 72,
            child: CustomPaint(painter: _SpeedoPainter(_speed / _maxForward, _gentle / _maxForward)),
          ));
        }

        // Pedals: reverse on the left, go on the right.
        if (!_finished) {
          children.add(Positioned(
              left: 20, bottom: 18, child: _pedal(Icons.fast_rewind_rounded, const Color(0xFF4C6EF5), -1, 84)));
          children.add(Positioned(
              right: 24, bottom: 18, child: _pedal(Icons.speed_rounded, const Color(0xFF2DC653), 1, 112)));
        }
        children.add(Positioned.fill(child: StarBurst(trigger: _burst)));
        return Stack(children: children);
      }),
    );
  }
}

class _DeliveryPainter extends CustomPainter {
  final double x, time, vanLeft, vanW, vanH, wheelTurn, lift, unit;
  final List<_House> houses;
  final List<double> bumps;
  final double? bakeryAt;
  final List<(Offset, double)> flying;

  _DeliveryPainter({
    required this.x,
    required this.time,
    required this.vanLeft,
    required this.vanW,
    required this.vanH,
    required this.wheelTurn,
    required this.lift,
    required this.houses,
    required this.bumps,
    required this.bakeryAt,
    required this.flying,
    required this.unit,
  });

  double sx(double wx) => vanLeft + (wx - x);

  @override
  void paint(Canvas c, Size size) {
    SceneryPainter(scroll: x).paint(c, size);
    final roadTop = RoadLayout.top(size);
    final lane = RoadLayout.lane(size);
    final hh = size.height * 0.3;

    // Houses with big door numbers.
    for (final h in houses) {
      final p = sx(h.x);
      if (p < -hh || p > size.width + hh) continue;
      _house(c, Offset(p, roadTop - 4), hh, '${h.number}', h.delivered);
      if (h.delivered) {
        c.save();
        c.translate(p + hh * 0.45, roadTop - 6);
        paintFigure(c, h.who, Offset.zero, hh * 0.55, mood: 1);
        c.restore();
      }
    }

    // The bakery at the end of the egg run.
    final b = bakeryAt;
    if (b != null) {
      final p = sx(b);
      if (p > -hh && p < size.width + hh) {
        _house(c, Offset(p, roadTop - 4), hh * 1.1, 'BAKERY', false, wall: const Color(0xFFFFE5EC));
      }
    }

    // Bumps, each with a slow sign before it.
    for (final bx in bumps) {
      final p = sx(bx);
      if (p < -300 || p > size.width + 300) continue;
      c.drawArc(Rect.fromCenter(center: Offset(p, lane + 14), width: 150 * unit, height: 40 * unit),
          math.pi, math.pi, true, Paint()..color = const Color(0xFF6B6880));
      final sp = p - 260 * unit;
      c.drawLine(Offset(sp, roadTop), Offset(sp, roadTop - size.height * 0.2),
          Paint()
            ..color = kInk
            ..strokeWidth = 4);
      final sign = Offset(sp, roadTop - size.height * 0.2 - 22);
      c.drawCircle(sign, 26, Paint()..color = Colors.white);
      c.drawCircle(
          sign,
          26,
          Paint()
            ..color = const Color(0xFFE63946)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 6);
      final tp = TextPainter(
        text: const TextSpan(
            text: 'SLOW', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: kInk)),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(c, sign - Offset(tp.width / 2, tp.height / 2));
    }

    // The van.
    final top = lane - vanH * 0.92 - lift;
    c.save();
    c.translate(vanLeft, top);
    c.scale(vanW / kSimpleW);
    paintSimpleVehicle(c, CarLook(type: VehicleType.postVan, wheelTurn: wheelTurn, t: time));
    c.restore();

    // Parcels flying to the door.
    for (final (from, t0) in flying) {
      final p = ((time - t0) / 1.0).clamp(0.0, 1.0);
      final pos = from + Offset(p * vanW * 0.3, -math.sin(p * math.pi) * 80 - p * 40);
      final r = Rect.fromCenter(center: pos, width: 34, height: 28);
      c.drawRect(r, Paint()..color = fade(const Color(0xFFC9A66B), 1 - p * 0.5));
      c.drawRect(
          r,
          Paint()
            ..color = kInk
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2);
    }
  }

  void _house(Canvas c, Offset base, double h, String label, bool done,
      {Color wall = const Color(0xFFFFF8E1)}) {
    final w = h * 0.9;
    final r = Rect.fromLTWH(base.dx - w / 2, base.dy - h * 0.75, w, h * 0.75);
    final ink = Paint()
      ..color = kInk
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;
    c.drawRect(r, Paint()..color = wall);
    c.drawRect(r, ink);
    final roof = Path()
      ..moveTo(r.left - 10, r.top)
      ..lineTo(base.dx, r.top - h * 0.3)
      ..lineTo(r.right + 10, r.top)
      ..close();
    c.drawPath(roof, Paint()..color = const Color(0xFFB5524B));
    c.drawPath(roof, ink);
    final door = RRect.fromLTRBR(base.dx - w * 0.14, base.dy - h * 0.38, base.dx + w * 0.14, base.dy,
        const Radius.circular(5));
    c.drawRRect(door, Paint()..color = const Color(0xFF3A86FF));
    c.drawRRect(door, ink);
    // Number plaque above the door, big enough to read at a glance.
    final plaque = RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(base.dx, r.top + h * 0.17), width: label.length > 2 ? w * 0.8 : w * 0.42, height: h * 0.24),
        const Radius.circular(8));
    c.drawRRect(plaque, Paint()..color = done ? const Color(0xFFB7E4C7) : Colors.white);
    c.drawRRect(plaque, ink);
    final tp = TextPainter(
      text: TextSpan(
          text: label,
          style: TextStyle(fontSize: label.length > 2 ? h * 0.13 : h * 0.19, fontWeight: FontWeight.w900, color: kInk)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(c, plaque.center - Offset(tp.width / 2, tp.height / 2));
  }

  @override
  bool shouldRepaint(covariant _DeliveryPainter old) => true;
}

class _SpeedoPainter extends CustomPainter {
  final double speed; // 0..1
  final double gentle; // 0..1
  _SpeedoPainter(this.speed, this.gentle);

  @override
  void paint(Canvas c, Size s) {
    final ctr = Offset(s.width / 2, s.height - 6);
    final r = s.width * 0.45;
    final rect = Rect.fromCircle(center: ctr, radius: r);
    c.drawArc(rect, math.pi, math.pi, true, Paint()..color = Colors.white);
    c.drawArc(rect.deflate(8), math.pi, math.pi * gentle, false,
        Paint()
          ..color = const Color(0xFF2DC653)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 12);
    c.drawArc(rect.deflate(8), math.pi + math.pi * gentle, math.pi * (1 - gentle), false,
        Paint()
          ..color = const Color(0xFFE63946)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 12);
    c.drawArc(
        rect,
        math.pi,
        math.pi,
        true,
        Paint()
          ..color = kInk
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3);
    final a = math.pi + speed.clamp(0.0, 1.0) * math.pi;
    c.drawLine(ctr, ctr + Offset(math.cos(a), math.sin(a)) * r * 0.85,
        Paint()
          ..color = kInk
          ..strokeWidth = 4
          ..strokeCap = StrokeCap.round);
    c.drawCircle(ctr, 6, Paint()..color = kInk);
  }

  @override
  bool shouldRepaint(covariant _SpeedoPainter old) => old.speed != speed;
}
