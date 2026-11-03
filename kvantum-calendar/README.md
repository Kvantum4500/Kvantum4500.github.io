# Kvantum Naptár

Személyes naptárapp (Windows + Android, Flutter), szerver nélkül: Google Calendar (események) + Google Drive `appDataFolder` (saját adat) + Gemini (AI). Teljes terv: lásd a munkamenet tervfájlját; a lényeg lent.

## Állapot
| Rész | Állapot |
|---|---|
| `packages/kvantum_core` – tiszta Dart mag: időzóna/DST, ismétlődés, ISO-hét, duplikáció-védelem, AI szabályellenőrző | **kész, 23 teszt zöld** |
| `handbook/` – Gemini kézikönyv | **első verzió** |
| Flutter app (UI, Google belépés, Calendar/Drive szinkron, Gemini hívás) | következő lépés |
| Turbo mód (Cloudflare Worker + FCM) | következő lépés |

## Futtatás (mag)
```bash
cd packages/kvantum_core && dart pub get && dart analyze && dart test
```

## Fő tervezési döntések
- Időpont tárolás: **falióra + IANA zóna** (mint a Google), az instant származtatott. Ismétlődés falióra-időben fut (DST-biztos), az esemény időtartama valós eltelt idő.
- DST: tavaszi hiányzó idő előre tolódik, őszi dupla idő az első előfordulást kapja.
- Duplikáció: `reconcile()` sorrend: tárolt link → `appEventId` (saját írás visszhangja) → iCalUID → új.
- AI: Gemini a kézikönyvvel; a szabad idősávokat és a kemény szabályokat **kód** ellenőrzi (`validateProposal`), az AI csak választ és indokol.
- Titkok (API-kulcs, tokenek) soha nem kerülnek a repóba; az eszköz biztonságos tárolójában élnek.
- Megjegyzés: a mappa a `kvantum4500.github.io` repóban van, így GitHub Pages-en forrásként nyilvános; titkot nem tartalmaz. Külön repóba költöztethető.
