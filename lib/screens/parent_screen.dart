import 'package:flutter/material.dart';

import '../data/models.dart';
import '../state/game_state.dart';

/// Grown-up settings, reached only through the parental gate.
class ParentScreen extends StatefulWidget {
  const ParentScreen({super.key});

  @override
  State<ParentScreen> createState() => _ParentScreenState();
}

class _ParentScreenState extends State<ParentScreen> {
  late final TextEditingController _name =
      TextEditingController(text: GameScope.read(context).childName);

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = GameScope.of(context);
    final parts = s.vehicle.parts;
    return Scaffold(
      appBar: AppBar(title: const Text('For grown-ups')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Progress', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 8),
                  Text('${s.stars} stars · ${s.learned.length} of ${parts.length} parts learned · '
                      '${s.spotted.length} of ${spotItems.length} vehicles spotted'),
                  const SizedBox(height: 12),
                  Wrap(spacing: 8, runSpacing: 8, children: [
                    for (final p in parts)
                      Chip(
                        avatar: Icon(
                            s.learned.contains(p.kind)
                                ? Icons.check_circle
                                : Icons.radio_button_unchecked,
                            size: 18),
                        label: Text(p.name),
                      ),
                  ]),
                  const SizedBox(height: 8),
                  const Text('Try asking: "Can you find the wheels on a real car?"'),
                ]),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _name,
              maxLength: 12,
              decoration: const InputDecoration(
                  labelText: "Child's first name (shown on the truck)",
                  border: OutlineInputBorder()),
              onSubmitted: s.setName,
              onChanged: s.setName,
            ),
            SwitchListTile(
              title: const Text('Voice'),
              subtitle: const Text('Spoken part names and instructions'),
              value: s.voiceOn,
              onChanged: s.setVoice,
            ),
            SwitchListTile(
              title: const Text('Sound effects'),
              value: s.soundsOn,
              onChanged: s.setSounds,
            ),
            ListTile(
              title: const Text('Wind-down timer'),
              subtitle: const Text(
                  'When time is up, the truck goes to sleep in the garage. No hard lock screen.'),
              trailing: SegmentedButton<int>(
                segments: const [
                  ButtonSegment(value: 0, label: Text('Off')),
                  ButtonSegment(value: 10, label: Text('10m')),
                  ButtonSegment(value: 20, label: Text('20m')),
                  ButtonSegment(value: 30, label: Text('30m')),
                ],
                selected: {s.windDownMinutes},
                onSelectionChanged: (v) => s.setWindDown(v.first),
              ),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.lock_open_rounded),
              title: const Text('Unlock every vehicle'),
              subtitle: const Text('More vehicles coming soon.'),
              onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Purchases are not set up yet.'))),
            ),
            const ListTile(
              leading: Icon(Icons.verified_user_rounded),
              title: Text('No ads. No tracking. Works offline.'),
              subtitle: Text('Nothing your child does here leaves this device.'),
            ),
            ListTile(
              leading: const Icon(Icons.restart_alt_rounded, color: Colors.red),
              title: const Text('Reset progress'),
              onTap: () async {
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Reset progress?'),
                    content: const Text('Stars, learned parts, stickers and spotted vehicles are cleared.'),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.of(context).pop(false),
                          child: const Text('Cancel')),
                      FilledButton(
                          onPressed: () => Navigator.of(context).pop(true),
                          child: const Text('Reset')),
                    ],
                  ),
                );
                if (ok == true) s.resetProgress();
              },
            ),
          ],
        ),
      ),
    );
  }
}
