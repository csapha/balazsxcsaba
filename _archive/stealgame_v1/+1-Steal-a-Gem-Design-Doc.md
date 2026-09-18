# +1 Steal a Gem — Játék Design Doc

> Verzió: 0.1 (ötlet-vázlat)
> Dátum: 2026-09-18
> Műfaj: Incremental / +1 + lopós PvP (Steal a X meta)
> Platform: Roblox (Mobile-first, Desktop/Console támogatással)
> Cím: **+1 Steal a Gem** (a "+1" és a "Steal a X" keresést is lovagolja)
> Alternatív címek: **+1 Steal Gems**, **Steal a Gem +1**, **+1 Gem Heist**

---

## 1. Egy mondatban

Bányászod a saját kristálybányádat, a kitermelt drágaköveket a nyílt tálcán gyűjtöd, csiszolod vagy kockáztatod — és közben mások fosztogatják a tálcádat, te pedig az övéket.

---

## 2. Miért működik (piaci alap)

- A **"+1" incremental hullám** most a legforróbb, olcsó fejlesztésű, mobilbarát műfaj (pl. +1 Speed Keyboard Escape ~294K CCU, +1 Cut Grass 65M+ visit).
- A **"Steal a X" lopós-PvP** a legérzelmesebb, legklipgyártóbb meta (Steal a Brainrot ~25.4M CCU rekord; Steal An Egg 1M+ kedvenc; Build a Base and Steal 271K kedvenc).
- A kettő **kombinációja nem létezik**: az összes +1 játék szóló/solitaire, az összes lopós játék gacha-pet alapú.
- A drágakő a lopható tárgy: normális, menő, csillogó, gyerekek által imádott — nincs IP-kockázat, és a ritkaság-létra természetesen illik hozzá.

---

## 3. Core loop

```
Tap/hold (csákányütés) -> a fal reped -> kitörik egy kő (rarity-roll)
   -> a kő a bánya előtti NYÍLT TÁLCÁRA pottyan (lopható!)
   -> döntés: CSISZOLOD (biztos pénz, kisebb érték)
              vagy NYERSEN TARTOD (trade/gyűjtemény/event, nagy érték, DE lopható)
   -> pénz/nyers kő -> jobb csákány, mélyebb zóna, vault, őrök
   -> közben: mások tálcájának fosztogatása, saját tálca védése
   -> rebirth ("új akna") -> permanent szorzók
   -> offline: auto-bányász robotok termelnek a tálcára (reggel vagyont vagy üres tálcát találsz)
```

Ez a játék lelke: **minden +1 akció egy fizikai, lopható tárgyat hoz létre**, és a kockázat magában a döntésben él (nyers vs csiszolt).

---

## 4. Ritkasági rendszer

### 4.1 Alap szintek (alap roll minden ütésnél)

| Szint | Kő | Esély | Vizuális |
|---|---|---|---|
| Common | Kavics / Kvarc | 60% | matt, szürke |
| Uncommon | Ametiszt | 25% | enyhe lila fény |
| Rare | Zafír | 10% | kék ragyogás |
| Epic | Smaragd | 3.5% | zöld glow + részecskék |
| Legendary | Rubin | 1% | fényoszlop + saját hang |
| Mythic | Gyémánt | 0.4% | teljes csillogás, egyedi hang |
| Secret | Csillagkő / Fekete gyémánt | 0.1% | képernyő-effekt + szerver-announce |

### 4.2 Mutációk (bármelyik kőre ráülhet, szorzót ad)

| Mutáció | Szorzó | Esély | Megjegyzés |
|---|---|---|---|
| Normál | x1 | — | alap |
| Fényes (Shiny) | x2 | 1/50 | csillogó felület |
| Arany | x5 | 1/500 | arany bevonat |
| Jég / Lézer | x10 | 1/5 000 | neon / jeges textúra |
| Galaxis | x25 | 1/25 000 | csillagos textúra |
| Szivárvány | x100 | 1/250 000 | ultra ritka |
| Repedt | x0.5 | — | "junk", újracsiszolható |

### 4.3 Méret-variánsok (bizonyított Huge-minta)

- **BIG** — x10 érték, nagyobb modell + névtábla
- **HUGE** — x100 érték, 1/100 000+, szerver-broadcast ("X talált egy HUGE Galaxis Gyémántot!"), piedesztálon kiállítható

### 4.4 Érték formula

