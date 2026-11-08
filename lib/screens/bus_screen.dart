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

const _numberWords = ['zero', 'one', 'two', 'three', 'four', 'five', 'six', 'seven', 'eight', 'nine', 'ten'];
const _riders = [kit, ella, granny, farmer, baker, bramble];
const _shirts = [
  Color(0xFF4CC9F0),
  Color(0xFFFF6FB5),
  Color(0xFF9B5DE5),
  Color(0xFF6A994E),
  Color(0xFFFFB703),
  Color(0xFFE63946),
];

/// Helping the bus driver: tap people on and off at each stop, counting out
/// loud, then say how many are left on the bus.
class BusScreen extends StatefulWidget {
  final Mission mission;
  const BusScreen({super.key, required this.mission});

  @override
  State<BusScreen> createState() => _BusScreenState();
}

enum _Phase { off, on, driving, ask, done }

class _BusScreenState extends State<BusScreen> with TickerProviderStateMixin {
  late final AnimationController _drive = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1800));
  late final List<(int, int)> _stops; // (get off, get on) at each stop
  int _stop = 0;
  _Phase _phase = _Phase.on;
  final List<int> _onBus = []; // rider ids
  final List<int> _waiting = [];
  int _offLeft = 0;
  int _counted = 0;
  int _nextRider = 0;
  double _scroll = 0;
  late List<int> _answers;
  int _burst = 0;

  @override
  void initState() {
    super.initState();
    _stops = switch (GameScope.read(context).ageBand) {
      AgeBand.little => const [(0, 2), (0, 1)],
      AgeBand.middle => const [(0, 3), (1, 2)],
      AgeBand.big => const [(0, 3), (2, 3), (1, 1)],
    };
    _drive.addListener(() => setState(() => _scroll = _stop * 900 + _drive.value * 900));
    WidgetsBinding.instance.addPostFrameCallback((_) => _arrive());
  }

  @override
  void dispose() {
    _drive.dispose();
    super.dispose();
  }

  void _arrive() {
    final (off, on) = _stops[_stop];
    _counted = 0;
    _waiting.clear();
    for (var i = 0; i < on; i++) {
      _waiting.add(_nextRider++ % _riders.length);
    }
    _offLeft = off;
    if (off > 0) {
      _phase = _Phase.off;
      Voice.instance.say('Bus stop! ${_cap(_numberWords[off])} ${off == 1 ? 'person gets' : 'people get'} off here. Tap them in the windows!');
    } else {
      _phase = _Phase.on;
      Voice.instance.say('Bus stop! ${_cap(_numberWords[on])} ${on == 1 ? 'person is' : 'people are'} waiting. Tap them to get on!');
    }
    setState(() {});
  }

  String _cap(String s) => s[0].toUpperCase() + s.substring(1);

  void _tapWaiting(int i) {
    if (_phase != _Phase.on) return;
    Sfx.tap();
    setState(() {
      _onBus.add(_waiting.removeAt(i));
      _counted++;
    });
    Voice.instance.say(_numberWords[_counted]);
    if (_waiting.isEmpty) _leave();
  }

  void _tapRider(int i) {
    if (_phase != _Phase.off || _offLeft == 0) return;
    Sfx.tap();
    setState(() {
      _onBus.removeAt(i);
      _offLeft--;
      _counted++;
    });
    Voice.instance.say('${_numberWords[_counted]}. Bye bye!');
    if (_offLeft == 0) {
      Future<void>.delayed(const Duration(milliseconds: 900), () {
        if (!mounted) return;
        final on = _stops[_stop].$2;
        _counted = 0;
        setState(() => _phase = _Phase.on);
        Voice.instance.say('Now ${_numberWords[on]} ${on == 1 ? 'person gets' : 'people get'} on. Tap them!');
      });
    }
  }

  Future<void> _leave() async {
    await Future<void>.delayed(const Duration(milliseconds: 900));
    if (!mounted) return;
    if (_stop == _stops.length - 1) {
      _ask();
      return;
    }
    setState(() => _phase = _Phase.driving);
    Voice.instance.say('Ding ding! Off we go.');
    await _drive.forward(from: 0);
    if (!mounted) return;
    _stop++;
    _arrive();
  }

  void _ask() {
    final n = _onBus.length;
    final count = choicesFor(GameScope.read(context).ageBand);
    final opts = <int>{n};
    var d = 1;
    while (opts.length < count) {
      if (n - d >= 1) opts.add(n - d);
      if (opts.length < count) opts.add(n + d);
      d++;
    }
    _answers = opts.toList()..shuffle(math.Random());
    setState(() => _phase = _Phase.ask);
    Voice.instance.say('Last stop! How many people are on the bus now? Count the faces in the windows.');
  }

  Future<void> _answer(int a) async {
    if (_phase != _Phase.ask) return;
    final n = _onBus.length;
    if (a != n) {
      final words = [for (var i = 1; i <= n; i++) _numberWords[i]].join(', ');
      Voice.instance.say('Let\'s count together: $words. There are $n!');
      await Future<void>.delayed(Duration(milliseconds: 1200 + n * 700));
    } else {
      Voice.instance.say('Yes! ${_cap(_numberWords[n])} people on the bus. Great counting!');
    }
    if (!mounted) return;
    setState(() {
      _phase = _Phase.done;
      _burst++;
    });
    await Future<void>.delayed(const Duration(milliseconds: 2400));
    if (mounted) finishMission(context, widget.mission);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LayoutBuilder(builder: (context, c) {
        final size = Size(c.maxWidth, c.maxHeight);
        final lane = RoadLayout.lane(size);
        // Leave room above the bus for the banner and the counter badge.
        final busW = math.min(size.width * 0.58, (lane - 150) / 0.92 * kSimpleW / kSimpleH);
        final busH = busW * kSimpleH / kSimpleW;
        final busRect = Rect.fromLTWH(size.width * 0.06, lane - busH * 0.92, busW, busH);
        final s = busW / kSimpleW;
        final wobble = _phase == _Phase.driving ? math.sin(_scroll / 30) * 2 : 0.0;

        final children = <Widget>[
          Positioned.fill(child: CustomPaint(painter: SceneryPainter(scroll: _scroll))),
          Positioned.fromRect(
            rect: busRect.shift(Offset(0, wobble)),
            child: CustomPaint(
                painter: SimpleVehiclePainter(
                    CarLook(type: VehicleType.bus, wheelTurn: _scroll / 40))),
          ),
        ];

        // Riders in the windows (5 seats; extra riders squeeze in).
        for (var i = 0; i < _onBus.length; i++) {
          final seat = i % 5;
          final cx = busRect.left + (40 + seat * 46.0) * s + (i >= 5 ? 10 * s : 0);
          final cy = busRect.top + 74 * s + wobble;
          final r = 16 * s;
          children.add(Positioned(
            left: cx - r * 1.4,
            top: cy - r * 1.4,
            width: r * 2.8,
            height: r * 2.8,
            child: GestureDetector(
              onTap: () => _tapRider(i),
              child: CustomPaint(
                painter: _HeadPainter(_riders[_onBus[i]],
                    highlight: _phase == _Phase.off && _offLeft > 0),
              ),
            ),
          ));
        }

        // Bus stop and people waiting.
        if (_phase != _Phase.driving) {
          final stopX = busRect.right + size.width * 0.06;
          children.add(Positioned(
            left: stopX,
            top: lane - size.height * 0.42,
            child: Column(children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: const Color(0xFFE63946),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 6),
                ),
              ),
              Container(width: 6, height: size.height * 0.3, color: const Color(0xFF6C757D)),
            ]),
          ));
          for (var i = 0; i < _waiting.length; i++) {
            final fx = stopX + 60 + i * size.width * 0.07;
            final h = size.height * 0.3;
            children.add(Positioned(
              left: fx - h * 0.3,
              top: RoadLayout.top(size) - h,
              width: h * 0.6,
              height: h,
              child: GestureDetector(
                onTap: () => _tapWaiting(i),
                child: CustomPaint(
                    painter: _FigurePainter(_riders[_waiting[i]], _shirts[_waiting[i]],
                        highlight: _phase == _Phase.on)),
              ),
            ));
          }
        }

        // Counter badge.
        children.add(Positioned(
          left: busRect.left + 8,
          top: busRect.top - 62,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: const Color(0xFFFFB703), width: 4),
            ),
            child: Text(_phase == _Phase.ask ? '?' : '${_onBus.length}',
                style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w900, color: kInk)),
          ),
        ));

        if (_phase == _Phase.ask) {
          children.add(Positioned(
            right: 24,
            top: size.height * 0.25,
            child: Column(children: [
              for (final a in _answers)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: BubbleButton(
                    size: 84,
                    color: const Color(0xFF4C6EF5),
                    onTap: () => _answer(a),
                    child: Text('$a',
                        style: const TextStyle(fontSize: 40, fontWeight: FontWeight.w900, color: Colors.white)),
                  ),
                ),
            ]),
          ));
        }

        children.addAll([
          Positioned(
            top: 14,
            left: 0,
            right: 0,
            child: Center(
              child: PartBanner(
                title: switch (_phase) {
                  _Phase.off => 'Getting off',
                  _Phase.on => 'Getting on',
                  _Phase.driving => 'Ding ding!',
                  _Phase.ask => 'How many?',
                  _Phase.done => 'Great counting!',
                },
                line: 'Stop ${math.min(_stop + 1, _stops.length)} of ${_stops.length}',
              ),
            ),
          ),
          const Positioned(left: 20, top: 20, child: BackBubble()),
          const Positioned(right: 20, top: 20, child: StarCounter()),
          Positioned.fill(child: StarBurst(trigger: _burst)),
        ]);
        return Stack(children: children);
      }),
    );
  }
}

