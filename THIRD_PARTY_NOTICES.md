# Fleshdrive third-party notices

This file is the publication-facing asset and font manifest for the pre-alpha demo.

## Pixeloid fonts

- Files: `Assets/fonts/PixeloidSans.ttf`, `PixeloidSans-Bold.ttf`, and related Pixeloid font files.
- Author: GGBotNet.
- License: SIL Open Font License 1.1.
- Included license evidence: `Assets/fonts/Pixeloid-License.txt`.

## Frostwindz VFX

- Files: `Assets/vfx/licensed/frostwindz/**`.
- Included license evidence: `Assets/vfx/licensed/frostwindz/Frostwindz_Asset_License_Agreement.docx`.
- The license document is shipped beside the source assets so the release package can be audited without relying on a store listing.

## BitBlast Studio Pixel VFX

- Runtime files: `Assets/vfx/licensed/pixel_juice/**`.
- Source packs: `Assets/Pixel VFX/**` (excluded from binary exports).
- Author: Fellor / BitBlast Studio.
- License: commercial and non-commercial use and modification are permitted;
  standalone resale or redistribution is prohibited.
- Included evidence: the original per-pack license files under
  `Assets/Pixel VFX/**/License.txt` and the runtime-adjacent copy at
  `Assets/vfx/licensed/pixel_juice/LICENSE.txt`.

## Animated Gold Coin

- Runtime use: Blood Memory spinning and collection animation.
- Source: `Assets/Pixel VFX/Animated Gold Coin - Free/**`.
- License permits commercial projects and modification, but prohibits
  standalone resale or redistribution.
- Included evidence: `LICENSE.txt` and `README.txt` beside the source asset.

## Pulsing Heart status icon

- File family: `Assets/ui/status/Pulsing-Heart*`.
- Attribution and source notes: `Assets/ui/status/Pulsing-Heart-readme.txt`.
- The bundled note describes layer order but does not state a redistribution
  license. Public source distribution therefore still requires the original
  license or author permission.

## PixelLab grassy environment source bundle

- Files: `Assets/environment/grassy/**`.
- Tool/source notes: `Assets/environment/grassy/README.md`.
- The imported subproject is source material only; Fleshdrive controls filtering, scaling, collision, and runtime composition.

## Project-supplied VFX collections requiring release-owner evidence

The following folders are integrated as licensed project assets, but no standalone license or receipt was present in the repository during the publication pass:

- `Assets/vfx/licensed/lightning_pack/**`
- `Assets/vfx/licensed/fire_explosions/**`
- `Assets/vfx/licensed/fireball/**`
- `Assets/vfx/licensed/slashes/**`
- `Assets/vfx/licensed/status/**`

Before uploading a public binary, the release owner must attach the relevant purchase receipt or license text to the source archive. This manifest deliberately does not infer redistribution rights from a folder name.

## Raw source bundles requiring public-repository clearance

Publishing a GitHub repository distributes the raw source files, which can be
more restrictive than shipping the assets inside a compiled game. No standalone
redistribution license was found beside these source bundles during the audit:

- `Assets/asset packs/Free-Undead-Tileset-Top-Down-Pixel-Art/**`
- `Assets/asset packs/Free-Undead-Tileset-Top-Down-Pixel-Art.zip`
- the PixelLab map source/export archives under `Assets/environment/**`

Keep the repository private until the applicable store/tool terms or creator
permissions explicitly allow public redistribution of these raw files. If they
do not, retain only permitted derived runtime assets or replace them before a
public push.

## Binary export policy

The Windows presets exclude tests, tools, reports, documentation, marketing
sources, the complete purchased Pixel VFX source tree, retired prototype assets,
third-party raw asset packs, archives, PSD files and Aseprite sources. Compiled
playtest packages may contain only the runtime derivatives referenced by the
game and the notices that their licences require.

All other original code, procedural graphics, UI composition, and Fleshdrive-specific atlases are part of the Fleshdrive project.
