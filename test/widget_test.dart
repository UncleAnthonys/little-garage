import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:little_garage/art/truck_art.dart';
import 'package:little_garage/data/models.dart';
import 'package:little_garage/data/tow_truck.dart';
import 'package:little_garage/main.dart';
import 'package:little_garage/state/game_state.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('tow truck has every part exactly once', () {
    final kinds = towTruck.parts.map((p) => p.kind).toList();
    expect(kinds.toSet(), PartKind.values.toSet());
    expect(kinds.length, PartKind.values.length);
  });

  test('building every part completes the truck', () async {
    final s = GameState();
    await s.load();
    s.startBuild();
    for (final p in towTruck.parts) {
      expect(s.nextPart?.kind, p.kind);
      s.buildPart(p.kind);
    }
    expect(s.isBuilt, isTrue);
    expect(s.learned.length, PartKind.values.length);
  });

  test('tapping the cab in Mechanic Mode finds the cab', () {
    final hit = TruckGeo.hitTest(
        const Offset(360, 170), WheelStyle.classic, PartKind.values.toSet());
    expect(hit, PartKind.cab);
  });

  testWidgets('home screen shows title and play button', (tester) async {
    tester.view.physicalSize = const Size(1600, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final s = GameState();
    await s.load();
    await tester.pumpWidget(LittleGarageApp(state: s));
    await tester.pump();

    expect(find.text('Little Garage'), findsOneWidget);
    expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);

    // Dispose the app so the wind-down timer and animations stop.
    await tester.pumpWidget(const SizedBox());
  });
}
