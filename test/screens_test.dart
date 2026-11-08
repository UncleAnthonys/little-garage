import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:little_garage/art/town_art.dart';
import 'package:little_garage/data/missions.dart';
import 'package:little_garage/screens/assemble_screen.dart';
import 'package:little_garage/screens/bus_screen.dart';
import 'package:little_garage/screens/car_park_screen.dart';
import 'package:little_garage/screens/customise_screen.dart';
import 'package:little_garage/screens/diagnose_screen.dart';
import 'package:little_garage/screens/dispatch_screen.dart';
import 'package:little_garage/screens/drive_screen.dart';
import 'package:little_garage/screens/fix_screen.dart';
import 'package:little_garage/screens/garage_screen.dart';
import 'package:little_garage/screens/home_screen.dart';
import 'package:little_garage/screens/hq_screen.dart';
import 'package:little_garage/screens/mission_flow.dart';
import 'package:little_garage/screens/parent_screen.dart';
import 'package:little_garage/screens/route_screen.dart';
import 'package:little_garage/screens/spot_screen.dart';
import 'package:little_garage/screens/wash_screen.dart';
import 'package:little_garage/data/models.dart';

import 'helpers.dart';

/// Opens every screen on a phone and a tablet and runs it for a few seconds.
/// Any layout overflow or exception fails the test.
void main() {
  setUpAll(loadFonts);

  final screens = <String, Widget Function()>{
    'home': () => const HomeScreen(),
    'assemble': () => const AssembleScreen(),
    'garage': () => const GarageScreen(),
    'wash': () => const WashScreen(),
    'paint': () => const CustomiseScreen(startTab: 0),
    'wheels': () => const CustomiseScreen(startTab: 1),
    'stickers': () => const CustomiseScreen(startTab: 2),
    'drive': () => const DriveScreen(),
    'fix': () => const FixScreen(problem: Breakdown.flatTyre),
    'hq': () => const HqScreen(),
    'spot': () => const SpotScreen(),
    'parent': () => const ParentScreen(),
    'car_park': () => CarParkScreen(mission: missionById('car_park')),
    'bus': () => BusScreen(mission: missionById('bus_count')),
    'complete': () => MissionCompleteScreen(mission: missionById('flat_tyre')),
    'call': () => CallScreen(mission: missionById('flat_tyre')),
    for (final m in missions.where((m) => m.kind == MissionKind.diagnose))
      'diagnose_${m.id}': () => DiagnoseScreen(mission: m),
    for (final m in missions.where((m) => m.kind == MissionKind.dispatch))
      'dispatch_${m.id}': () => DispatchScreen(mission: m),
    for (final m in missions.where((m) => m.kind == MissionKind.drive))
      'route_${m.id}': () => RouteScreen(mission: m),
    for (final m in missions.where((m) => m.kind == MissionKind.drive))
      'drive_${m.id}': () => DriveScreen(course: m.course, onFinished: () {}),
  };

  for (final size in [phone, tablet]) {
    for (final e in screens.entries) {
      testWidgets('${e.key} opens on ${size.width.toInt()}x${size.height.toInt()}', (tester) async {
        await setSize(tester, size);
        final s = await freshState();
        await tester.pumpWidget(host(s, e.value()));
        await run(tester, const Duration(seconds: 3));
        expect(tester.takeException(), isNull);
        await teardown(tester);
      });
    }
  }

  testWidgets('every age band opens diagnose, dispatch, car park and bus', (tester) async {
    await setSize(tester, phone);
    for (final a in AgeBand.values) {
      final s = await freshState();
      s.setAgeBand(a);
      for (final w in [
        DiagnoseScreen(mission: missionById('flat_tyre')),
        DispatchScreen(mission: missionById('bakery_fire')),
        CarParkScreen(mission: missionById('car_park')),
        BusScreen(mission: missionById('bus_count')),
      ]) {
        await tester.pumpWidget(host(s, w));
        await run(tester, const Duration(seconds: 3));
        expect(tester.takeException(), isNull);
        await teardown(tester);
      }
    }
  });

  testWidgets('diagnose: find the flat tyre, pick the pump, mission completes', (tester) async {
    await setSize(tester, phone);
    final s = await freshState();
    final m = missionById('flat_tyre');
    await tester.pumpWidget(host(s, DiagnoseScreen(mission: m)));
    await run(tester, const Duration(seconds: 2)); // car arrives

    // Tap where the clue is, using the same layout maths as the screen.
    final carW = phone.width * 0.56;
    final carH = carW * kSimpleH / kSimpleW;
    final box = Rect.fromLTWH(phone.width * 0.06, phone.height * 0.62 - carH * 0.92, carW, carH);
    final spot = faults[Fault.flatTyre]!.spot;
    await tester.tapAt(Offset(box.left + spot.dx * box.width, box.top + spot.dy * box.height));
    await run(tester, const Duration(seconds: 1));
    expect(find.text('Found it!'), findsOneWidget);

    await tester.tap(find.byIcon(tools[Tool.pump]!.icon));
    await run(tester, const Duration(seconds: 5));
    expect(s.completed.contains(m.id), isTrue);
    expect(find.byType(MissionCompleteScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
    await teardown(tester);
  });

  testWidgets('dispatch: sending the fire engine completes the mission', (tester) async {
    await setSize(tester, phone);
    final s = await freshState();
    final m = missionById('bakery_fire');
    await tester.pumpWidget(host(s, DispatchScreen(mission: m)));
    await run(tester, const Duration(seconds: 1));
    final fireEngine = find.byWidgetPredicate((w) =>
        w is CustomPaint &&
        w.painter is SimpleVehiclePainter &&
        (w.painter as SimpleVehiclePainter).look.type == VehicleType.fireEngine);
    expect(fireEngine, findsOneWidget);
    await tester.tap(fireEngine);
    await run(tester, const Duration(seconds: 7), steps: 40);
    expect(s.completed.contains(m.id), isTrue);
    expect(tester.takeException(), isNull);
    await teardown(tester);
  });

  testWidgets('drive: holding the pedal reaches a red light and the truck stops', (tester) async {
    await setSize(tester, phone);
    final s = await freshState();
    const course = DriveCourse(length: 4000, trafficLights: [1500.0]);
    await tester.pumpWidget(host(s, const DriveScreen(course: course, onFinished: _noop)));
    await tester.pump();
    final g = await tester.startGesture(const Offset(400, 200));
    await run(tester, const Duration(seconds: 6), steps: 120);
    expect(find.text('Red means stop'), findsOneWidget);
    await g.up();
    await run(tester, const Duration(seconds: 6), steps: 60);
    expect(tester.takeException(), isNull);
    await teardown(tester);
  });

  testWidgets('home Play goes to the garage once the truck has been built', (tester) async {
    await setSize(tester, phone);
    final s = await freshState(built: true);
    await tester.pumpWidget(host(s, const HomeScreen()));
    await tester.pump();
    await tester.tap(find.byIcon(Icons.play_arrow_rounded));
    await run(tester, const Duration(seconds: 2));
    expect(find.byType(HqScreen), findsOneWidget);
    await teardown(tester);
  });

  testWidgets('mission unlocking follows the job order', (tester) async {
    final s = await freshState(completed: {'flat_tyre'});
    expect(s.nextMission?.id, missions[1].id);
    expect(s.isUnlocked(missions[1]), isTrue);
    expect(s.isUnlocked(missions[2]), isFalse);
  });

  test('every mission has the data its kind needs', () {
    for (final m in missions) {
      switch (m.kind) {
        case MissionKind.diagnose:
          expect(m.fault, isNotNull, reason: m.id);
        case MissionKind.dispatch:
          expect(m.rescue, isNotNull, reason: m.id);
        case MissionKind.drive:
          expect(m.course, isNotNull, reason: m.id);
        case MissionKind.carPark:
        case MissionKind.bus:
          break;
      }
    }
    expect(missions.map((m) => m.id).toSet().length, missions.length);
  });
}

void _noop() {}
