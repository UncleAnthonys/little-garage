import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../art/scenery.dart';
import '../art/town_art.dart';
import '../art/truck_art.dart';
import '../data/missions.dart';
import '../data/projects.dart';
import '../services/voice.dart';
import '../state/game_state.dart';
import '../widgets/ui.dart';

/// A new vehicle arrives in pieces. The child drags each part onto its
/// glowing outline and hears what it does, then the vehicle joins the
/// fleet. Owned vehicles can be rebuilt from the fleet garage for fun.
class VehicleIntroScreen extends StatefulWidget {
  final VehicleType type;

  /// True when it joins the fleet at the end; false to rebuild an owned one.
  final bool joining;
  const VehicleIntroScreen({super.key, required this.type, this.joining = true});

  /// Where the vehicle sits: below the banner, left of the parts card.
  static Rect areaFor(Size s) {
    const top = 100.0;
    final maxH = s.height - top - 50;
    final w = math.min(s.width * 0.64, maxH * kSimpleW / kSimpleH);
    final h = w * kSimpleH / kSimpleW;
    return Rect.fromLTWH((s.width * 0.72 - w) / 2, top + (maxH - h) / 2, w, h);
  }

  static Rect cardFor(Size s) =>
      Rect.fromLTRB(s.width * 0.74, s.height * 0.26, s.width * 0.97, s.height * 0.74);


  @override
  State<VehicleIntroScreen> createState() => _VehicleIntroScreenState();
}

