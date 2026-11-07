import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../art/scenery.dart';
import '../art/truck_art.dart';
import '../data/models.dart';
import '../services/voice.dart';
import '../state/game_state.dart';
import '../widgets/ui.dart';

/// Paint, wheels and stickers. Colour names are spoken (colour learning);
/// wheel choices explain what they are good at, which matters on the road.
class CustomiseScreen extends StatefulWidget {
  final int startTab;
  const CustomiseScreen({super.key, this.startTab = 0});

  @override
  State<CustomiseScreen> createState() => _CustomiseScreenState();
}

class _CustomiseScreenState extends State<CustomiseScreen>
    with SingleTickerProviderStateMixin {
  late int _tab = widget.startTab;
  late final AnimationController _spin = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1400));

  // Sticker dragging, in screen pixels.
  StickerKind? _dragKind;
  Offset? _dragPos;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Voice.instance.say(const [
        'Pick a colour!',
        'Pick some wheels!',
        'Drag stickers onto your truck!',
      ][_tab]);
    });
  }

  @override
  void dispose() {
    _spin.dispose();
    super.dispose();
  }

  Rect _area(Size s) =>
      Rect.fromLTRB(s.width * 0.14, s.height * 0.12, s.width * 0.86, s.height * 0.7);

  void _dropSticker(Rect area) {
    final kind = _dragKind;
    final pos = _dragPos;
    setState(() {
      _dragKind = null;
      _dragPos = null;
    });
    if (kind == null || pos == null) return;
    final fit = Fit.contain(area.size);
    final v = fit.toVehicle(pos - area.topLeft);
    final onTruck = TruckGeo.hitTest(v, WheelStyle.classic, allParts) != null;
    if (!onTruck) return;
    GameScope.read(context).addSticker(PlacedSticker(kind, v.dx, v.dy));
    Sfx.snap();
  }

  void _tapTruck(TapUpDetails d, Rect area) {
    if (_tab != 2) return;
    final s = GameScope.read(context);
    final v = Fit.contain(area.size).toVehicle(d.localPosition);
    for (final st in s.stickers.reversed) {
      if ((Offset(st.x, st.y) - v).distance < 20) {
        s.removeSticker(st);
        Sfx.tap();
        return;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = GameScope.of(context);
    return Scaffold(
      body: LayoutBuilder(builder: (context, c) {
        final size = Size(c.maxWidth, c.maxHeight);
        final area = _area(size);
        return Stack(children: [
          const Positioned.fill(child: CustomPaint(painter: GaragePainter())),
          Positioned.fromRect(
            rect: area,
            child: GestureDetector(
              onTapUp: (d) => _tapTruck(d, area),
              child: AnimatedBuilder(
                animation: _spin,
                builder: (context, _) => CustomPaint(
                  painter: VehiclePainter(lookFrom(s,
                      built: allParts,
                      wheelTurn: Curves.easeOut.transform(_spin.value) * math.pi * 4)),
                ),
              ),
            ),
          ),

          // Tab switcher.
          Positioned(
            top: 18,
            left: 0,
            right: 0,
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              for (final (i, icon, col) in const [
                (0, Icons.palette_rounded, Color(0xFFFF6FB5)),
                (1, Icons.tire_repair, Color(0xFF9B5DE5)),
                (2, Icons.emoji_emotions_rounded, Color(0xFFFFB703)),
              ]) ...[
                IconBubble(icon,
                    size: _tab == i ? 72 : 56,
                    color: col,
                    glow: _tab == i,
                    dimmed: _tab != i,
                    onTap: () => setState(() => _tab = i)),
                const SizedBox(width: 16),
              ],
            ]),
          ),

          // Tray.
          Positioned(
            left: 0,
            right: 0,
            bottom: 14,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFF6C4AB6),
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: Colors.white, width: 4),
                ),
                child: _tray(s, area),
              ),
            ),
          ),

          if (_dragKind != null && _dragPos != null)
            Positioned(
              left: _dragPos!.dx - 36,
              top: _dragPos!.dy - 36,
              width: 72,
              height: 72,
              child: IgnorePointer(
                  child: CustomPaint(painter: StickerPainter(_dragKind!))),
            ),

          const Positioned(left: 20, top: 20, child: BackBubble()),
          const Positioned(right: 20, top: 20, child: StarCounter()),
        ]);
      }),
    );
  }

  Widget _tray(GameState s, Rect area) {
    switch (_tab) {
      case 0:
        return Row(mainAxisSize: MainAxisSize.min, children: [
          for (final p in paintChoices)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: BubbleButton(
                size: s.bodyColor == p.color ? 70 : 58,
                color: p.color,
                glow: s.bodyColor == p.color,
                onTap: () {
                  s.setColor(p.color);
                  Voice.instance.say(p.name);
                },
                child: const SizedBox(),
              ),
            ),
        ]);
      case 1:
        return Row(mainAxisSize: MainAxisSize.min, children: [
          for (final w in WheelStyle.values)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: BubbleButton(
                size: 80,
                color: s.wheels == w ? const Color(0xFFFFD23F) : const Color(0xFFBDE0FE),
                glow: s.wheels == w,
                onTap: () {
                  s.setWheels(w);
                  _spin.forward(from: 0);
                  Voice.instance.say(wheelLines[w]!);
                },
                child: SizedBox(
                    width: 64,
                    height: 64,
                    child: CustomPaint(painter: WheelThumbPainter(w))),
              ),
            ),
        ]);
      default:
        return Row(mainAxisSize: MainAxisSize.min, children: [
          for (final k in StickerKind.values)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: GestureDetector(
                onPanStart: (d) => setState(() {
                  _dragKind = k;
                  _dragPos = d.globalPosition;
                }),
                onPanUpdate: (d) => setState(() => _dragPos = d.globalPosition),
                onPanEnd: (_) => _dropSticker(area),
                child: SizedBox(
                    width: 64,
                    height: 64,
                    child: CustomPaint(painter: StickerPainter(k))),
              ),
            ),
          const SizedBox(width: 12),
          IconBubble(Icons.delete_sweep_rounded,
              size: 56,
              color: const Color(0xFFE63946),
              onTap: s.clearStickers),
        ]);
    }
  }
}
