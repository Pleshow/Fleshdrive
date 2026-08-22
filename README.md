# Fleshdrive

Current public-playtest preparation status and remaining release blockers are
tracked in `Docs/RELEASE_STATUS.md` and `Docs/PUBLIC_PLAYTEST_CHECKLIST.md`.

Fleshdrive is a Godot 4.7 pre-alpha survivor-action prototype built around
biomechanical mutation and organ loadouts. The public playtest is scope-locked
to the Dusk Garden arena and the Voltaic Heart, with English and Hungarian UI,
mouse and controller support, persistent progression and a twelve-minute boss
run ending with the Visceral Warden.

## Requirements

- Godot 4.7 stable (Forward+ renderer)
- Git LFS for the editable PSD, Aseprite, archive and document sources
- Windows is the currently tested export target

## Opening the project

1. Clone the repository and run `git lfs pull`.
2. Open Godot's project manager.
3. Import the repository's `project.godot` file.
4. Run the main project scene.

## Default controls

- Move: WASD, arrow keys or left stick
- Aim/attack: mouse or right stick/trigger
- Dash: Space or controller face button
- Active skill: E or controller face button
- Pause/cancel: Escape or controller menu button

## Validation

Run the complete automated Dusk Garden + Voltaic publication gate from PowerShell:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Tools\run_release_gate.ps1 -GodotPath "C:\path\to\Godot_v4.7-stable_win64_console.exe"
```

Alternatively, set `GODOT_CONSOLE_PATH` to the Godot console executable and
omit `-GodotPath`.

The measurable Voltaic balance contract, F10 debug workflow, and scenario matrix
are in `Docs/VOLTAIC_BALANCE_PLAYTEST_PLAN.md`.

Release changes and currently known limitations are recorded in `CHANGELOG.md`
and `Docs/KNOWN_ISSUES.md`.

## Licensing and third-party assets

No open-source license has been selected for Fleshdrive's original code and
assets; default copyright applies. Third-party credits and the current asset
evidence audit are documented in `THIRD_PARTY_NOTICES.md`.

Some integrated VFX collections and raw vendor source packs still require the
repository owner's redistribution evidence. Do not publish this repository or
redistribute those raw files publicly until that evidence has been confirmed.
