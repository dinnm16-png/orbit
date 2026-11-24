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

## Phase 3 — Game loop
- [ ] Next-planet preview
- [ ] Game-over rule (proposal in PROJECT_SPEC §5) + warning state
- [ ] Game-over screen, one-tap restart
- [ ] Local best score (offline, `user://`)
- [ ] Tests for game-over timing and edge cases

## Phase 4 — Feel & polish
- [ ] Smooth shader-based planet rendering (removes visible shading bands, most visible on big planets)
- [ ] Make top levels (10–12: pearl / gold / white) more distinct; consider a symbol per level for color-blind players
- [ ] Merge animation, subtle particles, screen-space glow
- [ ] Trajectory preview using `OrbitPhysics` (design decision: difficulty impact)
- [ ] Launcher position/angle design review after playtests
- [ ] Haptics on mobile, minimal sound design
- [ ] Physics interpolation for high-refresh-rate displays
- [ ] Performance pass on low-end Android (target 60 FPS with ~40 planets)

## Phase 5 — Mobile release prep
- [ ] Export presets (Android, iOS), icons, splash
- [ ] Safe-area handling (notches), pause on app background
- [ ] Settings (sound, haptics), accessibility (color-blind-friendly levels)
- [ ] Device testing matrix

## Later (not started, needs explicit approval)
- Monetization strategy (ethical, non-manipulative)
- Online leaderboards / backend
