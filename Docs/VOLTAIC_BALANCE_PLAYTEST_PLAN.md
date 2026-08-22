# Voltaic balance and playtest contract

## Locked public scope

- Arena: Dusk Garden only.
- Fleshdrive: Voltaic only.
- Current demo: one continuous twelve-minute run ending with the Visceral Warden.
- Builds: Thunder God / Chainstorm, Volt Hound / Thunder Ram, and Orange Tempest.
- No node map, new Fleshdrive, new arena, or major progression system enters this release candidate.

The proposed 20-25 minute node-map format remains post-playtest work. Mixing it into this candidate would invalidate the existing run, encounter, camera, and performance baselines.

## Measurement contract

Every graphical run writes a JSON summary under `user://telemetry` containing:

- elapsed/active time, result, death cause, boss reach and kill time;
- kills by crawler, spitter, charger, elite, and boss;
- damage dealt by source, hit counts, contribution percentages, and average DPS;
- secondary/status proc counts and authored build-trigger counts;
- damage received by source and first-damage time;
- biomass spawned, collected, and missed;
- highest level, offers, offer relevance, selections by card/class/archetype, rerolls, currency spent, and skips;
- peak enemies, projectiles and VFX, plus the performance snapshot and optional power checkpoints.

Upgrade classes are `STAT`, `MAJOR`, `MECHANIC`, `SYNERGY`, and `KEYSTONE`. Existing prerequisites remain authoritative.

## Power curve

| Checkpoint | Target output |
|---|---:|
| Level 1 | 1.0x |
| Early | 1.4x |
| Mid | 2.0x |
| Late | 3.0x |
| Pre-boss | 4.5x |
| Boss-capable | 6.0x (acceptable 5.5-7.0x) |

These are comparison targets, not fabricated results. Rendered runs must capture single-target and five-target DPS, activation frequency, targets per activation, crawler TTK, and boss TTK.

## Encounter contract

Threat costs are crawler 1, spitter 2, charger 3, elite 7. Phase budgets preserve the authored population. Late pressure should come mostly from projectiles, chargers, elites, and the Warden; normal crawlers retain the late-level execution multiplier and fodder role.

## Standard scenarios

Run each for all three builds with a fixed seed where possible:

1. Level 1 against one crawler.
2. Level 1 against five crawlers.
3. Early: three selections and normal opening pressure.
4. Mid: six selections and crawler/spitter mix.
5. Late: ten selections and full mixed horde.
6. Pre-boss: completed build with projectile/charger pressure.
7. Warden: boss time, received damage, and source contribution.

Press F10 in a debug build for the balance panel. It can set level, add an upgrade, force a public build, spawn an enemy, apply a damage multiplier, fast-forward sixty seconds, start the boss, toggle god mode, and clear non-boss enemies. It is not instantiated in release builds.

`Tools/run_balance_benchmarks.ps1` executes 102 seeded accelerated samples across the three Voltaic builds and writes `Reports/production_hardening_soak.json`. It detects large regressions; it does not replace rendered or human testing.

## Human gates

- Ten consecutive complete internal runs without crash, softlock, script error, P0 telegraph failure, or broken progression.
- Eighteen to twenty total telemetry-bearing internal balance runs across all three builds.
- Five to eight observed external playtests without coaching.
- Review pick, reroll, skip and irrelevant-offer rates; death time/cause; biomass curve; damage contribution; boss time; and subjective build clarity.
- Fix all P0/P1 findings, build RC2, freeze features for 48 hours, then run the final clean-install smoke.

No human gate is complete until a real session row and its telemetry artifact exist.
