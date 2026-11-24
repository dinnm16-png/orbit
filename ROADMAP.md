# ORBIT — Roadmap

Small, testable milestones. Each ends with: tests run, game launched, log updated.
Major architectural changes are proposed for approval before implementation.

## ✅ Phase 1 — Foundation (done)
- [x] Godot 4 project structure, portrait, mobile-first settings
- [x] PROJECT_SPEC.md, ROADMAP.md, DEVELOPMENT_LOG.md
- [x] Main scene
- [x] Gravitational core (static collider, procedural visuals, boundary ring)
- [x] One launchable planet (reloads after each launch for testing)
- [x] Touch + mouse slingshot input with aim indicator
- [x] Configurable `GameConfig` with 12 planet levels
- [x] Headless test runner + 17 tests

## ✅ Phase 2 — Merging & scoring (done)
- [x] `MergeRules` (pure): pair selection, resulting level, max-level vanish
- [x] Contact detection (`contact_monitor` + polling in `PlanetField`)
- [x] **Duplicate-merge guard**: each planet in at most one merge per step + consumed flag
- [x] Merged planet at center of mass, 50% of combined momentum, grow-in
- [x] Chain reactions with time window and multiplier
- [x] `ScoreRules` (pure) + score display + floating score popups
- [x] Distinct colors for neighbouring levels (+ regression test)
- [x] Tests: 41 total incl. triple contact, chain, vanish, conservation stress test
- [x] Wake neighbours when a planet is removed

## ✅ Phase 3 — Game loop (done)
- [x] Next-planet preview
- [x] Game-over rule (PROJECT_SPEC §5) + pulsing warning state
- [x] Game-over screen, one-tap restart
- [x] Local best score (offline, `user://`)
- [x] Tests for game-over timing and edge cases (57 tests total)

## ✅ Phase 4 — Feel, polish & performance (done)
- [x] Shader-based planets: smooth shading, one batched quad per planet (958 → 77 draw calls)
- [x] Resting planets sleep (gravity as a constant force updated only on change)
- [x] Core drawn once; pulse via opacity only
- [x] Physics interpolation for 90/120 Hz displays
- [x] Top levels (10–12) clearly distinct (+ test)
- [x] Merge burst effect (ring + sparks); score popups placed above the planet
- [x] Haptics on phones (short, subtle; configurable)
- [x] Procedural sound (pentatonic merge bells, launch whoosh, vanish & game-over chords), generated on a background thread
- [x] Test runner fails on any engine error (shader/script)
- ~~Trajectory preview~~ (designer decision: aim line only)

## Phase 4b — Needs playtesting on a real device
- [ ] Launcher position/angle design review
- [ ] Listen to and tune the sounds (they were never heard during development — cloud machine has no audio)
- [ ] Feel of haptic strengths
- [ ] Chain popups can overlap when many merges happen at once
- [ ] Difficulty/pacing tuning from real playtests (bot game: ~260 launches, ~2.5 min)
- [ ] In-game pause / restart button (only `R` and game-over restart today)
- [ ] Performance pass on low-end Android (target 60 FPS with ~40 planets)

## Phase 5 — Mobile release prep
- [ ] Export presets (Android, iOS), icons, splash
- [ ] Safe-area handling (notches), pause on app background
- [ ] Settings screen (sound, haptics), accessibility: a symbol per level for color-blind players
- [ ] Android export: add the VIBRATE permission (needed for haptics)
- [ ] Device testing matrix

## Later (not started, needs explicit approval)
- Monetization strategy (ethical, non-manipulative)
- Online leaderboards / backend
