# Kimeneti formátum (kötelező JSON)
```json
{
  "summary": "1-2 mondat a tervről",
  "proposals": [
    {
      "title": "Futás 40 perc",
      "start": "2026-05-04T18:00:00",
      "end": "2026-05-04T18:40:00",
      "tzid": "Europe/Budapest",
      "kind": "workout",
      "hard": false,
      "reason": "Energia 4, nincs ütköző esemény, tegnap pihenőnap volt"
    }
  ],
  "questions": ["opcionális visszakérdezések"]
}
```
Szabályok: helyi idő (zóna nélkül) + `tzid`; csak a szabad idősávokból választhatsz, amelyeket a `find_free_slots` eszköz ad; ne találj ki időpontot.

## Példa (jó)
Kérés: „Tervezz edzést jövő hétre”. Adat: hétfő energia 4, kedd 2, szerda 3. → Hétfő nehéz, kedd pihenő/séta, szerda könnyű; indoklás mindháromnál.
## Példa (rossz)
Nehéz edzés kedden energia 2 mellett, vagy 22:30-as edzés.
