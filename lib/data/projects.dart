import 'package:flutter/material.dart';

import 'missions.dart';

// ---------------------------------------------------------------------------
// The fleet: vehicles the child can own. The tow truck is theirs from the
// start; the rest join when a town project needs them.
// ---------------------------------------------------------------------------

const fleetOrder = <VehicleType>[
  VehicleType.towTruck,
  VehicleType.digger,
  VehicleType.dumpTruck,
  VehicleType.mixer,
  VehicleType.craneTruck,
  VehicleType.fireEngine,
  VehicleType.bus,
  VehicleType.ambulance,
];

/// A part of a fleet vehicle to tap and learn, in the 300 x 180 vehicle box.
class VehiclePart {
  final String name;
  final String line;
  final Rect area;
  const VehiclePart(this.name, this.line, this.area);
}

const vehicleParts = <VehicleType, List<VehiclePart>>{
  VehicleType.digger: [
    VehiclePart('Bucket', 'The bucket has teeth to scoop up dirt and rocks.', Rect.fromLTWH(10, 90, 56, 56)),
    VehiclePart('Arm', 'The arm bends in the middle, like your elbow, to reach down and dig.', Rect.fromLTWH(60, 20, 90, 70)),
    VehiclePart('Cab', 'The driver sits in the cab and works the levers.', Rect.fromLTWH(176, 36, 80, 58)),
    VehiclePart('Tracks', 'Tracks go round like a belt, so the digger can drive on bumpy, muddy ground.', Rect.fromLTWH(56, 130, 206, 40)),
  ],
  VehicleType.dumpTruck: [
    VehiclePart('Tipper', 'The tipper lifts up at the front so the load slides out the back.', Rect.fromLTWH(10, 40, 182, 90)),
    VehiclePart('Cab', 'The driver sits in the cab.', Rect.fromLTWH(196, 44, 94, 100)),
    VehiclePart('Big wheels', 'Big wheels carry heavy loads without sinking.', Rect.fromLTWH(30, 124, 250, 52)),
  ],
  VehicleType.mixer: [
    VehiclePart('Drum', 'The drum spins round and round so the concrete stays runny.', Rect.fromLTWH(20, 38, 170, 84)),
    VehiclePart('Chute', 'The chute is a slide that pours the concrete out.', Rect.fromLTWH(0, 86, 30, 44)),
    VehiclePart('Cab', 'The driver sits in the cab.', Rect.fromLTWH(196, 44, 94, 100)),
  ],
  VehicleType.craneTruck: [
    VehiclePart('Boom', 'The boom is the long arm that stretches up high.', Rect.fromLTWH(20, 0, 100, 104)),
    VehiclePart('Hook', 'The hook holds heavy things while the crane lifts them.', Rect.fromLTWH(14, 52, 32, 30)),
    VehiclePart('Counterweight', 'The counterweight is a heavy block that stops the crane tipping over.', Rect.fromLTWH(78, 80, 74, 34)),
    VehiclePart('Cab', 'The driver sits in the cab.', Rect.fromLTWH(196, 44, 94, 100)),
  ],
};

// ---------------------------------------------------------------------------
// Town projects: each step needs the right vehicle, in the right order.
// ---------------------------------------------------------------------------

/// How the child does a step once the right vehicle is there.
enum Work { tap, hold }

class ProjectStep {
  final VehicleType vehicle;

  /// What needs doing, phrased to follow "First we need to ..."
  final String task;

  /// Shown and said when the step starts.
  final String doing;
  final Work work;

  /// Said when the step is finished: a little fact about why.
  final String done;
  const ProjectStep(this.vehicle, this.task, this.doing, this.work, this.done);
}

enum Area { garageStreet, riverside, hillFarm }

const areaNames = <Area, String>{
  Area.garageStreet: 'Garage Street',
  Area.riverside: 'Riverside',
  Area.hillFarm: 'Hill Farm',
};

class TownProject {
  final String id;
  final String title;
  final Townsperson asker;
  final String ask; // what the townsperson says
  final Area area;

  /// Horizontal position on the town map, in map units.
  final double x;
  final List<ProjectStep> steps;

