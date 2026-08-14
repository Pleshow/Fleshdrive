# Fleshdrive — publikálható prototípus roadmap

Állapotfelmérés dátuma: 2026-07-22

## Cél

Egy publikálható prototípus alatt egy stabil, önmagában érthető, 12–15 perces vertical slice értendő, amely:

- elejétől a végéig végigjátszható;
- bemutatja a Fleshdrive saját identitását: biomass, mutációk, szervek és eltérő buildek;
- legalább 3 normál ellenfelet, 1 elit variánst és 1 bosst tartalmaz;
- rendelkezik főmenüvel, pause-zal, game over/victory képernyővel, újraindítással és alapbeállításokkal;
- kapott használható hangokat, vizuális visszajelzéseket és egy rövid onboardingot;
- Windows buildként hibamentesen exportálható és itch.io-ra feltölthető.

Ez nem a teljes játék: nem része több pálya, történeti kampány, meta-progression, online funkciók, achievementek vagy nagy mennyiségű végleges content.

## Jelenlegi állapot

### Ami már működik

- 8 irányú játékosmozgás és animációválasztás;
- manuális, félautomata és automata támadási mód alapjai;
- dash és chain lightning képesség;
- egy üldöző ellenfél, kontaktsebzés és egyszerű horda-szétválás;
- ellenfél-spawn, biomass drop és felszedés;
- HP, biomass és szint HUD;
- háromlapos szintlépési választás;
- 6 ismételhető item és 3 egyszer telepíthető organ;
- brain, heart és legs foglalat drag-and-drop kezelése;
- alap grafikai assetek, továbbá 10 Fleshdrive ikon.

### A publikálhatósághoz hiányzó fő részek

- nincs run-struktúra, időzítés, nehézségi görbe, győzelem vagy rendes vereség;
- nincs game over, restart, főmenü, pause menü vagy options;
- csak egy ellenféltípus van, nincs elit és boss;
- a Fleshdrive ikonok mögött még nincs látható gameplay-rendszer;
- az aréna jelenleg placeholder, nincs pályahatár vagy környezeti tartalom;
- nincs hang, zene, screen shake, juice és teljes combat feedback;
- az upgrade választás képei mellől hiányzik a név, leírás és stat-változás;
- nincs tutorial/onboarding, kontroller-támogatás és input-remapping;
- nincs automatizált smoke test, export preset vagy dokumentált release-folyamat;
- a balansz még sandbox értékekre épül, nem egy teljes runra.

Becsült készültség: **kb. 25–30% egy publikálható prototípushoz képest**. A legfontosabb technikai alapok már megvannak, de a content, UX és polish teszi ki a hátralévő munka nagyobb részét.

## Időbecslés

Várható hátralévő munka: **kb. 260–360 fókuszált munkaóra** egyetlen fejlesztővel.

| Munkaritmus | Várható idő | Biztonságos vállalás |
|---|---:|---:|
| Teljes idő, heti 35–40 óra | 7–9 hét | 10 hét |
| Részidő, heti 20 óra | 13–18 hét | 20 hét |
| Esti/hétvégi, heti 10–15 óra | 18–30 hét | 7 hónap |

A várható céldátum teljes idejű fejlesztéssel **2026. szeptember vége**, részidős fejlesztéssel **2026. november vége–december közepe**. A becslés 20% integrációs és hibajavítási tartalékot feltételez.

## Milestone-ok

### M0 — Scope lock és stabil alap

Idő: 12–18 óra / 2–3 nap

Teendők:

- rögzíteni a 12–15 perces run pontos szabályait;
- meghatározni a prototípusban szereplő 3 Fleshdrive/build fantasy-t;
- debug indítás, gyors szintlépés és boss-jump eszközök;
- gameplay állapotok szétválasztása: playing, paused, level-up, game over, victory;
- kritikus edge case-ek javítása, különösen többszörös level-up és halál közbeni spawn;
- verziózott balanszadatok és rövid technikai README.

Kilépési feltétel:

- 10 perces smoke test alatt nincs script error vagy soft lock;
- a scope-on kívüli ötletek külön backlogba kerültek;
- egy gombbal tesztelhető minden fő gameplay állapot.

### M1 — Teljes run-loop

Idő: 32–45 óra / 1 hét

Teendők:

- run timer és központi run/game manager;
- időalapú hullámok és fokozódó spawn-budget;
- győzelem, vereség, game over, statisztika és restart;
- játékos- és ellenfél-spawn biztonságossá tétele;
- arénahatár, kamera-határok és spawn-validáció;
- pause menü és kilépés a főmenübe;
- alap run statok: idő, kill, biomass, level, választott mutációk.

Kilépési feltétel:

- a játék főmenüből elindítható, végigjátszható, megnyerhető, elveszíthető és újraindítható;
- egymás után 5 run soft lock nélkül lefut.

### M2 — Combat és ellenfél-content

Idő: 55–80 óra / 1,5–2 hét

Teendők:

- 2 új, eltérő döntést kikényszerítő ellenfél: például távolsági és rohamozó;
- 1 elit variáns jól olvasható telegráffal;
- 1 boss legalább 2 fázissal vagy 3 külön támadással;
- hullámkompozíciók és spawn súlyozás;
- sebzés-, halál- és veszélyjelzések;
- találatstop, villanás, screen shake, részecskék és jobb lightning VFX;
- O(n²) horda-szétválás profilozása és szükség szerinti optimalizálása;
- ellenfél object pooling csak akkor, ha a profiler indokolja.

Kilépési feltétel:

- a 12–15 perces run során legalább három különböző taktikai helyzet alakul ki;
- a boss első találkozáskor is érthető, de nem automatikusan legyőzhető;
- célhardveren stabil a képfrissítés a tervezett maximális ellenfélszámnál.

### M3 — Buildcraft és Fleshdrive-identitás

Idő: 40–55 óra / 1–1,5 hét

Teendők:

- 3 választható kezdő Fleshdrive vagy run-mód implementálása;
- minden Fleshdrive kapjon egy egyértelmű passzívot és build-irányt;
- upgrade-kártyák: név, rövid leírás, ritkaság/típus és számszerű hatás;
- minimum 12–15 érdemi upgrade, ebből legalább 6 build-szinergia;
- organ slot UX: kompatibilis slot kiemelése, hibás drop visszajelzés, cancel/fallback;
- upgrade pool szabályok, előfeltételek és duplikációs limitek;
- balanszadatok kivitele Resource-okba a kódban lévő match további növelése helyett;
- run végi build-összegzés.

Kilépési feltétel:

- legalább 3 felismerhető és életképes build készíthető;
- nincs olyan level-up, amelyből a játékos nem tud továbblépni;
- minden választásból előre érthető, mit fog változtatni.

### M4 — UX, prezentáció és onboarding

Idő: 45–65 óra / 1,5–2 hét

Teendők:

- főmenü, pause, settings, credits és first-run onboarding;
- billentyűzet+egér és kontroller teljes támogatása;
- hangerőszabályzás, fullscreen/windowed mód és alap input-remapping;
- egységes HUD, hover/focus állapotok és olvasható tipográfia;
- aréna vizuális passza, talaj, landmarkok és pályahatár;
- zene, UI-, támadás-, találat-, pickup-, level-up- és halálhangok;
- vizuális hierarchia és accessibility: kontraszt, ne csak szín hordozzon információt;
- hibás karakterkódolású kommentek/szövegek rendbetétele;
- első 60 másodperces tutorial tesztelése magyarázat nélküli játékossal.

Kilépési feltétel:

- egy új játékos külső segítség nélkül el tudja indítani és megérti az alap loopot;
- minden képernyő használható egérrel és kontrollerrel;
- a fontos események hangból és képből is egyértelműek.

### M5 — Balansz, QA és teljesítmény

Idő: 40–55 óra / 1–1,5 hét

Teendők:

- legalább 20 belső teljes run naplózása;
- 5–8 külső playtester, egységes kérdőív és megfigyelési jegyzet;
- progression curve, enemy HP/damage, drop rate és upgrade súlyok hangolása;
- input-, pause-, fókuszvesztés-, felbontás- és restart edge case-ek;
- hosszabb soak test és memória/node leak ellenőrzés;
- hibák P0/P1/P2 osztályozása és javítása;
- alacsonyabb kategóriás célgépen teljesítményteszt;
- build-verzió és crash/error log ellenőrzése.

Kilépési feltétel:

- nincs ismert P0 vagy P1 hiba;
- 10 egymást követő teljes runból nincs crash vagy soft lock;
- a playtesterek legalább 80%-a segítség nélkül eljut az első upgrade-ig és érti a vereség/győzelem okát.

### M6 — Release candidate és publikálás

Idő: 20–30 óra / 3–5 nap

Teendők:

- Windows export preset és tiszta gépes build-teszt;
- licenc- és asset-forrás audit;
- itch.io oldal: kapszula, screenshotok, leírás, irányítás, ismert hibák;
- rövid trailer vagy 15–30 másodperces gameplay GIF;
- verziószám, changelog és feedback link;
- RC1 feltöltése, 48 órás freeze, csak release-blocker javítás;
- végső smoke test és publikálás.

Kilépési feltétel:

- a letöltött publikus csomag tiszta Windows gépen telepítés nélkül elindul;
- az oldal pontosan leírja a scope-ot és az irányítást;
- a release buildben nincs debug-only UI vagy ismert blocker.

## Ajánlott heti sorrend teljes idejű fejlesztésnél

| Hét | Fókusz | Kimenet |
|---:|---|---|
| 1. | M0 + M1 kezdete | scope lock, game state-ek, run timer |
| 2. | M1 befejezése + M2 | teljes run, második ellenfél |
| 3. | M2 | harmadik ellenfél, elit, hullámok |
| 4. | M2 + M3 | boss, 3 Fleshdrive alapja |
| 5. | M3 | teljes upgrade/buildcraft rendszer |
| 6. | M4 | menük, onboarding, kontroller, HUD |
| 7. | M4 + M5 | audio-vizuális passz, első külső teszt |
| 8. | M5 + M6 | balansz, QA, RC1 |
| 9–10. | tartalék | javítások, újrateszt, publikálás |

## Prioritások

**P0 — prototípus nem publikálható nélküle:** teljes run-loop, game over/restart, arénahatár, legalább 3 ellenfél + boss, érthető upgrade-ek, menü/pause, stabil export, alap hang és külső playtest.

**P1 — erősen ajánlott:** 3 Fleshdrive, kontroller, input-remapping, run statok, részletes juice, több settings és kiforrott organ UX.

**P2 — a prototípus után:** meta-progression, több pálya, mentés, achievement, lore-rendszer, napi challenge, további 7 Fleshdrive teljes implementációja.

## Scope-védelem

A publikálási dátum tartásához:

- csak 1 aréna készüljön;
- a 10 meglévő Fleshdrive ikonból első körben csak 3 kapjon teljes mechanikát;
- a run maradjon 12–15 perces;
- ne készüljön meta-progression a prototípushoz;
- új rendszer csak akkor kerüljön be, ha közvetlenül erősíti a combat–biomass–mutation loopot;
- az M3 után content freeze, az M5 elejétől feature freeze legyen.

## Legnagyobb kockázatok

1. **Tartalomgyártás:** az új ellenfelek, boss, animációk és hangok könnyen megduplázhatják az időt. Megoldás: egyszerű, jól telegráfolt viselkedések és korai placeholder teszt.
2. **Scope creep:** mind a 10 Fleshdrive kidolgozása önmagában több hetes pluszmunka. Megoldás: 3 reprezentatív build a prototípusban.
3. **Balansz:** a repetitív upgrade-ek miatt gyorsan elszaladhat a sebzés és a támadási sebesség. Megoldás: capek, adatvezérelt tuning és run-telemetria.
4. **Horda-teljesítmény:** a jelenlegi separation minden ellenféllel összevet minden ellenfelet. Megoldás: profilozás, majd szükség esetén ritkított update vagy térbeli felosztás.
5. **Polish alulbecslése:** a „működik” és a „publikálható” közötti utolsó 20% sok iterációt igényel. Megoldás: két hét tartalék és korai külső teszt.

## Következő konkrét lépések

1. Fogadjuk el vagy szűkítsük a fenti publishable-prototype definíciót.
2. Döntsük el a prototípus 3 Fleshdrive-ját és egy-egy mondatos build fantasy-ját.
3. Készítsük el az M0/M1 feladatokból az első sprint backlogját.
4. Az első sprint végére legyen teljes, bár még csúnya 12–15 perces run.
5. A második héttől minden héten legalább egy külső vagy „fresh eyes” playtest történjen.
