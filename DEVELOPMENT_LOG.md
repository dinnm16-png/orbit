# ORBIT — Development Log

Newest entries first. Every "passed" below refers to a test run that was actually executed.

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