```
érték = alap_érték(ritkaság) x mutáció_szorzó x méret_szorzó
```

A kombináció (ritkaság + mutáció + méret) adja a végtelen vadászatot és a trade-piaci mélységet.

---

## 5. Honnan szerzed a drágaköveket

### 5.1 A saját bányád (alapforrás)

Minden játékos telkén van egy kristályfal / bánya-bejárat. Tap/hold = csákányütés, a fal reped, a kő kipottyan. Minél többet bányászol, annál **mélyebbre megy a gödröd** — a lyuk mélysége vizuálisan látszik = ranglista/clout.

### 5.2 Zónák (mélység = progression)

| Zóna | Pool |
|---|---|
| 1. Felszíni gödör | Kavics, Kvarc |
| 2. Barlang | Ametiszt, Zafír |
| 3. Mélybarlang | Smaragd, Rubin |
| 4. Kristálybarlang | Gyémánt |
| 5. Lávabánya | ritka mutációk |
| 6. Aszteroida / Szakadék | Secret pool |

Mélyebb zóna = jobb ritkaság-esély, de keményebb a fal -> jobb csákány kell.

### 5.3 Szerszámok (tool-progression)

Csákány szintek -> fúrógép -> robbantás (AoE) -> auto-bányász robotok (offline termelés).

### 5.4 Event-források

- **Meteor-zápor** — meteor csapódik a telkedbe, közösen feltöritek, ritka kő-burst
- **Arany ér** — limitált ideig bányászható kristály-ér jelenik meg
- **Heist Hour** — teljes erejű lopás + dupla mutáció esély
- **Kristályvirágzás** — minden kő újra-rollolhat mutációt

### 5.5 Offline termelés

Az auto-bányász robotok a tálcára termelnek. Visszatéréskor vagy vagyon, vagy üres tálca vár (a tolvajok megdolgoztak) — ez a napi visszatérési horog.

---

## 6. Kockázat / hozam rendszer

| Hol van a kő | Biztonság | Érték |
|---|---|---|
| Nyílt tálca (bánya előtt) | lopható | teljes |
| Vault / pince | biztonságos (limitált slot, upgradelhető) | teljes |
| Csiszolt kő | biztonságos pénz | kisebb, garantált |

A döntés folyamatos: gyorsan csiszolod biztos pénzért, vagy nyersen tartod trade-re/gyűjteményre és véded.

---

## 7. Lopási réteg

### 7.1 A lopás menete

1. Odamész egy másik játékos telkéhez (a telkek egy téren vannak, rálátással egymásra)
2. A nyílt tálcán hevernek a fizikai kövek — a szín + glow + méret miatt a ritkaság messziről látszik
3. E/tap a kövön -> felveszed -> **carry limit** (kezdetben 1-2 kő, upgradelhető), cipekedés közben lassabb a mozgás
4. A saját telkedre visszaérve a zsákmány a tiéd (a tálcádra vagy a vaultba kerül)
5. Ha elkapnak: **elejted az összes lopott követ** (a földre pottyannak, bárki felveheti) + 3 mp stun + rövid **"wanted"** állapot
6. Ha a tulaj épp a telkén van, az érintése azonnali elkapás (nincs verekedés — gyerekbarát)

### 7.2 Az őr (guard)

- A tulaj telkén járőrözik (4-6 waypoint: tálca -> vault -> bánya -> vissza), idle szimatolás animációval
- Ha nem-tulaj lép a védett zónába (tálca környéke): **gyanú-mérő** töltődik (~1,5 mp) -> ugatás/alarm -> üldözés
- Üldözés közben követi a tolvajt, de **póráz-limit** van (a telken túl már nem megy), sebessége kicsit lassabb a játékosénál — így a sebesség-upgrade-eknek értelme van
- Elkapás után visszatér járőrözni
- Upgrade-ek (tulaj fejleszti): kutya-tier, sebesség, érzékelési sugár, póráz hossz, darabszám (1-3)
- Tolvaj counterplay: sneak stat (lassabb gyanú-töltés), sprint, csont/decoy, Heist Hour kivárása, "melyik telket fosztom" döntés
- Offline: az őr ilyenkor is aktív (véd, amíg alszol), de az offline raid cap továbbra is él

### 7.3 Szerver-oldali megvalósítás

