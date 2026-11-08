import 'package:flutter/material.dart';

import '../art/scenery.dart';
import '../art/truck_art.dart';
import '../data/missions.dart';
import '../data/projects.dart';
import '../services/voice.dart';
import '../state/game_state.dart';
import '../widgets/fleet_art.dart';
import '../widgets/ui.dart';
import 'garage_screen.dart';
import 'vehicle_intro_screen.dart';

/// The child's fleet, parked in bays. Empty bays show the outline of
/// vehicles still to come.
class FleetScreen extends StatelessWidget {
  const FleetScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = GameScope.of(context);
    return Scaffold(
      body: LayoutBuilder(builder: (context, c) {
        final cols = 4;
        final bayW = (c.maxWidth - 120) / cols;
        final bayH = ((c.maxHeight - 110) / 2).clamp(80.0, bayW * 0.75);
        return Stack(children: [
          const Positioned.fill(child: CustomPaint(painter: GaragePainter())),
          Positioned(
            left: 60,
            right: 60,
            top: 96,
            child: Wrap(
              children: [
                for (final v in fleetOrder)
                  SizedBox(
                    width: bayW,
                    height: bayH,
                    child: GestureDetector(
                      onTap: () {
                        Sfx.tap();
                        if (!s.fleet.contains(v)) {
                          Voice.instance.say('A mystery vehicle! Help the town to find out what it is.');
                        } else if (v == VehicleType.towTruck) {
                          Navigator.of(context)
                              .push(MaterialPageRoute(builder: (_) => const GarageScreen()));
                        } else if (vehicleParts.containsKey(v)) {
                          Navigator.of(context).push(MaterialPageRoute(
                              builder: (_) => VehicleIntroScreen(type: v, joining: false)));
                        } else {
                          Voice.instance.say(vehicleJobs[v]!);
                        }
                      },
                      child: Container(
                        margin: const EdgeInsets.all(5),
                        padding: const EdgeInsets.fromLTRB(8, 6, 8, 4),
                        decoration: BoxDecoration(
                          color: fade(Colors.white, s.fleet.contains(v) ? 0.75 : 0.35),
                          border: const Border(
                            left: BorderSide(color: Colors.white, width: 4),
                            right: BorderSide(color: Colors.white, width: 4),
                            bottom: BorderSide(color: Colors.white, width: 6),
                          ),
                        ),
                        child: Column(children: [
                          Expanded(
                            child: SizedBox(
                              width: double.infinity,
                              child: fleetVehicleArt(s, v, silhouette: !s.fleet.contains(v)),
                            ),
                          ),
                          Text(
                            s.fleet.contains(v) ? vehicleNames[v]! : '?',
                            style: const TextStyle(
                                fontSize: 15, fontWeight: FontWeight.w900, color: kInk),
                          ),
                        ]),
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
                  title: 'My fleet', line: '${s.fleet.length} of ${fleetOrder.length} vehicles'),
            ),
          ),
          const Positioned(left: 20, top: 20, child: BackBubble()),
          const Positioned(right: 20, top: 20, child: StarCounter()),
        ]);
      }),
    );
  }
}