class _VehicleIntroScreenState extends State<VehicleIntroScreen> with TickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 900))
    ..repeat(reverse: true);
  late final AnimationController _clock = AnimationController(
      vsync: this, duration: const Duration(seconds: 10))
    ..repeat();
  late final AnimationController _snap = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 500));

  final Set<String> _built = {};
  String? _bannerTitle;
  String? _bannerLine;
  int _burst = 0;
  bool _busy = false;

  // Dragging, in screen pixels.
  Offset? _piecePos;
  bool _returning = false;
  Offset _cardCentre = Offset.zero;

  Timer? _hintTimer;
  bool _hint = false;

  List<VehiclePart> get _parts => vehicleParts[widget.type] ?? const [];
  String get _name => vehicleNames[widget.type]!;
  bool get _done => _built.length == _parts.length;

  VehiclePart? get _next {
    for (final p in _parts) {
      if (!_built.contains(p.id)) return p;
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Voice.instance.say(widget.joining
          ? 'A new $_name! It comes in pieces. Drag each part onto the glowing space to build it.'
          : 'Let\'s build the $_name again! Drag each part onto the glowing space.');
      _startHint();
    });
  }

  @override
  void dispose() {
    _hintTimer?.cancel();
    _pulse.dispose();
    _clock.dispose();
    _snap.dispose();
    super.dispose();
  }

  void _startHint() {
    _hintTimer?.cancel();
    if (mounted) setState(() => _hint = false);
    _hintTimer = Timer(hintDelayFor(GameScope.read(context).ageBand), () {
      if (mounted && _piecePos == null) setState(() => _hint = true);
    });
  }

  void _dragStart(DragStartDetails d, VehiclePart part, double scale) {
    if (_busy) return;
    _hintTimer?.cancel();
    final size = part.area.size * scale;
    setState(() {
      _hint = false;
      _returning = false;
      _piecePos = d.globalPosition - Offset(size.width / 2, size.height / 2 + 24);
    });
  }

  void _dragUpdate(DragUpdateDetails d) {
    if (_piecePos == null || _returning) return;
    setState(() => _piecePos = _piecePos! + d.delta);
  }

  void _dragEnd(VehiclePart part, Rect area, double scale) {
    final pos = _piecePos;
    if (pos == null || _returning) return;
    final size = part.area.size * scale;
    final centre = pos + Offset(size.width / 2, size.height / 2);
    final target = area.topLeft + part.area.center * scale;
    if ((centre - target).distance < math.max(70.0, size.longestSide * 0.35)) {
      setState(() => _piecePos = null);
      _place(part);
    } else {
      setState(() {
        _returning = true;
        _piecePos = _cardCentre - Offset(size.width / 2, size.height / 2);
      });
      Voice.instance.say('Try the glowing space!');
    }
  }

  Future<void> _place(VehiclePart part) async {
    Sfx.snap();
    setState(() {
      _built.add(part.id);
      _busy = true;
      _bannerTitle = part.name;
      _bannerLine = part.line;
    });
    _snap.forward(from: 0);
    Voice.instance.say('The ${part.name.toLowerCase()}! ${part.line}');
    await Future<void>.delayed(const Duration(milliseconds: 2600));
    if (!mounted) return;
    if (_done) {
      setState(() {
        _burst++;
        _bannerTitle = 'You built a $_name!';
        _bannerLine = widget.joining ? 'Add it to your fleet' : null;
      });
      Voice.instance.say(widget.joining
          ? 'You built a $_name! Add it to your fleet.'
          : 'You built the $_name again!');
      setState(() => _busy = false);
      return;
    }
    setState(() {
      _busy = false;
      _bannerTitle = null;
      _bannerLine = null;
    });
    _startHint();
  }

  void _join() {
    GameScope.read(context).addToFleet(widget.type);
    Voice.instance.say('The $_name joined your fleet!');
    setState(() => _burst++);
    Future<void>.delayed(const Duration(milliseconds: 1400), () {
      if (mounted) Navigator.of(context).pop(true);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LayoutBuilder(builder: (context, c) {
        final size = Size(c.maxWidth, c.maxHeight);
        final area = VehicleIntroScreen.areaFor(size);
        final scale = area.width / kSimpleW;
        final card = VehicleIntroScreen.cardFor(size);
        _cardCentre = card.center;
        final next = _next;
        return AnimatedBuilder(
          animation: Listenable.merge([_pulse, _clock, _snap]),
          builder: (context, _) {
            final t = _clock.value * 10;
            final bounce = _done ? math.sin(_snap.value * math.pi) * -10 : 0.0;
            final look = CarLook(type: widget.type, t: t, wheelTurn: _done ? t : 0);
            final children = <Widget>[
              const Positioned.fill(child: CustomPaint(painter: GaragePainter())),
              Positioned.fromRect(
                rect: area.shift(Offset(0, bounce)),
                child: CustomPaint(
                  painter: _BuildPainter(look, Set.of(_built),
                      target: _busy ? null : next, pulse: _pulse.value),
                ),
              ),
            ];

            // The next part, waiting on its card.
            if (next != null && !_busy) {
              children.add(Positioned.fromRect(
                rect: card,
                child: GestureDetector(
                  onPanStart: (d) => _dragStart(d, next, scale),
                  onPanUpdate: _dragUpdate,
                  onPanEnd: (_) => _dragEnd(next, area, scale),
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF2FA4E7),
                      borderRadius: BorderRadius.circular(26),
                      border: Border.all(color: Colors.white, width: 5),
                      boxShadow: [
                        BoxShadow(
                            color: fade(const Color(0xFFFFE066), 0.3 + 0.5 * _pulse.value),
                            blurRadius: 20,
                            spreadRadius: 2),
                      ],
                    ),
                    child: Opacity(
                      opacity: _piecePos == null ? 1 : 0.25,
                      child: Column(children: [
                        Expanded(
                          child: SizedBox(
                            width: double.infinity,
                            child: CustomPaint(painter: _PartThumbPainter(look, next)),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Text(next.name,
                              style: const TextStyle(
                                  fontSize: 20, fontWeight: FontWeight.w900, color: Colors.white)),
                        ),
                      ]),
                    ),
                  ),
                ),
              ));
            }

            // The piece in the child's hand, or sliding back to the card.
            if (next != null && _piecePos != null) {
              final ps = next.area.size * scale;
              children.add(AnimatedPositioned(
                duration: _returning ? const Duration(milliseconds: 280) : Duration.zero,
                left: _piecePos!.dx,
                top: _piecePos!.dy,
                width: ps.width,
                height: ps.height,
                onEnd: () {
                  if (_returning) {
                    setState(() {
                      _returning = false;
                      _piecePos = null;
                    });
                    _startHint();
                  }
                },
                child: IgnorePointer(child: CustomPaint(painter: _PiecePainter(look, next, scale))),
              ));
            }

            // Hint: a hand gliding from the card to the outline.
            if (next != null && _hint && _piecePos == null && !_busy) {
              final target = area.topLeft + next.area.center * scale;
              final pos = Offset.lerp(card.center, target, Curves.easeInOut.transform(_pulse.value))!;
              children.add(Positioned(
                left: pos.dx - 24,
                top: pos.dy - 10,
                child: const IgnorePointer(
                  child: Icon(Icons.touch_app_rounded,
                      size: 56, color: Colors.white, shadows: [Shadow(color: Colors.black38, blurRadius: 6)]),
                ),
              ));
            }

            children.addAll([
              Positioned(
                top: 14,
                left: 0,
                right: 0,
                child: Center(
                  child: PartBanner(
                    title: _bannerTitle ?? (widget.joining ? 'New: ${_cap(_name)}!' : _cap(_name)),
                    line: _bannerLine ?? (_done ? null : 'Drag the part into place'),
                  ),
                ),
              ),
              Positioned(
                left: 0,
                right: size.width * 0.28,
                bottom: 12,
                child: Center(
                  child: Text('${_built.length} of ${_parts.length} parts',
                      style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          color: kInk,
                          shadows: [Shadow(color: Colors.white, blurRadius: 6)])),
                ),
              ),
              if (_done && !_busy)
                Positioned(
                  right: 24,
                  bottom: 18,
                  child: widget.joining
                      ? IconBubble(Icons.add_rounded,
                          size: 96, color: const Color(0xFF2DC653), glow: true, onTap: _join)
                      : IconBubble(Icons.check_rounded,
                          size: 96,
                          color: const Color(0xFF2DC653),
                          glow: true,
                          onTap: () => Navigator.of(context).pop(false)),
                ),
              Positioned(left: 20, top: 20, child: BackBubble(onTap: () => Navigator.of(context).pop(false))),
              Positioned.fill(child: StarBurst(trigger: _burst)),
            ]);
            return Stack(children: children);
          },
        );
      }),
    );
  }

  String _cap(String s) => s[0].toUpperCase() + s.substring(1);
}

