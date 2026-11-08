// Renders key screens to docs/shots/*.png so they can be checked by eye.
// Run: SHOTS=1 flutter test test/screenshots_test.dart --update-goldens
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:little_garage/data/missions.dart';
import 'package:little_garage/data/models.dart';
import 'package:little_garage/screens/assemble_screen.dart';
import 'package:little_garage/screens/bus_screen.dart';
import 'package:little_garage/screens/car_park_screen.dart';
import 'package:little_garage/screens/diagnose_screen.dart';
import 'package:little_garage/screens/dispatch_screen.dart';
import 'package:little_garage/screens/drive_screen.dart';
import 'package:little_garage/screens/home_screen.dart';
import 'package:little_garage/screens/hq_screen.dart';
import 'package:little_garage/screens/mission_flow.dart';
import 'package:little_garage/screens/route_screen.dart';

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
