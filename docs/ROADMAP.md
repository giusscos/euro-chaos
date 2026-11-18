# EuroChaos — Roadmap

Each phase ends with a playable build and a playtest stop. Each mini-game adds
**one** new core system that the final island game reuses.

## Phase 0 — Foundations  ✓ done (merged 2026-11-18)

Goal: drive a greybox Vespa around a bare test level and have it feel good.

- [x] Repo: `master` → `main`, initial commit, work on `phase-0` branch,
      `.gitignore` additions (`.DS_Store`, `/build/`)
- [x] Project settings: typed-GDScript warnings as errors, physics interpolation,
      custom user dir, Jolt, physics layer names
- [x] Folder structure and `docs/ASSETS.md`
- [x] Input map via `tools/setup_input_map.gd` + `InputActions` constants
- [x] Autoloads: `Events`, `GameState`, `SceneLoader`
- [x] Main menu listing mini-games from `MiniGameInfo` resources, plus
      "Vehicle Test Level" and "Quit"; minimal pause menu (pulled from Phase 1)
- [x] Vespa Delivery placeholder main scene (a `MiniGame`, runs on its own)
- [x] Bare test level: ground, sun, sky, ramps, jump, speed bumps, curb, hill,
      steep slope, street canyon, pillars, crate stack
- [x] Vehicle: `ArcadeVehicle`, `VehicleWheel`, `VehicleStats`, `VehicleIntent`,
      `PlayerVehicleController`, greybox scooter
- [x] Greybox 4-wheel test van with its own stats (same code)
- [x] `ChaseCamera` + per-vehicle `ChaseCameraProfile`
- [x] Debug overlay; R resets upright; Backspace respawns; Tab swaps vehicle
- [x] Headless tests: script compile check, smoke test (every scene), mini-game
      contract, scene loader, vehicle physics (rest, accelerate, turn, brake,
      reverse, top speed, reset)
- [x] Playtest + feedback. Fixed from it: wheels sinking into the ground
      after jumps (ray start + bump stop), scooter weaving at speed
      (effective-mass tire forces), throttle + handbrake creeping (locked
      wheels get no drive)

## Phase 1 — Vespa Delivery: core loop (greybox)  ← next

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
- [ ] Results screen (pause menu already done in Phase 0)
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

- [ ] Final game name and scooter brand: fictional. "Vespa" and "Ape" are
      Piaggio trademarks and can't appear in the game, icon or store listing
      (internal folder names are fine)
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
