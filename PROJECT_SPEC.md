# ORBIT — Project Specification

> **Simple to play. Infinite to master.**
> A premium, minimalist 2D physics merge puzzle for iOS and Android.

Status: **Phase 1 (foundation)** · Engine: **Godot 4.5.1 stable** · Language: **GDScript**

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
| Planets | Up to 12 configurable levels (radius + color per level). | ✅ data · ⏳ merging |
| Merging | Two touching planets of the same level → one planet of level +1. Exactly once per pair. | ⏳ Phase 2 |
| Chain reactions | A merged planet can immediately merge again. | ⏳ Phase 2 |
| Scoring | Points awarded per merge (scaling with level; chain bonus). | ⏳ Phase 2 |
| Next planet | Preview of the upcoming planet. | ⏳ Phase 3 |
| Game over | Based on the playable boundary ring (see §5). | ⏳ Phase 3 |
| Restart | Immediate, one tap. (Dev shortcut `R` exists now.) | ⏳ Phase 3 |

## 3. Physics model (decisions & reasons)

- **Engine:** Godot's built-in 2D physics (`RigidBody2D`), 60 physics ticks/s.
  Project default gravity is **0** — the only gravity is ours, toward the core.
- **Gravity applied as a force** in `Planet._integrate_forces()` using
  `OrbitPhysics.gravity_acceleration()`. A force is integrated *before* contacts
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

## 4. Controls

- Touch (phone) and mouse (desktop) share **one code path**: the project enables
  *Emulate Touch From Mouse*, so the launcher only handles touch events.
- Only the first finger aims; extra fingers are ignored. An OS-cancelled touch
  never fires.

## 5. Game-over condition (proposal — to confirm in Phase 3)

The faint ring around the core is the **playable boundary** (`boundary_radius`).
Proposed rule: *the game ends when any launched planet has its center outside
the boundary while nearly at rest (speed < threshold) for a continuous grace
period (e.g. 2 s).* Moving planets passing through the ring never end the game,
which keeps it fair. A visual warning appears during the grace period.

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

## 7. Technical architecture

```
orbit/
├── project.godot              # Engine settings (portrait, 720×1280 base, gl_compatibility)
├── resources/config/
│   └── default_config.tres    # Active GameConfig — tweak gameplay here
├── scripts/
│   ├── config/game_config.gd  # GameConfig resource: all tunable numbers + validate()
│   └── physics/orbit_physics.gd  # Pure static math (unit-tested)
├── scenes/
│   ├── main/       main.tscn/.gd       # Wires everything; spawning; layout
│   ├── core/       gravity_core.*      # StaticBody2D core + boundary drawing
│   ├── planet/     planet.*            # RigidBody2D planet + procedural drawing
│   └── launcher/   launcher.*          # Touch/mouse slingshot + aim indicator
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
- **Pure logic separated from nodes** (`OrbitPhysics`, later `MergeRules`,
  `ScoreRules`) so it can be unit-tested without running scenes.
- **No third-party dependencies**, no backend, no monetization, offline-only.

## 8. Testing

- Run: `godot --headless -s res://tests/run_tests.gd` (exit code 0 = pass).
- Unit tests: physics math, config validation.
- Integration tests: real scene + real physics, headless (launch, settle,
  speed cap, touch input, cancel).

## 9. Non-goals (for now)

Monetization, ads, analytics, backend/leaderboards, paid APIs, push
notifications, streaks/daily-reward pressure mechanics.
