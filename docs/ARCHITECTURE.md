# EuroChaos — Architecture

Godot 4.7 (Forward+, Metal on macOS), Jolt physics, statically typed GDScript.
C++ (GDExtension) only for hot paths that profiling proves are too slow in GDScript.

## Principles

- **One project, many mini-games.** `core/` never depends on `minigames/`.
  Mini-games depend on `core/`, never on each other.
- **Every scene runs on its own** (F6 / "Run Current Scene"). Autoloads guarantee
  global services exist whatever scene is booted.
- **Data in Resources.** Vehicle stats, missions, mini-game metadata are `.tres`
  files (think `Codable` structs the editor can edit). Gameplay numbers are
  `@export` vars, never literals in code.
- **Intent, not input.** Controllers (player, AI, test script) write an intent
  object (`throttle`, `brake`, `steer`, …); actors only read intent. The same
  Vespa can be driven by the player, by traffic AI or by a headless test.
- **Signals up, calls down.** Children emit signals, parents call methods.
  A small global `Events` bus only for cross-system events.
- **Sandbox-safe I/O.** Read `res://`, write only `user://`. Saves are JSON, not
  `.tres` (loading a `.tres` from disk can run embedded scripts).

## Layout

```
res://
  core/
    autoload/       Events, GameState, SceneLoader, Settings, SaveManager, AudioManager
    input/          InputActions (StringName constants for every action)
    vehicle/        ArcadeVehicle, VehicleWheel, VehicleStats, VehicleIntent,
                    PlayerVehicleController, greybox vehicle scenes, stats/*.tres
    camera/         ChaseCamera, ChaseCameraProfile, profiles/*.tres
    interaction/    Interactable, Interactor            (Phase 1)
    missions/       MissionData, MissionRunner          (Phase 1)
    minigame/       MiniGame base script, MiniGameInfo resource
    levels/         test_level, vehicle_playground, greybox/ (grid shader,
                    GreyboxBlock: sized box/cylinder with collision, crate)
    ui/             main_menu, pause_menu, debug_overlay, HUD widgets, theme/
  minigames/
    vespa_delivery/ vespa_delivery.tscn (main), info.tres, levels/, missions/
  assets/
    blender/        our .blend sources + exported .glb
    kenney/ quaternius/ kaykit/ polyhaven/   (CC0 only, mirrors source)
    audio/
  tools/
    check.sh              import + compile all scripts + boot + tests (one command)
    check_scripts.gd      compiles every script with autoloads loaded
    run_tests.gd          headless test runner; tests/test_*.gd hold the tests
    capture_scene.gd      opens a scene in a real window and saves a screenshot
    setup_input_map.gd    writes the input map into project.godot (headless)
    blender/export_gltf.py   (Phase 4)
  docs/             ARCHITECTURE.md, ROADMAP.md, ASSETS.md
```

## Autoloads (global singletons, registered in project.godot)

| Name | Job | Phase |
|---|---|---|
| `Events` | Global signal bus (`delivery_completed`, `chaos_triggered`, …) | 0 |
| `GameState` | Session state: active mini-game, money, flags | 0 |
| `SceneLoader` | Threaded scene change + loading screen | 0 |
| `Settings` | `user://settings.cfg`: volumes, display, input remaps | 1 |
| `SaveManager` | Versioned JSON slots in `user://saves/`, namespaced per mini-game | 1 |
| `AudioManager` | Bus layout, pooled one-shot SFX, music crossfade | 1 |

## Vehicle system

`ArcadeVehicle` (RigidBody3D) + N × `VehicleWheel` (raycast suspension) +
`VehicleStats` (Resource) + `VehicleIntent`.

Per physics tick, each wheel raycasts down and applies at its contact point:
spring + damper force (suspension), lateral grip force (cancels sideways slip,
shaped by a grip curve), drive/brake force along the wheel's forward. The body
adds: upright-assist torque (keeps two-wheelers from falling), speed-sensitive
steering, air control, top-speed limiting. Lean/pitch are applied to the
**visual mesh only**, so physics stays stable. Stability tweaks are applied as
angular acceleration, so tuning doesn't depend on mass or shape. The body's
own damping is replaced by the stats (Godot's project default would cap top
speed). Wheel rays start inside the chassis (`ray_start_height`) and a
predictive bump stop turns a bottomed-out wheel into a solid contact, so hard
landings never push the wheels into the ground. Tire grip and the bump stop use the
*effective mass* at the contact point (mass plus rotational inertia), not a
share of total mass; that keeps light, narrow vehicles stable at speed.

Why not `VehicleBody3D`: two-wheelers tip over, grip/drift tuning is opaque and
there is no lean. A custom raycast vehicle is a few hundred lines, fully
tunable, and costs a handful of raycasts per vehicle, so traffic is cheap and no
C++ is needed.

One script covers the Vespa (2 wheels + balance assist), the camper van
(4 wheels, heavy, soft) and traffic cars. The train is path-following
(`PathFollow3D`), not physics.

**Buyable vehicles (Phase 3).** Every vehicle is a `VehicleDefinition`
resource: display name, price, scene, `VehicleStats`, unlock rule, cargo slots.
`VehicleStats` already carries everything a vehicle's character needs (engine
power, top speed, mass, suspension stiffness/damping/travel, grip, brakes,
steering, balance assist), so a new vehicle is a new `.tres` plus a model, not
new code. The shop shows 0–5 ratings derived from the stats.

## Road rules and police (Phase 3)

