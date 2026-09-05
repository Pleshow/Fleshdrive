# Fleshdrive – képernyő- és játékmenetaudit, 2026. szeptember 5.

A legnagyobb javulást most a látható tartalom, az olvashatóság és a gyorsabb játékba jutás adná. A biomechanikus karakterek és az implantáció–mutáció–újragyártás ötlete felismerhető saját arculatot adnak. Ezt jelenleg több felülethiba és a sok, nehezen olvasható információ gyengíti.

Vizsgálat: aktuális helyi forrás, jelenetek, egyensúlyadatok, automatizált tesztek és 30 renderelt kép. A képek Godot 4.7, Forward+, D3D12, GTX 970 mellett, 1280×720 méretben készültek; magyar és néhány angol állapotban. A jeleneteket és állapotokat ellenőrzőprogram nyitotta meg, a harci kép rendezett teszthelyzet. Ez nem végigjátszott, emberi 12 perces menet, és nem kontrolleres vagy minden felbontást lefedő teszt. A képeken szereplő eredményszámok tesztadatok, nem egyensúlymérés. A játékkódot nem módosítottam; a keretek elrejtése csak az ellenőrző folyamatban történt.

**Bizonyított hibák – ezeket javítanám először**

| Prioritás | Megfigyelés | Konkrét változtatás | Mikor kész? |
|---|---|---|---|
| P1 | A Húsfa teljes középső tartalmát tömör panel takarja. Angolul és magyarul is reprodukálható. | A `VisibleViewportFrame` őrizze meg az átlátszó saját stílusát; a globális UI-stílus ne cserélje minden Panel hátterét automatikusan. | A csomópontok és kapcsolatok azonnal láthatók, egérrel és billentyűfókusszal azonosíthatók. |
| P1 | A biofabrikátor kamrájában Koda és a nyomtatási animáció nem látható. A `PrinterGlass` elrejtésére előbukkan. | A kamraüveg kapjon valóban áttetsző stílust és kivételt a közös panelstílus alól. | A nyomtatás minden fázisa és a kész karakter is látható. |
| P1 | A mutációkártyák felső képterülete üres; az alsó szöveg zsúfolt és levágódik. A keret elrejtése önmagában nem hozza vissza a képeket. | Az illusztráció betöltését és méretezését külön ellenőrizni; 40% kép / 60% döntési információ arányt kipróbálni. Egy rövid hatásleírás és egy számszerű változás legyen, ne ismétlődjön ugyanaz kétszer. | Hosszú magyar leírással és kijelölt állapotban sincs levágás; a kép valóban látható. |
| P1 | A szervképernyő Voltaic buildkártyájának szövege kifut a jobb panelből, közel az alsó tárgypanelhez. | A részletes szinergialeírást külön részletpanelre tenni; a kártyán név, szint és 1–2 fő hatás maradjon. | Egy teljes felszerelésnél sem fedik egymást a panelek és szövegek. |
| P1 | Magyar UI-ban angol buildleírások, kártyák, `CLOSE`, `BLOOD MEMORY`, `SUBJECT` és bossdialógus marad. | Minden játékosi szöveg fordítási kulcsból jöjjön; az adatvezérelt tartalmat is ellenőrizni, nem csak a menügombokat. | Magyar végigjárás során nincs véletlen angol szöveg; a szándékosan megtartott tulajdonnevek következetesek. |
| P2 | A beállítások fülfeliratai vizuálisan összeérnek. Több vezérlő 11 px-es, sötétvörös szöveget használ. | Rövid fülek: „Kép”, „Hang”, „Irányítás”, „Kisegítés”; nagyobb belső térköz, világos szöveg, egyértelmű aktív fül. | 720p-ben kényelmesen olvasható és a fülek külön gombként érzékelhetők. |
| P2 | A HP száma és a boss HP címe túl közel kerül a dekoratív kerethez; a statisztikapanel címe összeér a nagyítás gombjával. | Külön fejlécsor, legalább 12–16 px tartalmi margó; a gomb számára előre fenntartott hely. | A dekoráció semmilyen számot vagy feliratot nem metsz. |

A Húsfa okát forrás és összehasonlító render is igazolja: `Scripts/skill_tree_panel.gd` 54. sorától a keret `z_index = 200`, eredetileg áttetsző `StyleBoxFlat`. A `Scripts/ui_polish.gd` `_style_panel()` metódusa `StyleBoxTexture` stílusra cseréli. A futás közbeni lekérdezés ezt visszaigazolta. A meglévő `preserve_authored_ui_style` kivétel jó kiindulópont. A biofabrikátor esetében ugyanez a stílusmechanizmus érinti a karakter fölé rajzolt `PrinterGlass` panelt.

