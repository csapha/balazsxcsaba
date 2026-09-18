# SQUEEZE — Design Doc

> Verzió: 0.1 (terv)
> Dátum: 2026-09-19
> Műfaj: Incremental simulator (train -> gate -> minigame -> gacha -> mapa)
> Platform: Roblox (mobile-first)
> Munkacímek: **SQUEEZE**, **+1 Squeeze**, **Squeeze a Watermelon**

---

## 1. Egy mondatban

Guggolással (és később más gyakorlatokkal) edzed az **Erőt**, majd a pályán egyre nehezebb
tárgyakat szorítasz szét puszta kézzel — a dinnyétől a tankon át a bolygóig.

---

## 2. Miért most (piaci ellenőrzés)

- A **Lift a Cube** (2026-08-24, Freaky Strong!) 3 hét alatt ~2.4M visit, 16K egyidejű játékos,
  425K csoporttag. A képlete bizonyítottan húz:
  **edzés (stat) -> súly-gate -> klikk-minigame -> cash -> jobb testrész + gacha szorzó -> map**
- **Squeeze tematikájú nagy játék nincs a Robloxon.** A közeliek mások:
  - Muscle Simulator / Strong Legs — strength incrementális, de nincs szorítás
  - ONE FRUIT, Watermelon GO — gyümölcs merge / edzés, nem szorítás
  - Car Crushers — járműzúzás, nem kézi szorítás
- A **szétpukkanó tárgy** vizuálisan erősebb jutalom, mint a "felemelem a kockát" — ez a
  mi differenciálónk (satisfying faktor + klipgyár).

---

## 3. Core loop

```
Edzés: a HOTBAR 1-es slotjában a "Train" (guggolás) -> Erő nő
   -> map: séta egy tárgyhoz (súly + gate: Erő >= suly * gateRatio)
   -> squeeze minigame: rapid kattintás -> bar töltés
   -> POP! (szétpréselődik, szétpukkan) -> Cash
   -> upgrade: Kezek (szorzó) + Edzés (passzív/tap)
   -> láda -> kesztyű-anyag gacha (szorzók)
   -> nehezebb tárgy / új zóna
   -> Rebirth ("New Hands") -> permanent szorzó
```

Egy menet 30-60 mp: séta -> kattintás -> pop -> vásárlás -> tovább. A "még egy tárgy" érzés.

---

## 4. Rendszerek

### 4.1 Edzés (Erő) — a hotbarban

- Az edzés egy **Tool a hotbar 1-es slotjában** ("Train"), nem UI-gomb.
  - Mobilon a hotbar slotra tapolva, PC-n az `1` gombbal / kattintással aktiválódik.
  - Aktiválásra a karakter **guggolást** csinál (animáció), és +Erő jár.
- **Gyakorlatok (első a guggolás):** Squat (első, elérhető azonnal) ->
  Push-up -> Deadlift -> ... (a későbbiek unlockolhatók, mind más bónusszal:
  pl. Squat = alap Erő, Push-up = tap szorzó, Deadlift = súly-gate csökkentés).
- **Tap:** +1.5 Erő × hand multi (szerver limit: 15 tap/mp)
- **Idle:** edzés-tier passzív Erő/mp
- Az Erő a fő szám a HUD-on; ez a "stat", amit minden tárgy ellenőriz.

### 4.2 Tárgyak és gate

- Minden tárgynak van **súlya (kg)** és **gateRatio-ja**: `Erő >= weight * gateRatio` kell az indításhoz.
- Gate alatt: a prompt "Need X Power" jelzést ad, nem indul a minigame.
- Szükséges kattintás: `BaseClicks + (MaxClicks - BaseClicks) * (1 - Erő / weight)`
  (az Erő növekedésével egyre könnyebb szorítás).

### 4.3 Squeeze minigame

