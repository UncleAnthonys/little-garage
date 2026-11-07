import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'screens/home_screen.dart';
import 'state/game_state.dart';
import 'widgets/wind_down.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations(
      [DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]);
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  final state = GameState();
  await state.load();
  runApp(LittleGarageApp(state: state));
}

class LittleGarageApp extends StatelessWidget {
  final GameState state;
  const LittleGarageApp({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    return GameScope(
      state: state,
      child: MaterialApp(
        title: 'Little Garage',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          colorSchemeSeed: const Color(0xFF4C6EF5),
        ),
        builder: (context, child) =>
            RotateHint(child: WindDownGuard(child: child ?? const SizedBox())),
        home: const HomeScreen(),
      ),
    );
  }
}

/// Browsers can't lock orientation, so ask for landscape when held upright.
class RotateHint extends StatelessWidget {
  final Widget child;
  const RotateHint({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final portrait = size.height > size.width;
    return Stack(children: [
      child,
      if (portrait)
        const Positioned.fill(
          child: Material(
            color: Color(0xFF4C6EF5),
            child: Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.screen_rotation_rounded, size: 96, color: Colors.white),
                SizedBox(height: 16),
                Text('Turn your phone sideways',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 28, fontWeight: FontWeight.w900, color: Colors.white)),
              ]),
            ),
          ),
        ),
    ]);
  }
}