Bizonyítékok: [Húsfa jelenleg](audit_20_tree_en.png), [ugyanaz a takaró keret nélkül](audit_21_tree_frame_hidden.png), [nyomtató jelenleg](audit_27_victory_actual.png), [ugyanaz az üvegpanel nélkül](audit_28_printer_glass_hidden.png), [mutációkártyák](audit_14_upgrades.png), [szervképernyő](audit_13_organs.png).

**Képernyőnkénti javaslatok**

| Képernyő | Mit tartanék meg? | Mit változtatnék? |
|---|---|---|
| Indító logók | Rövid stúdióazonosító, visszafogott megjelenés. | Az első logó kb. 2 másodperces szakasza alatt is lehessen átugrani; ismételt indításnál rövidebb bemutató. |
| Főmenü | A saját Koda-illusztráció és egyszerű négygombos szerkezet erős. | A gombszöveg legyen világosabb a keretnél. „Run indítása” helyett következetes „Új menet”; első alkalommal a „Húsfa” kapjon „Állandó fejlesztések” magyarázatot. |
| Betöltés | Egyetlen állapot és folyamatjelző. | Megszüntetni az 5 másodperces kötelező várakozást; a tényleges betöltés befejezése után rövid átmenet elegendő. |
| Kép és hang | Felbontás, fullscreen és külön hangerők már léteznek. | A fent jelzett füljavítás mellett „Tiszta pixelkép” és „Hangulatos” előbeállítás; a technikai effektekhez rövid magyarázat és előnézet. |
| Irányítás és kisegítés | Kamera-, flash-, VFX-, célkereszt- és aim-assist beállítások jó alapot adnak. | Ne csak az E/Q legyen átállítható. Mozgás, dash, támadás is; ütköző kiosztás felismerése, alaphelyzet gomb, kontrolleres jelölések. |
| Húsfa | Az összekötött szervcsomópontok tematikusak. | A takarás után automatikus teljesfa-nézet és középre állítás. Kijelöléskor részlet, külön vásárlásgomb; jelenleg a csomópont megnyomása közvetlenül vásárol. A teljes törlés kerüljön kevésbé hangsúlyos helyre. |
| Implantáció | Mimichu és a szívillusztrációk a legerősebb képek közé tartoznak. | A játszható szív kapja a fő hangsúlyt; a fejlesztés alatt állók maradjanak láthatók és tiltottak, kisebb súllyal. Elsőként köznyelvi leírás: „A villám átterjed a közeli ellenfelekre.” A szaknevek csak részletekben. |
| Karakterlap | A lényeges statisztikák egy helyen vannak. | „Alapérték + állandó bónusz + aktuális build” bontás; magyarázat a képességgyorsasághoz. A nagy üres jobb oldalt használja a tényleges képességleírás. |
| Eligazítás | Rövid cél és külön megnyitható részletes irányítás. | Visszatérő játékosnál ne legyen kötelező ismételt panel. Az első menetben cselekvéshez kötött tanítás: mozogj, találj el, dash-elj, használd az aktívat. A jelenlegi négy tipp kb. 11 másodperc alatt lefut, függetlenül attól, hogy a játékos kipróbálta-e. |
| Játék HUD | HP, XP és idő egyszerű alapszerkezet. | A kb. 130 px magas felső sáv túl sokat kér a 720 px-es képből. 70–90 px-es célt kipróbálni; jól jelölt aktív képesség, feltöltöttség, cooldown és billentyű. A Koda fölötti kék sáv funkcióját tanítani. |
| Szünet | A folytatás első helyen van. | Az azonnali újrakezdés/kilépés előtt jelezni az elvesző menetet; a billentyűzetes fókusz legyen feltűnő. Gyakran használt buildadatok kerüljenek a szünet első nézetébe. |
| Mutációválasztás | Három alternatíva, kiválasztás és megerősítés jó döntési alap. | Minden ajánlat válaszoljon: mit csinál, mit változtat most, mivel működik együtt. Példa: „Láncvillám célpontjai: 2 → 3”, alatta egyetlen szinergia. |
| Szervbeültetés | A kutya anatómiai ábrája jól illik az alapötlethez. | Választott szervnél csak a megfelelő foglalat világítson; legyen kattintásos beültetés is egyértelműen tanítva. Cserekor régi → új hatás, és egy mondat arról, mi vész el. A már létező függő szervkezelést megőrizni. |
| Bossbevezető | Van külön bemutató, fázisjelzés és támadási előjelzés. | A párbeszéd ne foglalja el a harctér alsó nagy részét; egy rövid, fordított mondat, majd elhalványulás. A boss figyelmeztetése és HP-sávja kapjon külön helyet. |
| Halál és győzelem utáni biofabrikáció | Az új test nyomtatása erős saját motívum. | A láthatósági hiba után világos „Meghaltál” / „Őrző legyőzve” főcím, megszerzett véremlék, egy fő tanulság, azonnal elérhető új menet. A győzelem és halál ugyanarra az útvonalra érkezik, ezért a siker külön visszajelzést igényel. |
| Mimichu-párbeszéd | Rövid karakteres reakciók fokozhatják az újrakezdési kedvet. | Ismételt menetnél az új játék gombjához ne kelljen minden dialógusoldalon átlépni. A történetszöveg maradjon külön olvasható. |
| Részletes statisztika | Sebzésforrás, bejövő sebzés és ellenféltípus már rendelkezésre áll. | A halál okát az alapösszegzésben is megmutatni, nem csak nagyított részletekben. Belső azonosítók helyett lefordított nevek. Győzelemnél a „Halál oka” sor elhagyható. |

