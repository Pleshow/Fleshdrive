# Sprint 01 — teljes run-loop alapjai

Időszak: 2026-07-22-től

## Sprintcél

A combat sandboxból legyen lezárt játékfolyam: a run elindul, nehezedik, szüneteltethető, győzelemmel vagy vereséggel véget ér, statisztikát mutat és újraindítható.

## Elkészült

- központi `RunManager` és explicit playing/paused/level-up/game-over/victory állapotok;
- 12 perces visszaszámláló és győzelmi feltétel;
- időalapú spawn-intervallum és enemy budget görbe;
- kill, biomass, elért szint és eltelt idő statisztika;
- pause overlay resume, restart és quit műveletekkel;
- victory/game-over összegző képernyő;
- arénahatár, kamera-limit és arénán belülre korlátozott spawn;
- halálkor a spawn leállítása és a run befagyasztása;
- egymásra torlódó level-upok soros kezelése;
- automatizált headless smoke test.

## Ellenőrzés

Parancs:

```powershell
.\Tools\run_release_gate.ps1 -GodotPath 'C:\path\to\Godot_v4.7-stable_win64_console.exe'
```

A teszt ellenőrzi:

- a scene és a fő node-ok betöltését;
- pause/resume állapotot és UI-t;
- a difficulty curve két végpontját;
- biomass-túlcsordulásból származó soros level-upot;
- victory és game-over állapotot, valamint a megfelelő overlayt.

## Sprintből hátralévő kézi ellenőrzés

- teljes 12 perces run balanszteszt;
- arénaszélek és sarok-spawnok vizuális ellenőrzése;
- pause/restart gyors egymásutánban;
- legalább 5 teljes run soft lock nélkül;
- HUD finomhangolása különböző képarányokon.

## Következő sprintre javasolt backlog

1. Hullám-fázisok és egyértelmű difficulty események a folytonos görbe fölé.
2. Második, távolsági ellenféltípus.
3. Harmadik, rohamozó vagy területet lezáró ellenféltípus.
4. Elit variáns és telegráf-rendszer.
5. Első combat juice pass: hit stop, screen shake, halál-VFX és hang hookok.

## Playtest iteráció 01

Két teljes run visszajelzése alapján elkészült:

- a kezdő mozgási sebesség 280-ról 210-re csökkent;
- az aréna 1280×720-ról 2560×1440-re nőtt, követő kamerával;
- az ellenfelek legalább 80 pixellel a látható viewporton kívül spawnolnak;
- a 3., 6. és 9. percben 14 másodperces rush indul;
- egy rush 10 ellenfeles kezdőlökést, háromszoros spawnsebességet és +18 enemy capet ad;
- a 15. szinttől garantáltan megjelenik az Autonomic Reflex evolution, ha a Reflex Cortex már aktív;
- az Autonomic Reflex teljes automata célzásra állítja a támadást;
- az autoattack evolution ideiglenesen a Reflex Cortex képét használja, amíg nem készül külön evolution-kártya.
