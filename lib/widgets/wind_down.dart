import 'dart:async';

import 'package:flutter/material.dart';

import '../art/scenery.dart';
import '../art/truck_art.dart';
import '../services/voice.dart';
import '../state/game_state.dart';
import 'ui.dart';

/// Covers the app with a gentle "truck goes to sleep" scene when the
/// parent's wind-down timer runs out. No hard lock screen.
class WindDownGuard extends StatefulWidget {
  final Widget child;
  const WindDownGuard({super.key, required this.child});

  @override
  State<WindDownGuard> createState() => _WindDownGuardState();
}

class _WindDownGuardState extends State<WindDownGuard> {
  Timer? _timer;
  bool _showing = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 10), (_) => _check());
  }

  void _check() {
    if (!mounted) return;
    final s = GameScope.read(context);
    if (s.windDownDue && !_showing) {
      setState(() => _showing = true);
      final name = s.childName.isEmpty ? '' : ', ${s.childName}';
      Voice.instance.say(
          'The truck is sleepy$name. Time to park it in the garage. See you next time!');
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(children: [
      widget.child,
      if (_showing)
        Positioned.fill(
          child: _SleepScene(onMoreTime: () {
            GameScope.read(context).extendSession();
            setState(() => _showing = false);
          }),
        ),
    ]);
  }
}

/// Sits above the Navigator, so the grown-up question is shown inline
/// rather than as a dialog.
class _SleepScene extends StatefulWidget {
  final VoidCallback onMoreTime;
  const _SleepScene({required this.onMoreTime});

  @override
  State<_SleepScene> createState() => _SleepSceneState();
}

class _SleepSceneState extends State<_SleepScene> {
  bool _asking = false;

  @override
  Widget build(BuildContext context) {
    final s = GameScope.of(context);
    return Material(
      child: Stack(children: [
        Positioned.fill(child: CustomPaint(painter: SceneryPainter(night: true))),
        LayoutBuilder(builder: (context, c) {
          final h = c.maxHeight * 0.45;
          return Align(
            alignment: const Alignment(0, 0.35),
            child: SizedBox(
              width: h * kVehicleW / kVehicleH,
              height: h,
              child: CustomPaint(
                  painter: VehiclePainter(
                      lookFrom(s, built: allParts, sleeping: true))),
            ),
          );
        }),
        const Align(
          alignment: Alignment(0, -0.65),
          child: Text('Zzz… time to rest!',
              style: TextStyle(
                  fontSize: 44, fontWeight: FontWeight.w900, color: Colors.white)),
        ),
        Positioned(
          right: 20,
          bottom: 20,
          child: _asking
              ? Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                      color: Colors.white, borderRadius: BorderRadius.circular(16)),
                  child: ParentGatePanel(onResult: (ok) {
                    if (ok) widget.onMoreTime();
                  }),
                )
              : TextButton(
                  onPressed: () => setState(() => _asking = true),
                  child: const Text('Grown-ups: more time',
                      style: TextStyle(color: Colors.white70, fontSize: 16)),
                ),
        ),
      ]),
    );
  }
}