A régi `show_run_end()` összegzőpanelt is megnyitottam: annak közepét takarja a statisztikaablak. Ez azonban nem a jelenlegi normál befejezési út: a `RunManager.finish_run()` mindkét eredményt a biofabrikátorhoz küldi. Emiatt ezt a régi panelhibát alacsonyabb prioritásúnak tekintem; törölni vagy egyértelműen leválasztani érdemes.

**Játékmenet: javasolt változtatások és mérési célok**

Az alábbi számok kipróbálandó célértékek, nem a mostani játék mért eredményei.

1. **Az első perc mutassa meg a játék különlegességét.** Az első mutáció célozhat 25–40 másodpercet; 60–90 másodperc alatt a játékos lásson jól felismerhető láncreakciót vagy mozgásra épülő szinergiát. A korai Voltaic ajánlatok már támogatottak, ezért először az ajánlat és a vizuális hatás kapcsolatát tisztáznám, nem új rendszert építenék.
2. **Kevesebb szakfogalom egyszerre.** Shock, Thunder Meter, kinetic charge, aktív, másodlagos aktív, szerv és tárgy fokozatosan jelenjen meg. A tooltipben legyen egy egyszerű mondat, utána a pontos számok. A 10./15. szint körüli Reflex Cortex / automata evolúció előtt a kézi támadás legyen önmagában is kényelmes; a hozzáférhetőségi célzás ne legyen késői jutalomhoz kötve.
3. **A 3., 6. és 9. perces rohamokat megtartanám.** Ezek jó ritmuspontok. Köztük 60–90 másodpercenként lehet egy felismerhető kisebb változás: eltérő megközelítési irány, kiemelt elite vagy rövid jutalomhelyzet. A már meglévő encounter-profilokra építenék. A 9:15-ös harapófogó és 10:15-ös kereszttűz jelenleg későre koncentrálja a külön eseményeket.
4. **A Dusk Garden kapjon helyazonosságot.** A jelenlegi pályakép nagy, homogén pontozott mező néhány külön fával. Ez a forrástextúrán is ilyen, nem a shader hibája. Három nagy, sötét, jól elkülönülő tájékozódási pontot tennék bele: sérült biofabrikátor, kiszáradt medence, gyökérgyűrű. A mozgási teret szélesen hagynám, és minden valóban szilárd elem ütközését együtt tervezném a spawnokkal.
5. **Veszély és saját effekt különüljön el.** A rendezett harci képen a vörös ellenséges lövedék elkülönül a fehér/kék saját effektektől; ezt megtartanám. Koda, crawler és a padló viszont rokon sötétvörös tónusú. Erősebb sziluett, eltérő forma és jól olvasható talajjel segítene. A kritikus telegráfok alacsony VFX-beállításnál is maradjanak teljesek.
6. **A pénznem legyen egyértelmű.** A Húsfa és az újradobás ugyanazt a tartós erőforrást használja, eltérő elnevezésekkel. Egységesen „Véremlék”, egy ikon, és szövegesen: „az állandó fejlesztési pénzedből”. Kipróbálnék egy valóban ingyenes első újradobást meneten belül, mielőtt a játékos tartós fejlődésért félretett pénzt költ.
7. **A bossidő és a cél mondjon ugyanazt.** A boss 11:00-nál jön, a számláló 12:00-nál nullára ér, de a boss jelenlétében a menet nem ér automatikusan véget. Bossfázisban a visszaszámlálást „Győzd le az Őrzőt” céllá alakítanám. Átlagos tesztbuilddel 45–75 másodperces bosspróbát mérnék, erős és gyenge builddel külön. A meglévő támadási előjelzéseket megtartanám; az időket csak videós próbák után rövidíteném.
8. **A vereség tanítson.** „A roham talált el; a dash készen állt” jellegű tanulság csak akkor jelenjen meg, ha tényleges eseményadat igazolja. Első körben halálok, legtöbb sebzést okozó ellenféltípus és legjobban működő képesség elég. Cél: ismételt halálnál 3–5 másodpercen belül lehessen új menetet kezdeni.
9. **A siker ne csak több statisztika legyen.** Boss után rövid, erős sikerjelzés, megszerzett jutalom, következő elérhető cél. A biofabrikátor motívuma maradhat közös, de a győzelem hangulata váljon el a vereségtől.

