# ORBIT — Development Log

Newest entries first. Every "passed" below refers to a test run that was actually executed.

---

## 2026-11-24 — Phase 5: Mobile release prep

### Built
- `SafeArea` (pure): converts the phone's safe area to canvas margins; score,
  pause button, launcher and hint respect notches / home indicator. Desktop: 0.
- Pause: `PauseButton` (top-left, 72 px touch target), `PauseMenu` (Resume,
  Restart, Sound / Vibration / Planet numbers switches). Automatic pause on
  `NOTIFICATION_APPLICATION_PAUSED` / `FOCUS_OUT`. Main state machine gained PAUSED.
- `PlayerSettings`: saved in the same file as the best score (separate section).
- Accessibility: optional level numbers on planets and in the NEXT preview.
- `export_presets.cfg`: Android (arm64 + armv7, VIBRATE permission, no INTERNET
  permission, immersive) and iOS (iPhone + iPad, iOS 14+). Version 0.5.0.

### Issues found & fixed
- Score popups rendered above the pause menu → own `HUD/Popups` layer below overlays (+ test).
- Default grey CheckButtons were ambiguous and off-style → custom `SwitchToggle`
  (aqua = on). Track seams from overlapping translucent shapes → opaque colors
  (this last tweak was not re-rendered).

### Verification (executed)
- Tests: **80 passed, 0 failed** (engine-error detection active).
- `--export-pack Android`: pack mounted in an empty project and listed: 53 files,
  no `tests/`, no docs, main scene present.
- Rendered at 720×1560 (19.5:9): tall layout, pause menu, planet numbers OK.

### Blocked / environment
- dl.google.com was blocked by the cloud environment's network policy; the
  owner approved allowing it. Export templates (4.5.1) and Android command-line
  tools were installed in the session scratchpad.
- Installing SDK packages requires **accepting the Android SDK license**; that is
  the project owner's decision, so the signed APK build was not done.
- Not verified: anything on a real device (touch, safe area, haptics, sound, FPS).

---

## 2026-11-24 — Performance pass + Phase 4: Feel & polish

### Performance (measured, same benchmark before/after: ~60 planets spawned)
| | Before | After |
|---|---|---|
| Draw calls / frame | 958 | 77 |
| Frame time (CPU software rendering in container) | ~36 ms | ~9 ms |
| Resting planets asleep | 0 of 26 | 32 of 32 |
| Physics time / frame | ~1.0 ms | ~0.65 ms |

Changes:
- **Shader planets.** Each planet was ~35 draw calls (stacked translucent
  circles). Now one quad + `planet.gdshader` (sphere lighting, rim, glow per
  pixel). All planets share one ShaderMaterial and pass color as vertex color,
  so Godot batches them. Also removes the visible shading bands.
- **Sleeping bodies.** `state.apply_central_force` every step woke every body.
  Gravity is now `constant_force`, re-set only if it changes by >1%. Resting
  planets sleep; the speed cap only writes velocity when exceeded.
- **Core** split into cached layers; breathing glow animates `modulate` only.
- **Physics interpolation** enabled (smooth on 90/120 Hz screens);
  teleports call `reset_physics_interpolation()`.

### Issues found & fixed
- Shader used the reserved name `LIGHT` → compile error, **but tests still
  passed**. Added `tests/error_counter.gd` (Godot 4.5 `Logger`): any engine error
  now fails the running test. Verified: the broken shader makes a test fail.
- NEXT preview showed a faint square (glow-less quad corners) → always draw the
  full glow quad.
- Sound generation took 95 ms on the desktop CPU; done lazily it would freeze
  the first merge on phones → generated on a WorkerThreadPool thread at startup,
  shared across restarts.

### Phase 4 features
- Merge burst (ring + sparks), popups offset above the planet.
- `Feedback` node: sound + haptics behind a tiny API (launch/merge/vanish/game over).
- `ToneSynth`: procedural bells (C-major pentatonic by level), whoosh, chords.
- Level 10 color changed (pearl → orchid) so the three top levels are distinct.

### Verification (executed)
- `godot --headless -s res://tests/run_tests.gd` → **67 passed, 0 failed**, with
  engine-error detection active.
- Rendered runs: shader planets, merge burst, no shader/script errors.
- **Not verified:** how the sounds actually sound (no audio device here), haptics
  (needs a phone), real-device FPS.

---

## 2026-11-24 — Phase 3: Game loop

### Built
- `BoundaryMonitor` (engine-free): per-planet danger timers, progress 0..1, game over.
- `HighScoreStore`: best score in `user://orbit_save.cfg` via ConfigFile.
- `PlanetArt`: planet drawing extracted so the NEXT preview matches real planets.
- `NextPreview`, `GameOverPanel` (score, best / NEW BEST, PLAY AGAIN).
- `Main` state machine PLAYING → GAME_OVER: freezes the field, disables the
  launcher, stops scoring, saves the best score; restart reloads the scene
  (simplest way to guarantee a clean state).
- Warning visuals: boundary ring and offending planet pulse white.

