import 'package:flutter/material.dart';

// ---------------------------------------------------------------------------
// Townsfolk: original animal characters who phone the garage for help.
// ---------------------------------------------------------------------------

enum Ears { round, pointy, long, floppy, none }

enum Hat { none, glasses, chef, farmer, cap, topHat, bow }

class Townsperson {
  final String id;
  final String name;
  final Color fur;
  final Color snout;
  final Ears ears;
  final Hat hat;
  final bool beak;
  const Townsperson(this.id, this.name, this.fur, this.snout, this.ears, this.hat,
      {this.beak = false});
}

const granny = Townsperson('granny', 'Granny Hettie', Color(0xFFB08968),
    Color(0xFFF2D7B6), Ears.round, Hat.glasses);
const bramble = Townsperson('bramble', 'Mr Bramble', Color(0xFF5C5C6E),
    Color(0xFFF4F1EE), Ears.round, Hat.none);
const baker = Townsperson('baker', 'Baker Bea', Color(0xFFFFB3C6),
    Color(0xFFFFE5EC), Ears.pointy, Hat.chef);
const farmer = Townsperson('farmer', 'Farmer Woolly', Color(0xFFF4F1EE),
    Color(0xFF6B4F3A), Ears.floppy, Hat.farmer);
const ella = Townsperson('ella', 'Ella', Color(0xFFBFC6D1),
    Color(0xFFFFD6E0), Ears.round, Hat.bow);
const mayor = Townsperson('mayor', 'Mayor Pip', Color(0xFFFFB5A7),
    Color(0xFFFF8FA3), Ears.pointy, Hat.topHat);
const driverDot = Townsperson('dot', 'Driver Dot', Color(0xFFFFE066),
    Color(0xFFFF9F1C), Ears.none, Hat.cap, beak: true);
const gus = Townsperson('gus', 'Gus', Color(0xFF9C6B4E),
    Color(0xFFF2D7B6), Ears.pointy, Hat.none, beak: true);
const kit = Townsperson('kit', 'Kit', Color(0xFF8AC926),
    Color(0xFFE9F5DB), Ears.long, Hat.cap);

// ---------------------------------------------------------------------------
// Diagnose and fix: symptom -> cause -> tool.
// ---------------------------------------------------------------------------

enum Fault { flatTyre, noFuel, brokenLight, dirtyWindscreen, flatBattery, looseBolt, noCharge }

enum Tool { pump, fuelCan, bulb, washer, jumpLeads, spanner, charger }

/// Where on the customer car the fault lives, as a fraction of the car box.
class FaultInfo {
  final String symptom; // spoken when the car arrives
  final String found; // spoken when the child taps the right spot
  final Offset spot; // 0..1 inside the car box
  final Tool tool;
  final String fixed; // spoken when fixed
  const FaultInfo(this.symptom, this.found, this.spot, this.tool, this.fixed);
}

const faults = <Fault, FaultInfo>{
  Fault.flatTyre: FaultInfo(
      'The car is leaning over and going bumpety-bump. Tap where the problem is!',
      'The tyre is flat! All the air leaked out.',
      Offset(0.77, 0.8),
      Tool.pump,
      'Pump pump pump! Air makes the tyre round and strong again.'),
  Fault.noFuel: FaultInfo(
      'The engine goes cough cough, then stops. Tap where the problem is!',
      'The fuel gauge says empty! The engine has no fuel to burn.',
      Offset(0.5, 0.42),
      Tool.fuelCan,
      'Glug glug! Fuel is the engine\'s food. Now it has power to go.'),
  Fault.brokenLight: FaultInfo(
      'It\'s getting dark and only one light works. Tap where the problem is!',
      'The headlight bulb is broken!',
      Offset(0.95, 0.55),
      Tool.bulb,
      'A new bulb! Now the headlight shines bright so we can see at night.'),
  Fault.dirtyWindscreen: FaultInfo(
      'The driver can\'t see where they are going! Tap where the problem is!',
      'The windscreen is covered in mud!',
      Offset(0.68, 0.28),
      Tool.washer,
      'Squirt and swish! The wipers and washer water clean the windscreen.'),
  Fault.flatBattery: FaultInfo(
      'Turn the key... click click. Nothing happens! Tap where the problem is!',
      'The battery is flat! It has no electricity left to start the engine.',
      Offset(0.86, 0.5),
      Tool.jumpLeads,
      'Jump leads share electricity from another battery. Vroom! It started!'),
  Fault.looseBolt: FaultInfo(
      'Clunk clunk clunk! Something is rattling. Tap where the problem is!',
      'A wheel bolt is loose! That\'s what is rattling.',
      Offset(0.24, 0.8),
      Tool.spanner,
      'Twist twist with the spanner. Tight bolts keep the wheel on safely.'),
  Fault.noCharge: FaultInfo(
      'This electric car has stopped. Look at the little light. Tap where the problem is!',
      'The battery light is red. The electric car needs charging!',
      Offset(0.5, 0.42),
      Tool.charger,
      'Electric cars don\'t use fuel. They plug in and charge, like a phone!'),
};

