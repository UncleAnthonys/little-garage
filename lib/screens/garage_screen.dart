import 'package:flutter/material.dart';

import '../art/scenery.dart';
import '../art/truck_art.dart';
import '../data/models.dart';
import '../services/voice.dart';
import '../state/game_state.dart';
import '../widgets/ui.dart';
import 'customise_screen.dart';
import 'drive_screen.dart';
import 'hq_screen.dart';
import 'spot_screen.dart';
import 'wash_screen.dart';

/// The hub after building. Tap any part to hear its name and see it work
/// (Mechanic Mode); pick wash, customise, stickers or drive.
class GarageScreen extends StatefulWidget {
  final bool fromBuild;
  const GarageScreen({super.key, this.fromBuild = false});

  @override
  State<GarageScreen> createState() => _GarageScreenState();
}

class _GarageScreenState extends State<GarageScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _action = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 2200));
  PartKind? _highlight;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Voice.instance.say(widget.fromBuild
          ? 'Your truck is ready! Tap a part to learn about it. Then tap the arrow to go to the garage. Someone needs your help!'
          : 'Welcome back to the garage!');
    });
  }

  @override
  void dispose() {
    _action.dispose();
    super.dispose();
  }

  Rect _area(Size s) =>
      Rect.fromLTRB(s.width * 0.14, s.height * 0.08, s.width * 0.86, s.height * 0.76);

  void _tapTruck(TapUpDetails d, Size size) {
    final s = GameScope.read(context);
    final area = _area(size);
    final fit = Fit.contain(area.size);
    final v = fit.toVehicle(d.localPosition);
    final hit = TruckGeo.hitTest(v, s.wheels, allParts);
    if (hit == null) return;
    final part = s.vehicle.part(hit);
    Sfx.tap();
    setState(() => _highlight = hit);
    Voice.instance.say('${part.name}. ${part.line}');
    _action.forward(from: 0).then((_) {
      if (mounted) setState(() => _highlight = null);
    });
  }

  void _open(Widget screen) =>
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));

  @override
  Widget build(BuildContext context) {
    final s = GameScope.of(context);
    final part = _highlight == null ? null : s.vehicle.part(_highlight!);
    return Scaffold(
      body: LayoutBuilder(builder: (context, c) {
        final size = Size(c.maxWidth, c.maxHeight);
        final area = _area(size);
        return Stack(children: [
          const Positioned.fill(child: CustomPaint(painter: GaragePainter())),
          Positioned.fromRect(
            rect: area,
            child: GestureDetector(
              onTapUp: (d) => _tapTruck(d, size),
              child: AnimatedBuilder(
                animation: _action,
                builder: (context, _) => CustomPaint(
                  painter: VehiclePainter(lookFrom(s,
                      built: allParts, highlight: _highlight, t: _action.value)),
                ),
              ),
            ),
          ),
          Positioned(
            top: 14,
            left: 0,
            right: 0,
            child: Center(
              child: PartBanner(
                title: part?.name ?? (_highlight == null ? 'Tap a part!' : null),
                line: part?.line,
              ),
            ),
          ),
          Positioned(
            left: 20,
            top: 20,
            child: BackBubble(
                onTap: () => widget.fromBuild
                    ? Navigator.of(context).pushReplacement(
                        MaterialPageRoute(builder: (_) => const HqScreen()))
                    : Navigator.of(context).maybePop()),
          ),
          const Positioned(right: 20, top: 20, child: StarCounter()),
          Positioned(
            left: 0,
            right: 0,
            bottom: 16,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconBubble(Icons.water_drop_rounded,
                    color: const Color(0xFF4CC9F0),
                    glow: s.dirty,
                    onTap: () => _open(const WashScreen())),
                const SizedBox(width: 18),
                IconBubble(Icons.palette_rounded,
                    color: const Color(0xFFFF6FB5),
                    onTap: () => _open(const CustomiseScreen(startTab: 0))),
                const SizedBox(width: 18),
                IconBubble(Icons.tire_repair,
                    color: const Color(0xFF9B5DE5),
                    onTap: () => _open(const CustomiseScreen(startTab: 1))),
                const SizedBox(width: 18),
                IconBubble(Icons.emoji_emotions_rounded,
                    color: const Color(0xFFFFB703),
                    onTap: () => _open(const CustomiseScreen(startTab: 2))),
                const SizedBox(width: 18),
                IconBubble(Icons.visibility_rounded,
                    color: const Color(0xFF2EC4B6),
                    onTap: () => _open(const SpotScreen())),
                const SizedBox(width: 28),
                IconBubble(Icons.flag_rounded,
                    size: 96,
                    color: const Color(0xFF2DC653),
                    glow: !s.dirty,
                    onTap: () => _open(const DriveScreen())),
              ],
            ),
          ),
        ]);
      }),
    );
  }
}
