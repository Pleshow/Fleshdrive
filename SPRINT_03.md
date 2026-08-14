# Sprint 03 – Combat feedback hangok nélkül

## Cél

A találatok és ellenfélhalálok legyenek azonnal érzékelhetők akkor is, amíg a végleges hangcsomag nem áll rendelkezésre.

## Elkészült

- Világkamerára kötött, trauma-alapú camera shake.
- Rövid, valós időben lejáró hit stop, amely minden esetben visszaállítja az `Engine.time_scale` értékét.
- Külön `Effects` konténer, hogy a harci VFX a világban maradjon, miközben a HUD stabil.
- Skálázott halál-burst a Crawler, Spitter és Charger ellenfelekhez.
- Enyhe feedback nem halálos találatnál, erősebb feedback kivégzésnél.
- Játékossérüléshez jól elkülönülő, erősebb kamera- és hit-stop reakció.
- Automatikus combat feedback teszt és teljes gameplay regresszió.

## Manuális tesztelés

1. Ölj meg egymás után több Crawlert; a kis ellenfelek visszajelzése ne akassza meg folyamatosan a mozgást.
2. Ölj meg egy Spittert és egy Chargert; a nagyobb ellenfél halála legyen érezhetően hangsúlyosabb.
3. Sebződj meg mindhárom ellenféltől; a játékossérülés legyen jól észrevehető, de ne legyen zavaró.
4. Rush alatt figyeld a halál-burstök olvashatóságát és az FPS-t.
5. Nyiss level-up vagy pause képernyőt közvetlenül találat után; a játék ne maradjon lassítva.
6. Figyeld, hogy a HUD ne remegjen együtt a világgal.

## Hangok későbbi bekötési pontjai

- játékos lövés és találat;
- Crawler, Spitter és Charger sérülés/halál;
- Spitter wind-up, lövedék és becsapódás;
- Charger wind-up, roham és becsapódás;
- játékossérülés, level-up, rush kezdete és vége;
- UI hover, választás, pause, győzelem és game over.

## Következő javasolt sprint

Meta- és prezentációs réteg: főmenü, beállítások (külön camera shake csúszkával), első indítási útmutató, majd a hangfájlok megérkezésekor központi audio busz és hangkezelő.