class ToolInfo {
  final String name;
  final IconData icon;
  final Color color;
  final String job; // what this tool does, said when it's the wrong one
  const ToolInfo(this.name, this.icon, this.color, this.job);
}

const tools = <Tool, ToolInfo>{
  Tool.pump: ToolInfo('Air pump', Icons.tire_repair, Color(0xFF4C6EF5),
      'The air pump fills tyres with air.'),
  Tool.fuelCan: ToolInfo('Fuel can', Icons.local_gas_station, Color(0xFFE63946),
      'The fuel can fills up the fuel tank.'),
  Tool.bulb: ToolInfo('Light bulb', Icons.lightbulb, Color(0xFFFFB703),
      'A light bulb makes headlights shine.'),
  Tool.washer: ToolInfo('Washer water', Icons.water_drop, Color(0xFF4CC9F0),
      'Washer water cleans the windscreen.'),
  Tool.jumpLeads: ToolInfo('Jump leads', Icons.cable, Color(0xFF2B2D42),
      'Jump leads give a flat battery some electricity.'),
  Tool.spanner: ToolInfo('Spanner', Icons.build, Color(0xFF8D99AE),
      'A spanner tightens loose bolts.'),
  Tool.charger: ToolInfo('Charger', Icons.ev_station, Color(0xFF2DC653),
      'A charger fills an electric car with electricity.'),
};

// ---------------------------------------------------------------------------
// Right vehicle for the job.
// ---------------------------------------------------------------------------

enum Rescue { fire, tree, rocks, hurt, crowd, brokenCar }

enum VehicleType { car, fireEngine, ambulance, bus, dumpTruck, craneTruck, towTruck, electricCar }

const vehicleNames = <VehicleType, String>{
  VehicleType.car: 'car',
  VehicleType.fireEngine: 'fire engine',
  VehicleType.ambulance: 'ambulance',
  VehicleType.bus: 'bus',
  VehicleType.dumpTruck: 'dump truck',
  VehicleType.craneTruck: 'crane truck',
  VehicleType.towTruck: 'tow truck',
  VehicleType.electricCar: 'electric car',
};

/// What each vehicle is for. Said when the child picks the wrong one.
const vehicleJobs = <VehicleType, String>{
  VehicleType.fireEngine: 'The fire engine carries water and ladders to put out fires.',
  VehicleType.ambulance: 'The ambulance takes poorly people to hospital.',
  VehicleType.bus: 'The bus carries lots of people at once.',
  VehicleType.dumpTruck: 'The dump truck carries heavy rocks and tips them out.',
  VehicleType.craneTruck: 'The crane truck lifts heavy things up high.',
  VehicleType.towTruck: 'The tow truck pulls broken cars to the garage.',
  VehicleType.car: 'A car carries a few people.',
  VehicleType.electricCar: 'An electric car runs on electricity.',
};

class RescueInfo {
  final String problem;
  final VehicleType answer;
  final List<VehicleType> others;
  final String solved;
  const RescueInfo(this.problem, this.answer, this.others, this.solved);
}

