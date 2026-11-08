import 'package:flutter/material.dart';

import '../art/town_art.dart';
import '../art/truck_art.dart';
import '../data/missions.dart';
import '../state/game_state.dart';
import 'ui.dart';

/// Draws any fleet vehicle. The tow truck is the child's own, painted and
/// stickered; the rest use the simple vehicle art.
Widget fleetVehicleArt(GameState s, VehicleType v,
    {double t = 0, double turn = 0, bool silhouette = false}) {
  final Widget art = v == VehicleType.towTruck
      ? CustomPaint(painter: VehiclePainter(lookFrom(s, built: allParts, wheelTurn: turn)))
      : CustomPaint(painter: SimpleVehiclePainter(CarLook(type: v, t: t, wheelTurn: turn)));
  if (!silhouette) return art;
  return ColorFiltered(
    colorFilter: ColorFilter.mode(fade(kInk, 0.18), BlendMode.srcIn),
    child: art,
  );
}
