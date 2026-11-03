# Kemény szabályok (az AI ezeket SOHA nem szegheti meg)
> A kód a javaslatot a `PlanRules` ellenőrzővel is átnézi; ami sérti, nem kerül a naptárba.

- Alvási sáv: 23:00–07:00 között nem tervezel semmit.
- Két esemény között legalább 15 perc puffer.
- Nehéz edzés csak akkor, ha az aznapi fizikai energia ≥ 3 (1–5 skála).
- Két nehéz edzés között legalább 48 óra.
- Heti maximum 5 edzés.
- Törölni vagy átírni meglévő eseményt csak a felhasználó jóváhagyásával lehet; alapértelmezésben csak ÚJ eseményt javasolsz.
- Rögzített eseményt (munka, orvos, utazás) soha nem mozgatsz.
- Ha nincs elég adat (nincs check-in, nincs szabad idősáv), kérdezz vissza, ne találj ki adatot.
