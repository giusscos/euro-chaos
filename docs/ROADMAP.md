# EuroChaos — Roadmap

Each phase ends with a playable build and a playtest stop. Each mini-game adds
**one** new core system that the final island game reuses.

## Phase 0 — Foundations  ← current

Goal: drive a greybox Vespa around a bare test level and have it feel good.

- [ ] Repo: rename `master` → `main`, initial commit, work on `phase-0` branch,
      `.gitignore` additions (`.DS_Store`, `/build/`)
- [ ] Project settings: typed-GDScript warnings as errors, physics interpolation,
      custom user dir, Jolt (already set)
- [ ] Folder structure (`core/`, `minigames/vespa_delivery/`, `assets/`, `tools/`, `docs/`)
      and `docs/ASSETS.md` (empty table)
- [ ] Input map via `tools/setup_input_map.gd` + `InputActions` constants
- [ ] Autoloads: `Events`, `GameState`, `SceneLoader`
- [ ] Main menu (`core/ui/main_menu.tscn`) listing mini-games from `MiniGameInfo`
      resources, plus "Test Level" and "Quit"
- [ ] Vespa Delivery placeholder main scene (runs, loads the test level)
- [ ] Bare test level: ground plane, sun, sky, plus ramps, bumps, a slope, a curb,
      walls (for testing suspension and camera collision)
- [ ] Vehicle: `ArcadeVehicle`, `VehicleWheel`, `VehicleStats`, `VehicleIntent`,
      `PlayerVehicleController`, greybox scooter + `scooter_stats.tres`
- [ ] Greybox 4-wheel test van with its own stats (proves the controller is shared)
- [ ] `ChaseCamera` with tunable exports
- [ ] Debug overlay: speed, wheels grounded, FPS; R resets the vehicle; key to swap vehicle
- [ ] Headless tests: smoke test (load every scene); vehicle test (throttle moves
      it forward, it stays upright at rest and after a turn)
- [ ] **Stop: report + playtest instructions**

## Phase 1 — Vespa Delivery: core loop (greybox)

Goal: a complete, fun 5-minute loop with no art.

- [ ] Greybox village: piazza, narrow streets, stairs-free hill route, coast road,
      ~8 delivery addresses. Built from primitive "kit" scenes, hand-laid
- [ ] `core/interaction`: Area3D interactables + prompt UI
- [ ] `core/missions`: `MissionData` (pickup, dropoff, time limit, payout, cargo
      type), `MissionRunner`, mission list for the village
- [ ] Delivery loop: pick up at pizzeria → deliver → tip from time + cargo condition
- [ ] HUD: timer, money, objective arrow
- [ ] `SaveManager` (money, best times), `Settings` (volumes), `AudioManager` +
      bus layout, CC0 placeholder SFX
- [ ] Pause menu, results screen
- [ ] Tests: mission flow (accept → pickup → deliver → payout)

## Phase 2 — Comic chaos and feel

- [ ] Cargo physics: stacked pizza boxes / gelato that wobble and can fall
- [ ] Pedestrians on a navmesh, comedic knockback (cartoon, no gore: keeps the
      App Store age rating low)
- [ ] Physics props: fruit crates, café chairs, laundry lines, an angry nonna
- [ ] Satire events (all fictional): tour group following an umbrella blocks the
      street, influencer filming in the road, rival app "FreedomBurger Express"
- [ ] Traffic: AI drivers reuse `ArcadeVehicle` through an AI controller on paths
- [ ] Juice: camera shake, speed lines, horn gags, near-miss bonus

## Phase 3 — Road rules, police, garage

Goal: breaking the law is fun and has consequences; delivery money buys vehicles.

- [ ] `core/traffic`: `TrafficRuleZone` (speed limit, one-way, pedestrian-only
      piazza, sidewalk), `TrafficLight`, stop signs
- [ ] `LawMonitor` on the player vehicle: detects speeding, red lights, wrong way,
      sidewalk driving, hitting pedestrians/cars, only when a witness or police
      unit sees it
- [ ] `WantedSystem`: heat level (stars), decays when out of sight
- [ ] `PoliceDispatcher`: police units (fictional livery, our own uniform designs)
      reuse `ArcadeVehicle` with a pursuit AI controller; roadblocks at high heat
- [ ] Busted → comic fine + lost cargo; escaped → heat resets
- [ ] Vehicle garage/shop: `VehicleDefinition` (name, price, scene, `VehicleStats`,
      unlock rule) in a `VehicleCatalog`; owned vehicles saved
- [ ] Each vehicle has its own engine power, top speed, weight, suspension,
      grip, brakes, steering and cargo capacity; the shop shows ratings derived
      from the stats
- [ ] Starter roster (all fictional): rusty scooter, classic Vespa-style scooter,
      three-wheeled cargo truck (Ape-style), tiny city car, sporty moped

## Phase 4 — Art pass

- [ ] Blender pipeline: shared palette material, `tools/blender/export_gltf.py`
- [ ] Low-poly Vespa, village modular kit (houses, arches, café, church, harbor), props
- [ ] CC0 fillers from Kenney / Quaternius / KayKit, logged in `ASSETS.md`
- [ ] Lighting: warm Mediterranean sun, sky, fog, time of day
- [ ] Audio: engine sound pitched by speed, ambience, music

## Phase 5 — Ship "Vespa Delivery" on the Mac App Store

- [ ] Settings menu (graphics, audio, input remap), EN + IT localization scaffold
- [ ] Export preset with feature tag, bundle ID, icon, sandbox entitlements
- [ ] Verify gamepads work inside the sandbox
- [ ] Performance budget: 60 fps on a base M1 at native resolution
- [ ] Signing, `.pkg`, TestFlight for Mac, App Store Connect listing, age rating,
      privacy details (no data collected)

## Phase 6 — World generator prototype (parallel track, can start after Phase 1)

- [ ] Rule Resources (`RegionRule`, feature rules), seeded heightmap, road graph,
      lot placement for one region (Mediterranean village), baked to `.tscn`
- [ ] Compare against the hand-made village: is it fun to drive?
- [ ] `ClimateState` + `OutfitRule` prototype on placeholder NPCs
- [ ] Profile; decide whether any step needs GDExtension C++

## Later — next mini-games (one new system each)

Ideas, to be decided after Phase 5:

- **On foot** (Dutch canal town): `CharacterBody3D` player controller, interaction,
  bicycles everywhere
- **Camper van** (Alpine pass): heavy vehicle, hairpins, snow and weather
- **Train**: path-following vehicle, stations, passengers, timetable
- **City** (Paris-like): crowds, dense traffic, streaming
- **Island**: world streaming, vehicle switching, the four regions linked