- `RequestSteal(plotId, gemId)` remote -> a szerver validál: távolság, plot ownership, tier, cooldown, raid cap, tálca állapot
- Soha nem a kliens dönt; minden állapot és tranzakció szerveren történik
- HUGE / Secret kő megszerzése szerver-announce-t kap — mindenki tudja, kinél van a zsíros zsákmány

---

## 8. Anti-grief szabályok (kritikus)

1. Csak a **nyílt tálca** lopható, a vault SOHA.
2. **Raid cap:** egy támadásban max a tálca egy kis %-a / max X kő.
3. **Cooldown** célpontonként (pl. 60 mp), hogy ne lehessen lefosztani egy játékost.
4. **Tier-gate:** csak kb. hasonló "net worth" sávú játékostól lehet lopni (nincs bully).
5. **Kezdő-védelem:** az első szinteken a tálca sebezhetetlen — előbb megtanulod a játékot.
6. **Heist Hour:** teljes erejű lopás csak az event idején; egyébként csak csipkedés.
7. **Revenge:** értesítés arról, ki lopott meg + jelölt telek + visszalopási bónusz.
8. **Offline cap:** alvás közben is limitált a lopható mennyiség (reggel nem üres tálcát találsz, hanem raid-összefoglalót).
9. A tolvaj wanted lesz -> közös vadászat = dráma, nem frusztráció.
10. Privát szerver opció (a Build a Base and Steal mintájára).

---

## 9. Progression és meták

- **Csákány / zónák / mélység** — fő szám-növekedés
- **Rebirth ("új akna")** — resettel permanent szorzókat kapsz
- **Múzeum / dex** — minden kő+mutáció+méret kombináció bejegyzés; szett-kirakás -> permanent luck szorzó
- **Luck** — csákány tier, múzeum szettek, szerver luck, code-ok, eventek
- **Trade** — nyers kövek és HUGE/Secret kombók cserélhetők (a játék pénzneme)
- **Ranglisták** — bánya mélység, legjobb kő, gyűjtemény teljesség

---

## 10. Social és viralitás

- Szerver-announce a ritka dropoknál (bevált RNG-játék motor)
- Klipgyártható pillanatok: HUGE reveal, lopás-dráma, wanted-vadászat
- Trade-piac és értéklisták (a közösség magától csinálja, mint a Slime RNG-nél)
- Discord + code-ok (standard meta)

---

## 11. Monetizáció

- Auto-bányász robotok (offline boost)
- Extra vault / tálca slotok
- Luck pass / battle pass
- Csákány- és bánya-skinek, karakter-kozmetika
- Event-boosterek

---

## 12. MVP hatókör és végrehajtási sorrend

**1. hullám (day 1 — a pénteki szelet):**
1. Tap -> +1 -> ritkaság-roll -> kő megjelenik a tálcán
2. Csiszolás -> pénz; vault slotok
3. 1 zóna + 3 csákány-upgrade
4. Offline termelés alap verziója

**2. hullám (lopás + social):**

5. Lopás: carry, raid cap, cooldown, tier-gate, wanted állapot
6. Őr NPC (patrol -> suspicion -> chase -> catch/leash)
7. Leaderboard (pénz + bánya mélység), raid-értesítés + revenge

**3. hullám (tartalom):**

rebirth, mutációk, múzeum/dex, trade, eventek (Heist Hour, meteor), HUGE-ok, szerver-announce

---

## 13. Tech jegyzetek

- Kövek: egyszerű part-ok/decálok + ParticleEmitter + Highlight; mesh csak a HUGE-oknál
- Lopás: szerver-authoritative raycast + proximity prompt + cooldown; soha nem kliens dönt
- Tálca: fizikai part-ok helyett adat-alapú lista + megjelenített modellek (perf)
- Offline: DataStore + időbélyeg-alapú kalkuláció (a meglévő idle játékok mintája)
- Mobile-first UI: 1 hüvelykujjas tap, nagy gombok, kevés szöveg

---

## 14. Nyitott kérdések / teendők

- [x] Név-ellenőrzés a Roblox keresőben ("Steal a Gem", "+1 Steal", "gem mine") — 2026-09-18: nincs találat, zöld a lámpa
- [ ] Ritkaság-oddsok finomhangolása playtesttel
- [ ] Anti-grief szabályok validálása (frustráció-teszt)
- [ ] Monetizáció etikus hangolása (nincs pay-to-win a lopásban)
- [ ] MVP prototípus Studio-ban, majd első playtest

---

*Készült: opencode + Roblox Studio session, 2026-09-18*