- Range: 14 stud; tap limit: 22/mp (szerver-oldali validálás)
- A bar **lecseng**, ha nem kattintasz (fail decay 0.8/s) -> 0-nál megszakad
- Siker: **POP** — részecske + léfröccsenés + hang + lebegő `+Cash`
- Cash: `weight * 0.4 * valueMulti` (balanszolható)
- POP után a tárgy eltűnik és **5 mp múlva újra megjelenik** (folyamatos grind)
- Szerver validál: távolság, gate, tap rate, "már szorítod-e"

### 4.4 Upgrade-ek

**Kezek** (tap + passzív szorzó):

| Tier | Ár | Szorzó |
|---|---|---|
| Bare Hands | $0 | x1.0 |
| Grip Gloves | $100 | x1.5 |
| Iron Grip | $600 | x2.5 |
| Titan Hands | $3,500 | x4.0 |
| Diamond Grip | $20,000 | x7.0 |
| Star Squeeze | $120,000 | x15.0 |

**Edzés** (passzív Erő/mp + tap bónusz):

| Tier | Ár | Passzív | Tap bónusz |
|---|---|---|---|
| Couch Potato | $0 | 0/mp | x1.0 |
| Jogger | $150 | 3/mp | x1.5 |
| Gym Rat | $900 | 20/mp | x2.5 |
| Athlete | $5,000 | 150/mp | x4.0 |
| Champion | $30,000 | 1200/mp | x7.0 |

### 4.5 Gacha (ládák)

- Ládák: Wooden ($1K) -> Silver ($25K) -> Golden ($500K) -> Cosmic ($10M)
- Roll: **kesztyű-anyag** (Gumi, Vas, Titán, Gyémánt, Csillag, **Secret**), szorzó x1.1 - x25
- Az anyagok **cserélhetők** (trade) -> közösségi piac
- Pity: 20 roll után garantált Epic+ (frustráció-csökkentés)

### 4.6 Zónák (map)

| # | Zóna | Példa tárgyak | Súly-tartomány |
|---|---|---|---|
| 1 | Garden | dinnye, kókusz, tök | 5 - 500 kg |
| 2 | Kitchen | hűtő, sütő, pult | 1K - 500K kg |
| 3 | Gym | súlyzó, gép, széf | 1M - 100M kg |
| 4 | Industrial | konténer, daru, tartály | 500M - 1B kg |
| 5 | Military | tank, helikopter, rakéta | 10B - 500B kg |
| 6 | Volcano | szikla, lávakő, gyémánt | 1T - 100T kg |
| 7 | Space | műhold, ufó, meteor | 1Qa - 100Qa kg |
| 8 | Core | bolygómag, fekete lyuk | végtelen sáv |

Zóna-váltás: az adott zóna összes tárgyát ki kell szorítani (vagy elég a Power gate).

### 4.9 UI/UX (a Lift a Cube elrendezése + retro/éles stílus)

**Stílus (Figma referencia alapján):**
- **Nincs lekerekítés** — minden sarok éles, `UICorner` sehol
- Sötét panel (`#101218` / `#1C202A`), vékony világos keret (UIStroke)
- **Piros fejlécsáv** a paneleken (cím + X bezárás), fehér UPPERCASE címek
- **Zöld gomb** a vásárlásra, **piros** a negatív/bezárás, sárga a pénznél
- Betű: vastag, chunky (GothamBlack a címekre, GothamBold a gombokra)
- Shop-sor felépítése: ikon + NÉV + stat sor (`MULTIPLIER x1.5` / `+3/s • TAP x1.5`) + státusz (`OWNED` / `EQUIPPED` / `BUY` / `LOCKED`) + gomb

**Elrendezés:**
- **Hotbar (alul):** "Train" Tool az 1-es slotban (guggolás)
- **Top-center:** két nagy számláló: **Power** (kék) + **Cash** (sárga)
- **Bal oldal:** boost-kártyák (`PASSIVE +X / s`, `HANDS xN.0`)
- **Bal alsó:** **PERMANENT 2x** badge (rebirth szorzó, ára látszik)
- **Jobb felül:** tárgy **refresh timer** ("Objects Refresh In 0:05")
- **Tárgy felett:** prompt + tooltip (`SQUEEZE`, gate alatt `Need X Power`, `Squeeze Time`)
- **Középen:** popup szövegek ("STRONGER HANDS", "ROLL FOR BETTER MATERIALS")
- **Jobb felül sarok:** FREE REWARD ikon

