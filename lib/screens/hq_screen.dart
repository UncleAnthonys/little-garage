import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../art/scenery.dart';
import '../art/town_art.dart';
import '../art/truck_art.dart';
import '../data/missions.dart';
import '../services/voice.dart';
import '../state/game_state.dart';
import '../widgets/ui.dart';
import 'drive_screen.dart';
import 'garage_screen.dart';
import 'mission_flow.dart';
import 'spot_screen.dart';

/// The town garage. The phone rings when someone needs help; the job board
/// shows every mission so favourites can be replayed.
class HqScreen extends StatefulWidget {
  const HqScreen({super.key});

  @override
  State<HqScreen> createState() => _HqScreenState();
}

class _HqScreenState extends State<HqScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _clock = AnimationController(
      vsync: this, duration: const Duration(seconds: 6))
    ..repeat();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _greet());
  }

  void _greet() {
    if (!mounted) return;
    final s = GameScope.read(context);
    final name = s.childName.isEmpty ? '' : ' ${s.childName}';
    Voice.instance.say(s.nextMission == null
        ? 'Hello$name! Every job is done. You are a super mechanic! Pick any job to play again.'
        : 'Hello$name! I\'m Gus. Ring ring! Someone needs help. Tap the phone!');
  }

  @override
  void dispose() {
    _clock.dispose();
    super.dispose();
  }

  Future<void> _open(Widget screen) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
  }

  @override
  Widget build(BuildContext context) {
    final s = GameScope.of(context);
    final next = s.nextMission;
    return Scaffold(
      body: LayoutBuilder(builder: (context, c) {
        final size = Size(c.maxWidth, c.maxHeight);
        final h = size.height;
        return AnimatedBuilder(
          animation: _clock,
          builder: (context, _) {
            return Stack(children: [
              const Positioned.fill(child: CustomPaint(painter: GaragePainter())),

              // Gus the owl, garage boss.
              Positioned(
                left: size.width * 0.03,
                top: h * 0.22,
                width: h * 0.34,
                height: h * 0.34,
                child: GestureDetector(
                  onTap: _greet,
                  child: CustomPaint(
                      painter: TownspersonPainter(gus, mood: 1, t: _clock.value * 6)),
                ),
              ),
              Positioned(
                left: size.width * 0.03,
                top: h * 0.56,
                width: h * 0.34,
                child: const Text('Gus',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: kInk)),
              ),

              // The phone.
              Positioned(
                left: size.width * 0.03 + h * 0.36,
                top: h * 0.2,
                width: h * 0.3,
                height: h * 0.3,
                child: GestureDetector(
                  onTap: () {
                    if (next != null) {
                      startMission(context, next);
                    } else {
                      Voice.instance.say('No calls right now. Pick a job from the board!');
                    }
                  },
                  child: CustomPaint(
                      painter: PhonePainter(ring: _clock.value, ringing: next != null)),
                ),
              ),

              // Job board.
              Positioned(
                right: size.width * 0.03,
                top: h * 0.14,
                bottom: h * 0.2,
                width: size.width * 0.44,
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFC9A66B),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: const Color(0xFF7A5230), width: 6),
                  ),
                  child: GridView.count(
                    crossAxisCount: 4,
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                    childAspectRatio: 1,
                    children: [
                      for (final m in missions)
                        _JobCard(
                          mission: m,
                          done: s.completed.contains(m.id),
                          unlocked: s.isUnlocked(m),
                          next: m == next,
                          wobble: math.sin(_clock.value * math.pi * 12),
                          onTap: () {
                            if (s.isUnlocked(m)) {
                              startMission(context, m);
                            } else {
                              Voice.instance.say('Finish the other jobs first!');
                            }
                          },
                        ),
                    ],
                  ),
                ),
              ),

              // Bottom row: my truck, free drive, spot it.
              Positioned(
                left: 20,
                bottom: 16,
                child: Row(children: [
                  BubbleButton(
                    size: 84,
                    color: const Color(0xFF9B5DE5),
                    onTap: () => _open(const GarageScreen()),
                    child: SizedBox(
                      width: 66,
                      height: 44,
                      child: CustomPaint(painter: VehiclePainter(lookFrom(s, built: allParts))),
                    ),
                  ),
                  const SizedBox(width: 14),
                  IconBubble(Icons.flag_rounded,
                      size: 72,
                      color: const Color(0xFF2DC653),
                      onTap: () => _open(const DriveScreen())),
                  const SizedBox(width: 14),
                  IconBubble(Icons.visibility_rounded,
                      size: 72,
                      color: const Color(0xFF2EC4B6),
                      onTap: () => _open(const SpotScreen())),
                ]),
              ),

              Positioned(
                top: 14,
                left: 0,
                right: size.width * 0.45,
                child: Center(
                  child: Text('${s.completed.length} of ${missions.length} jobs done',
                      style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: kInk,
                          shadows: [Shadow(color: Colors.white, blurRadius: 6)])),
                ),
              ),
              Positioned(
                  left: 20,
                  top: 20,
                  child: BackBubble(onTap: () => Navigator.of(context).popUntil((r) => r.isFirst))),
              Positioned(right: size.width * 0.03 + 8, bottom: 16, child: const StarCounter()),
            ]);
          },
        );
      }),
    );
  }
}

class _JobCard extends StatelessWidget {
  final Mission mission;
  final bool done, unlocked, next;
  final double wobble;
  final VoidCallback onTap;
  const _JobCard({
    required this.mission,
    required this.done,
    required this.unlocked,
    required this.next,
    required this.wobble,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = switch (mission.kind) {
      MissionKind.diagnose => const Color(0xFFE63946),
      MissionKind.dispatch => const Color(0xFF4C6EF5),
      MissionKind.drive => const Color(0xFF2DC653),
      MissionKind.carPark => const Color(0xFF6C757D),
      MissionKind.bus => const Color(0xFFFFB703),
    };
    return GestureDetector(
      onTap: () {
        Sfx.tap();
        onTap();
      },
      child: Transform.rotate(
        angle: next ? wobble * 0.06 : 0,
        child: Container(
          decoration: BoxDecoration(
            color: unlocked ? const Color(0xFFFFF8E1) : const Color(0xFFE0D6C2),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: next ? const Color(0xFFFFD23F) : Colors.transparent, width: 4),
            boxShadow: [BoxShadow(color: fade(Colors.black, 0.2), blurRadius: 3, offset: const Offset(1, 2))],
          ),
          child: Stack(children: [
            Center(
              child: Opacity(
                opacity: unlocked ? 1 : 0.3,
                child: Icon(mission.icon, size: 40, color: color),
              ),
            ),
            if (!unlocked)
              const Center(child: Icon(Icons.lock_rounded, size: 26, color: Color(0xFF6C757D))),
            if (done)
              const Positioned(
                  right: 2,
                  top: 2,
                  child: Icon(Icons.star_rounded, size: 22, color: Color(0xFFFF9F1C))),
          ]),
        ),
      ),
    );
  }
}
