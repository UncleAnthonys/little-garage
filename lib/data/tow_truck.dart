import 'models.dart';

/// The launch vehicle. New vehicles are added as another VehicleDef plus
/// their geometry in art/.
const towTruck = VehicleDef(
  id: 'tow_truck',
  name: 'Tow truck',
  parts: [
    PartDef(PartKind.chassis, 'Chassis',
        'The chassis is the strong frame that holds everything together.'),
    PartDef(PartKind.cab, 'Cab', 'The cab is where the driver sits.'),
    PartDef(PartKind.wheels, 'Wheels',
        'Wheels roll round and round so the truck can move.'),
    PartDef(PartKind.engine, 'Engine', 'The engine makes the power to go!'),
    PartDef(PartKind.exhaust, 'Exhaust pipe',
        'Old air puffs out of the exhaust pipe.'),
    PartDef(PartKind.crane, 'Crane',
        'The crane lifts broken cars with its strong hook.'),
    PartDef(PartKind.headlights, 'Headlights',
        'Headlights help us see in the dark.'),
    PartDef(PartKind.steering, 'Steering wheel',
        'Turn the steering wheel to go left and right.'),
  ],
);
