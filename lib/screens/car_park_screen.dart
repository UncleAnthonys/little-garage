import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../art/town_art.dart';
import '../art/truck_art.dart';
import '../data/missions.dart';
import '../services/voice.dart';
import '../state/game_state.dart';
import '../widgets/ui.dart';
import 'mission_flow.dart';

const _parkColors = <(String, Color)>[
  ('red', Color(0xFFE63946)),
  ('blue', Color(0xFF3A86FF)),
  ('yellow', Color(0xFFFFB703)),
  ('green', Color(0xFF2DC653)),
];

/// Sorting by colour: park every car in the space that matches it, then
/// count them together. Builds on kids' love of lining cars up.
class CarParkScreen extends StatefulWidget {
  final Mission mission;
  const CarParkScreen({super.key, required this.mission});

  @override
  State<CarParkScreen> createState() => _CarParkScreenState();
}

class _CarParkScreenState extends State<CarParkScreen> {
  late final List<int> _cars; // colour index per car
  late final List<int?> _bays; // car index parked in each bay
  late final List<int> _bayColour;
  int _burst = 0;
  bool _done = false;
  int? _wrongBay;

  @override
  void initState() {
    super.initState();
    final band = GameScope.read(context).ageBand;
    final colours = switch (band) {
      AgeBand.little => 2,
      AgeBand.middle => 3,
      AgeBand.big => 4,
    };
    const perColour = 2;
    _bayColour = [for (var c = 0; c < colours; c++) for (var i = 0; i < perColour; i++) c];
    _cars = [..._bayColour]..shuffle(math.Random());
    _bays = List.filled(_bayColour.length, null);
    WidgetsBinding.instance.addPostFrameCallback((_) => Voice.instance.say(
        'Drag each car into a space that matches its colour!'));
  }

  bool _parked(int car) => _bays.contains(car);

  void _drop(int car, int bay) {
    if (_bays[bay] != null) return;
    final cName = _parkColors[_cars[car]].$1;
    if (_cars[car] != _bayColour[bay]) {
      setState(() => _wrongBay = bay);
      Voice.instance.say('That\'s a $cName car. Find a $cName space!');
      Future<void>.delayed(const Duration(milliseconds: 600), () {
        if (mounted) setState(() => _wrongBay = null);
      });
      return;
    }
    Sfx.snap();
    setState(() => _bays[bay] = car);
    Voice.instance.say('$cName!');
    if (!_bays.contains(null)) _finish();
  }

  Future<void> _finish() async {
    setState(() {
      _done = true;
      _burst++;
    });
    final counts = <String>[];
    for (var c = 0; c < _parkColors.length; c++) {
      final n = _bayColour.where((b) => b == c).length;
      if (n > 0) counts.add('$n ${_parkColors[c].$1}');
    }
    Voice.instance.say(
        'All parked! Let\'s count: ${counts.join(', ')}. That\'s ${_cars.length} cars altogether!');
    await Future<void>.delayed(const Duration(milliseconds: 5200));
    if (mounted) finishMission(context, widget.mission);
  }

  Widget _car(int car, double w) => SizedBox(
        width: w,
        height: w * kSimpleH / kSimpleW,
        child: CustomPaint(
          painter: SimpleVehiclePainter(CarLook(color: _parkColors[_cars[car]].$2)),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LayoutBuilder(builder: (context, c) {
        final size = Size(c.maxWidth, c.maxHeight);
        final n = _bays.length;
        final bayW = math.min(size.width * 0.8 / n, 170.0);
        final carW = bayW * 0.82;
        return Stack(children: [
          const Positioned.fill(child: ColoredBox(color: Color(0xFF6B6880))),
          // Bays.
          Positioned(
            left: 0,
            right: 0,
            top: size.height * 0.2,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var b = 0; b < n; b++)
                  DragTarget<int>(
                    onWillAcceptWithDetails: (d) => _bays[b] == null,
                    onAcceptWithDetails: (d) => _drop(d.data, b),
                    builder: (context, cand, rej) {
                      final col = _parkColors[_bayColour[b]].$2;
                      final parked = _bays[b];
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        width: bayW,
                        height: bayW * 1.05,
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        decoration: BoxDecoration(
                          color: _wrongBay == b
                              ? fade(const Color(0xFFE63946), 0.25)
                              : cand.isNotEmpty
                                  ? fade(col, 0.35)
                                  : fade(col, 0.15),
                          border: Border(
                            left: BorderSide(color: Colors.white, width: b == 0 ? 6 : 3),
                            right: const BorderSide(color: Colors.white, width: 3),
                            top: BorderSide(color: col, width: 12),
                          ),
                        ),
                        alignment: Alignment.center,
                        child: parked == null
                            ? Icon(Icons.local_parking, size: bayW * 0.4, color: fade(col, 0.6))
                            : _car(parked, carW),
                      );
                    },
                  ),
              ],
            ),
          ),
          // Cars waiting to park.
          Positioned(
            left: 0,
            right: 0,
            bottom: 16,
            child: _done
                ? const SizedBox()
                : Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 12,
                    runSpacing: 8,
                    children: [
                      for (var i = 0; i < _cars.length; i++)
                        if (!_parked(i))
                          Draggable<int>(
                            data: i,
                            feedback: Material(color: Colors.transparent, child: _car(i, carW * 1.1)),
                            childWhenDragging: Opacity(opacity: 0.25, child: _car(i, carW)),
                            onDragStarted: () => Voice.instance.say('${_parkColors[_cars[i]].$1} car'),
                            child: _car(i, carW),
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
                title: _done ? 'All parked!' : 'Car park',
                line: _done ? null : 'Match each car to its colour',
              ),
            ),
          ),
          const Positioned(left: 20, top: 20, child: BackBubble()),
          const Positioned(right: 20, top: 20, child: StarCounter()),
          Positioned.fill(child: StarBurst(trigger: _burst)),
        ]);
      }),
    );
  }
}
