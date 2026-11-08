import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../art/truck_art.dart';
import '../data/models.dart';
import '../services/voice.dart';
import '../state/game_state.dart';

/// Builds the current look of the truck from state, with per-screen extras.
VehicleLook lookFrom(
  GameState s, {
  Set<PartKind>? built,
  PartKind? target,
  double pulse = 0,
  PartKind? highlight,
  double t = 0,
  double wheelTurn = 0,
  bool lightsOn = false,
  Breakdown? breakdown,
  bool sleeping = false,
  double? craneLift,
  List<PlacedSticker>? stickers,
}) =>
    VehicleLook(
      built: built ?? s.built,
      body: s.bodyColor,
      wheels: s.wheels,
      driver: s.driver,
      name: s.childName,
      stickers: stickers ?? s.stickers,
      target: target,
      pulse: pulse,
      highlight: highlight,
      t: t,
      wheelTurn: wheelTurn,
      lightsOn: lightsOn,
      breakdown: breakdown,
      sleeping: sleeping,
      craneLift: craneLift ?? (s.craneDown ? kCraneDown : 0),
    );

Set<PartKind> get allParts => PartKind.values.toSet();

/// Big glossy round button sized for small fingers.
class BubbleButton extends StatefulWidget {
  final Widget child;
  final Color color;
  final double size;
  final VoidCallback? onTap;
  final bool glow;
  final bool dimmed;

  const BubbleButton({
    super.key,
    required this.child,
    required this.onTap,
    this.color = const Color(0xFF4C6EF5),
    this.size = 72,
    this.glow = false,
    this.dimmed = false,
  });

  @override
  State<BubbleButton> createState() => _BubbleButtonState();
}

class _BubbleButtonState extends State<BubbleButton>
    with SingleTickerProviderStateMixin {
  bool _down = false;
  late final AnimationController _pulse = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 900))
    ..repeat(reverse: true);

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.color;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _down = true),
      onTapCancel: () => setState(() => _down = false),
      onTapUp: (_) => setState(() => _down = false),
      onTap: widget.onTap == null
          ? null
          : () {
              Sfx.tap();
              widget.onTap!();
            },
      child: AnimatedBuilder(
        animation: _pulse,
        builder: (context, child) {
          final g = widget.glow ? _pulse.value : 0.0;
          return AnimatedScale(
            scale: _down ? 0.88 : 1.0 + g * 0.06,
            duration: const Duration(milliseconds: 120),
            child: Opacity(
              opacity: widget.dimmed ? 0.4 : 1,
              child: Container(
                width: widget.size,
                height: widget.size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: widget.size * 0.06),
                  gradient: RadialGradient(
                    center: const Alignment(-0.35, -0.45),
                    colors: [shade(c, 0.18), c, shade(c, -0.12)],
                    stops: const [0, 0.6, 1],
                  ),
                  boxShadow: [
                    BoxShadow(
                        color: fade(Colors.black, 0.25),
                        blurRadius: 6,
                        offset: const Offset(0, 4)),
                    if (widget.glow)
                      BoxShadow(
                          color: fade(const Color(0xFFFFE066), 0.5 + 0.4 * g),
                          blurRadius: 18 + 10 * g,
                          spreadRadius: 2),
                  ],
                ),
                child: Center(child: child),
              ),
            ),
          );
        },
        child: widget.child,
      ),
    );
  }
}

class IconBubble extends StatelessWidget {
  final IconData icon;
  final Color color;
  final double size;
  final VoidCallback? onTap;
  final bool glow;
  final bool dimmed;
  const IconBubble(this.icon,
      {super.key,
      required this.onTap,
      this.color = const Color(0xFF4C6EF5),
      this.size = 72,
      this.glow = false,
      this.dimmed = false});

  @override
  Widget build(BuildContext context) => BubbleButton(
        onTap: onTap,
        color: color,
        size: size,
        glow: glow,
        dimmed: dimmed,
        child: Icon(icon, color: Colors.white, size: size * 0.48),
      );
}

class BackBubble extends StatelessWidget {
  final VoidCallback? onTap;
  const BackBubble({super.key, this.onTap});

  @override
  Widget build(BuildContext context) => IconBubble(
        Icons.arrow_back_rounded,
        color: const Color(0xFFFF9F1C),
        size: 60,
        onTap: onTap ?? () => Navigator.of(context).maybePop(),
      );
}

class StarCounter extends StatelessWidget {
  const StarCounter({super.key});

  @override
  Widget build(BuildContext context) {
    final s = GameScope.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 6, 16, 6),
      decoration: BoxDecoration(
        color: fade(Colors.white, 0.85),
        borderRadius: BorderRadius.circular(40),
        border: Border.all(color: const Color(0xFFFFD23F), width: 3),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        SizedBox(
            width: 34,
            height: 34,
            child: CustomPaint(painter: _StarIcon())),
        const SizedBox(width: 6),
        Text('${s.stars}',
            style: const TextStyle(
                fontSize: 26, fontWeight: FontWeight.w900, color: kInk)),
      ]),
    );
  }
}

