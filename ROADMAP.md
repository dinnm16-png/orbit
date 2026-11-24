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
- [x] In-game pause / restart button (Phase 5)
- [ ] Performance pass on low-end Android (target 60 FPS with ~40 planets)

## ✅ Phase 5 — Mobile release prep (code done; device build pending)
- [x] Export presets (Android with VIBRATE permission, iOS); tests/docs excluded from builds (verified)
- [x] Safe-area handling (notches, home indicator)
- [x] Pause: button + automatic when the app goes to the background
- [x] Pause menu: Resume, Restart, settings (sound, vibration, planet numbers), saved on device
- [x] Accessibility: optional level numbers on planets (color-blind friendly)
- [ ] Build a signed APK (blocked here: needs Android SDK license acceptance — see DEVELOPMENT_LOG)
- [ ] Device testing matrix (low-end Android, recent iPhone, notched/tall screens)

## ✅ Phase 6 — Release identity (done)
- [x] App icon rendered with the game's own shader (`tools/render_icons.gd`):
      iOS 1024 (opaque), Android 192 + adaptive foreground/background/monochrome
- [x] Splash screen (emblem + ORBIT wordmark)
- [x] App ID `com.dinnm16.orbit` (permanent once published — confirm before first upload)
- [x] Version 0.6.0 (code 2), consistent across project and presets (tested)
- [x] Privacy policy, store listing draft, release checklist (`docs/`)
- [x] Release tests: icon sizes, opaque iOS icon, preset paths, app ID, no INTERNET permission

## ✅ Phase 7 — Depth: modes, mechanics, options, progress, puzzles (done, v0.7.0)
- [x] M1 Game modes as data: Classic, Zen, Daily Orbit, Blitz, Collapse, Limited Shots, Binary Star
- [x] M2 Main menu: animated backdrop, mode cards, detail sheet, tabs, fades, back navigation
- [x] M3 Special planets (wildcard, comet, black hole, anchor), hold slot, sliding launcher, gravity pulse
- [x] M4 Difficulty (separate bests), aim assist (path prediction), 4 color themes
- [x] M5 Planet collection, stats, 13 milestones, quiet toasts, theme unlocks
- [x] M6 30 puzzles in 6 chapters with stars; every puzzle verified solvable by a bot
- [x] Tools: tools/balance.gd, tools/puzzle_check.gd, tools/capture.gd, tools/capture_menu.gd

## Later — store release (needs the owner: accounts, fees, signing key)
- [ ] Google Play Console / Apple Developer accounts
- [ ] Release signing key (see `docs/RELEASE_CHECKLIST.md`)
- [ ] AAB build (Gradle) for Google Play
- [ ] Real-device screenshots + Google Play feature graphic
- [ ] Host the privacy policy (e.g. GitHub Pages)

## Later (not started, needs explicit approval)
- Monetization strategy (ethical, non-manipulative)
- Online leaderboards / backend
