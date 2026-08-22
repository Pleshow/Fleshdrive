# Fleshdrive public playtest checklist

Release scope: Dusk Garden, Voltaic Heart, twelve-minute Visceral Warden run,
Windows, English and Hungarian.

## Automated release candidate

- [x] `Tools/run_release_gate.ps1` passes all 28 active suites.
- [x] Rendered performance profile meets its frame-time and population budget.
- [x] Windows Release export completes without missing-resource warnings.
- [x] Export preset excludes raw archives, editable sources, tests and retired arenas.
- [ ] A clean log covers boot, run, death, refabrication, restart, victory and quit.

## Manual internal verification

- [ ] Ten consecutive complete runs have no crash, softlock or P0/P1 defect.
- [ ] At least three runs end in victory and three end in death.
- [ ] Keyboard/mouse and controller each complete a full run.
- [ ] Shader on/off, pause, focus loss, restart and all supported resolutions pass.
- [ ] Late rush and boss stay readable without reducing enemy population.

Record every run in `Reports/internal_playtest_runs.csv`; do not mark a row as
passed unless a person completed the real-time build.

## External observed playtest

- [ ] Five to eight first-time players are observed without coaching.
- [ ] At least 80% reach the first mutation and understand the core loop.
- [ ] Death cause, XP/biomass, Blood Memory, dash and Kinetic Charge are understood.
- [ ] P0/P1 feedback is fixed and regression-tested.

## Publication

- [ ] Every integrated runtime asset has licence or purchase evidence.
- [ ] Version, changelog, controls, known issues, credits and feedback link exist.
- [ ] The downloaded ZIP starts on a clean Windows machine without Godot installed.
- [ ] RC2 receives a real 48-hour feature freeze and a final smoke test.
