import 'package:flutter/material.dart';

/// Every part a child can snap on. Order of the enum is not the build order;
/// the build order lives in [VehicleDef.parts].
enum PartKind { chassis, cab, wheels, engine, exhaust, crane, headlights, steering }

enum WheelStyle { classic, monster, racing, flower }

enum DriverKind { bear, bunny, robot }

enum StickerKind { star, heart, bolt, flower, smile, flame }

enum Breakdown { flatTyre, noFuel, brokenLight }

class PartDef {
  final PartKind kind;
  final String name;

  /// What the part does, in words a 3-6 year old understands. Spoken aloud.
  final String line;

  const PartDef(this.kind, this.name, this.line);
}

class VehicleDef {
  final String id;
  final String name;

  /// Parts in the order the child assembles them.
  final List<PartDef> parts;

  const VehicleDef({required this.id, required this.name, required this.parts});

  PartDef part(PartKind kind) => parts.firstWhere((p) => p.kind == kind);
}

class PlacedSticker {
  final StickerKind kind;

  /// Position in vehicle units (see art/truck_art.dart, 400 x 250 box).
  final double x;
  final double y;

  const PlacedSticker(this.kind, this.x, this.y);

  Map<String, dynamic> toJson() => {'k': kind.index, 'x': x, 'y': y};

  static PlacedSticker fromJson(Map<String, dynamic> j) => PlacedSticker(
        StickerKind.values[(j['k'] as num).toInt()],
        (j['x'] as num).toDouble(),
        (j['y'] as num).toDouble(),
      );
}

class PaintChoice {
  final String name;
  final Color color;
  const PaintChoice(this.name, this.color);
}

const paintChoices = <PaintChoice>[
  PaintChoice('Red', Color(0xFFE63946)),
  PaintChoice('Orange', Color(0xFFFF8C42)),
  PaintChoice('Yellow', Color(0xFFFFD23F)),
  PaintChoice('Green', Color(0xFF8AC926)),
  PaintChoice('Blue', Color(0xFF3A86FF)),
  PaintChoice('Purple', Color(0xFF9B5DE5)),
  PaintChoice('Pink', Color(0xFFFF6FB5)),
  PaintChoice('Teal', Color(0xFF2EC4B6)),
];

const wheelLines = <WheelStyle, String>{
  WheelStyle.classic: 'Everyday wheels. Round and round they go!',
  WheelStyle.monster: 'Monster tyres! Big bumpy tyres grip in the mud.',
  WheelStyle.racing: 'Racing wheels. Light and speedy!',
  WheelStyle.flower: 'Flower wheels! So pretty.',
};

const driverNames = <DriverKind, String>{
  DriverKind.bear: 'Bear',
  DriverKind.bunny: 'Bunny',
  DriverKind.robot: 'Robot',
};

/// Things a child might spot on a walk or a car journey.
class SpotItem {
  final String id;
  final String name;
  final IconData icon;
  const SpotItem(this.id, this.name, this.icon);
}

const spotItems = <SpotItem>[
  SpotItem('tow', 'Tow truck', Icons.car_repair),
  SpotItem('fire', 'Fire engine', Icons.fire_truck),
  SpotItem('bus', 'Bus', Icons.directions_bus),
  SpotItem('tractor', 'Tractor', Icons.agriculture),
  SpotItem('lorry', 'Lorry', Icons.local_shipping),
  SpotItem('taxi', 'Taxi', Icons.local_taxi),
  SpotItem('bike', 'Bicycle', Icons.pedal_bike),
  SpotItem('plane', 'Aeroplane', Icons.flight),
];