### Issues found & fixed
- **Warning too faint:** in a rendered bot game the warning frame was captured at
  the pulse's low point and was nearly invisible. Raised the minimum brightness;
  re-captured a frame at the pulse minimum to confirm it stays visible.

### Verification (executed)
- `godot --headless -s res://tests/run_tests.gd` → **57 passed, 0 failed** (exit 0).
- Mutation check: forcing `game_over` to always be false made 4 tests fail
  (then restored → 57 pass). The game-over tests really test the rule.
- Rendered bot game (random aims, Xvfb): game over reached after 261 launches,
  ~152 s, score 20,375, "NEW BEST" shown; clicking PLAY AGAIN with a simulated
  mouse click loaded a fresh game (score 0, planet loaded, state PLAYING).
- Still unverified: real phones, touch on actual hardware, performance.

---

## 2026-11-24 — Phase 2: Merging & scoring

### Decisions confirmed by the designer
- Launcher stays fixed at the bottom; aim line only (no trajectory preview);
  game-over proposal (PROJECT_SPEC §5) approved for Phase 3.

### Built
- `MergeRules` and `ScoreRules` (pure, unit-tested).
- `PlanetField` node replaces the plain `Planets` container: spawning, merge
  resolution (once per physics step), despawn of escaped planets.
- `Planet`: contact reporting, `consumed` flag, `chain_depth`, grow-in after merge.
- Score label + floating "+points" popups (chains shown in aqua with ×depth).
- New config values: merge momentum keep, grow time, chain window, max-level
  vanish, base points, chain bonus, vanish points.
- Design choices made (easy to change in config): two max-level planets vanish
  for 1000 points; chain multiplier +0.5 per step; points by triangular numbers.

### Issue found & fixed
- **Symptom:** in a rendered 30-launch session, levels 0–2 were hard to tell
  apart (three similar violets).
- **Fix:** new palette where neighbouring levels differ in hue, plus test
  `test_adjacent_levels_have_distinct_colors`. Verified the test FAILS on the old
  palette (levels 0/1, 1/2, 2/3 too similar) and PASSES on the new one.

### Verification (executed)
- `godot --headless -s res://tests/run_tests.gd` → **41 passed, 0 failed** (exit 0).
- Rendered 30-launch simulated session (Xvfb, software OpenGL): 18 merges,
  chains up to depth 3, highest level reached 5, no script errors.
  Screenshots: `docs/orbit_phase2.png`, `docs/orbit_levels.png`.
- FPS in this container (CPU software rendering) was ~48 with ~12 planets;
  this is NOT representative of phones. Real-device performance still unverified.

### Known limitations
- Test `test_loaded_planet_at_launcher_never_merges` is weak as an integration
  test (the active planet may drift away quickly); the rule itself is covered by
  the unit test `test_find_pairs_ignores_inactive_planets`.

---

## 2026-11-24 — Phase 1: Foundation

### Environment
- Starting directory was empty; no Godot installed in the cloud dev container.
- Downloaded official **Godot 4.5.1 stable** (Linux) to run imports, tests and
  rendered screenshots. Xvfb used as a virtual display for screenshots.

### Built
- Project config: portrait, 720×1280 base, `canvas_items` + `expand` stretch,
  `gl_compatibility` renderer, 60 physics ticks, zero default gravity,
  touch emulated from mouse.
- `GameConfig` resource (all tunables, 12 levels, `validate()`).
- `OrbitPhysics` pure math: gravity, speed clamp, slingshot launch velocity, mass.
- Scenes: `Main`, `GravityCore`, `Planet`, `Launcher`.
- Dependency-free headless test runner (`tests/run_tests.gd`).

### Issue found & fixed
- **Symptom:** integration test *"launched planet settles"* failed — planet was
  touching the core but reported 17 px/s forever, with occasional 35 px/s spikes.
- **Cause:** gravity was added directly to `linear_velocity` inside
  `_integrate_forces`, which Godot runs *after* the contact solver, so every step
  ended with un-cancelled gravity velocity.
- **Fix:** apply gravity with `state.apply_central_force(accel * mass)`. Forces
  are integrated before contacts are solved. Trace after fix: exactly 0.0 px/s,
  position constant.
- **Note:** a resting planet stays "awake" (applying a force each step prevents
  sleep). Harmless now; revisit in the Phase 4 performance pass.

### Verification (executed)
- `godot --headless --import` — no script errors.
- `godot --headless -s res://tests/run_tests.gd` → **17 passed, 0 failed** (exit 0).
- Rendered run under Xvfb (OpenGL3): main scene runs, 6 planets launched and
  settled around the core, aim indicator renders. Screenshots in `docs/`.
- Not yet verified: running on a real phone, exported builds, real-device FPS.

### Open questions for the designer
1. Launcher fixed at the bottom vs. movable around the boundary?
2. Should a trajectory preview exist (easier) or only the aim line (more skill)?
3. Game-over rule proposal in PROJECT_SPEC §5 — approve or adjust.
