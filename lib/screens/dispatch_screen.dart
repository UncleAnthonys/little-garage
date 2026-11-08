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

/// The right vehicle for the job. Wrong picks are told what they ARE for.
class DispatchScreen extends StatefulWidget {
  final Mission mission;
  const DispatchScreen({super.key, required this.mission});

  @override
  State<DispatchScreen> createState() => _DispatchScreenState();
}

class _DispatchScreenState extends State<DispatchScreen> with TickerProviderStateMixin {
  late final AnimationController _clock = AnimationController(
      vsync: this, duration: const Duration(seconds: 10))
    ..repeat();
  late final AnimationController _drive = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1800));
  late final AnimationController _solve = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 2200));

  late List<VehicleType> _choices;
  final Set<VehicleType> _tried = {};
  VehicleType? _sent;

  RescueInfo get _info => rescues[widget.mission.rescue!]!;

  @override
  void initState() {
    super.initState();
    final s = GameScope.read(context);
    final rnd = math.Random();
    final others = [..._info.others]..shuffle(rnd);
    _choices = [_info.answer, ...others.take(choicesFor(s.ageBand) - 1)]..shuffle(rnd);
    WidgetsBinding.instance.addPostFrameCallback((_) => Voice.instance.say(_info.problem));
  }

  @override
  void dispose() {
    _clock.dispose();
    _drive.dispose();
    _solve.dispose();
    super.dispose();
  }

  Future<void> _pick(VehicleType v) async {
    if (_sent != null) return;
    if (v != _info.answer) {
      setState(() => _tried.add(v));
      Voice.instance.say('${vehicleJobs[v]} Is that the right one for this job? Try another!');
      return;
    }
    Sfx.snap();
    setState(() => _sent = v);
    Voice.instance.say('Yes! Send the ${vehicleNames[v]}!');
    await _drive.forward();
    if (!mounted) return;
    Voice.instance.say(_info.solved);
    await _solve.forward();
    await Future<void>.delayed(const Duration(milliseconds: 1600));
    if (mounted) finishMission(context, widget.mission);
  }

  Widget _vehicleArt(GameState s, VehicleType v, double t, {double turn = 0}) {
    if (v == VehicleType.towTruck) {
      return CustomPaint(
          painter: VehiclePainter(lookFrom(s, built: allParts, wheelTurn: turn)));
    }
    return CustomPaint(painter: SimpleVehiclePainter(CarLook(type: v, t: t, wheelTurn: turn)));
  }

  @override
  Widget build(BuildContext context) {
    final s = GameScope.of(context);
    return Scaffold(
      body: LayoutBuilder(builder: (context, c) {
        final size = Size(c.maxWidth, c.maxHeight);
        final scene = Rect.fromLTWH(0, size.height * 0.04, size.width, size.height * 0.66);
        final cardW = math.min(size.width * 0.2, 220.0);

        return AnimatedBuilder(
          animation: Listenable.merge([_clock, _drive, _solve]),
          builder: (context, _) {
            final t = _clock.value * 10;
            final sent = _sent;
            final vw = scene.height * 0.62 * kSimpleW / kSimpleH;
            final arriveX = scene.width + 20 -
                Curves.easeOutCubic.transform(_drive.value) * (scene.width * 0.36 + vw * 0.5);
            return Stack(children: [
              Positioned.fill(child: CustomPaint(painter: SceneryPainter())),
              Positioned.fromRect(
                rect: scene,
                child: CustomPaint(
                    painter: RescueScenePainter(widget.mission.rescue!, t, _solve.value)),
              ),

              // The chosen vehicle drives in.
              if (sent != null)
                Positioned(
                  left: arriveX,
                  top: scene.bottom - scene.height * 0.62 - scene.height * 0.06,
                  width: vw,
                  height: scene.height * 0.62,
                  child: Transform.flip(
                    flipX: true,
                    child: _vehicleArt(s, sent, t, turn: -_drive.value * 14),
                  ),
                ),

              // Choices.
              if (sent == null)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 14,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      for (final v in _choices)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          child: GestureDetector(
                            onTap: () => _pick(v),
                            child: AnimatedOpacity(
                              opacity: _tried.contains(v) ? 0.4 : 1,
                              duration: const Duration(milliseconds: 200),
                              child: Container(
                                width: cardW,
                                height: cardW * 0.7,
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(22),
                                  border: Border.all(color: const Color(0xFF4C6EF5), width: 4),
                                  boxShadow: [
                                    BoxShadow(
                                        color: fade(Colors.black, 0.2),
                                        blurRadius: 6,
                                        offset: const Offset(0, 4)),
                                  ],
                                ),
                                child: _vehicleArt(s, v, t),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),

              Positioned(
                top: 14,
                left: 0,
                right: 0,
                child: Center(
                  child: PartBanner(
                    title: sent == null ? 'Who can help?' : 'On the way!',
                    line: sent == null ? 'Pick the right vehicle for the job' : null,
                  ),
                ),
              ),
              const Positioned(left: 20, top: 20, child: BackBubble()),
              const Positioned(right: 20, top: 20, child: StarCounter()),
              if (sent == null)
                Positioned(
                  right: 20,
                  top: 90,
                  child: IconBubble(Icons.replay_rounded,
                      size: 56,
                      color: const Color(0xFF4C6EF5),
                      onTap: () => Voice.instance.say(_info.problem)),
                ),
            ]);
          },
        );
      }),
    );
  }
}
