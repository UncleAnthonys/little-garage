import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../art/town_art.dart';
import '../art/town_map_art.dart';
import '../art/truck_art.dart';
import '../data/missions.dart';
import '../data/projects.dart';
import '../services/voice.dart';
import '../state/game_state.dart';
import '../widgets/ui.dart';
import 'drive_screen.dart';
import 'fleet_screen.dart';
import 'hq_screen.dart';
import 'project_screen.dart';

/// The child's town: a wide map that grows as projects are finished.
/// Unfinished projects wave for attention; the garage opens the phone jobs.
class TownScreen extends StatefulWidget {
  final bool firstVisit;
  const TownScreen({super.key, this.firstVisit = false});

  @override
  State<TownScreen> createState() => _TownScreenState();
}

class _TownScreenState extends State<TownScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _clock = AnimationController(
      vsync: this, duration: const Duration(seconds: 20))
    ..repeat();
  final ScrollController _scroll = ScrollController();
  double _scale = 1;
  bool _scrolled = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _greet());
  }

  @override
  void dispose() {
    _clock.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _greet() {
    if (!mounted) return;
    final s = GameScope.read(context);
    final open = s.openProjects;
    final name = s.childName.isEmpty ? 'your' : '${s.childName}\'s';
    if (open.isEmpty) {
      Voice.instance.say('Look at $name town! Every project is built. More are coming soon.');
    } else if (widget.firstVisit) {
      Voice.instance.say(
          'This is $name town! ${open.first.asker.name} needs help. Tap the hard hat sign to start. The phone at the garage rings with other jobs too!');
    } else {
      Voice.instance.say('${open.first.asker.name} needs help. Tap the hard hat sign!');
    }
  }

  /// Scrolls so the first open project is in view.
  void _scrollToWork(double viewW) {
    if (_scrolled || !_scroll.hasClients) return;
    _scrolled = true;
    final open = GameScope.read(context).openProjects;
    if (open.isEmpty) return;
    final target = (open.first.x * _scale - viewW / 2)
        .clamp(0.0, _scroll.position.maxScrollExtent);
    _scroll.animateTo(target, duration: const Duration(milliseconds: 1200), curve: Curves.easeInOut);
  }

  Future<void> _startProject(TownProject p) async {
    final s = GameScope.read(context);
    if (s.projectDone(p)) {
      Voice.instance.say('${p.title} is finished. Well done!');
      return;
    }
    Voice.instance.say('${p.asker.name} needs help! Drive there and collect stars on the way.');
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (ctx) => DriveScreen(
        course: DriveCourse(
          length: 2800,
          bumps: const [1100.0],
          trafficLights: p.area == Area.riverside ? const [1800.0] : const [],
          stars: DriveCourse.starsFor(2800),
        ),
        onFinished: () => Navigator.of(ctx).pushReplacement(
            MaterialPageRoute(builder: (_) => ProjectScreen(project: p))),
      ),
    ));
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final s = GameScope.of(context);
    final garageName = s.childName.isEmpty ? 'LITTLE GARAGE' : '${s.childName.toUpperCase()}\'S GARAGE';
    return Scaffold(
      body: LayoutBuilder(builder: (context, c) {
        _scale = c.maxHeight / kMapH;
        final mapW = kMapW * _scale;
        WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToWork(c.maxWidth));
        return Stack(children: [
          SingleChildScrollView(
            controller: _scroll,
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: mapW,
              height: c.maxHeight,
              child: AnimatedBuilder(
                animation: _clock,
                builder: (context, _) {
                  final t = _clock.value * 20;
                  return Stack(children: [
                    Positioned.fill(
                      child: CustomPaint(
                        painter: TownPainter(
                          TownState(
                            steps: s.projectSteps,
                            riversideOpen: s.areaOpen(Area.riverside),
                            garageName: garageName,
                          ),
                          t,
                        ),
                      ),
                    ),
                    // The garage: phone jobs.
                    Positioned(
                      left: (190 - 115) * _scale,
                      top: (kGroundY - 184) * _scale,
                      width: 230 * _scale,
                      height: 184 * _scale,
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => Navigator.of(context)
                            .push(MaterialPageRoute(builder: (_) => const HqScreen())),
                      ),
                    ),
                    if (s.nextMission != null)
                      Positioned(
                        left: 250 * _scale,
                        top: (kGroundY - 210) * _scale,
                        width: 70 * _scale,
                        height: 70 * _scale,
                        child: IgnorePointer(
                          child: CustomPaint(painter: PhonePainter(ring: t / 20, ringing: true)),
                        ),
                      ),
                    // Project signs.
                    for (final p in projects)
                      if (s.areaOpen(p.area))
                        Positioned(
                          left: p.x * _scale - 34,
                          top: (kGroundY - 250) * _scale +
                              (s.projectDone(p) ? 0 : math.sin(t * 3 + p.x) * 6),
                          child: s.projectDone(p)
                              ? IconBubble(Icons.star_rounded,
                                  size: 56,
                                  color: const Color(0xFFFFB703),
                                  onTap: () => _startProject(p))
                              : IconBubble(Icons.engineering_rounded,
                                  size: 68,
                                  color: const Color(0xFFFF8C42),
                                  glow: true,
                                  onTap: () => _startProject(p)),
                        ),
                  ]);
                },
              ),
            ),
          ),
          Positioned(
              left: 20,
              top: 20,
              child: BackBubble(onTap: () => Navigator.of(context).popUntil((r) => r.isFirst))),
          const Positioned(right: 20, top: 20, child: StarCounter()),
          Positioned(
            right: 20,
            bottom: 16,
            child: Row(children: [
              BubbleButton(
                size: 76,
                color: const Color(0xFF9B5DE5),
                onTap: () => Navigator.of(context)
                    .push(MaterialPageRoute(builder: (_) => const FleetScreen())),
                child: SizedBox(
                  width: 58,
                  height: 40,
                  child: CustomPaint(painter: VehiclePainter(lookFrom(s, built: allParts))),
                ),
              ),
              const SizedBox(width: 12),
              IconBubble(Icons.phone_in_talk_rounded,
                  size: 76,
                  color: const Color(0xFFE63946),
                  glow: s.nextMission != null,
                  onTap: () => Navigator.of(context)
                      .push(MaterialPageRoute(builder: (_) => const HqScreen()))),
            ]),
          ),
        ]);
      }),
    );
  }
}
