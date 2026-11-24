# ORBIT — Project Specification

> **Simple to play. Infinite to master.**
> A premium, minimalist 2D physics merge puzzle for iOS and Android.

Status: **Phase 5 (mobile release prep) — code complete, device build pending** · Engine: **Godot 4.5.1 stable** · Language: **GDScript**

---

## 1. Vision

ORBIT is an elegant, calm, replayable game about gravity, precision and strategy.
The player launches planets toward a gravitational core; planets of the same
level merge into larger ones. Depth comes from physics and planning, not from
clutter, timers or manipulative mechanics.

## 2. Core gameplay

| Element | Rule | Status |
|---|---|---|
| Gravitational core | Fixed at the screen center. Static collider planets rest on. | ✅ Phase 1 |
| Gravity | Constant-magnitude pull toward the core (configurable). | ✅ Phase 1 |
| Launch | One finger: touch anywhere, pull back, release (slingshot). Power ∝ pull distance, capped. Short pulls cancel. | ✅ Phase 1 |
| Planets | 12 configurable levels (radius + color per level); neighbouring levels have clearly different hues. | ✅ Phase 1–2 |
| Merging | Two touching active planets of the same level → one planet of level +1 at their center of mass, keeping 50% of their momentum. A planet takes part in at most one merge per physics step. | ✅ Phase 2 |
| Max level | Two touching level-12 planets vanish (bonus, frees space). Configurable. | ✅ Phase 2 |
| Chain reactions | A merged planet that merges again within 1.2 s continues the chain (depth 2, 3, ...). | ✅ Phase 2 |
| Scoring | `10 × T(level) × chain multiplier`, T = triangular number (1, 3, 6, 10...), multiplier = 1 + 0.5 × (depth − 1). Vanish = 1000 × multiplier. | ✅ Phase 2 |
| Next planet | Preview ("NEXT") beside the launcher shows the planet loaded after the current one. | ✅ Phase 3 |
| Game over | Based on the playable boundary ring (see §5), with a pulsing warning. | ✅ Phase 3 |
| Restart | One tap on "PLAY AGAIN" (desktop: `R` any time). | ✅ Phase 3 |
| Best score | Saved on the device (`user://orbit_save.cfg`), shown under the score. | ✅ Phase 3 |
| Pause | Button (top-left) or automatic when the app is backgrounded. Menu: Resume, Restart, settings. | ✅ Phase 5 |
| Settings | Sound, Vibration, Planet numbers (accessibility); saved on device. | ✅ Phase 5 |

## 3. Physics model (decisions & reasons)

- **Engine:** Godot's built-in 2D physics (`RigidBody2D`), 60 physics ticks/s.
  Project default gravity is **0** — the only gravity is ours, toward the core.
- **Gravity applied as a constant force** (`Planet._update_gravity_force()`),
  re-set only when it changes by more than 1% so resting planets can sleep. A force is integrated *before* contacts
  are solved, so resting planets reach exactly zero velocity (no jitter).
  *(Verified: applying it as a direct velocity change left resting planets
  vibrating at ~17 px/s — see DEVELOPMENT_LOG.)*
- **Constant magnitude**, not inverse-square: real gravity explodes near the
  center and makes stacks unstable; constant pull is predictable and fair.
- **Speed cap** (`max_planet_speed`) enforced every physics step → no runaway
  acceleration.
- **Continuous collision detection** (shape cast) → fast planets don't tunnel.
- **Mass ∝ area** (`(r / reference)²`) → big planets push small ones.
- **Damping** (linear/angular, replace mode) → planets settle in a few seconds.
- **Safety despawn:** planets farther than `despawn_distance` from the core are removed.

## 3b. Merge system (decisions & reasons)

- **One place, once per step.** `PlanetField._physics_process` collects every
  active planet and its contacts, then `MergeRules.find_pairs()` picks pairs.
  Each planet id can appear in only one pair → **no duplicate merges**, even
  when three equal planets touch at once.
- **Polling contacts instead of `body_entered` signals.** Signals fire only on
  the *first* touch and can arrive in any order; polling `get_colliding_bodies()`
  also catches planets that were already touching, and resolves deterministically
  (oldest planets first).
- **Consumed flag.** A merged planet is marked `consumed`, hidden, its collision
  disabled and freed; everything ignores consumed planets.
- **Grow-in.** The merged planet's collision and visual grow from the old size to
  the new one over 0.15 s, so it doesn't violently shove its neighbours.
- **Frozen planets never merge** (the one waiting at the launcher).
- **Chain depth** comes from parents, but only if they were born from a merge less
  than `chain_window` seconds ago, so "chains" are real cascades.