class _BuildPainter extends CustomPainter {
  final CarLook look;
  final Set<String> built;
  final VehiclePart? target;
  final double pulse;
  _BuildPainter(this.look, this.built, {this.target, this.pulse = 0});

  @override
  void paint(Canvas c, Size size) {
    final s = math.min(size.width / kSimpleW, size.height / kSimpleH);
    c.save();
    c.translate((size.width - kSimpleW * s) / 2, (size.height - kSimpleH * s) / 2);
    c.scale(s);
    paintVehicleBuild(c, look, built,
        target: target?.id, targetBounds: target?.area, pulse: pulse);
    c.restore();
  }

  @override
  bool shouldRepaint(covariant _BuildPainter old) => true;
}

/// One part, fitted into the parts card.
class _PartThumbPainter extends CustomPainter {
  final CarLook look;
  final VehiclePart part;
  _PartThumbPainter(this.look, this.part);

  @override
  void paint(Canvas c, Size size) {
    const pad = 12.0;
    final b = part.area;
    final s = math.min((size.width - 2 * pad) / b.width, (size.height - 2 * pad) / b.height);
    c.save();
    c.translate((size.width - b.width * s) / 2, (size.height - b.height * s) / 2);
    c.scale(s);
    c.translate(-b.left, -b.top);
    paintVehiclePart(c, look.type, part.id, look);
    c.restore();
  }

  @override
  bool shouldRepaint(covariant _PartThumbPainter old) => true;
}

/// One part at the vehicle's on-screen scale, for dragging.
class _PiecePainter extends CustomPainter {
  final CarLook look;
  final VehiclePart part;
  final double scale;
  _PiecePainter(this.look, this.part, this.scale);

  @override
  void paint(Canvas c, Size size) {
    c.save();
    c.scale(scale);
    c.translate(-part.area.left, -part.area.top);
    paintVehiclePart(c, look.type, part.id, look);
    c.restore();
  }

  @override
  bool shouldRepaint(covariant _PiecePainter old) => true;
}
