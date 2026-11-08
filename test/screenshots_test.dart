// Renders key screens to docs/shots/*.png so they can be checked by eye.
// Run: SHOTS=1 flutter test test/screenshots_test.dart --update-goldens
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:little_garage/art/town_art.dart';
import 'package:little_garage/data/missions.dart';
import 'package:little_garage/data/models.dart';
import 'package:little_garage/screens/assemble_screen.dart';
import 'package:little_garage/screens/bus_screen.dart';
import 'package:little_garage/screens/car_park_screen.dart';
import 'package:little_garage/screens/delivery_screen.dart';
import 'package:little_garage/screens/diagnose_screen.dart';
import 'package:little_garage/screens/dispatch_screen.dart';
import 'package:little_garage/screens/drive_screen.dart';
import 'package:little_garage/screens/home_screen.dart';
import 'package:little_garage/screens/hq_screen.dart';
import 'package:little_garage/screens/mission_flow.dart';
import 'package:little_garage/screens/route_screen.dart';
import 'package:little_garage/data/projects.dart';
import 'package:little_garage/screens/fleet_screen.dart';
import 'package:little_garage/screens/project_screen.dart';
import 'package:little_garage/screens/town_screen.dart';
import 'package:little_garage/screens/vehicle_intro_screen.dart';

import 'helpers.dart';

final _on = Platform.environment['SHOTS'] == '1';

void main() {
  setUpAll(loadFonts);

  Future<void> shot(WidgetTester tester, String name, Widget screen,
      {Duration wait = const Duration(seconds: 3),
      Future<void> Function(WidgetTester)? act,
      void Function(dynamic)? prep}) async {
    await setSize(tester, phone);
    final s = await freshState(completed: {'flat_tyre', 'bakery_fire', 'flat_battery'});
    prep?.call(s);
    await tester.pumpWidget(host(s, screen));
    await run(tester, wait, steps: 30);
    if (act != null) await act(tester);
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('../docs/shots/$name.png'));
    await teardown(tester);
  }

  testWidgets('screenshots', skip: !_on, (tester) async {
    await shot(tester, '01_home', const HomeScreen());
    await shot(tester, '02_assemble', const AssembleScreen());
    await shot(tester, '03_hq', const HqScreen());
    await shot(tester, '04_call', CallScreen(mission: missionById('flat_battery')),
        act: (t) async {
      await t.tapAt(Offset(phone.width / 2, phone.height / 2));
      await run(t, const Duration(seconds: 1));
    });
    await shot(tester, '05_diagnose_battery', DiagnoseScreen(mission: missionById('flat_battery')));
    await shot(tester, '06_diagnose_electric', DiagnoseScreen(mission: missionById('electric_car')));
    await shot(tester, '07_diagnose_windscreen', DiagnoseScreen(mission: missionById('dirty_windscreen')));
    await shot(tester, '08_dispatch_fire', DispatchScreen(mission: missionById('bakery_fire')));
    await shot(tester, '09_dispatch_tree', DispatchScreen(mission: missionById('tree_down')));
    await shot(tester, '10_dispatch_crowd', DispatchScreen(mission: missionById('bus_stop')));
    await shot(tester, '11_route_map', RouteScreen(mission: missionById('muddy_tow')));
    await shot(tester, '12_route_clues', RouteScreen(mission: missionById('night_delivery')));
    await shot(tester, '13_car_park', CarParkScreen(mission: missionById('car_park')));
    await shot(tester, '14_bus', BusScreen(mission: missionById('bus_count')));
    await shot(tester, '15_complete', MissionCompleteScreen(mission: missionById('tree_down')));
    await shot(tester, '28_post_round', DeliveryScreen(mission: missionById('post_round')),
        act: (t) async {
      final g = await t.startGesture(Offset(phone.width - 80, phone.height - 70));
      await run(t, const Duration(milliseconds: 1700), steps: 34);
      await g.up();
      await run(t, const Duration(seconds: 1), steps: 20);
    });
    await shot(tester, '29_fragile_eggs', DeliveryScreen(mission: missionById('egg_delivery')),
        act: (t) async {
      final g = await t.startGesture(Offset(phone.width - 80, phone.height - 70));
      await run(t, const Duration(milliseconds: 3200), steps: 64);
      await g.up();
      await run(t, const Duration(milliseconds: 300), steps: 6);
    });
    await shot(tester, '20_town_start', const TownScreen(), wait: const Duration(seconds: 4));
    await shot(tester, '21_town_grown', const TownScreen(), wait: const Duration(seconds: 4), prep: (s) {
      for (final p in projects) {
        s.projectSteps[p.id] = p.steps.length;
      }
      s.addToFleet(VehicleType.digger);
    });
    await shot(tester, '22_fleet', const FleetScreen(), prep: (s) {
      s.addToFleet(VehicleType.digger);
      s.addToFleet(VehicleType.dumpTruck);
    });
    await shot(tester, '23_project_choose', ProjectScreen(project: projectById('bramble_house')));
    await shot(tester, '24_project_bridge_mid', ProjectScreen(project: projectById('river_bridge')),
        prep: (s) => s.projectSteps['river_bridge'] = 2);
    await shot(tester, '25_intro_crane', const VehicleIntroScreen(type: VehicleType.craneTruck));
    await shot(tester, '26_intro_digger_midbuild', const VehicleIntroScreen(type: VehicleType.digger),
        act: (t) async {
      final area = VehicleIntroScreen.areaFor(phone);
      final card = VehicleIntroScreen.cardFor(phone);
      final scale = area.width / kSimpleW;
      for (final part in vehicleParts[VehicleType.digger]!.take(2)) {
        final target = area.topLeft + part.area.center * scale + const Offset(0, 24);
        await t.dragFrom(card.center, target - card.center);
        await run(t, const Duration(seconds: 3));
      }
    });
    await shot(tester, '27_project_park_mid', ProjectScreen(project: projectById('riverside_park')),
        prep: (s) => s.projectSteps['riverside_park'] = 2);

    // Drives: hold the pedal to reach the interesting part.
    Future<void> hold(WidgetTester t, Duration d) async {
      final g = await t.startGesture(const Offset(420, 120));
      await run(t, d, steps: (d.inMilliseconds / 16).round());
      await g.up();
      await t.pump(const Duration(milliseconds: 50));
    }

    await shot(tester, '16_drive_bridge',
        DriveScreen(course: missionById('low_bridge').course, onFinished: () {}),
        act: (t) => hold(t, const Duration(seconds: 9)));
    await shot(tester, '17_drive_night_light',
        DriveScreen(course: missionById('night_delivery').course, onFinished: () {}),
        act: (t) => hold(t, const Duration(seconds: 7)));
    await shot(tester, '18_drive_mud',
        DriveScreen(course: missionById('muddy_tow').course, onFinished: () {}),
        act: (t) => hold(t, const Duration(seconds: 6)),
        prep: (s) => s.setWheels(WheelStyle.classic));
  });
}