class _StarIcon extends CustomPainter {
  @override
  void paint(Canvas c, Size s) {
    final p = starPath(s.center(Offset.zero), s.shortestSide / 2);
    c.drawPath(p, Paint()..color = const Color(0xFFFFD23F));
    c.drawPath(
        p,
        Paint()
          ..color = const Color(0xFFE09F00)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// The part name and what it does, shown big at the top of the screen.
class PartBanner extends StatelessWidget {
  final String? title;
  final String? line;
  const PartBanner({super.key, this.title, this.line});

  @override
  Widget build(BuildContext context) {
    final show = title != null;
    return AnimatedSlide(
      offset: show ? Offset.zero : const Offset(0, -1.5),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutBack,
      child: AnimatedOpacity(
        opacity: show ? 1 : 0,
        duration: const Duration(milliseconds: 200),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 560),
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: const Color(0xFF4C6EF5), width: 4),
            boxShadow: [
              BoxShadow(color: fade(Colors.black, 0.2), blurRadius: 8, offset: const Offset(0, 4))
            ],
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(title ?? '',
                style: const TextStyle(
                    fontSize: 30, fontWeight: FontWeight.w900, color: kInk)),
            if (line != null)
              Text(line!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w600, color: Color(0xFF4A4E69))),
          ]),
        ),
      ),
    );
  }
}

/// Burst of stars for celebrations. Plays once when [trigger] changes.
class StarBurst extends StatefulWidget {
  final int trigger;
  const StarBurst({super.key, required this.trigger});

  @override
  State<StarBurst> createState() => _StarBurstState();
}

class _StarBurstState extends State<StarBurst> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1400));

  @override
  void didUpdateWidget(covariant StarBurst old) {
    super.didUpdateWidget(old);
    if (old.trigger != widget.trigger && widget.trigger > 0) _c.forward(from: 0);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => IgnorePointer(
        child: AnimatedBuilder(
          animation: _c,
          builder: (context, _) => CustomPaint(
              size: Size.infinite, painter: _BurstPainter(_c.value, _c.isAnimating)),
        ),
      );
}

class _BurstPainter extends CustomPainter {
  final double t;
  final bool on;
  _BurstPainter(this.t, this.on);

  @override
  void paint(Canvas c, Size s) {
    if (!on || t <= 0 || t >= 1) return;
    final rnd = math.Random(3);
    final ctr = Offset(s.width / 2, s.height * 0.45);
    for (var i = 0; i < 26; i++) {
      final a = rnd.nextDouble() * math.pi * 2;
      final speed = 0.4 + rnd.nextDouble() * 0.6;
      final dist = Curves.easeOut.transform(t) * s.shortestSide * 0.6 * speed;
      final p = ctr + Offset(math.cos(a), math.sin(a)) * dist + Offset(0, t * t * 80);
      final colors = [const Color(0xFFFFD23F), const Color(0xFFFF6FB5), const Color(0xFF4CC9F0)];
      c.drawPath(starPath(p, 10 + 8 * speed),
          Paint()..color = fade(colors[i % 3], 1 - t));
    }
  }

  @override
  bool shouldRepaint(covariant _BurstPainter old) => true;
}

/// A grown-up question. Calls [onResult] with true when answered correctly.
class ParentGatePanel extends StatefulWidget {
  final ValueChanged<bool> onResult;
  final Color textColor;
  const ParentGatePanel({super.key, required this.onResult, this.textColor = kInk});

  @override
  State<ParentGatePanel> createState() => _ParentGatePanelState();
}

class _ParentGatePanelState extends State<ParentGatePanel> {
  final _rnd = math.Random();
  late int _a, _b;
  late List<int> _options;

  @override
  void initState() {
    super.initState();
    _newQuestion();
  }

  void _newQuestion() {
    _a = 3 + _rnd.nextInt(7);
    _b = 3 + _rnd.nextInt(7);
    final answer = _a * _b;
    final opts = <int>{answer};
    var step = 1;
    while (opts.length < 3) {
      opts.add(answer + (_rnd.nextBool() ? step : -step) * (2 + _rnd.nextInt(3)));
      step++;
    }
    _options = opts.toList()..shuffle(_rnd);
  }

  @override
  Widget build(BuildContext context) {
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Text('Grown-ups only: what is $_a × $_b?',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: widget.textColor)),
      const SizedBox(height: 14),
      Wrap(spacing: 12, children: [
        for (final o in _options)
          FilledButton(
            onPressed: () {
              final ok = o == _a * _b;
              if (!ok) setState(_newQuestion);
              widget.onResult(ok);
            },
            child: Text('$o', style: const TextStyle(fontSize: 20)),
          ),
      ]),
    ]);
  }
}

/// Shows the grown-up question in a dialog. Needs a Navigator above [context].
Future<bool> showParentGate(BuildContext context) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      content: ParentGatePanel(onResult: (ok) {
        if (ok) Navigator.of(context).pop(true);
      }),
      actions: [
        TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel')),
      ],
    ),
  );
  return ok ?? false;
}