  /// Area that opens when this project is finished.
  final Area? opens;
  final String finished;

  /// Vehicles the child chooses between (always includes every step's).
  final List<VehicleType> choices;

  const TownProject({
    required this.id,
    required this.title,
    required this.asker,
    required this.ask,
    required this.area,
    required this.x,
    required this.steps,
    required this.finished,
    required this.choices,
    this.opens,
  });
}

const projects = <TownProject>[
  TownProject(
    id: 'bramble_house',
    title: 'Mr Bramble\'s house',
    asker: bramble,
    ask: 'I want to build my new house here, but there\'s a big pile of rocks in the way! Can your fleet help?',
    area: Area.garageStreet,
    x: 760,
    choices: [VehicleType.digger, VehicleType.dumpTruck, VehicleType.towTruck],
    steps: [
      ProjectStep(VehicleType.digger, 'break up the big rocks', 'Tap the digger to scoop the rocks!', Work.tap,
          'The digger\'s bucket broke up the rocks. Now they need carrying away.'),
      ProjectStep(VehicleType.dumpTruck, 'carry the rocks away', 'Tap the dump truck to load it up and tip!', Work.tap,
          'The dump truck carried the rocks away and tipped them out.'),
      ProjectStep(VehicleType.digger, 'dig a hole for the house to stand in', 'Tap the digger to dig the hole!', Work.tap,
          'Houses need a strong bottom part called foundations, so they don\'t wobble.'),
    ],
    finished: 'Hooray! The builders made Mr Bramble\'s house. Thank you!',
  ),
  TownProject(
    id: 'river_bridge',
    title: 'The river bridge',
    asker: ella,
    ask: 'My friends live across the river, but there\'s no bridge! Can we build one?',
    area: Area.garageStreet,
    x: 1240,
    opens: Area.riverside,
    choices: [VehicleType.craneTruck, VehicleType.mixer, VehicleType.digger, VehicleType.dumpTruck],
    steps: [
      ProjectStep(VehicleType.digger, 'dig holes on both sides of the river for the bridge legs',
          'Tap the digger to dig the holes!', Work.tap, 'Deep holes keep the bridge legs strong.'),
      ProjectStep(VehicleType.mixer, 'fill the holes with concrete to make strong legs',
          'Press and hold the mixer to pour the concrete!', Work.hold,
          'Concrete goes in runny, then sets hard like stone.'),
      ProjectStep(VehicleType.craneTruck, 'lift the long bridge across the river',
          'Press and hold the crane to lift the bridge!', Work.hold,
          'The crane\'s counterweight stopped it tipping over while it lifted.'),
    ],
    finished: 'The bridge is open! Now we can drive to Riverside. Who lives over there?',
  ),
  TownProject(
    id: 'riverside_park',
    title: 'Riverside playground',
    asker: kit,
    ask: 'Hi! It\'s Kit. Riverside has a muddy field. Could it be a playground?',
    area: Area.riverside,
    x: 1780,
    choices: [VehicleType.dumpTruck, VehicleType.digger, VehicleType.craneTruck, VehicleType.mixer],
    steps: [
      ProjectStep(VehicleType.digger, 'flatten the bumpy mud', 'Tap the digger to smooth the ground!', Work.tap,
          'Flat ground is safe for running about.'),
      ProjectStep(VehicleType.dumpTruck, 'bring soft sand to land on', 'Tap the dump truck to tip the sand!', Work.tap,
          'Soft sand is kind to knees if you fall.'),
      ProjectStep(VehicleType.craneTruck, 'lift the big slide into place', 'Press and hold the crane to lift the slide!',
          Work.hold, 'The slide is heavy, so the crane lifted it gently.'),
    ],
    finished: 'The playground is open! Wheee!',
  ),
];

TownProject projectById(String id) => projects.firstWhere((p) => p.id == id);

/// Vehicles a project will need that the child doesn't have yet.
Iterable<VehicleType> newVehiclesFor(TownProject p, Set<VehicleType> fleet) =>
    p.steps.map((s) => s.vehicle).where((v) => !fleet.contains(v)).toSet();
