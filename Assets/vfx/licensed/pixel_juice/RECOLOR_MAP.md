# Pixel VFX recolor map

Edit the PNG files in this directory, not their `.import` sidecars. Godot will
automatically reimport the edited sheets. These runtime copies intentionally
bypass both `pixel_emissive.gdshader` and the world-level Ink Crimson
quantizer, so their PNG colors appear unchanged in-game.

## Requested gameplay effects

| Runtime PNG | Sheet layout | Godot effect IDs | Gameplay use |
| --- | --- | --- | --- |
| `ball_lightning_v1.png` | 384x384, 64x64 cells, 6 columns | `ball_lightning_idle`, `ball_lightning_explosion` | Ball Lightning hover frames 4-27 and final explosion frames 28-33 |
| `projectile_lightning_v3.png` | 384x320, 64x64 cells, 6 columns, 27 frames | `projectile_lightning`, `projectile_lightning_loop` | Electric player projectile and authored Volt Hound dash trace; no longer used as an extra Voltaic body aura |
| `kinetic_lightning_v7.png` | 256x192, 64x64 cells, 4 columns, 10 frames | `kinetic_charge_lightning` | Four-direction Kinetic Charge aura |
| `lightning_radial.png` | 192x192, 64x64 cells, 3 columns, 8 frames | `enemy_death_lightning`, `electric_impact`, `electric_micro_hit`, `shock_proc`, `biomass_collect`, `ui_energy_confirm`, `organ_activation` | Lightning_v4 enemy death and shared compact electric feedback |
| `shock_lightning_v9.png` | 256x192, 64x64 cells, 4 columns, 10 frames | `shock_status` | Shocked-target and Thunderstate status aura |
| `decoy_smoke_v9.png` | 256x192, 64x64 cells, 4 columns, 10 frames | `decoy_smoke` | Shed Skin decoy disappearance |
| `holy_heal_v3.png` | 320x256, 64x64 cells, 5 columns, 17 frames | `holy_heal` | Koda healing feedback |

## Other purchased runtime sheets also left in source colors

| Runtime PNG | Godot effect IDs / use |
| --- | --- |
| `dash_smoke.png` | `dash_smoke`, `dash_smoke_end` |
| `spawn_smoke.png` | `charge_dust`, `enemy_spawn` |
| `impact_smoke.png` | `generic_hit`, `charger_impact` |
| `fire_burst.png` | `heavy_hit`, `fire_impact`, `boss_slam`, `boss_death` |
| `fire_slash.png` | `magma_spear_impact` |
| `organic_burst.png` | `enemy_death_burst`, `organ_flesh_pulse` |
| `tissue_droplets.png` | `tissue_droplets` |