class _HeadPainter extends CustomPainter {
  final Townsperson p;
  final bool highlight;
  _HeadPainter(this.p, {this.highlight = false});

  @override
  void paint(Canvas c, Size s) {
    final r = s.shortestSide / 2.8;
    if (highlight) {
      c.drawCircle(s.center(Offset.zero), r * 1.35, Paint()..color = fade(const Color(0xFFFFE066), 0.7));
    }
    paintTownsperson(c, p, s.center(Offset.zero), r);
  }

  @override
  bool shouldRepaint(covariant _HeadPainter old) => old.highlight != highlight || old.p != p;
}

class _FigurePainter extends CustomPainter {
  final Townsperson p;
  final Color shirt;
  final bool highlight;
  _FigurePainter(this.p, this.shirt, {this.highlight = false});

  @override
  void paint(Canvas c, Size s) {
    if (highlight) {
      c.drawOval(Rect.fromCenter(center: Offset(s.width / 2, s.height - 4), width: s.width, height: 16),
          Paint()..color = fade(const Color(0xFFFFE066), 0.8));
    }
    paintFigure(c, p, Offset(s.width / 2, s.height), s.height * 0.75, shirt: shirt);
  }

  @override
  bool shouldRepaint(covariant _FigurePainter old) => old.highlight != highlight;
}
