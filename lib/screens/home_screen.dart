import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../art/scenery.dart';
import '../art/truck_art.dart';
import '../data/models.dart';
import '../services/voice.dart';
import '../state/game_state.dart';
import '../widgets/ui.dart';
import 'assemble_screen.dart';
import 'town_screen.dart';
import 'parent_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _bob = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1600))
    ..repeat();

  @override
  void dispose() {
    _bob.dispose();
    super.dispose();
  }

  Future<void> _editName() async {
    final s = GameScope.read(context);
    final ctrl = TextEditingController(text: s.childName);
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Name your truck'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          maxLength: 12,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(hintText: 'e.g. Ruby'),
          onSubmitted: (v) => Navigator.of(context).pop(v),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(ctrl.text),
              child: const Text('Done')),
        ],
      ),
    );
    if (name != null) {
      s.setName(name);
      if (s.childName.isNotEmpty) {
        Voice.instance.say("${s.childName}'s truck! What a great name.");
      }
    }
  }

  void _play() {
    if (GameScope.read(context).everBuilt) {
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => const TownScreen()));
      return;
    }
    _build();
  }

  void _build() {
    Voice.instance.say("Let's build a tow truck!");
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const AssembleScreen()));
  }

  @override
  Widget build(BuildContext context) {
    final s = GameScope.of(context);
    return Scaffold(
      body: LayoutBuilder(builder: (context, c) {
        final size = Size(c.maxWidth, c.maxHeight);
        final truckH = size.height * 0.4;
        final truckW = truckH * kVehicleW / kVehicleH;
        final lane = RoadLayout.lane(size);
        return Stack(children: [
          const Positioned.fill(child: CustomPaint(painter: _HomeScenery())),

          // Title.
          const Align(
            alignment: Alignment(0, -0.88),
            child: Text('Little Garage',
                style: TextStyle(
                  fontSize: 56,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFFFF9F1C),
                  shadows: [
                    Shadow(color: Colors.white, offset: Offset(0, 4), blurRadius: 0),
                    Shadow(color: Color(0x55000000), offset: Offset(0, 6), blurRadius: 8),
                  ],
                )),
          ),

          // The child's truck, bobbing on the road.
          AnimatedBuilder(
            animation: _bob,
            builder: (context, _) {
              final bob = math.sin(_bob.value * math.pi * 2) * 3;
              return Positioned(
                left: size.width * 0.5 - truckW / 2,
                top: lane - truckH * (230 / kVehicleH) + bob,
                width: truckW,
                height: truckH,
                child: GestureDetector(
                  onTap: _editName,
                  child: CustomPaint(
                      painter: VehiclePainter(lookFrom(s,
                          built: allParts, wheelTurn: _bob.value * math.pi * 2))),
                ),
              );
            },
          ),

          // Stars.
          const Positioned(left: 20, top: 20, child: StarCounter()),

          // Parent zone (behind a grown-up question).
          Positioned(
            right: 20,
            top: 20,
            child: IconBubble(Icons.lock_rounded,
                size: 52,
                color: const Color(0xFF8D99AE),
                onTap: () async {
              final ok = await showParentGate(context);
              if (!ok || !context.mounted) return;
              Navigator.of(context)
                  .push(MaterialPageRoute(builder: (_) => const ParentScreen()));
            }),
          ),

          // Driver picker.
          Positioned(
            left: 20,
            bottom: 20,
            child: Row(children: [
              for (final d in DriverKind.values)
                Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: BubbleButton(
                    size: 64,
                    color: s.driver == d
                        ? const Color(0xFFFFD23F)
                        : const Color(0xFFBDE0FE),
                    glow: s.driver == d,
                    onTap: () {
                      s.setDriver(d);
                      Voice.instance.say('${driverNames[d]} is driving!');
                    },
                    child: SizedBox(
                        width: 48,
                        height: 48,
                        child: CustomPaint(painter: DriverPainter(d))),
                  ),
                ),
            ]),
          ),

          // Name button.
          Positioned(
            left: 20,
            bottom: 100,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: kInk,
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12)),
              onPressed: _editName,
              icon: const Icon(Icons.edit_rounded),
              label: Text(s.childName.isEmpty ? 'Name your truck' : s.childName,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            ),
          ),

          // Play and garage.
          Positioned(
            right: 24,
            bottom: 20,
            child: Row(children: [
              if (s.everBuilt) ...[
                IconBubble(Icons.build_rounded,
                    size: 76, color: const Color(0xFF9B5DE5), onTap: _build),
                const SizedBox(width: 16),
              ],
              IconBubble(Icons.play_arrow_rounded,
                  size: 110,
                  color: const Color(0xFF2DC653),
                  glow: true,
                  onTap: _play),
            ]),
          ),
        ]);
      }),
    );
  }
}

class _HomeScenery extends CustomPainter {
  const _HomeScenery();

  @override
  void paint(Canvas canvas, Size size) => SceneryPainter().paint(canvas, size);

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
