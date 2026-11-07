import 'package:flutter/material.dart';

import '../art/scenery.dart';
import '../data/models.dart';
import '../services/voice.dart';
import '../state/game_state.dart';
import '../widgets/ui.dart';

/// Spot-it-outside: a sticker sheet of real vehicles. When the child sees
/// one on a walk or journey, they tap it here. Links play to the real world.
class SpotScreen extends StatefulWidget {
  const SpotScreen({super.key});

  @override
  State<SpotScreen> createState() => _SpotScreenState();
}

class _SpotScreenState extends State<SpotScreen> {
  int _burst = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => Voice.instance
        .say('When you see one of these outside, tap it to get a sticker!'));
  }

  @override
  Widget build(BuildContext context) {
    final s = GameScope.of(context);
    return Scaffold(
      body: Stack(children: [
        const Positioned.fill(child: CustomPaint(painter: GaragePainter())),
        Positioned.fill(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(100, 100, 100, 24),
            child: GridView.count(
              crossAxisCount: 4,
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              childAspectRatio: 1.3,
              children: [
                for (final item in spotItems)
                  _SpotCard(
                    item: item,
                    found: s.spotted.contains(item.id),
                    onTap: () {
                      final first = s.spot(item.id);
                      if (first) {
                        setState(() => _burst++);
                        Voice.instance.say('You spotted a ${item.name.toLowerCase()}! Well done!');
                      } else {
                        Voice.instance.say('${item.name}!');
                      }
                    },
                  ),
              ],
            ),
          ),
        ),
        const Positioned(
          top: 24,
          left: 0,
          right: 0,
          child: Center(child: PartBanner(title: 'Spot it outside!')),
        ),
        const Positioned(left: 20, top: 20, child: BackBubble()),
        const Positioned(right: 20, top: 20, child: StarCounter()),
        Positioned.fill(child: StarBurst(trigger: _burst)),
      ]),
    );
  }
}

class _SpotCard extends StatelessWidget {
  final SpotItem item;
  final bool found;
  final VoidCallback onTap;
  const _SpotCard({required this.item, required this.found, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Sfx.tap();
        onTap();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        decoration: BoxDecoration(
          color: found ? const Color(0xFFFFD23F) : Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
              color: found ? const Color(0xFFE09F00) : const Color(0xFFBDE0FE), width: 4),
        ),
        child: Stack(children: [
          Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(item.icon, size: 56, color: found ? const Color(0xFF3D405B) : const Color(0xFF8D99AE)),
              const SizedBox(height: 4),
              Text(item.name,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            ]),
          ),
          if (found)
            const Positioned(
                right: 8,
                top: 6,
                child: Icon(Icons.star_rounded, color: Color(0xFFFF8C42), size: 30)),
        ]),
      ),
    );
  }
}
