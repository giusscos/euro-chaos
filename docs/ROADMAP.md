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

## Phase 1 — Vespa Delivery: core loop (greybox)  ✓ done (merged 2026-11-18)

Goal: a complete, fun 5-minute loop with no art.

- [x] Greybox village (192 × 176 m): piazza with fountain and church, narrow
      streets, upper town on a 6 m plateau with two ramps, coast road, beach,
      pier, sea; 9 customer houses + pizzeria + gelateria. Described as an ASCII
      map (`minigames/vespa_delivery/levels/village_map.txt`) and built by
      `GreyboxMapBuilder` (first step toward the Phase 6 generator)
- [x] `core/interaction`: `Interactable` (stop inside / press E) + prompt UI;
      `HazardZone` (the sea)
- [x] `core/missions`: `CargoType`, `MissionData`, `MissionLocation`,
      `MissionRunner`, `CargoMonitor`, `DeliveryResult`, `ObjectiveMarker`;
      10 satirical missions and 5 cargo types for the village
- [x] Delivery loop: shift of 5 jobs → pick up → timed delivery → pay + tip
      from time left and cargo condition; late = half pay; ruined = nothing;
      fall in the sea = respawn + wet cargo
- [x] HUD: job + customer quote, objective + distance, timer, cargo bar,
      money, shift progress, prompt, pop-ups; 3D objective arrow
- [x] `SaveManager` (money, best shift, deliveries), `Settings` (volumes),
      `AudioManager` + bus layout; placeholder SFX synthesized in code
      (`ProceduralSfx`), engine sound pitched by speed, horn
- [x] Results screen (pause menu already done in Phase 0)
- [x] Tests: interaction, mission flow and scoring, cargo damage, saving,
      audio, map builder, village locations, a full shift end to end, sea respawn
- [x] Playtest + feedback: approved

## Phase 2 — Comic chaos and feel  ✓ done (merged 2026-11-18)

- [x] Cargo you can see: pizza boxes / tower / gelato / espresso tray on the
      rack, swaying with the ride, toppling past each cargo's limit
- [x] Pedestrians on the level's street grid (navmesh postponed: the grid is
      simpler and every map gets it free), cartoon knockback, horn dodges
- [x] Physics props: café tables and chairs, fruit stands; angry nonnas on
      their doorsteps (laundry lines: Phase 4 art pass)
- [x] Satire events (all fictional): tour group following an umbrella,
      influencer filming in the road, rival app "FreedomBurger Express"
      racing you for the tip
- [x] Traffic: AI drivers reuse `ArcadeVehicle` via `AiVehicleController`;
      village gets a two-lane ring road, alleys become a scooter-only zone
      with bollards
- [x] Juice: camera shake, speed lines, horn gags, near-miss bonus, chaos
      score with floating text
- [x] Playtest + feedback: approved

## Phase 3 — Road rules, police, garage  ✓ done (merged 2026-11-20)

- [x] Road rules as map data (`@oneway`, `@light`, `@camera`): 3 one-way
      alleys, lights at both ring-road junctions, 2 speed cameras; speed
      limits per kind of street; AI cars stop at red
- [x] `LawMonitor`: speeding, wrong way, red lights, mayhem; witnesses
      (pedestrians or police with line of sight); speed camera fines
- [x] `WantedSystem`: heat → stars, cools off out of police sight; HUD stars
- [x] `PoliceDispatcher`: cars (and a scooter from 3 stars) chase with the
      shared AI driver; busted = fine + order confiscated; escape when heat
      cools; sirens and light bars (fictional "VIGILI")
- [x] Garage: `VehicleDefinition`, `VehicleCatalog`, `Garage`; Zanzara 125
      (starter), Formica cargo trike, Saetta 50 moped, Topolino city car with
      roof rack; ratings from stats; garage screen from the results screen
- [x] Tests: rules, offences and witnesses, heat, police bust/escape, garage
      buying and vehicle swap, bollards vs fits_alleys
- [x] Playtest + feedback: approved

## Phase 4 — Art pass  ← next

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
