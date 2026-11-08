import 'package:flutter/material.dart';

import '../art/scenery.dart';
import '../art/town_art.dart';
import '../art/truck_art.dart';
import '../data/missions.dart';
import '../services/voice.dart';
import '../state/game_state.dart';
import '../widgets/ui.dart';
import 'bus_screen.dart';
import 'car_park_screen.dart';
import 'delivery_screen.dart';
import 'diagnose_screen.dart';
import 'dispatch_screen.dart';
import 'drive_screen.dart';
import 'route_screen.dart';

/// Starts a mission: the phone call first, then the job itself.
Future<void> startMission(BuildContext context, Mission m) => Navigator.of(context)
    .push(MaterialPageRoute(builder: (_) => CallScreen(mission: m)));

/// Swaps the current screen for the mission's job screen.
void openMissionJob(BuildContext context, Mission m) {
  final Widget job = switch (m.kind) {
    MissionKind.diagnose => DiagnoseScreen(mission: m),
    MissionKind.dispatch => DispatchScreen(mission: m),
    MissionKind.drive => RouteScreen(mission: m),
    MissionKind.carPark => CarParkScreen(mission: m),
    MissionKind.bus => BusScreen(mission: m),
    MissionKind.delivery => DeliveryScreen(mission: m),
  };
  Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => job));
}

/// Swaps a route screen for the drive.
void openMissionDrive(BuildContext context, Mission m) {
  Navigator.of(context).pushReplacement(MaterialPageRoute(
    builder: (ctx) => DriveScreen(
      course: m.course,
      onFinished: () => finishMission(ctx, m),
    ),
  ));
}

/// Swaps the job screen for the celebration.
void finishMission(BuildContext context, Mission m) {
  GameScope.read(context).completeMission(m);
  Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => MissionCompleteScreen(mission: m)));
}

// ---------------------------------------------------------------------------

/// Ring ring! The caller explains their problem.
class CallScreen extends StatefulWidget {
  final Mission mission;
  const CallScreen({super.key, required this.mission});

  @override
  State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _t = AnimationController(
      vsync: this, duration: const Duration(seconds: 6))
    ..repeat();
  bool _answered = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => Voice.instance.say('Ring ring! Tap the phone to answer.'));
  }

  @override
  void dispose() {
    _t.dispose();
    super.dispose();
  }

  void _answer() {
    setState(() => _answered = true);
    Voice.instance.say(widget.mission.call);
  }

  @override
  Widget build(BuildContext context) {
    final m = widget.mission;
    return Scaffold(
      body: LayoutBuilder(builder: (context, c) {
        final h = c.maxHeight;
        return Stack(children: [
          const Positioned.fill(child: CustomPaint(painter: GaragePainter())),
          if (!_answered)
            Center(
              child: GestureDetector(
                onTap: _answer,
                child: AnimatedBuilder(
                  animation: _t,
                  builder: (context, _) => SizedBox(
                    width: h * 0.45,
                    height: h * 0.45,
                    child: CustomPaint(painter: PhonePainter(ring: _t.value, ringing: true)),
                  ),
                ),
              ),
            )
          else
            Center(
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                AnimatedBuilder(
                  animation: _t,
                  builder: (context, _) => Container(
                    width: h * 0.42,
                    height: h * 0.42,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFF4C6EF5), width: 6),
                    ),
                    child: CustomPaint(
                      painter: TownspersonPainter(m.caller,
                          mood: -0.5, talking: true, t: _t.value * 6),
                    ),
                  ),
                ),
                const SizedBox(width: 24),
                Container(
                  constraints: BoxConstraints(maxWidth: c.maxWidth * 0.42),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: kInk, width: 3),
                  ),
                  child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(m.caller.name,
                        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: kInk)),
                    const SizedBox(height: 6),
                    Text(m.call,
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: Color(0xFF4A4E69))),
                  ]),
                ),
              ]),
            ),
          const Positioned(left: 20, top: 20, child: BackBubble()),
          if (_answered)
            Positioned(
              right: 24,
              bottom: 20,
              child: Row(children: [
                IconBubble(Icons.replay_rounded,
                    size: 64, color: const Color(0xFF4C6EF5), onTap: () => Voice.instance.say(m.call)),
                const SizedBox(width: 16),
                IconBubble(Icons.check_rounded,
                    size: 100,
                    color: const Color(0xFF2DC653),
                    glow: true,
                    onTap: () {
                      Voice.instance.say("Let's go!");
                      openMissionJob(context, m);
                    }),
              ]),
            ),
        ]);
      }),
    );
  }
}

// ---------------------------------------------------------------------------

/// Job done: a happy caller, stars, a wow fact, and an idea for grown-ups.
class MissionCompleteScreen extends StatefulWidget {
  final Mission mission;
  const MissionCompleteScreen({super.key, required this.mission});

  @override
  State<MissionCompleteScreen> createState() => _MissionCompleteScreenState();
}

class _MissionCompleteScreenState extends State<MissionCompleteScreen> {
  int _burst = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      setState(() => _burst++);
      final s = GameScope.read(context);
      final name = s.childName.isEmpty ? '' : ', ${s.childName}';
      Voice.instance.say('Thank you$name! You fixed it! ${widget.mission.wow}');
    });
  }

  @override
  Widget build(BuildContext context) {
    final m = widget.mission;
    return Scaffold(
      body: LayoutBuilder(builder: (context, c) {
        final h = c.maxHeight;
        return Stack(children: [
          Positioned.fill(child: CustomPaint(painter: SceneryPainter())),
          Align(
            alignment: const Alignment(0, -0.35),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Container(
                width: h * 0.36,
                height: h * 0.36,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFFFFD23F), width: 6),
                ),
                child: CustomPaint(painter: TownspersonPainter(m.caller, mood: 1)),
              ),
              const SizedBox(width: 24),
              Container(
                constraints: BoxConstraints(maxWidth: c.maxWidth * 0.5),
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: const Color(0xFFFFD23F), width: 4),
                ),
                child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Job done! +3 stars',
                      style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: kInk)),
                  const SizedBox(height: 6),
                  Text(m.wow,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Color(0xFF4A4E69))),
                ]),
              ),
            ]),
          ),
          // For the grown-up: carry it into real life.
          Positioned(
            left: 24,
            bottom: 20,
            child: Container(
              constraints: BoxConstraints(maxWidth: c.maxWidth * 0.55),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: fade(Colors.white, 0.9),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.family_restroom_rounded, color: Color(0xFF4C6EF5), size: 30),
                const SizedBox(width: 10),
                Flexible(
                  child: Text('Grown-ups: ${m.grownUp}',
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: kInk)),
                ),
              ]),
            ),
          ),
          Positioned(
            right: 24,
            bottom: 20,
            child: IconBubble(Icons.home_repair_service_rounded,
                size: 100,
                color: const Color(0xFF2DC653),
                glow: true,
                onTap: () => Navigator.of(context).maybePop()),
          ),
          const Positioned(right: 20, top: 20, child: StarCounter()),
          Positioned.fill(child: StarBurst(trigger: _burst)),
        ]);
      }),
    );
  }
}
