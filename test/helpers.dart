import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:little_garage/main.dart';
import 'package:little_garage/state/game_state.dart';
import 'package:little_garage/widgets/wind_down.dart';

/// iPhone 14 held sideways, in logical pixels.
const phone = Size(844, 390);

/// iPad held sideways.
const tablet = Size(1180, 820);

bool _fontsLoaded = false;

/// Loads Roboto and Material Icons from the Flutter SDK so text and icons
/// render (and measure) like the real app instead of test boxes.
Future<void> loadFonts() async {
  if (_fontsLoaded) return;
  _fontsLoaded = true;
  final root = Platform.environment['FLUTTER_ROOT'];
  if (root == null) return;
  final dir = Directory('$root/bin/cache/artifacts/material_fonts');
  if (!dir.existsSync()) return;
  final roboto = FontLoader('Roboto');
  final icons = FontLoader('MaterialIcons');
  for (final f in dir.listSync().whereType<File>()) {
    final name = f.uri.pathSegments.last;
    final bytes = f.readAsBytes().then((b) => ByteData.view(b.buffer));
    if (name.startsWith('Roboto-')) roboto.addFont(bytes);
    if (name.startsWith('MaterialIcons-Regular')) icons.addFont(bytes);
  }
  await roboto.load();
  await icons.load();
}

Future<GameState> freshState({bool built = true, Set<String> completed = const {}}) async {
  SharedPreferences.setMockInitialValues({
    'everBuilt': built,
    'completed': completed.toList(),
    'childName': 'Ruby',
  });
  final s = GameState();
  await s.load();
  return s;
}

/// Hosts [screen] the way the real app does.
Widget host(GameState s, Widget screen) => GameScope(
      state: s,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData(useMaterial3: true, colorSchemeSeed: const Color(0xFF4C6EF5)),
        builder: (context, child) =>
            RotateHint(child: WindDownGuard(child: child ?? const SizedBox())),
        home: screen,
      ),
    );

Future<void> setSize(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

/// Advances time in small steps so animations and tickers run.
Future<void> run(WidgetTester tester, Duration total, {int steps = 20}) async {
  for (var i = 0; i < steps; i++) {
    await tester.pump(total ~/ steps);
  }
}

/// Removes the app and lets any delayed callbacks finish.
Future<void> teardown(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 30));
}