const rescues = <Rescue, RescueInfo>{
  Rescue.fire: RescueInfo(
      'Help! There\'s a fire at the bakery! Which vehicle should we send?',
      VehicleType.fireEngine,
      [VehicleType.bus, VehicleType.dumpTruck, VehicleType.ambulance],
      'Whoosh! The fire engine sprayed water and the fire is out!'),
  Rescue.tree: RescueInfo(
      'A big tree has fallen across the road! Nobody can get past. Which vehicle can lift it?',
      VehicleType.craneTruck,
      [VehicleType.ambulance, VehicleType.bus, VehicleType.fireEngine],
      'Up it goes! The crane lifted the heavy tree out of the way.'),
  Rescue.rocks: RescueInfo(
      'There\'s a big pile of rocks at the building site. Which vehicle can carry them away?',
      VehicleType.dumpTruck,
      [VehicleType.ambulance, VehicleType.fireEngine, VehicleType.bus],
      'Rumble, tip! The dump truck carried all the rocks away.'),
  Rescue.hurt: RescueInfo(
      'Oh no, someone fell over at the park and hurt their leg. Which vehicle helps poorly people?',
      VehicleType.ambulance,
      [VehicleType.dumpTruck, VehicleType.craneTruck, VehicleType.bus],
      'Nee-naw! The ambulance came to help. They will be better soon.'),
  Rescue.crowd: RescueInfo(
      'Lots of friends are waiting at the bus stop to go to school. Which vehicle can carry them all?',
      VehicleType.bus,
      [VehicleType.car, VehicleType.fireEngine, VehicleType.dumpTruck],
      'All aboard! The bus can carry lots of people at once.'),
  Rescue.brokenCar: RescueInfo(
      'A car has broken down and can\'t move. Which vehicle can pull it to the garage?',
      VehicleType.towTruck,
      [VehicleType.bus, VehicleType.ambulance, VehicleType.dumpTruck],
      'Hook it on! The tow truck pulled the car to the garage.'),
};

// ---------------------------------------------------------------------------
// Drive courses.
// ---------------------------------------------------------------------------

class DriveCourse {
  final double length;
  final List<(double, double)> mud;
  final (double, double)? tunnel;
  final List<double> bumps;
  final List<double> trafficLights;
  final List<double> zebras;
  final List<double> lowBridges;
  final double? breakdownAt;
  final bool night;
  final List<(double, double)> stars;

  const DriveCourse({
    this.length = 9000,
    this.mud = const [],
    this.tunnel,
    this.bumps = const [],
    this.trafficLights = const [],
    this.zebras = const [],
    this.lowBridges = const [],
    this.breakdownAt,
    this.night = false,
    this.stars = const [],
  });

  bool inMud(double x) => mud.any((m) => x > m.$1 && x < m.$2);
  bool inTunnel(double x) {
    final t = tunnel;
    return t != null && x > t.$1 && x < t.$2;
  }

  /// Stars spaced along the course, skipping hazards' stopping zones.
  static List<(double, double)> starsFor(double length) => [
        for (var i = 0; 700.0 + i * 320 < length - 300; i++)
          (700.0 + i * 320, (i % 3) / 2),
      ];

  /// The free-play course (from the truck garage).
  static final free = DriveCourse(
    mud: const [(2100.0, 2700.0), (6500.0, 7100.0)],
    tunnel: (5100.0, 6100.0),
    bumps: const [1500.0, 3100.0, 7800.0],
    trafficLights: const [4300.0],
    breakdownAt: 3600,
    stars: starsFor(9000),
  );
}

// ---------------------------------------------------------------------------
// Missions.
// ---------------------------------------------------------------------------

enum MissionKind { diagnose, dispatch, drive, carPark, bus }

enum Prep { monsterTyres, headlights, lowerCrane, roadSense }

class Mission {
  final String id;
  final MissionKind kind;
  final Townsperson caller;

  /// What the caller says on the phone.
  final String call;

  /// Short label for the mission board.
  final String title;
  final IconData icon;

  final Fault? fault;
  final VehicleType carType;
  final Rescue? rescue;
  final DriveCourse? course;

  /// Things the child should think about before a drive. Shown as picture
  /// clues on the route screen.
  final List<Prep> clues;
  final bool routeChoice;

  /// "Did you know?" fact, read out at the end.
  final String wow;

  /// A suggestion for the grown-up, to carry the idea into real life.
  final String grownUp;

  const Mission({
    required this.id,
    required this.kind,
    required this.caller,
    required this.call,
    required this.title,
    required this.icon,
    required this.wow,
    required this.grownUp,
    this.fault,
    this.carType = VehicleType.car,
    this.rescue,
    this.course,
    this.clues = const [],
    this.routeChoice = false,
  });
}