## 4. Controls

- Touch (phone) and mouse (desktop) share **one code path**: the project enables
  *Emulate Touch From Mouse*, so the launcher only handles touch events.
- Only the first finger aims; extra fingers are ignored. An OS-cancelled touch
  never fires.

## 5. Game-over condition (approved, implemented in Phase 3)

The faint ring around the core is the **playable boundary** (`boundary_radius`).
Rule: *the game ends when any launched planet has its center outside
the boundary while nearly at rest (speed < threshold) for a continuous grace
period (2 s, `game_over_grace_time`).* "Nearly at rest" = slower than 60 px/s
(`game_over_speed_threshold`). Moving planets passing through the ring never end
the game, which keeps it fair. The timer resets if the planet moves back inside,
speeds up, or merges away. During the grace period the boundary ring and the
planet pulse white (never fully fading). On game over the simulation freezes,
input is disabled, scoring stops, and the best score is saved if beaten.
Implemented by `BoundaryMonitor` (engine-free, unit-tested).

## 6. Visual direction

Premium futuristic minimalism. Procedural graphics only (no image assets yet).

| Token | Hex | Use |
|---|---|---|
| Background | `#080910` | Clear color |
| Secondary | `#171B30` | Core body, boundary fill |
| Violet | `#917AFF` | Glow, rings, accents |
| Aqua | `#52E5D5` | Core rim, aim indicator |
| White | `#F5F5FA` | Highlights, text |

Subtle glow, elegant orbital rings, smooth motion, no clutter, no cartoon look.

Rendering: planets are drawn by `resources/shaders/planet.gdshader` (one quad
per planet, shared material → batched). Merges show a short ring + spark burst.

Feedback: soft procedural sounds (merge notes follow the C-major pentatonic
scale by level, so chains rise musically) and short haptics on phones. Both
can be switched off in `GameConfig` (settings screen planned).

## 7. Technical architecture

```
orbit/
├── project.godot              # Engine settings (portrait, 720×1280 base, gl_compatibility)
├── resources/config/
│   └── default_config.tres    # Active GameConfig — tweak gameplay here
├── scripts/
│   ├── config/game_config.gd  # GameConfig resource: all tunable numbers + validate()
│   ├── physics/orbit_physics.gd  # Pure static math (unit-tested)
│   ├── rules/                 # Pure merge_rules, score_rules, boundary_monitor (unit-tested)
│   ├── save/high_score_store.gd  # Best score on device (ConfigFile)
│   └── visual/planet_art.gd   # Shared procedural planet drawing
├── scenes/
│   ├── main/       main.tscn/.gd       # Wires everything; spawning; layout
│   ├── core/       gravity_core.*      # StaticBody2D core + boundary drawing
│   ├── field/      planet_field.gd     # Owns all planets: spawn, merge, despawn
│   ├── planet/     planet.*            # RigidBody2D planet + procedural drawing
│   ├── launcher/   launcher.*          # Touch/mouse slingshot + aim indicator
│   └── ui/         next_preview.gd, game_over_panel.gd
├── tests/          # Dependency-free headless test runner + unit/integration tests
└── docs/           # Screenshots
```

Key choices:

- **Renderer `gl_compatibility`** (OpenGL ES 3): widest device support on
  Android/iOS and best suited to simple 2D. Can be revisited if we need
  advanced effects.
- **Base resolution 720×1280, stretch `canvas_items`, aspect `expand`**: crisp on
  all screens; taller phones simply see more vertical space. Layout is computed
  from the visible rect at runtime.
- **All gameplay numbers in `GameConfig`**, validated at startup.
- **Pure logic separated from nodes** (`OrbitPhysics`, `MergeRules`,
  `ScoreRules`) so it can be unit-tested without running scenes.
- **No third-party dependencies**, no backend, no monetization, offline-only.

## 8. Testing

- Run: `godot --headless -s res://tests/run_tests.gd` (exit code 0 = pass).
- Unit tests: physics math, config validation, color distinctness, merge pair
  selection, chain depth, scoring.
- Integration tests: real scene + real physics, headless (launch, settle,
  speed cap, touch input, cancel, merge, no-merge, triple contact, chain,
  max-level vanish, launcher planet excluded).
- Game loop tests: next-planet prediction, game over after grace (and not
  before), no false game over in normal play, input/scoring locked after game
  over, best score saved only when higher, corrupt save file handled.
- Stress test: 16 planets; the sum of 2^level must be conserved (a duplicate
  merge would break it).

## 9. Non-goals (for now)

Monetization, ads, analytics, backend/leaderboards, paid APIs, push
notifications, streaks/daily-reward pressure mechanics.