`core/traffic/` holds the rules, the world only places them:
`TrafficRuleZone` (Area3D: speed limit, one-way direction, pedestrian-only),
`TrafficLight`, stop signs. A `LawMonitor` node on the player vehicle checks
the zones it is in and emits `Events.violation_committed(type, position)`,
counted only if a witness or police unit has line of sight. `WantedSystem`
turns violations into heat (stars) that decays when nobody sees you.
`PoliceDispatcher` spawns police units: an `ArcadeVehicle` with a pursuit AI
controller (same intent interface as the player), so police drive under the
same physics. All police branding is fictional.

## Camera

`ChaseCamera` is a top-level Node3D (not parented to the vehicle, to avoid
jitter) that follows a target with yaw lag, smoothed height, speed-based
distance and FOV, look-ahead, a sphere cast so it never ends up inside a wall,
and right-stick/mouse orbit with auto-recenter. Framing lives in a
`ChaseCameraProfile` resource that each target carries (`camera_profile`), so
a scooter and a van each get the right view.
Physics interpolation is on (smooth on 120 Hz ProMotion screens), so the camera
reads `get_global_transform_interpolated()` in `_process`.

## Input

Actions live in Godot's Input Map (`project.godot`), written by
`tools/setup_input_map.gd` so the setup is repeatable and diffable.

| Action | Keyboard | Gamepad |
|---|---|---|
| `accelerate` | W, ↑ | RT |
| `brake_reverse` | S, ↓ | LT |
| `steer_left` / `steer_right` | A / D, ← / → | Left stick X |
| `handbrake` | Space | A / Cross |
| `horn` | H | Y / Triangle |
| `interact` | E | X / Square |
| `camera_look` (4 actions) | mouse | Right stick |
| `reset_vehicle` | R | Back / Select |
| `pause` | Esc, P | Start |
| `debug_swap_vehicle` | Tab | RB |
| `debug_respawn` | Backspace | LB |
| `debug_toggle_overlay` | O | L3 |

## Mini-game contract

- Main scene `minigames/<name>/<name>.tscn`, root uses the `MiniGame` script
  (`start()`, `finish(result)`, signal `finished`). Booted directly, it starts itself.
- `minigames/<name>/info.tres` (`MiniGameInfo`: title, description, main scene,
  icon). The dev main menu lists every `info.tres` it finds.
- **Shipping one mini-game as its own app:** one export preset per mini-game
  with a custom feature tag (e.g. `vespa_delivery`). Feature-tag overrides in
  `project.godot` (`application/run/main_scene.vespa_delivery`,
  `application/config/name.vespa_delivery`, custom user dir) swap main scene,
  name and save folder; export filters drop the other mini-games' folders;
  bundle ID is set per preset.

## Procedural world (Phase 6, see ROADMAP)

Seeded and deterministic. Rules are Resources: a `RegionRule` (alpine,
mediterranean, canal, city) declares terrain parameters and required features:
city → road graph, building lots, shops, parks; mountains → rivers, lakes, snow
line. Pipeline: heightmap → water → roads → lots → buildings/props → NPC spawn
tables. First as an **edit-time tool** that bakes a `.tscn` we can hand-tweak;
runtime streaming only for the final island.
`ClimateState` (temperature, precipitation, time of day) drives NPC `OutfitRule`s
(shorts and sandals in summer, umbrellas in rain, coats in snow).
GDScript first; port hot loops (mesh building, erosion) to GDExtension C++ after
profiling.

## Art pipeline

Low-poly, flat-shaded, one shared palette texture so most models share one
material (few draw calls). Blender: 1 unit = 1 m, transforms applied, origin at
the base, exported with `tools/blender/export_gltf.py`. CC0 or our own assets
only, every external asset listed in `docs/ASSETS.md`.

## Conventions

- Files and folders `snake_case`; `class_name` `PascalCase`; signals in past tense.
- Static typing enforced: the `untyped_declaration` GDScript warning is set to **Error**.
- Tests: `tools/run_tests.gd` (headless) plus a smoke test that loads every scene.

Dev commands (Godot is not on `PATH`; scripts default to the app bundle,
override with `GODOT=...`):

```bash
tools/check.sh                                   # everything below, in order
GODOT=/Applications/Godot.app/Contents/MacOS/Godot
$GODOT --headless --path . --import              # import assets, rebuild class cache
$GODOT --headless --path . --script res://tools/check_scripts.gd
$GODOT --headless --path . --quit-after 120      # boot the main scene
$GODOT --headless --path . --fixed-fps 60 --script res://tools/run_tests.gd [-- vehicle]
```

Gotchas found so far:
- `--check-only` doesn't know autoloads, so it rejects valid scripts that use
  `Events`/`GameState`; use `tools/check_scripts.gd` instead.
- A `--script` entry script is compiled before autoloads exist: it must not
  reference classes that use autoloads by type. Load them at runtime (as
  `run_tests.gd` does).
- Under `--fixed-fps` the main loop never pauses, which starves background
  loading; tests that wait on `SceneLoader` yield 1 ms per frame.
- Headless mode doesn't compile shaders; use `tools/capture_scene.gd` (opens a
  window) to catch shader errors.

## macOS / Mac App Store

- Apple Silicon first (arm64). Universal later if it costs nothing.
- App Sandbox on. `use_custom_user_dir` so `user://` is
  `~/Library/Application Support/<App>` (inside the container when sandboxed).
- Store builds: Apple Distribution cert + Mac App Store provisioning profile,
  signed `.pkg`, uploaded with Transporter. Notarization is only for Developer ID
  builds outside the store (handy for sending playtest builds to friends).
- Any GDExtension `.dylib` must be signed and live inside the bundle.
