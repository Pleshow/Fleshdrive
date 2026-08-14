# Sprint 02 — Enemy Variety

Állapot: implementálva, kézi balansztesztre kész

## Elkészült

### Spitter

- 12% run progress után kerülhet a spawn poolba;
- 390 px körüli távolságot próbál tartani és oldalaz;
- 610 px támadási távolság;
- 0,78 másodperces, vizuálisan és célzóvonallal jelzett windup;
- 320 px/s sebességű, 9 sebzéses lövedék;
- 2,35 másodperces támadási cooldown;
- hatframe-es impact és röviden elhalványuló savfolt;
- 45 HP és 14 biomass drop.

### Charger

- 25% run progress után kerülhet a spawn poolba;
- 230–620 px távolságból indíthat rohamot;
- 0,88 másodperces, rögzített irányú telegráf;
- 650 px/s rohamsebesség, 0,72 másodperces roham;
- 22 sebzés és 0,72 másodperces recovery;
- roham közben nem akad fenn más ellenfeleken, de falnak és játékosnak ütközik;
- külön windup, charge, trail és impact vizuál;
- 85 HP és 20 biomass drop.

### Spawn-kompozíció

- a run eleje továbbra is csak Crawlerekkel indul;
- a Spitter 12%-nál, a Charger 25%-nál nyílik meg;
- a speciális ellenfelek súlya fokozatosan nő a run végéig;
- rush alatt a Spitter súlya 1,25×, a Charger súlya 1,75× szorzót kap;
- az offscreen spawn és az enemy cap továbbra is érvényes minden típusra.

### Autoattack evolution

- az Autonomic Reflex resource most a felhasználó által készített `04_autonomic_reflex.png` kártyát használja;
- továbbra is level 15-től garantált, ha a Reflex Cortex már aktív.

## Automatizált ellenőrzések

- teljes run smoke test: PASS;
- új scene-ek betöltése: PASS;
- spawn unlock és late-game pool: PASS;
- Spitter windup és valódi physics projectile fire: PASS;
- Charger windup, telegráf, charge és collision-mask váltás: PASS;
- Auto Reflex kártya és evolution: PASS.
- 6 másodperces late-game rush stress test: PASS — 70 aktív ellenfél
  (31 Crawler, 21 Spitter, 18 Charger), runtime error nélkül.

## Kézi playtest fókusz

1. A Spitter célzóvonala elég korán és jól láthatóan jelzi-e a lövést.
2. A lövedék kikerülhető-e normál, 210-es játékossebességgel.
3. A Spitter nem ragad-e falhoz vagy más ellenfelek mögé.
4. A Charger telegráfja egyértelmű-e rush közbeni káoszban is.
5. A Charger rohama büntető, de fair-e; különösen falak és sarkok közelében.
6. A 3., 6. és 9. perces rushok speciális enemy mixe nem okoz-e FPS-esést.
7. A 9 sebzéses lövedék és 22 sebzéses roham együtt nem hoz-e létre elkerülhetetlen burst damage-et.
8. A biomass reward arányban áll-e a két ellenfél veszélyességével.

## Következő javasolt lépés

- első combat-juice pass: általános death VFX, hit stop, camera shake és hang hookok;
- ezt követően elit variáns és az első boss prototype.