final missions = <Mission>[
  const Mission(
    id: 'flat_tyre',
    kind: MissionKind.diagnose,
    caller: granny,
    title: 'Bumpy car',
    icon: Icons.tire_repair,
    call: 'Hello, garage? It\'s Granny Hettie. My car is going bumpety-bump! Can you help?',
    fault: Fault.flatTyre,
    wow: 'Did you know? Tyres are full of air, like a balloon. That makes the ride soft and bouncy.',
    grownUp: 'Press a bike or car tyre together. Feel how hard the air makes it.',
  ),
  const Mission(
    id: 'bakery_fire',
    kind: MissionKind.dispatch,
    caller: baker,
    title: 'Fire!',
    icon: Icons.local_fire_department,
    call: 'Help! It\'s Baker Bea. There\'s smoke coming from my bakery!',
    rescue: Rescue.fire,
    wow: 'Did you know? A fire engine carries its own water tank, and long hoses to reach far away.',
    grownUp: 'Talk about what to do if a smoke alarm goes off at home.',
  ),
  const Mission(
    id: 'flat_battery',
    kind: MissionKind.diagnose,
    caller: bramble,
    title: 'Won\'t start',
    icon: Icons.battery_charging_full,
    call: 'Hello, it\'s Mr Bramble. I turn the key and my car just goes click!',
    fault: Fault.flatBattery,
    wow: 'Did you know? A car battery gives the spark that starts the engine. Leaving the lights on can make it go flat.',
    grownUp: 'Spot the battery symbol on a phone or remote. What happens when it runs out?',
  ),
  Mission(
    id: 'muddy_tow',
    kind: MissionKind.drive,
    caller: ella,
    title: 'Muddy road',
    icon: Icons.agriculture,
    call: 'Hi, it\'s Ella! My car is stuck on the farm road. It\'s very muddy out here!',
    clues: const [Prep.monsterTyres],
    routeChoice: true,
    course: DriveCourse(
      length: 7000,
      mud: const [(2000.0, 3000.0), (4600.0, 5600.0)],
      bumps: const [1300.0, 6200.0],
      stars: DriveCourse.starsFor(7000),
    ),
    wow: 'Did you know? Tractors have giant bumpy tyres so they grip in squishy mud.',
    grownUp: 'Next time it rains, look at tyre tracks in mud. Which tyres made deep bumpy marks?',
  ),
  const Mission(
    id: 'tree_down',
    kind: MissionKind.dispatch,
    caller: farmer,
    title: 'Fallen tree',
    icon: Icons.forest,
    call: 'Baa! It\'s Farmer Woolly. A big tree fell across the road in the storm!',
    rescue: Rescue.tree,
    wow: 'Did you know? Cranes have heavy weights on the back so they don\'t tip over when they lift.',
    grownUp: 'Can you lift something heavy with a long stick? Talk about why cranes need to be strong.',
  ),
  const Mission(
    id: 'car_park',
    kind: MissionKind.carPark,
    caller: mayor,
    title: 'Car park',
    icon: Icons.local_parking,
    call: 'Hello, it\'s Mayor Pip! The town car park is a muddle. Can you park every car in the right space?',
    wow: 'Did you know? Some car parks are stacked up high, like a tower of floors.',
    grownUp: 'In a real car park, count the red cars together. Then the blue ones!',
  ),
  const Mission(
    id: 'dirty_windscreen',
    kind: MissionKind.diagnose,
    caller: farmer,
    title: 'Can\'t see',
    icon: Icons.water_drop,
    call: 'Baa, it\'s Farmer Woolly again. My windscreen is so muddy I can\'t see the road!',
    fault: Fault.dirtyWindscreen,
    wow: 'Did you know? Windscreen wipers swish side to side, and a little squirter sprays soapy water.',
    grownUp: 'On a rainy day, watch the wipers in the car. Count how many swishes!',
  ),
  const Mission(
    id: 'bus_count',
    kind: MissionKind.bus,
    caller: driverDot,
    title: 'Bus helper',
    icon: Icons.directions_bus,
    call: 'Quack! It\'s Driver Dot. I need a helper to count people on and off my bus!',
    wow: 'Did you know? A big double-decker bus can carry about 80 people!',
    grownUp: 'On a bus ride, count how many people get on at each stop.',
  ),
  Mission(
    id: 'night_delivery',
    kind: MissionKind.drive,
    caller: baker,
    title: 'Night delivery',
    icon: Icons.nightlight_round,
    call: 'It\'s Baker Bea. Can you deliver bread for breakfast? You\'ll need to drive in the dark!',
    clues: const [Prep.headlights, Prep.roadSense],
    course: DriveCourse(
      length: 7500,
      night: true,
      trafficLights: const [2400.0],
      zebras: const [5000.0],
      bumps: const [1200.0, 6400.0],
      stars: DriveCourse.starsFor(7500),
    ),
    wow: 'Did you know? Red means stop, amber means get ready, and green means go.',
    grownUp: 'At a real crossing, wait for the green person together and talk about why we wait.',
  ),
  const Mission(
    id: 'park_hurt',
    kind: MissionKind.dispatch,
    caller: kit,
    title: 'Ouch!',
    icon: Icons.local_hospital,
    call: 'Hello? It\'s Kit at the park. My friend fell off the climbing frame!',
    rescue: Rescue.hurt,
    wow: 'Did you know? In the UK you call 999 in an emergency, and an ambulance can come with flashing lights.',
    grownUp: 'Practise saying your address together, in case you ever need to call 999.',
  ),
  const Mission(
    id: 'loose_bolt',
    kind: MissionKind.diagnose,
    caller: ella,
    title: 'Clunk clunk',
    icon: Icons.build,
    call: 'It\'s Ella! My car goes clunk clunk clunk when I drive. It sounds funny!',
    fault: Fault.looseBolt,
    wow: 'Did you know? Mechanics listen to cars carefully. Strange noises are clues!',
    grownUp: 'Find a bolt or screw at home and try turning it with a spanner or screwdriver.',
  ),
  const Mission(
    id: 'electric_car',
    kind: MissionKind.diagnose,
    caller: mayor,
    title: 'Electric car',
    icon: Icons.ev_station,
    carType: VehicleType.electricCar,
    call: 'Mayor Pip here! My new electric car has stopped. Do I need fuel?',
    fault: Fault.noCharge,
    wow: 'Did you know? Electric cars are very quiet and they don\'t puff out smoke.',
    grownUp: 'Look for car chargers in a car park. Is anyone plugged in?',
  ),
  Mission(
    id: 'low_bridge',
    kind: MissionKind.drive,
    caller: granny,
    title: 'Low bridge',
    icon: Icons.vertical_align_bottom,
    call: 'Granny Hettie again! Can you tow my old car? The road goes under a very low bridge!',
    clues: const [Prep.lowerCrane, Prep.roadSense],
    routeChoice: true,
    course: DriveCourse(
      length: 8000,
      lowBridges: const [3000.0],
      trafficLights: const [5400.0],
      tunnel: (6200.0, 7000.0),
      bumps: const [1500.0],
      stars: DriveCourse.starsFor(8000),
    ),
    wow: 'Did you know? Low bridges have signs that tell drivers how tall their truck can be.',
    grownUp: 'Spot a bridge on a journey. Would a tall bus fit underneath?',
  ),
  const Mission(
    id: 'rocks',
    kind: MissionKind.dispatch,
    caller: bramble,
    title: 'Rock pile',
    icon: Icons.construction,
    call: 'Mr Bramble here. I\'m building a new house, but there\'s a huge pile of rocks in the way!',
    rescue: Rescue.rocks,
    wow: 'Did you know? Some giant dump trucks are as big as a house!',
    grownUp: 'Build a pile of blocks and use a toy truck or a box to move them.',
  ),
  const Mission(
    id: 'bus_stop',
    kind: MissionKind.dispatch,
    caller: driverDot,
    title: 'School run',
    icon: Icons.groups,
    call: 'Quack! Driver Dot here. Lots of friends are waiting at the bus stop!',
    rescue: Rescue.crowd,
    wow: 'Did you know? One bus can carry as many people as about 20 cars!',
    grownUp: 'Count the people at a bus stop. Would they all fit in your car?',
  ),
  const Mission(
    id: 'no_fuel',
    kind: MissionKind.diagnose,
    caller: kit,
    title: 'Cough cough',
    icon: Icons.local_gas_station,
    call: 'It\'s Kit! My car coughed and then stopped right in the road!',
    fault: Fault.noFuel,
    wow: 'Did you know? The fuel gauge shows how much fuel is left. E means empty and F means full.',
    grownUp: 'At a petrol station, look for the E and F on the fuel gauge.',
  ),
];

Mission missionById(String id) => missions.firstWhere((m) => m.id == id);

/// Age bands chosen by the parent. Changes how many choices are shown and
/// how quickly hints appear.
enum AgeBand { little, middle, big }

const ageBandLabels = <AgeBand, String>{
  AgeBand.little: '2–3',
  AgeBand.middle: '4–5',
  AgeBand.big: '6+',
};

int choicesFor(AgeBand a) => switch (a) {
      AgeBand.little => 2,
      AgeBand.middle => 3,
      AgeBand.big => 4,
    };

Duration hintDelayFor(AgeBand a) => switch (a) {
      AgeBand.little => const Duration(seconds: 4),
      AgeBand.middle => const Duration(seconds: 8),
      AgeBand.big => const Duration(seconds: 14),
    };
