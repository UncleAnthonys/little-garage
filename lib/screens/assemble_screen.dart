import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../art/scenery.dart';
import '../art/truck_art.dart';
import '../data/models.dart';
import '../services/voice.dart';
import '../state/game_state.dart';
import '../widgets/ui.dart';
import 'garage_screen.dart';

/// Drag each part onto its glowing silhouette. Every part is named aloud and
/// shows what it does: the learning core of the game.
class AssembleScreen extends StatefulWidget {
  const AssembleScreen({super.key});

  @override
  State<AssembleScreen> createState() => _AssembleScreenState();
}

class _AssembleScreenState extends State<AssembleScreen>
    with TickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 900))
    ..repeat(reverse: true);
  late final AnimationController _action = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 2200));

  PartKind? _highlight;
  String? _bannerTitle;
  String? _bannerLine;
  int _burst = 0;
  bool _busy = false;

  // Dragging.
  Offset? _piecePos; // top-left of the dragged piece, screen pixels
  bool _returning = false;
  Offset _cardCentre = Offset.zero;

  Timer? _hintTimer;
  bool _showHint = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      GameScope.read(context).startBuild();
      _promptNext();
    });
  }

  @override
  void dispose() {
    _pulse.dispose();
    _action.dispose();
    _hintTimer?.cancel();
    super.dispose();
  }

  void _promptNext() {
    _hintTimer?.cancel();
    setState(() => _showHint = false);
    _hintTimer = Timer(const Duration(seconds: 5), () {
      if (mounted && _piecePos == null) setState(() => _showHint = true);
    });
  }

  Rect _vehicleArea(Size s) =>
      Rect.fromLTRB(s.width * 0.04, s.height * 0.1, s.width * 0.72, s.height * 0.78);

  Fit _fit(Size s) {
    final area = _vehicleArea(s);
    final f = Fit.contain(area.size);
    return Fit(f.scale, f.offset + area.topLeft);
  }

  Rect _cardRect(Size s) => Rect.fromLTRB(
      s.width * 0.74, s.height * 0.2, s.width * 0.97, s.height * 0.62);

  void _onDragStart(DragStartDetails d, PartDef part, Fit fit) {
    if (_busy) return;
    _hintTimer?.cancel();
    final b = TruckGeo.bounds(part.kind, GameScope.read(context).wheels);
    final pieceSize = b.size * fit.scale;
    setState(() {
      _showHint = false;
      _returning = false;
      _piecePos = d.globalPosition -
          Offset(pieceSize.width / 2, pieceSize.height / 2 + 30);
    });
  }

  void _onDragUpdate(DragUpdateDetails d) {
    if (_piecePos == null || _returning) return;
    setState(() => _piecePos = _piecePos! + d.delta);
  }

  void _onDragEnd(PartDef part, Fit fit) {
    if (_piecePos == null || _returning) return;
    final s = GameScope.read(context);
    final b = TruckGeo.bounds(part.kind, s.wheels);
    final pieceSize = b.size * fit.scale;
    final pieceCentre = _piecePos! + Offset(pieceSize.width / 2, pieceSize.height / 2);
    final target = fit.toLocal(b.center);
    final tolerance = math.max(80.0, pieceSize.longestSide * 0.3);

    if ((pieceCentre - target).distance < tolerance) {
      setState(() => _piecePos = null);
      _snap(part);
    } else {
      setState(() {
        _returning = true;
        _piecePos = _cardCentre - Offset(pieceSize.width / 2, pieceSize.height / 2);
      });
      Voice.instance.say('Try the glowing spot!');
    }
  }

  Future<void> _snap(PartDef part) async {
    final s = GameScope.read(context);
    Sfx.snap();
    s.buildPart(part.kind);
    setState(() {
      _busy = true;
      _highlight = part.kind;
      _bannerTitle = part.name;
      _bannerLine = part.line;
    });
    Voice.instance.say("That's the ${part.name.toLowerCase()}! ${part.line}");
    await _action.forward(from: 0);
    if (!mounted) return;

    if (s.isBuilt) {
      s.addStars(3);
      final name = s.childName.isEmpty ? 'You' : s.childName;
      setState(() {
        _burst++;
        _highlight = PartKind.wheels;
        _bannerTitle = 'You built it!';
        _bannerLine = '$name built a tow truck. Three stars!';
      });
      Voice.instance.say('Hooray! $name built a tow truck!');
      _action.forward(from: 0);
      await Future<void>.delayed(const Duration(milliseconds: 2600));
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const GarageScreen(fromBuild: true)));
      return;
    }

    setState(() {
      _busy = false;
      _highlight = null;
      _bannerTitle = null;
      _bannerLine = null;
    });
    _promptNext();
  }

  @override
  Widget build(BuildContext context) {
    final s = GameScope.of(context);
    final next = s.nextPart;
    return Scaffold(
      body: LayoutBuilder(builder: (context, c) {
        final size = Size(c.maxWidth, c.maxHeight);
        final area = _vehicleArea(size);
        final fit = _fit(size);
        final card = _cardRect(size);
        _cardCentre = card.center;

        return AnimatedBuilder(
          animation: Listenable.merge([_pulse, _action]),
          builder: (context, _) {
            final look = lookFrom(s,
                target: next?.kind,
                pulse: _pulse.value,
                highlight: _highlight,
                t: _action.value);
            final children = <Widget>[
              Positioned.fill(child: CustomPaint(painter: SceneryPainter())),
              Positioned.fromRect(
                rect: area,
                child: CustomPaint(painter: VehiclePainter(look)),
              ),
            ];

            // Next-part card.
            if (next != null && !_busy) {
              children.add(Positioned.fromRect(
                rect: card,
                child: GestureDetector(
                  onPanStart: (d) => _onDragStart(d, next, fit),
                  onPanUpdate: _onDragUpdate,
                  onPanEnd: (_) => _onDragEnd(next, fit),
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF2FA4E7),
                      borderRadius: BorderRadius.circular(28),
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
                          child: CustomPaint(
                            size: Size.infinite,
                            painter: PartThumbPainter(next.kind, look, padding: 16),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Text(next.name,
                              style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white)),
                        ),
                      ]),
                    ),
                  ),
                ),
              ));
            }

            // Piece being dragged (or sliding back to the card).
            if (next != null && _piecePos != null) {
              final b = TruckGeo.bounds(next.kind, s.wheels);
              final pieceSize = b.size * fit.scale;
              children.add(AnimatedPositioned(
                duration: _returning
                    ? const Duration(milliseconds: 280)
                    : Duration.zero,
                left: _piecePos!.dx,
                top: _piecePos!.dy,
                width: pieceSize.width,
                height: pieceSize.height,
                onEnd: () {
                  if (_returning) {
                    setState(() {
                      _returning = false;
                      _piecePos = null;
                    });
                    _promptNext();
                  }
                },
                child: IgnorePointer(
                  child: CustomPaint(
                      painter: PartPiecePainter(next.kind, look, fit.scale)),
                ),
              ));
            }

            // Idle hint: a hand gliding from the card to the target.
            if (next != null && _showHint && _piecePos == null && !_busy) {
              final target = fit.toLocal(TruckGeo.bounds(next.kind, s.wheels).center);
              final p = Curves.easeInOut.transform(_pulse.value);
              final pos = Offset.lerp(card.center, target, p)!;
              children.add(Positioned(
                left: pos.dx - 24,
                top: pos.dy - 10,
                child: const IgnorePointer(
                  child: Icon(Icons.touch_app_rounded, size: 56, color: Colors.white,
                      shadows: [Shadow(color: Colors.black38, blurRadius: 6)]),
                ),
              ));
            }

            children.addAll([
              Positioned(
                top: 14,
                left: 0,
                right: 0,
                child: Center(child: PartBanner(title: _bannerTitle, line: _bannerLine)),
              ),
              const Positioned(left: 20, top: 20, child: BackBubble()),
              const Positioned(right: 20, top: 20, child: StarCounter()),
              Positioned.fill(child: StarBurst(trigger: _burst)),
            ]);

            return Stack(children: children);
          },
        );
      }),
    );
  }
}