**Ajánlott munkasorrend**

1. Takaró panelek, kártyaképek, levágódó szövegek és szervpanel rendbetétele.
2. Teljes magyarítás, olvasható szövegszínek, beállításfülek és kisebb HUD.
3. Rövid indulás/újrakezdés, eseményhez kötött tutorial, pontos kártyaváltozások.
4. Pályabeli tájékozódás, rohamok közti ritmus és egyértelmű bosscél.
5. Emberi teszt friss mentéssel és fejlett profillal külön; utána számszerű balance-módosítás.

Javasolt elfogadási próba: minden főképernyő 1280×720 és 1920×1080 méretben, HU/EN, egér és kontroller; hosszú kártyaleírás, teli szervlista, sűrű harc, második bossfázis. Öt első játékosból legalább négy segítség nélkül induljon el, használja az aktív képességet és értse meg az első mutációválasztást. A meglévő `menu_overlay_seconds` mérés mutassa meg, mennyi időt töltenek ténylegesen menükben.

A helyi emberi tesztnaplók kitöltetlen sablonsorokat tartalmaznak. A korábbi teljesítményjelentés nem friss mérés ebből az auditból. A hangkeverés és a hosszú távú egyensúly ezért még valós játékpróbát igényel.

**A friss automatizált ellenőrzés eredménye**

A teljes release gate 32 tesztcsomagot futtatott: 25 sikeres, 7 sikertelen; a parancs hibával fejeződött be. [Teljes napló](release_gate.log).

| Sikertelen csomag | Jelzés |
|---|---|
| `core_loop_polish_test.gd` | Az ajánlat kategóriájának / következő szintjének ellenőrzése hibás. A badge új helyre került, ezért a teszt útvonalát is felül kell vizsgálni. |
| `enemy_behavior_test.gd` | A crawler animációs elvárása nem teljesül; az új asset képkockaszámával egyeztetendő. |
| `ink_crimson_visual_system_test.gd` | A teszt keret nélküli főmenügombokat vár, a jelenlegi menü keretes. |
| `main_menu_test.gd` | Régi font/háttér-elvárás, majd null objektum `texture` elérése; 180 másodperces időtúllépés. |
| `new_upgrades_test.gd` | Két upgrade pool-tagsága és két fegyver sebzésellenőrzése hibás. A tartalmi szűkítés és a lövedékutazás elvárásaival összevetendő. |
| `publication_readiness_test.gd` | A kártyaikonokra és 16 px-es változásleírásra vonatkozó ellenőrzés nem teljesül. |
| `run_smoke_test.gd` | Null objektumon `find_child` hívás a 850. sornál; 180 másodperces időtúllépés. |

Ezek nem hét bizonyított játékösszeomlást jelentenek: több ellenőrzés régi UI-struktúrát vagy assetet vár. A tesztelvárásokat a szándékos változásokkal egyeztetni kell, miközben a renderelt képeken igazolt valódi hibákat is javítjuk. A `Docs/RELEASE_STATUS.md` „28 sikeres teszt” állítása nem írja le a mostani checkoutot. A CA-store figyelmeztetés külön környezeti jelzés; a gate bukását az assertion/script hibák és időtúllépések igazolják.
