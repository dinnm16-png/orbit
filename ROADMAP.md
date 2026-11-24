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

## Phase 2 — Merging & scoring
- [ ] `MergeRules` (pure): which pairs merge, resulting level, max level behavior
- [ ] Contact detection (`contact_monitor` / `body_entered`) on planets
- [ ] **Duplicate-merge guard**: each planet can be consumed only once per step
      (a "merging" flag + deferred resolution in one place)
- [ ] Merged planet spawns at the contact midpoint with combined momentum
- [ ] Chain reactions (newly merged planet can merge immediately)
- [ ] `ScoreRules` (pure) + score display
- [ ] Tests: merge once, no double merge with 3 touching planets, chains, scoring
- [ ] Wake neighbours when a planet is removed (sleeping-body edge case)

## Phase 3 — Game loop
- [ ] Next-planet preview
- [ ] Game-over rule (proposal in PROJECT_SPEC §5) + warning state
- [ ] Game-over screen, one-tap restart
- [ ] Local best score (offline, `user://`)
- [ ] Tests for game-over timing and edge cases

## Phase 4 — Feel & polish
- [ ] Smooth shader-based planet rendering (removes visible shading bands)
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
