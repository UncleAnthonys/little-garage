import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/models.dart';
import '../data/tow_truck.dart';
import '../services/voice.dart';

/// All game state in one place. Saved locally; no account, no network.
class GameState extends ChangeNotifier {
  final VehicleDef vehicle = towTruck;

  int stars = 0;
  String childName = '';
  DriverKind driver = DriverKind.bear;
  Color bodyColor = paintChoices[1].color;
  WheelStyle wheels = WheelStyle.classic;
  List<PlacedSticker> stickers = [];
  Set<PartKind> learned = {};
  Set<String> spotted = {};

  /// Parts assembled in the current build. Not saved: every session starts
  /// with building the truck, which is the heart of the game.
  Set<PartKind> built = {};
  bool dirty = true;

  bool voiceOn = true;
  bool soundsOn = true;

  /// 0 = off.
  int windDownMinutes = 0;
  DateTime sessionStart = DateTime.now();

  SharedPreferences? _prefs;

  bool get isBuilt => built.length == vehicle.parts.length;

  PartDef? get nextPart {
    for (final p in vehicle.parts) {
      if (!built.contains(p.kind)) return p;
    }
    return null;
  }

  bool get windDownDue =>
      windDownMinutes > 0 &&
      DateTime.now().difference(sessionStart).inMinutes >= windDownMinutes;

  Future<void> load() async {
    try {
      final p = await SharedPreferences.getInstance();
      _prefs = p;
      stars = p.getInt('stars') ?? 0;
      childName = p.getString('childName') ?? '';
      driver = DriverKind.values[(p.getInt('driver') ?? 0)
          .clamp(0, DriverKind.values.length - 1)];
      final c = p.getInt('bodyColor');
      if (c != null) bodyColor = Color(c);
      wheels = WheelStyle.values[(p.getInt('wheels') ?? 0)
          .clamp(0, WheelStyle.values.length - 1)];
      final raw = p.getString('stickers');
      if (raw != null) {
        final list = jsonDecode(raw) as List<dynamic>;
        stickers = list
            .map((e) => PlacedSticker.fromJson(e as Map<String, dynamic>))
            .toList();
      }
      learned = (p.getStringList('learned') ?? [])
          .map((s) => PartKind.values.firstWhere((k) => k.name == s,
              orElse: () => PartKind.chassis))
          .toSet();
      spotted = (p.getStringList('spotted') ?? []).toSet();
      voiceOn = p.getBool('voiceOn') ?? true;
      soundsOn = p.getBool('soundsOn') ?? true;
      windDownMinutes = p.getInt('windDown') ?? 0;
    } catch (_) {
      // Corrupt or missing prefs: start fresh.
    }
    Voice.instance.enabled = voiceOn;
    Sfx.enabled = soundsOn;
    sessionStart = DateTime.now();
  }

  Future<void> _save() async {
    final p = _prefs;
    if (p == null) return;
    await p.setInt('stars', stars);
    await p.setString('childName', childName);
    await p.setInt('driver', driver.index);
    await p.setInt('bodyColor', bodyColor.toARGB32());
    await p.setInt('wheels', wheels.index);
    await p.setString(
        'stickers', jsonEncode(stickers.map((s) => s.toJson()).toList()));
    await p.setStringList('learned', learned.map((k) => k.name).toList());
    await p.setStringList('spotted', spotted.toList());
    await p.setBool('voiceOn', voiceOn);
    await p.setBool('soundsOn', soundsOn);
    await p.setInt('windDown', windDownMinutes);
  }

  void _changed() {
    notifyListeners();
    _save();
  }

  // --- Build ---------------------------------------------------------------

  void startBuild() {
    built = {};
    notifyListeners();
  }

  void buildPart(PartKind kind) {
    built.add(kind);
    learned.add(kind);
    _changed();
  }

  // --- Rewards -------------------------------------------------------------

  void addStars(int n) {
    stars += n;
    _changed();
  }

  // --- Customisation -------------------------------------------------------

  void setName(String name) {
    childName = name.trim();
    if (childName.length > 12) childName = childName.substring(0, 12);
    _changed();
  }

  void setDriver(DriverKind d) {
    driver = d;
    _changed();
  }

  void setColor(Color c) {
    bodyColor = c;
    _changed();
  }

  void setWheels(WheelStyle w) {
    wheels = w;
    _changed();
  }

  void addSticker(PlacedSticker s) {
    if (stickers.length >= 10) stickers.removeAt(0);
    stickers.add(s);
    _changed();
  }

  void removeSticker(PlacedSticker s) {
    stickers.remove(s);
    _changed();
  }

  void clearStickers() {
    stickers = [];
    _changed();
  }

  void setDirty(bool v) {
    dirty = v;
    notifyListeners();
  }

  /// Returns true the first time an item is spotted.
  bool spot(String id) {
    if (spotted.contains(id)) return false;
    spotted.add(id);
    stars += 1;
    _changed();
    return true;
  }

  // --- Parent settings -----------------------------------------------------

  void setVoice(bool v) {
    voiceOn = v;
    Voice.instance.enabled = v;
    if (!v) Voice.instance.stop();
    _changed();
  }

  void setSounds(bool v) {
    soundsOn = v;
    Sfx.enabled = v;
    _changed();
  }

  void setWindDown(int minutes) {
    windDownMinutes = minutes;
    sessionStart = DateTime.now();
    _changed();
  }

  void extendSession() {
    sessionStart = DateTime.now();
    notifyListeners();
  }

  void resetProgress() {
    stars = 0;
    learned = {};
    spotted = {};
    stickers = [];
    wheels = WheelStyle.classic;
    bodyColor = paintChoices[1].color;
    _changed();
  }
}

/// Makes [GameState] available to every widget below it.
class GameScope extends InheritedNotifier<GameState> {
  const GameScope({super.key, required GameState state, required super.child})
      : super(notifier: state);

  /// Rebuilds the caller when state changes.
  static GameState of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<GameScope>()!.notifier!;

  /// Reads state without subscribing (use in callbacks).
  static GameState read(BuildContext context) =>
      context.getInheritedWidgetOfExactType<GameScope>()!.notifier!;
}