### 4.7 Rebirth ("New Hands")

- Reset: Erő, cash, upgrade-ek; **maradnak a gacha anyagok**
- Jutalom: permanent szorzó (+1.5x / rebirth), új kesztyű-skin

### 4.8 Social

- **Giant Object event:** a szerver együtt szorít egy óriás tárgyat (közös bar, mindenki kap rewardot)
- Leaderboard: legnagyobb szétpréselt súly, Erő, zóna
- Trade: anyagok cseréje

---

## 5. Monetizáció

- **Auto-Trainer** (offline/idel boost) — a legfőbb bevétel
- 2x Cash pass, Extra Chest Slot
- Kesztyű skinek, trail effektek
- VIP: +1 rebirth multi, privát szerver

---

## 6. MVP (2-3 nap)

1. **Train Tool a hotbarban** (1-es slot): aktiválás -> guggolás animáció -> +Erő
2. 4 tárgy: dinnye, kókusz, gumiabroncs, üllő (gate + minigame + pop)
3. Cash + Kezek/Edzés upgrade-ek (UI: top-center számlálók + shop panel)
4. 1 láda gacha (3 anyag, egyszerű odds)
5. Session-only (mentés NÉLKÜL), leaderboard
6. Mobil UI: 1 hüvelykujj, nagy gombok, refresh timer a tárgyakon

**Nem MVP:** zónák, rebirth, trade, event, skinek, hangok, több gyakorlat.

---

## 7. Roadmap

1. MVP playtest -> balansz (cash flow, click számok)
2. Zónák + 20-30 tárgy
3. Gacha bővítés + trade
4. Rebirth + permanente szorzók
5. Event (Giant Object), szezonális tárgyak
6. Polish: hangok, screen shake, pop variációk (dinnyelé, csavarok, szikra)

---

## 8. Kockázatok

- **Klón-vád:** a skeleton a Lift a Cube-é, de a verb, a jutalom-látvány és a co-op más -> kommunikálni kell a különbséget
- **Bar minigame fárasztó lehet:** később Auto-Squeeze upgrade (kredit rendszer)
- **Szám-balansz:** a gate és a click-formula könnyen törhető -> 2-3 playtest kell
- **Név:** publikálás előtt ellenőrizni a Roblox keresőben (`Squeeze`, `+1 Squeeze`, `Squeeze a Watermelon`)

---

## 9. Tech jegyzetek

- Szerver-authoritative: minden tap/range/gate validálva (tap rate limit!)
- **Train Tool:** sima Tool a Backpackban (nincs látható Handle), `Tool.Activated` -> szerver
  validál (cooldown) -> +Erő; a guggolás animáció kliens-oldali
- **Guggolás animáció:** az új R15 rig **AnimationConstraint**-eket használ (nincs Motor6D),
  és a `Transform` írás nem érvényesül -> **publikált animáció kell**:
  `Game.SquatAnimationId = "rbxassetid://..."` (ha üres: por-effekt + lebegő +Erő)
  - Opció A: saját publikálás Studio Animation Editorból (2 keyframe elég)
  - Opció B: fizetős workout pack (pl. BuiltByBit "Workout Animations | R15" $2.99)
- Tárgyak: egyszerű Part-ok (Ball/Block/Cylinder) + attribute-ok (`objectId`, `weight`)
- Pop effekt: ParticleEmitter + lebegő szöveg + opcionális screen shake
- Adat: session-only indulás, a PlayerData úgy épül, hogy később DataStore legyen
- Rojo projekt: `default.project.json` már a SQUEEZE névre állítva

---

*Készült: opencode session, 2026-09-19*
