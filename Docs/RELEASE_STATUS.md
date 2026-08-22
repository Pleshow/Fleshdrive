# Fleshdrive playtest release status

Target version: `0.1.0-playtest.1`

Locked scope: Dusk Garden, Voltaic Heart, twelve-minute Visceral Warden run,
Windows, English and Hungarian.

## Completed locally

- Runtime arena selection is locked to Dusk Garden.
- Isometric, trial-autotile and non-Voltaic build tests are removed.
- The active release gate discovers every `Tests/*_test.gd` suite and rejects
  non-zero exits, failed assertions and GDScript errors.
- All 28 active suites pass.
- BASE CORE copy, spawn-budget overshoot and camera regressions are covered.
- A rendered late-rush profile passes with 141 enemies (16.67 ms average,
  18.54 ms p95, 24.68 ms p99); see
  `Reports/rendered_performance_profile.md`.
- The official Godot 4.7.1 Windows export templates are installed.
- A Windows x86_64 Release export completes and its headless boot smoke has no
  script or missing-resource error. The sandbox can only report that its
  restricted `user://logs` directory is not writable.
- Export presets exclude tests, tools, reports, source packs, editable graphics
  and archives.
- Third-party notices include the licences found in the repository and name the
  unresolved evidence explicitly.

## Blocking publication

1. Attach purchase/licence evidence for `lightning_pack`, `fire_explosions`,
   `fireball`, `slashes` and `status`, plus redistribution permission for the
   Pulsing Heart and PixelLab-derived sources, or replace/remove them.
2. Complete and record ten human, real-time internal runs.
3. Complete five to eight observed first-time-player sessions and triage every
   result using the protocol below.
4. Fix all observed P0/P1 issues and add a regression test where automation is
   possible.
5. Supply the public feedback URL and verify the ZIP on a clean Windows machine.
6. Cut RC2 only after the above, then begin a real 48-hour feature freeze and
   run the final smoke at the end of that interval.

Do not label the current commit RC2: automation, performance and local export
are green, but the human, licensing, clean-machine and elapsed-time gates cannot
be simulated.
