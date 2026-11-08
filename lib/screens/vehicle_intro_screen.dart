import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../art/scenery.dart';
import '../art/town_art.dart';
import '../art/truck_art.dart';
import '../data/missions.dart';
import '../data/projects.dart';
import '../services/voice.dart';
import '../state/game_state.dart';
import '../widgets/fleet_art.dart';
import '../widgets/ui.dart';

/// A new vehicle arrives. The child taps each part to hear what it does,
/// then adds the vehicle to their fleet. Also used to revisit owned ones.
class VehicleIntroScreen extends StatefulWidget {
  final VehicleType type;

  /// True when it joins the fleet at the end; false just to learn about it.
  final bool joining;
  const VehicleIntroScreen({super.key, required this.type, this.joining = true});

  @override
  State<VehicleIntroScreen> createState() => _VehicleIntroScreenState();
}

class _VehicleIntroScreenState extends State<VehicleIntroScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _clock = AnimationController(
      vsync: this, duration: const Duration(seconds: 10))
    ..repeat();
  final Set<int> _learned = {};
  int? _showing;
  int _burst = 0;

  List<VehiclePart> get _parts => vehicleParts[widget.type] ?? const [];
  String get _name => vehicleNames[widget.type]!;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Voice.instance.say(widget.joining
          ? 'A new vehicle! It\'s a $_name. Tap each glowing part to find out what it does.'
          : 'The $_name. Tap a part to hear what it does.');
    });
  }

  @override
  void dispose() {
    _clock.dispose();
    super.dispose();
  }

  void _tap(Offset local, Rect box) {
    final s = math.min(box.width / kSimpleW, box.height / kSimpleH);
    final origin = Offset((box.width - kSimpleW * s) / 2, (box.height - kSimpleH * s) / 2);
    final v = (local - origin) / s;
    for (var i = 0; i < _parts.length; i++) {
      if (_parts[i].area.inflate(6).contains(v)) {
        Sfx.tap();
        setState(() {
          _learned.add(i);
          _showing = i;
        });
        Voice.instance.say('${_parts[i].name}! ${_parts[i].line}');
        if (_learned.length == _parts.length && widget.joining) {
          Future<void>.delayed(const Duration(seconds: 4), () {
            if (mounted) Voice.instance.say('You know every part! Add the $_name to your fleet.');
          });
        }
        return;
      }
    }
  }

  void _join() {
    GameScope.read(context).addToFleet(widget.type);
    setState(() => _burst++);
    Voice.instance.say('The $_name joined your fleet!');
    Future<void>.delayed(const Duration(milliseconds: 1500), () {
      if (mounted) Navigator.of(context).pop(true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = GameScope.of(context);
    final allDone = _learned.length >= _parts.length;
    return Scaffold(
      body: LayoutBuilder(builder: (context, c) {
        final size = Size(c.maxWidth, c.maxHeight);
        const top = 104.0;
        final maxH = size.height - top - 110;
        final w = math.min(size.width * 0.62, maxH * kSimpleW / kSimpleH);
        final h = w * kSimpleH / kSimpleW;
        final box = Rect.fromLTWH((size.width - w) / 2, top + (maxH - h) / 2, w, h);
        final scale = w / kSimpleW;
        final part = _showing == null ? null : _parts[_showing!];
        return AnimatedBuilder(
          animation: _clock,
          builder: (context, _) {
            final t = _clock.value * 10;
            return Stack(children: [
              const Positioned.fill(child: CustomPaint(painter: GaragePainter())),
              Positioned.fromRect(
                rect: box,
                child: GestureDetector(
                  onTapUp: (d) => _tap(d.localPosition, Rect.fromLTWH(0, 0, w, h)),
                  child: fleetVehicleArt(s, widget.type, t: t),
                ),
              ),
              // Glowing dots on parts not yet learned.
              for (var i = 0; i < _parts.length; i++)
                if (!_learned.contains(i))
                  Positioned(
                    left: box.left + _parts[i].area.center.dx * scale - 16,
                    top: box.top + _parts[i].area.center.dy * scale - 16,
                    width: 32,
                    height: 32,
                    child: IgnorePointer(
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: fade(const Color(0xFFFFE066), 0.45 + 0.4 * math.sin(t * 6 + i).abs()),
                          border: Border.all(color: Colors.white, width: 3),
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
                    title: part?.name ?? (widget.joining ? 'New: ${_cap(_name)}!' : _cap(_name)),
                    line: part?.line ?? 'Tap the glowing parts',
                  ),
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 18,
                child: Center(
                  child: Text('${_learned.length} of ${_parts.length} parts',
                      style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          color: kInk,
                          shadows: [Shadow(color: Colors.white, blurRadius: 6)])),
                ),
              ),
              if (widget.joining && allDone)
                Positioned(
                  right: 24,
                  bottom: 18,
                  child: IconBubble(Icons.add_rounded,
                      size: 96, color: const Color(0xFF2DC653), glow: true, onTap: _join),
                ),
              Positioned(left: 20, top: 20, child: BackBubble(onTap: () => Navigator.of(context).pop(false))),
              Positioned.fill(child: StarBurst(trigger: _burst)),
            ]);
          },
        );
      }),
    );
  }

  String _cap(String s) => s[0].toUpperCase() + s.substring(1);
}
