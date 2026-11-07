# Little Garage (working title)

Build it, learn it, fix it, drive it. A vehicle game for ages 3–6.

## What's in v0.1

One vehicle (tow truck) through the full loop, with placeholder vector art:

1. **Home** – name the truck (name shows on the cab door), pick a driver (bear, bunny, robot).
2. **Assemble** – drag 8 parts onto glowing silhouettes. Each part is named aloud and plays a 2-second "what it does" animation.
3. **Garage** – tap any part to hear it again (Mechanic Mode). Hub for everything else.
4. **Wash** – soap, rinse, dry, each scrubbing its own layer.
5. **Customise** – paint (colour names spoken), wheels (classic, monster, racing, flower), drag-on stickers (tap a sticker on the truck to remove it).
6. **Drive** – press and hold anywhere to go. Horn, headlights, day/night.
   - Mud: small wheels get stuck, monster tyres splash through.
   - Tunnel and night: stars only show with headlights on.
   - Breakdown halfway (flat tyre, empty tank or broken headlight) → **Fix-it mission**: pick the right tool from the toolbox.
7. **Spot it outside** – tap a vehicle when you see it on a walk.
8. **Parent zone** (padlock, behind a grown-up maths question) – voice and sound toggles, wind-down timer (truck goes to sleep, no hard lock), progress card, reset.

No ads, no analytics, works offline, saves locally.

## First run

The repo has `lib/` and `pubspec.yaml` only. Generate the platform folders once:

```bash
flutter create . --org com.littlefortstudios --project-name little_garage --platforms ios,android,web
flutter pub get
flutter run -d chrome        # quickest check
```

Then lock orientation to landscape on iOS (the app also requests it in code):

`ios/Runner/Info.plist` → under `UISupportedInterfaceOrientations` keep only
`UIInterfaceOrientationLandscapeLeft` and `UIInterfaceOrientationLandscapeRight`
(same for the `~ipad` key).

Android: in `android/app/src/main/AndroidManifest.xml`, add
`android:screenOrientation="sensorLandscape"` to the `<activity>`.

## Code map

```
lib/
  main.dart                 app, landscape lock, wind-down overlay
  data/models.dart          parts, wheels, stickers, breakdowns, paint colours
  data/tow_truck.dart       the tow truck: part order, names, spoken lines
  state/game_state.dart     all state + local save (shared_preferences)
  services/voice.dart       text-to-speech (swap for recorded lines later), haptics
  art/truck_art.dart        placeholder vector art; geometry shared by silhouettes,
                            thumbnails, hit-testing and the wash mask
  art/scenery.dart          parallax road scene, garage interior
  widgets/ui.dart           bubble buttons, star counter, banner, star burst, parent gate
  widgets/wind_down.dart    "truck goes to sleep" timer overlay
  screens/                  home, assemble, garage, wash, customise, drive, fix, spot, parent
```

## Swapping in real art

Each `PartKind` is drawn by `paintPart()` in `art/truck_art.dart`, inside a 400 × 250
unit box. To use PNG layers: export each part on its own transparent layer at the
position given by `TruckGeo.bounds()`, then draw the image there instead of the
vector shapes. Keep `TruckGeo` shapes for silhouettes and hit-testing, or generate
silhouettes from the PNG alpha.

## Not done yet

- Purchases (RevenueCat) – placeholder button in the parent zone.
- Recorded voice lines and real sound effects (currently text-to-speech and system clicks).
- More vehicles (fire engine, digger, dump truck).
- Child photo in the driver's seat.
