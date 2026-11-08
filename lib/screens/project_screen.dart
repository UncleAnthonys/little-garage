import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../art/scenery.dart';
import '../art/town_art.dart';
import '../art/town_map_art.dart';
import '../art/truck_art.dart';
import '../data/missions.dart';
import '../data/projects.dart';
import '../services/voice.dart';
import '../state/game_state.dart';
import '../widgets/fleet_art.dart';
import '../widgets/ui.dart';
import 'vehicle_intro_screen.dart';

enum _Phase { choose, work, stepDone, finished }

/// A town project, one step at a time. The child decides which vehicle the
/// job needs next; picking a later vehicle explains what has to happen
/// first, so the order of building is the lesson.
class ProjectScreen extends StatefulWidget {
  final TownProject project;
  const ProjectScreen({super.key, required this.project});

  @override
  State<ProjectScreen> createState() => _ProjectScreenState();
}

class _ProjectScreenState extends State<ProjectScreen> with TickerProviderStateMixin {
  late final AnimationController _clock = AnimationController(
      vsync: this, duration: const Duration(seconds: 10))
    ..repeat();
  late final AnimationController _bounce = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 260));

  _Phase _phase = _Phase.choose;
  double _progress = 0;
  bool _holding = false;
  Timer? _holdTimer;
  final Set<VehicleType> _tried = {};
  int _wrong = 0;
  int _burst = 0;
  late final List<VehicleType> _choices = [...widget.project.choices]..shuffle(math.Random());

  TownProject get _p => widget.project;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _askNext(first: true));
  }

  @override
  void dispose() {
    _holdTimer?.cancel();
    _clock.dispose();
    _bounce.dispose();
    super.dispose();
  }

  ProjectStep? get _step {
    final done = GameScope.read(context).stepsDone(_p);
    return done < _p.steps.length ? _p.steps[done] : null;
  }

  void _askNext({bool first = false}) {
    final s = GameScope.read(context);
    final done = s.stepsDone(_p);
    _tried.clear();
    _wrong = 0;
    if (first) {
      Voice.instance.say('${_p.ask} What should we do ${done == 0 ? 'first' : 'next'}? Pick a vehicle!');
    } else {
      Voice.instance.say('What do we need to do next? Pick a vehicle!');
    }
    setState(() => _phase = _Phase.choose);
  }

  Future<void> _pick(VehicleType v) async {
    final step = _step;
    if (_phase != _Phase.choose || step == null) return;
    final s = GameScope.read(context);
    if (v != step.vehicle) {
      setState(() => _tried.add(v));
      _wrong++;
      final later = _p.steps.skip(s.stepsDone(_p)).any((st) => st.vehicle == v);
      final name = vehicleNames[v]!;
      final reason = later
          ? 'We will need the $name soon, but not yet!'
          : 'We don\'t need the $name for this job.';
      Voice.instance.say('$reason First we need to ${step.task}. Which vehicle can do that?');
      return;
    }
    // A vehicle the child doesn't have yet joins the fleet first.
    if (!s.fleet.contains(v)) {
      Voice.instance.say('Yes! We need a ${vehicleNames[v]}. Let\'s get one!');
      final joined = await Navigator.of(context).push<bool>(
          MaterialPageRoute(builder: (_) => VehicleIntroScreen(type: v)));
      if (!mounted || joined != true) return;
    } else {
      Voice.instance.say('Yes! The ${vehicleNames[v]} can ${step.task}.');
    }
    Sfx.snap();
    setState(() {
      _phase = _Phase.work;
      _progress = 0;
    });
    Future<void>.delayed(const Duration(milliseconds: 1600), () {
      if (mounted && _phase == _Phase.work) Voice.instance.say(step.doing);
    });
  }

  void _workTap() {
    final step = _step;
    if (_phase != _Phase.work || step == null || step.work != Work.tap) return;
    Sfx.tap();
    _bounce.forward(from: 0);
    setState(() => _progress = math.min(1, _progress + 1 / 6));
    if (_progress >= 0.999) _stepDone();
  }

  void _holdStart() {
    final step = _step;
    if (_phase != _Phase.work || step == null || step.work != Work.hold) return;
    _holding = true;
    _holdTimer?.cancel();
    _holdTimer = Timer.periodic(const Duration(milliseconds: 50), (_) {
      if (!mounted || !_holding) return;
      setState(() => _progress = math.min(1, _progress + 0.02));
      if (_progress >= 0.999) {
        _holdTimer?.cancel();
        _stepDone();
      }
    });
  }

  void _holdEnd() {
    _holding = false;
    _holdTimer?.cancel();
  }

  Future<void> _stepDone() async {
    final step = _step!;
    final s = GameScope.read(context);
    s.finishStep(_p);
    setState(() {
      _phase = _Phase.stepDone;
      _progress = 0;
    });
    Voice.instance.say('Well done! ${step.done}');
    await Future<void>.delayed(const Duration(milliseconds: 3200));
    if (!mounted) return;
    if (s.projectDone(_p)) {
      setState(() {
        _phase = _Phase.finished;
        _burst++;
      });
      final name = s.childName.isEmpty ? '' : ', ${s.childName}';
      Voice.instance.say('${_p.finished} Thank you$name! Five stars!');
    } else {
      _askNext();
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = GameScope.of(context);
    final done = s.stepsDone(_p);
    final step = done < _p.steps.length ? _p.steps[done] : null;
    return Scaffold(
      body: LayoutBuilder(builder: (context, c) {
        final size = Size(c.maxWidth, c.maxHeight);
        final cardW = math.min(math.min(size.width * 0.19, 200.0), size.height * 0.26 / 0.7);
        final cardsTop = size.height - 12 - cardW * 0.7;
        const top = 100.0;
        final scene = Rect.fromLTWH(0, top, size.width, (cardsTop - top - 6).clamp(120.0, 1000.0));
        return AnimatedBuilder(
          animation: Listenable.merge([_clock, _bounce]),
          builder: (context, _) {
            final t = _clock.value * 10;
            final siteProgress = _phase == _Phase.work ? _progress : 0.0;
            final children = <Widget>[
              Positioned.fill(child: CustomPaint(painter: SceneryPainter())),
              Positioned.fromRect(
                rect: scene,
                child: CustomPaint(painter: ProjectSitePainter(_p, done, siteProgress, t)),
              ),
            ];

            // The working vehicle, beside the site. Tap or hold it.
            if (_phase == _Phase.work && step != null) {
              final vw = math.min(scene.width * 0.32, scene.height * 0.8 * kSimpleW / kSimpleH);
              final vh = vw * kSimpleH / kSimpleW;
              final bob = math.sin(_bounce.value * math.pi) * -10 +
                  (_holding ? math.sin(t * 40) * 2 : 0);
              children.add(Positioned(
                left: size.width * 0.04,
                top: scene.top + scene.height * 0.72 - vh * 0.9 + bob,
                width: vw,
                height: vh,
                child: Listener(
                  onPointerDown: (_) => _holdStart(),
                  onPointerUp: (_) => _holdEnd(),
                  onPointerCancel: (_) => _holdEnd(),
                  child: GestureDetector(
                    onTap: _workTap,
                    child: fleetVehicleArt(s, step.vehicle, t: t, turn: _progress * 6),
                  ),
                ),
              ));
              // Progress meter.
              children.add(Positioned(
                left: size.width * 0.3,
                right: size.width * 0.3,
                bottom: 20,
                child: Container(
                  height: 30,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: kInk, width: 3),
                  ),
                  child: FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: _progress.clamp(0.02, 1.0),
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF2DC653),
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ));
            }

            // Vehicle choices.
            if (_phase == _Phase.choose) {
              children.add(Positioned(
                left: 0,
                right: 0,
                bottom: 12,
                child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  for (final v in _choices)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: GestureDetector(
                        onTap: () => _pick(v),
                        child: AnimatedOpacity(
                          opacity: _tried.contains(v) ? 0.4 : 1,
                          duration: const Duration(milliseconds: 200),
                          child: Container(
                            width: cardW,
                            height: cardW * 0.7,
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                  color: _wrong >= 2 && step?.vehicle == v
                                      ? const Color(0xFFFFD23F)
                                      : const Color(0xFF4C6EF5),
                                  width: _wrong >= 2 && step?.vehicle == v ? 6 : 4),
                            ),
                            child: Stack(children: [
                              Positioned.fill(child: fleetVehicleArt(s, v, t: t)),
                              if (!s.fleet.contains(v))
                                Positioned(
                                  right: 0,
                                  top: 0,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFE63946),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Text('NEW',
                                        style: TextStyle(
                                            fontSize: 12, fontWeight: FontWeight.w900, color: Colors.white)),
                                  ),
                                ),
                            ]),
                          ),
                        ),
                      ),
                    ),
                ]),
              ));
            }

            if (_phase == _Phase.finished) {
              children.add(Positioned(
                right: 24,
                bottom: 18,
                child: IconBubble(Icons.map_rounded,
                    size: 96,
                    color: const Color(0xFF2DC653),
                    glow: true,
                    onTap: () => Navigator.of(context).maybePop()),
              ));
              children.add(Positioned(
                left: 24,
                bottom: 18,
                child: Container(
                  width: size.height * 0.26,
                  height: size.height * 0.26,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFFFFD23F), width: 5),
                  ),
                  child: CustomPaint(painter: TownspersonPainter(_p.asker, mood: 1)),
                ),
              ));
            }

            final String title;
            final String? line;
            switch (_phase) {
              case _Phase.choose:
                title = done == 0 ? 'What first?' : 'What next?';
                line = '${_p.title}: step ${done + 1} of ${_p.steps.length}';
              case _Phase.work:
                title = step == null ? '' : _cap(step.task);
                line = step?.work == Work.hold ? 'Press and hold the vehicle' : 'Tap the vehicle';
              case _Phase.stepDone:
                title = 'Well done!';
                line = '${_p.title}: $done of ${_p.steps.length} done';
              case _Phase.finished:
                title = '${_p.title} is finished!';
                line = '+5 stars';
            }

            children.addAll([
              Positioned(
                top: 14,
                left: 0,
                right: 0,
                child: Center(child: PartBanner(title: title, line: line)),
              ),
              const Positioned(left: 20, top: 20, child: BackBubble()),
              const Positioned(right: 20, top: 20, child: StarCounter()),
              if (_phase == _Phase.choose)
                Positioned(
                  right: 20,
                  top: 90,
                  child: IconBubble(Icons.replay_rounded,
                      size: 52,
                      color: const Color(0xFF4C6EF5),
                      onTap: () => Voice.instance.say(_wrong > 0 && step != null
                          ? 'We need to ${step.task}.'
                          : _p.ask)),
                ),
              Positioned.fill(child: StarBurst(trigger: _burst)),
            ]);
            return Stack(children: children);
          },
        );
      }),
    );
  }

  String _cap(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
}
