# 🥩 Sell a Schnitzel – Fejlesztési terv (GDD)

> Roblox tycoon / idle-merge játék. Műfaji inspiráció: a "Sell All the Pizza" típusú **sütővásárlás → merge → eladás → rebirth** körforgás.
> Fontos: a mechanikák műfaji szinten átvehetők, de **minden asset, UI, név, szöveg és hang saját** legyen – ne másoljunk át logót, ikont, layoutot 1:1-ben. A schnitzel téma (klopfolás, panírozás, sistergő olaj, nagyi konyhája) bőven ad saját identitást.

---

## 0. Tartalom

1. [Játék összefoglaló](#1-játék-összefoglaló)
2. [Core loop](#2-core-loop)
3. [Rendszerek részletesen](#3-rendszerek-részletesen)
4. [Balance és számok](#4-balance-és-számok)
5. [Shop tartalma](#5-shop-tartalma)
6. [Monetizáció](#6-monetizáció)
7. [Első 10 perc (FTUE) – hogyan fogjuk meg a játékost](#7-első-10-perc-ftue--hogyan-fogjuk-meg-a-játékost)
8. [Retenció és social rendszerek](#8-retenció-és-social-rendszerek)
9. [UI design](#9-ui-design)
10. [VFX](#10-vfx)
11. [SFX és zene](#11-sfx-és-zene)
12. [Technikai architektúra (Roblox)](#12-technikai-architektúra-roblox)
13. [Analytics / KPI-k](#13-analytics--kpi-k)
14. [Fejlesztési ütemterv](#14-fejlesztési-ütemterv)
15. [Kockázatok és nyitott kérdések](#15-kockázatok-és-nyitott-kérdések)

---

## 1. Játék összefoglaló

| | |
|---|---|
| **Név** | Sell a Schnitzel |
| **Műfaj** | Tycoon / Idle / Merge, multiplayer szerver (6–8 játékos, mindenkinek saját telek) |
| **Platform** | Roblox (PC, mobil, konzol – **mobile-first** UI) |
| **Célcsoport** | 8–16 év, rövid sessionök (5–20 perc), sok visszatérés naponta |
| **Pitch** | Vegyél sütőket, merge-eld őket egyre durvább fritőzökké, a ropogós schnitzeleket add el a sorban álló vendégeknek, vegyél chefeket akik dolgoznak helyetted – aztán rebirth és kezdd újra nagyobb szorzóval. |
| **Fantázia** | "Kis büfétől a világ legnagyobb schnitzel-birodalmáig." |

**Három pillér:**
1. **Állandó számnövekedés** – mindig van valami, amire épp majdnem elég a pénz (5–30 mp-en belül).
2. **Kielégítő merge** – két sütő összeütközik, klopfolás, BUMM, nagyobb sütő. Ez a játék "juice"-a.
3. **Automatizálás** – a chefek miatt a játékos érzi, hogy "birodalmat" épít, és offline is termel.

---

## 2. Core loop

```
┌──────────────┐    ┌──────────────┐    ┌───────────────┐    ┌──────────────┐
│ Sütőt veszel │ →  │ Sütő süt     │ →  │ Schnitzel a   │ →  │ Elviszed a   │
│ (gombra lépsz)│    │ (szalagra)   │    │ gyűjtőtálcára │    │ pulthoz      │
└──────────────┘    └──────────────┘    └───────────────┘    └──────┬───────┘
        ▲                                                           │
        │           ┌──────────────┐    ┌───────────────┐           ▼
        └───────────│ Pénzt felveszed│ ← │ Vendégek    │ ← ─ ─ ─ ─ ─ ┘
                    │ (pénzkupac)   │    │ megveszik    │
                    └──────────────┘    └───────────────┘
```

**Rövid loop (5–30 mp):** gombra lépés → sütő vásárlás → merge → pénzfelvétel.
**Közepes loop (5–15 perc):** chefek fejlesztése, eladási sebesség, sütő-generáció upgrade, random event.
**Hosszú loop (30–90 perc):** Rebirth (X db sütő megvásárlása) → állandó pénzszorzó, új sütő-skinek, új terület.
**Meta loop (napok):** petek, aurák, Index (gyűjtemény), napi jutalmak, ranglista.

---

## 3. Rendszerek részletesen

### 3.1 Telek (Base) felépítése

Minden játékos kap egy saját telket a szerveren. Elrendezés (balról jobbra, ahogy a játékos halad):

1. **Sütősor** – 1 sorban 10 sütőhely (bővíthető 15 → 20 → 25 slotra). Felettük lebegő név + szint + kis progress bar (meddig süt).
2. **Futószalag** – a sütők elé teszi a kész schnitzelt, a szalag a **gyűjtőtálcába** (Merge-asztal mellett) viszi.
3. **Gombsor a szalag előtt** (fizikai, rálépős gombok, mint a tycoonokban):
   - `Vegyél 1-et` – `Vegyél 3-at` – `Vegyél 15-öt` – `Vegyél 100-at (Auto Merge)`
   - Robux gombok közéjük ékelve (sárga): `Sütési sebesség x2`, `Szerencsés Schnitzel x2`
4. **Merge-pad** – nagy lila/bordó platform "MERGE" felirattal. Rálépve minden lehetséges merge lefut.
5. **Chef-részleg** – chef-fejlesztő gombok + "Chef pihenőhely".
6. **Eladópult (büfé ablak)** – vendégsor, felette: `X 🥩 / mp`, pult szint + XP bar.
7. **Pénzkupac (raklap)** – ide gyűlik a bevétel, rálépve felveszed.
8. **Sütő-generáció upgrade tábla** – "Következő generáció: 1.1K / 10K sütő".

> Tipp: a telek **lineáris** legyen, a játékos szeme balról jobbra haladjon, mindig a következő drágább gomb felé.

### 3.2 Sütők

- Vásárláskor a sütő a **legalacsonyabb szabad slotra** kerül, a jelenlegi **generáció alapszintjén** (kezdetben Lv1).
- Minden sütő X másodpercenként 1 schnitzelt süt (lásd balance tábla), a schnitzel kirepül a szalagra.
- **Ha tele a sorod**, a "Vegyél" gomb pirosan villog → "Merge-elj!" tooltip. Ez tanítja a merge-et.
- Sütő ritkaság-esély: minden kisütött schnitzel kap egy ritkaság-dobást (lásd 3.4).

**Sütő szintek (saját nevekkel):**

| Lv | Név | Vizuális téma |
|---|---|---|
| 1 | Rozsdás Lábas | horpadt lábas gázrózsán |
| 2 | Kempingfőző | kis gázpalack, zöld |
| 3 | Téglasütő | piros tégla |
| 4 | Acél Serpenyő | fényes acél |
| 5 | Nagyi Tűzhelye | retro zománcos, virágmintás |
| 6 | Olajsütő | sárga fritőz, buborékok |
| 7 | Ipari Fritőz | dupla kosár, gőz |
| 8 | Réz Serpenyő | réz, csillogás |
| 9 | Arany Fritőz | arany + szikra |
| 10 | Gyémánt Fritőz | kristály, kék fény |
| 11 | Vulkán Fritőz | láva olaj |
| 12 | Jégsárkány Sütő | jég + lila tűz |
| 13 | Űr-Fritőz | UFO forma, neon |
| 14 | Kvantum Klopfoló | glitch effekt |
| 15 | A Végső Schnitzelgép | szivárvány aura, saját zenei stinger |

(Későbbi update-ekben 16–25 szint jöhet új világokkal.)

### 3.3 Merge rendszer

- **2 azonos szintű sütő → 1 db eggyel magasabb szintű.**
- Merge-padra lépve: az összes lehetséges pár összevonódik, alulról felfelé (kaszkád: két Lv1 → Lv2, ha már volt Lv2, akkor az kettő → Lv3 stb.).
- **Auto Merge**: a `Vegyél 100-at` gomb automatikusan merge-el; a Robux `Auto Merge` gamepass mindig, minden vásárlás után merge-el.
- Merge animáció (fontos a juice miatt!): a két sütő felrepül, egy óriás **húsklopfoló** lecsap rájuk, porfelhő + panírmorzsa, kiugrik az új sütő, szint-felirat pop-up (`Lv 7 – Ipari Fritőz!`). Első alkalommal minden szintnél "ÚJ SÜTŐ FELFEDEZVE!" banner + bekerül az Indexbe.

### 3.4 Schnitzel ritkaságok

| Ritkaság | Esély | Ár-szorzó | Kinézet |
|---|---|---|---|
| Sima Bécsi | maradék | x1 | aranybarna |
| Ezüst Schnitzel | 3% | x5 | ezüst csillogás |
| Arany Schnitzel | 0.5% | x25 | arany, csillag partikula |
| Gyémánt Schnitzel | 0.1% | x150 | kék kristály panír |
| **Nagyi Titkos Receptje** | 0.001% | x10 000 | szivárvány, szerver-szintű announcement |

- A `Szerencsés Schnitzel x2` gamepass + petek + luck boost duplázzák az esélyeket (a "Sima" kivételével).
- Nagyi Titkos Receptje esetén **globális chat üzenet** a szerveren: "🎉 [játékos] kisütötte NAGYI TITKOS RECEPTJÉT!" → social proof, FOMO.

### 3.5 Eladás (pult)

- A schnitzelek a gyűjtőtálcába kerülnek (kapacitás: 50, bővíthető).
- A **játékos** vagy a **chefek** felveszik és a pulthoz viszik (a játékos stack-je: 10 db kezdetben, karakter fején tornyosul – vicces vizuál).
- A pult **Eladási sebesség** (db/mp) alapján adja el a pultra tett schnitzeleket a vendégeknek → pénz a raklapra.
- **Pult szint + XP**: minden eladott schnitzel XP-t ad, pult-szintlépéskor kis pénzbónusz és több vendég jelenik meg (vizuálisan hosszabb sor).
- Pénz felvétele: rálépsz a raklapra (vagy `Auto Collect` gamepass).

> Szándékos szűk keresztmetszet: **termelés ↔ szállítás ↔ eladás**. A játékos mindig azt fejleszti, ami épp a bottleneck → ez ad döntést egy idle játékba. A UI jelezze is: piros "!" ikon azon a rendszeren, ami épp a szűk keresztmetszet.

### 3.6 Chefek (botok)

A chefek NPC-k, akik a tálcáról a pulthoz hordják a schnitzelt (később: automatikusan merge-elnek is, ha megveszed a "Főchef" fejlesztést).

| Statisztika | Mit csinál | Kezdő | Lépés | Max |
|---|---|---|---|---|
| **+1 Chef** | új chef NPC | 1 chef | +1 | 10 (rebirth-ökkel 15) |
| **Stack (kapacitás)** | hány schnitzelt visz egyszerre | 3 | +1 | 25 |
| **Speed (gyorsaság)** | mozgási sebesség | +0% | +3%/szint (később +4%, +5%) | +150% |
| **Stamina (kitartás)** | mennyi ideig dolgozik alvás előtt | 40 mp | +10 mp | 600 mp |
| **Anti-Sleep (ébresztő)** | felébresztés után boost | +10 mp boost | +5 mp | 60 mp |

**Alvás mechanika (aktív játékot jutalmaz):**
- Ha elfogy a stamina, a chef elalszik (ZZZ partikula, horkolás SFX), 20 mp múlva magától felkel.
- A játékos odamegy és **"Ébreszd fel!"** prompt (E / tap) → fakanállal fejbe kocogtatja → chef azonnal felkel + Anti-Sleep boost (gyorsabb egy ideig).
- Ez aktív interakciót ad az idle loopban, és értelmet ad a Stamina fejlesztésnek.
- `Robux: Soha nem alvó chefek` gamepass (lásd monetizáció).

**Chef ritkaságok (későbbi fázis):** a +1 Chef gomb mellett "Chef Gacha" ticketből – Gyakornok, Szakács, Főszakács, Sztárséf – különböző alap statokkal. Ez a meta-progresszió egyik csatornája.

### 3.7 Sütő-generáció (Oven Upgrade)

- Az összes eddig vásárolt sütő száma alapján: 1 000 / 10 000 / 50 000 ... vásárlás után **a "Vegyél" gomb már Lv2-es (majd Lv3, Lv4) sütőt ad**.
- Az ár ugrik (x1.8), de a vásárlások sokkal hatékonyabbak. Ez a közép-játékos "nagy pillanat".

### 3.8 Rebirth

| Rebirth | Követelmény | Jutalom |
|---|---|---|
| 1 | 5 000 sütő vásárolva | x2 pénz |
| 2 | 12 000 sütő | x3 pénz + új telek-skin |
| 3 | 25 000 sütő | x4 pénz + +1 max chef |
| 4 | 50 000 | x5 + új világ (Bécsi Kávéház) |
| 5+ | x2 előzőhöz képest | +1 szorzó / rebirth, minden 5.-nél új világ |

- Reseteli: pénz, sütők, chef-fejlesztések, pult szint.
- Megmarad: petek, aurák, Index, Robux gamepassok, rebirth tokenek, kozmetikumok.
- **Rebirth Token**: minden rebirth ad 1 tokent → Rebirth fán állandó perk-ek (pl. +5% offline kereset, kezdő 3 chef, kezdés Lv2 sütővel).
- **Rebirth Skip (Robux)**: azonnal megkapod a rebirth jutalmat, **progress megmarad** (erős, de fair: csak 1 szinttel ugrik).

### 3.9 Petek (Egg Pets)

- Tojások (itt: **"Panírtojás"** – tojás + morzsa téma!) pénzért és Robuxért.
- Petek bónuszai: pénz x, sütési sebesség x, szerencse x, chef sebesség x.
- 3 pet aktívan, slot bővíthető (gamepass). Pet merge: 5 azonos → arany változat.
- Pet témák: Klopfoló Kutyus, Morzsa Macska, Tojás Csibe, Kolbász Tacskó, Paprika Sárkány, Uborkasaláta Béka stb.

### 3.10 Aurák

- Ritka, gacha-szerű kozmetikai + kis buff (pl. +3% pénz). "Aura dobás" ticketből, amit playtime ajándékból / eventből kapsz.
- Aura a karakter körül: lángok, morzsaeső, olajbuborékok, villám. Erős flex-elem a szerveren.

### 3.11 Index (gyűjtemény)

- Sütők, schnitzel ritkaságok, petek, aurák, chefek. Minden kategória teljesítéséért állandó bónusz (pl. "Összes sütő felfedezve: +10% pénz").
- A collectorokat hosszú távon itt tartja.

### 3.12 Random eventek (5–7 percenként)

Kijelzés: "Következő esemény: 05:39" a képernyő tetején.

| Event | Hatás | Időtartam |
|---|---|---|
| **Ebédcsúcs** | vendégek x2, eladási sebesség x2 | 60 mp |
| **Arany Olaj** | arany schnitzel esély x5 | 45 mp |
| **Panírvihar** | égből schnitzelek hullanak, gyűjtsd őket | 30 mp |
| **Ételkritikus** | egy VIP vendég jön, ha 30 mp-en belül kiszolgálod: nagy pénz | 30 mp |
| **Nagyi Látogatás** | minden sütő +1 szint ideiglenesen | 30 mp |
| **Áramszünet** (ritka, vicces) | sütők leállnak, de chefek x3 gyorsak | 20 mp |

Az eventek szerver-szintűek → mindenki egyszerre éli meg, közös hype.

### 3.13 Offline kereset

- Kilépéskor a termelés 30%-a fut tovább, max 2 óra (fejleszthető 12 óráig Rebirth fán / gamepassal).
- Belépéskor popup: `Claim` (x1) – `Claim x2` (rövid reklám / Rewarded Video, ha elérhető, egyébként napi 1 ingyen) – `Claim x10` (Robux dev product).

---

## 4. Balance és számok

### 4.1 Alap képletek

```
Sütő ár (n = eddig vett sütők száma az aktuális generációban):
    ár(n) = Alapár_gen × 1.001^n
    Alapár_gen: Gen1 = 200$, Gen2 = 360$, Gen3 = 650$ ... (x1.8)
    → "Vegyél 3-at" ≈ 3 × ár (kis felár), "Vegyél 15/100" összeg = Σ ár

Sütő termelés:
    schnitzel/mp(Lv) = 0.5 × 2.15^(Lv-1)
    (2 sütő → 1 merge mindig +7,5% nyereség + felszabadul 1 slot → merge mindig megéri)

Schnitzel ár:
    eladási_ár = 1$ × ritkaság_szorzó × rebirth_szorzó × pet_szorzó × gamepass_szorzó × event_szorzó

Pult eladási sebesség:
    db/mp = 2 + 1 × szint_eladási_fejlesztés      (kezdő 2/mp)
    fejlesztés ára = 50 × 1.15^szint

Chef fejlesztések ára:
    +1 Chef   = 7 500 × 2.6^(chefek_száma-1)
    Stack     = 600   × 1.45^szint
    Speed     = 1 200 × 1.40^szint
    Stamina   = 300   × 1.35^szint
    Anti-Sleep= 1 000 × 1.50^szint
```

### 4.2 Sütő szint tábla

| Lv | Név | Schnitzel / mp | Ennyi Lv1 sütőből áll |
|---|---|---|---|
| 1 | Rozsdás Lábas | 0.5 | 1 |
| 2 | Kempingfőző | 1.08 | 2 |
| 3 | Téglasütő | 2.31 | 4 |
| 4 | Acél Serpenyő | 4.97 | 8 |
| 5 | Nagyi Tűzhelye | 10.7 | 16 |
| 6 | Olajsütő | 23.0 | 32 |
| 7 | Ipari Fritőz | 49.4 | 64 |
| 8 | Réz Serpenyő | 106 | 128 |
| 9 | Arany Fritőz | 228 | 256 |
| 10 | Gyémánt Fritőz | 491 | 512 |
| 11 | Vulkán Fritőz | 1.05K | 1 024 |
| 12 | Jégsárkány Sütő | 2.27K | 2 048 |
| 13 | Űr-Fritőz | 4.88K | 4 096 |
| 14 | Kvantum Klopfoló | 10.5K | 8 192 |
| 15 | A Végső Schnitzelgép | 22.6K | 16 384 |

### 4.3 Pacing célok (ingyenes játékos, aktív játék)

| Mérföldkő | Cél idő | Mit érez a játékos |
|---|---|---|
| Első sütő | 0–10 mp | "Azonnal csinálok valamit" |
| Első merge | 30–45 mp | "WOW, nagyobb lett" |
| Első chef | 3–4 perc | "Már helyettem dolgoznak" |
| Lv5 sütő | 6–8 perc | új vizuál (Nagyi Tűzhelye) |
| Első random event | 5–7 perc | meglepetés |
| Első pet tojás | 8–10 perc | gacha izgalom |
| Gen2 sütők | 15–20 perc | nagy ugrás |
| Rebirth 1 | 40–60 perc | "újrakezdem, de 2x gyorsabban" |
| Rebirth 2 | +60–80 perc | |
| Rebirth 5 | ~6–8 óra össz. játékidő | új világ |

**Szabály:** a következő megvehető dolog ára ne legyen soha több, mint a jelenlegi **30 mp-nyi bevétel** az első 10 percben, és **2–3 perc** a mid-game-ben. Ha egy upgrade 5 percnél messzebb van, a játékos unatkozik → event/pet/chef töltse ki.

### 4.4 Bottleneck-egyensúly

Cél: mindhárom rendszer nagyjából egy szinten legyen, felváltva legyen bottleneck.
- Termelés (sütők) ≈ szállítás (chefek: `chef_db × stack / körút_idő`) ≈ eladás (pult db/mp).
- Szimuláció: írj egy egyszerű **Python/Luau szimulátort**, ami egy "okos játékost" futtat (mindig a legjobb ROI-jú fejlesztést veszi), és kiadja a mérföldkövek idejét. Ezzel tuningold a konstansokat, ne kézzel!

### 4.5 Számformátum

`1.2K, 15.6M, 3.4B, 1.1T, 2.5Qa, 7.8Qi, ...` – max 4 értékes jegy. A fő számláló animáltan "pörög" fel.

---

## 5. Shop tartalma

A Shop egy UI ablak (bal oldali menüből) + a telken lévő fizikai gombok (azonnali vásárlás, kontextusban → jobb konverzió).

### 5.1 Fülek

**① Ajánlatok (Featured)**
- Kezdőcsomag (csak egyszer, első 3 napban, időzítővel)
- Napi akció (rotáló, -30%)
- Limitált event ajánlat

**② Gamepassok (állandó)** – lásd 6.2

**③ Pénz (Cash) csomagok** – az aktuális bevételhez skálázva (pl. "15 perc bevétel", "1 óra bevétel", "6 óra bevétel") → minden szinten értékes marad.

**④ Boostok (időszakos)**
- x2 Pénz 15 perc / 1 óra
- x2 Szerencse 15 perc
- x2 Sütési sebesség 15 perc
- Chef Energiaital (chefek nem alszanak 30 percig)

**⑤ Tojások / Petek**
- Pénzes tojások (3–4 db, egyre drágább, jobb petek)
- Robux tojás (exkluzív petek), 1x / 3x / 10x nyitás

**⑥ Kozmetikumok**
- Telek témák (Bécsi Kávéház, Falusi Lakodalom, Űrbázis, Halloween)
- Karakter kalapok (szakácssapka variánsok), kötények, fakanál/klopfoló "fegyver" skinek
- Aurák (néhány közvetlenül megvehető, de a legjobbak csak gachából)
- Trail-ek (panírmorzsa nyom)

**⑦ Kódok** – beváltó mező (pl. like-célok: "Új kód 5 600 like-nál!" tábla a pályán).

---

## 6. Monetizáció

### 6.1 Elvek

- **Fair to Play, Fun to Pay**: ingyen is végig lehet játszani, a fizetés gyorsít + flex.
- A Robux gombok **fizikailag ott vannak, ahol a vágy keletkezik** (Auto Collect a pénzkupac mellett, Cooking Speed a sütő gombok között, Anti-sleep a chefeknél).
- Soha ne blokkoljunk tartalmat Robux mögé; a premium tartalom legyen kozmetikus vagy kényelmi.
- Árak tesztelése A/B-vel (Roblox Price Optimization).

### 6.2 Gamepassok (egyszeri vásárlás)

| Gamepass | Hatás | Javasolt ár (R$) |
|---|---|---|
| **x2 Pénz** | minden bevétel x2 örökre | 199 |
| **x2 Sütési sebesség** | sütők 2x gyorsabban | 149 |
| **Auto Collect** | pénz automatikusan felvéve | 99 |
| **Auto Merge** | minden vásárlás után automatikus merge | 129 |
| **Szerencsés Schnitzel x2** | ritkaság esélyek x2 | 149 |
| **Fáradhatatlan Chefek** | chefek soha nem alszanak | 249 |
| **+2 Chef slot** | +2 max chef | 179 |
| **VIP** | x1.5 pénz, VIP chat tag, VIP terület, exkluzív pet, napi VIP ajándék | 399 |
| **+1 Pet slot** | 4. aktív pet | 99 |
| **Gyors tojásnyitás / 3x nyitás** | | 149 |
| **Offline x2 + 12h limit** | | 129 |

### 6.3 Dev Productok (ismételhető)

| Termék | Ár (R$) | Megjegyzés |
|---|---|---|
| Pénzcsomagok (S/M/L/XL) | 25 / 79 / 199 / 499 | bevétel-skálázott |
| Offline Claim x10 | 15–39 | belépéskor, impulzus |
| Rebirth Skip | 49 → skálázódik | progress megmarad |
| x2 Boostok (15 perc) | 19–29 | |
| Robux tojás 1x / 3x / 10x | 49 / 129 / 399 | exkluzív petek |
| Aura dobás | 25 | |
| **Troll / fun termékek** | 5–15 | pl. "Nagy Ugrás" (szuperugrás), "Schnitzel-eső mindenkire a szerveren", "Klopfold meg a szervert" (mindenki rázkódik) – olcsó, impulzus, social |
| Kezdőcsomag | 49 (90%+ értéknek tűnjön) | x2 pénz 1 óra + ritka pet + 100K cash |

### 6.4 Egyéb bevételi csatornák

- **Premium Payouts**: Roblox Premium tagoknak extra napi jutalom → hosszabb játékidő → több payout.
- **Rewarded Video Ads** (ha az élmény engedi és a korhatár megfelelő): Offline Claim x2, ingyen tojás.
- **Group jutalom**: csatlakozz a csoporthoz → +10% pénz, exkluzív kalap.
- **Like-célok + kódok**: likeolási ösztönzés → algoritmus.
- **Sorozat-alapú Season Pass** (későbbi fázis): 30 napos "Schnitzel Pass" ingyenes + premium (≈ 299 R$) sávval.

### 6.5 Fizetési pontok időzítése

| Mikor | Ajánlat |
|---|---|
| 2. perc | semmi! Csak élvezze. |
| 5–8. perc | első csendes Robux gomb észrevétel (sárga gombok a pályán) |
| Első chef elalvás | "Fáradhatatlan Chefek" ajánlat kis toast-ban (egyszer) |
| Első rebirth előtt | Rebirth Skip bemutatása |
| 2. session belépés | Offline Claim x10, Kezdőcsomag időzítővel |
| Ritka schnitzel után | "Szerencse x2" gamepass ajánlat (egyszer) |

Ne legyen felugró ablak 10 percen belül többször – frusztrál és rontja a retenciót.

---

## 7. Első 10 perc (FTUE) – hogyan fogjuk meg a játékost

**Cél: 30 mp alatt az első "WOW", 3 perc alatt egy automata gép, 10 perc alatt egy cél, amiért visszajön.**

### 7.1 Betöltőképernyő
- Saját logó: "SELL A SCHNITZEL" – sistergő, ropogós betűk, egy klopfoló lecsap a logóra (animált).
- Progress bar schnitzel formájú, ami "panírozódik" ahogy telik.
- `Koppints a kihagyáshoz` – ne tartsuk fel a játékost.
- Háttérben finom ismétlődő minta (schnitzel + citromkarika + klopfoló ikonok).

### 7.2 Spawn és első 60 mp (lépésről lépésre)
1. **0 mp** – A játékos a saját telkén spawnol, a kamera rövid (2 mp) "drón-repülés" a telek felett, majd vissza a karakterre. Egy chef NPC integet: "Szia! Segíts beindítani a büfét!"
2. **3 mp** – Arany nyíl + lüktető fénycsík a padlón a `Vegyél 1-et` gombhoz. Kezdő pénz: **pontosan elég 2 sütőre** (400$).
3. **8 mp** – Megveszi → sütő leesik az égből (BUMM, porfelhő), azonnal süt.
4. **12 mp** – Nyíl újra a gombra, megveszi a 2.-at.
5. **15 mp** – Nyíl a Merge-padra: "Két egyforma sütő? MERGE!" → klopfoló animáció → Lv2 sütő. **Ez a hook.**
6. **20–40 mp** – Schnitzel a tálcán → nyíl: "Vidd a pulthoz!" → vendégek ujjonganak → pénz a raklapon → nyíl: "Vedd fel a pénzt!" → pénz "beszívódik" a számlálóba hangos csilingeléssel.
7. **45 mp** – A pénz épp elég 1 új sütőre + a nyíl visszavezet. Innentől a loop magától megy.

### 7.3 2–10. perc
- **~3. perc**: az első chef **ingyen** jár ("Ajándék chef a nyitáshoz!"). Látja, hogy a chef hordja a schnitzelt → automatizálás élmény.
- **~4. perc**: az első chef elalszik → tutorial: "Ébreszd fel!" → megtanulja az interakciót.
- **~5. perc**: az első random event (Panírvihar) – **az első event fixen 5 percnél jön**, nem véletlenszerűen.
- **~7. perc**: ingyen tojás (első pet) – gacha élmény ingyen.
- **~9. perc**: Quest panel megjelenik: 3 rövid küldetés (pl. "Érj el Lv6 sütőt", "Adj el 500 schnitzelt") → konkrét célok.
- **~10. perc**: Rebirth gomb megjelenik halványan "2%" kijelzővel → hosszú távú cél látható.

### 7.4 FTUE szabályok
- Szöveg minimum, ikon + nyíl maximum (a célközönség nem olvas).
- Minden tutorial lépés átugorható, de nyíl marad.
- Az első 10 percben **nincs veszteség-élmény**, nincs fizetős felugró ablak.
- Lokalizáció: magyar + angol induláskor (Roblox auto-translate a többire, de a kulcsszövegek kézzel).

---

## 8. Retenció és social rendszerek

| Rendszer | Leírás |
|---|---|
| **Napi bejelentkezési jutalom** | 7 napos ciklus, a 7. nap nagy jutalom (ritka pet) |
| **Playtime ajándékok** | ajándékdoboz ikon visszaszámlálóval (pl. 0:51) – 5, 10, 15, 25, 40, 60 perc |
| **Napi / heti questek** | 3 napi, 5 heti, Rebirth Token / tojás jutalom |
| **Friend Boost** | minden barát a szerveren +10% pénz (max +50%) – "Friend Boost: +0%" kijelzés bal lent |
| **Ranglisták** | szerver (leaderstats: Pénz) + globális (össz. eladott schnitzel, rebirthek) fizikai táblákon a spawnnál |
| **Like-cél tábla** | "Új kód 5 600 like-nál!" progress bar a pályán |
| **Szerver announcement** | ritka schnitzel / pet kihúzás mindenki látja |
| **Látogatás** | más telkére el lehet sétálni, megnézni a sütősorát – flex |
| **Update ritmus** | 1–2 hetente kis update (új pet / event), havonta nagyobb (új világ / sütők) |

---

## 9. UI design

### 9.1 Stílus irány
- **Vastag, kerekített, "cartoon chunky"** stílus: vastag sötét körvonal (3–4px), belső fény, enyhe 3D (alsó árnyék), mint a modern simulator játékoknál – de **saját színpaletta**.
- Font: kerek, vastag display font (Roblox-on pl. **Fredoka One** vagy **Luckiest Guy**), minden felirat fehér + sötét stroke.
- Minden gomb **nyomásra összemegy (0.9 scale) és visszaugrik** (TweenService, Back easing).

### 9.2 Színpaletta (schnitzel téma)

| Szerep | Szín | Hex |
|---|---|---|
| Fő (panír arany) | aranybarna | `#F2A93B` |
| Kiemelés | citromsárga | `#FFE14D` |
| Pénz | élénk zöld | `#5BD94A` |
| Robux / prémium | sárga + Robux ikon | `#FFC21A` |
| Veszély / bezár | paradicsompiros | `#E8433A` |
| Háttér panel | meleg sötétbarna (85% átlátszó) | `#3B2418` |
| Ritkaság színek | Ezüst `#C9D3DD`, Arany `#FFC93C`, Gyémánt `#5CD6FF`, Nagyi: szivárvány gradiens | |

A háttér-téma a **bécsi/magyar konyha** hangulata: piros-fehér kockás abrosz minta a paneleken, fa textúra, citromkarika és petrezselyem díszek.

### 9.3 HUD elrendezés (mobile-first)

```
┌────────────────────────────────────────────────────────────────┐
│ [≡][💬]        [ 🏠 Telkem ] [ 🥚 Tojások ]        [🎟️][⚙️]    │
│                Következő esemény: 05:39            [Ranglista] │
│                                                                │
│ [🔄 Rebirth 2%]                                  [Nagy Ugrás]  │
│ [📖 Index    ]                                    R$ 15        │
│ [✨ Aurák    ]                                                 │
│ [🐶 Petek    ]                                  [x2 Pénz  R$] │
│ [🎁 0:51     ]                                  [x2 Seb.  R$] │
│                                                                │
│ 🎟️ 45                                                          │
│ $12.0K                    🥩 x 150 148            [x1][x1.1][x2]│
│ Barát boost: +0%                                  szorzók       │
└────────────────────────────────────────────────────────────────┘
```

- **Bal oldal**: menü gombok, ikonos, nagy (min. 70×70 px mobilon).
- **Bal alul**: valuták (ticket, pénz), barát boost.
- **Lent középen**: legfontosabb szám – **schnitzel készlet**, nagy, animált.
- **Jobb alul**: aktív szorzók (pénz, pet, rebirth, event) ikonokkal – rákattintva magyarázat.
- **Jobb oldal**: Robux ajánlatok (max 2–3, ne legyen zsúfolt).
- **Fent**: navigáció (Telkem / Tojások teleport) + event időzítő.

### 9.4 Ablakok (Rebirth, Shop, Offline, Petek)
- Fejléc: színes sáv ikonnal balra kilógva, cím, piros X jobbra.
- Tartalom: sötét, enyhén átlátszó panel, elmosott háttér (BlurEffect).
- Akciógombok alul: piros (alap) – sárga (x2) – zöld (x10 / legjobb érték), a **legjobb ajánlat a legnagyobb és legfényesebb**.
- Megnyitás: scale 0.6 → 1.05 → 1.0 (pop), bezárás gyors fade.

### 9.5 3D világ UI (BillboardGui)
- Gombok felett: cím fehérrel (`Vegyél 3-at`), ár zölddel (`$606`), Robux gomboknál sárga ikon.
- Ha nincs elég pénz: ár pirosra vált + lassú pulzálás tilt helyett.
- Sütők felett: név + szint + vékony progress bar.
- Floor decal-ok: "+5.2K $" pénzkupac értéke a padlón.

---

## 10. VFX

| Esemény | VFX |
|---|---|
| Sütő vásárlás | égből leesik, landoláskor porgyűrű + kis kamera rázkódás |
| Sütés közben | olajbuborékok, gőz, a sütő ritmikusan "lélegzik" (scale 1→1.03) |
| Schnitzel kiugrik | kis ív, aranyszín csillanás, panírmorzsa partikulák |
| **Merge** | 2 sütő felemelkedik → óriás klopfoló lecsap → fehér villanás + shockwave gyűrű + morzsa robbanás + "LV 8!" felirat felugrik, szivárvány a 10+ szinteken |
| Ritka schnitzel | Ezüst: csillanás; Arany: csillageső; Gyémánt: kék fénynyaláb az égbe; Nagyi: szivárvány oszlop + konfetti az egész szerveren |
| Pénz felvétel | bankjegyek repülnek a HUD pénzszámlálóba (screen-space), a számláló felpörög és megugrik |
| Chef alszik | ZZZ partikula, buborék |
| Chef felébresztés | csillag a fej felett, "pof!" képregényes felirat, sebesség-csíkok utána |
| Rebirth | képernyő fehérre villan, telek "összecsukódik" és újraépül, nagy "x3 PÉNZ!" felirat |
| Random event | képernyő-szélen színes vignetta + banner felülről lecsúszva |
| Tojásnyitás | tojás remeg, repedések, panír-robbanás, pet kiugrik ritkaság-színű fénnyel |
| Aura | folyamatos partikula a karakter körül (lángok, olajcseppek, villám) |

**Teljesítmény:** mobilon partikula-limit (max ~200 aktív/telek), LOD: más játékosok telkén kevesebb effekt. Grafikai beállítás szerint skálázás.

---

## 11. SFX és zene

### 11.1 Hangeffektek

| Esemény | Hang |
|---|---|
| Gomb UI | rövid "pop" / "bloop" |
| Gombra lépés (fizikai) | mély "kattanás" + pénztárgép "cha-ching" |
| Sütés | halk, loopolt **sistergés** (olaj) – távolságfüggő |
| Schnitzel kiugrik | ropogós "crunch" |
| **Merge** | felhúzó "whoosh" → **klopfoló csapás (THUD)** → csilingelő szint-fel arpeggio (szintenként magasabb hangon!) |
| Ritka schnitzel | ritkaságonként egyre epikusabb fanfár |
| Pénz felvétel | érmezuhatag, a számláló pörgésére gyors tick-ek |
| Chef horkol | vicces horkolás (több variáns) |
| Chef ébresztés | fakanál "konk" + meglepett "huh!" |
| Vendég eladás | vidám "mmm!" / "köszi!" hangfoszlányok (gibberish nyelv, nem kell lokalizálni) |
| Rebirth | nagy whoosh + kórus "aaah" + basszus drop |
| Event indul | csengő + harsona |

**Szabály:** minden gyakori hang 3–5 variánssal és ±5% hangmagasság randomizálással, hogy ne legyen idegesítő. Minden hangnak volume slider (Beállítások: Zene / SFX külön).

### 11.2 Zene
- Fő téma: vidám, pattogós **polka / bécsi keringő × modern lo-fi/chiptune** fúzió (harmonika, tuba, pizzicato + modern dob). Ez nagyon egyedi hangulatot ad.
- Event zene: gyorsabb tempó, ugyanaz a dallam.
- Rebirth / új világ: saját variáció (pl. Kávéház – zongora jazz).
- Zene ~ -18 LUFS, SFX alá, hogy ne fárasszon.
- Csak saját vagy Roblox licencelt (Creator Store, APM) zene!

---

## 12. Technikai architektúra (Roblox)

### 12.1 Mappastruktúra (Rojo-val ajánlott)

```
src/
├── ServerScriptService/
│   ├── Services/
│   │   ├── DataService.lua        -- ProfileStore/ProfileService mentés
│   │   ├── PlotService.lua        -- telek kiosztás, sütő slotok
│   │   ├── OvenService.lua        -- vásárlás, merge, termelés tick
│   │   ├── SellService.lua        -- pult, vendégek, pénz raklap
│   │   ├── ChefService.lua        -- chef AI (state machine)
│   │   ├── RebirthService.lua
│   │   ├── PetService.lua
│   │   ├── EventService.lua       -- random eventek, szerver-szintű
│   │   ├── MonetizationService.lua-- ProcessReceipt, gamepass cache
│   │   └── AnalyticsService.lua   -- Roblox AnalyticsService funnel-ek
├── ReplicatedStorage/
│   ├── Shared/
│   │   ├── Config/                -- ÖSSZES balance szám itt (OvenConfig, ChefConfig, PriceConfig)
│   │   ├── Formulas.lua           -- ár/termelés képletek (kliens is látja megjelenítéshez)
│   │   └── NumberFormat.lua
│   └── Remotes/
├── StarterPlayerScripts/
│   ├── Controllers/ (UIController, VFXController, SoundController, TutorialController)
└── StarterGui/
```

### 12.2 Kulcs-elvek
- **Szerver az igazság**: minden pénz, vásárlás, merge szerver oldalon számolódik. A kliens csak kér (`RemoteFunction: BuyOven(amount)`), a szerver validál.
- **Termelés nem fizikai**: a schnitzelek **számként** léteznek a szerveren, a szalagon guruló modellek csak kliens-oldali vizuálok (poololva, max ~30 látható). Különben szétfagy a szerver.
- **Tick rendszer**: szerver 1 mp-enként számolja a termelést/eladást aggregáltan; a kliens interpolálja a számlálót.
- **Chef AI**: kliens-oldali vizuális NPC-k, a szerver csak a "körút ciklust" szimulálja időalapon → olcsó és csalás-biztos.
- **Mentés**: ProfileStore (session locking), auto-save 60 mp-enként + kilépéskor + `BindToClose`. Verziózott adatséma migrációval.
- **ProcessReceipt**: idempotens, a vásárlás ID-t mentsd a profilba, csak mentés után adj `PurchaseGranted`-ot.
- **Big number**: 1e308 felett kell egy BigNum könyvtár (pl. mantissa+exponens), vagy cap-eld a játékot. Már a tervezésnél dönts!
- **Anti-exploit**: remote rate limit, távolság-ellenőrzés a gombokhoz, szerver oldali cooldown.
- **Teljesítmény**: StreamingEnabled, telkek közti távolság, mobil 60 FPS cél low-end eszközön is.

---

## 13. Analytics / KPI-k

| Metrika | Cél |
|---|---|
| D1 retenció | ≥ 30% |
| D7 retenció | ≥ 10% |
| Átlagos session hossz | ≥ 15 perc |
| FTUE befejezés (első merge) | ≥ 90% |
| Első chef megvétele | ≥ 75% |
| Első rebirth | ≥ 30% (D1-ig) |
| Payer konverzió | 2–5% |
| ARPDAU | tesztelés után benchmark |
| Like/dislike arány | ≥ 85% |

**Funnel események** (Roblox AnalyticsService `LogOnboardingFunnelStepEvent`): betöltés → első sütő → első merge → első eladás → első pénzfelvétel → első chef → első tojás → első rebirth.
**Economy események**: minden pénz forrás/nyelő (`LogEconomyEvent`), hogy lásd hol akad el a progresszió.

---

## 14. Fejlesztési ütemterv

| Fázis | Időtartam | Tartalom |
|---|---|---|
| **0. Prototípus** | 1–2 hét | szürke dobozos telek, sütővásárlás, merge, eladás, pénz – csak a loop. **Kérdés: szórakoztató-e 5 percig?** |
| **1. Vertical slice** | 2–3 hét | chefek (stamina/stack/speed), 10 sütő szint modellekkel, merge VFX/SFX, FTUE, mentés |
| **2. Alpha** | 2–3 hét | rebirth, petek + tojások, random eventek, offline kereset, shop UI, gamepassok |
| **3. Polish + Beta** | 2 hét | UI polish, hangok, zene, mobil optimalizáció, balance szimulátor, zárt teszt barátokkal (10–20 fő) |
| **4. Soft launch** | 1–2 hét | publikus, kis reklám (Sponsored/Ads ~ kis budget), KPI figyelés, gyors balance javítások |
| **5. Live ops** | folyamatos | kéthetente update, havi új világ, szezonális eventek (Halloween, Karácsony – "Karácsonyi rántott ponty" event!), Schnitzel Pass |

**MVP must-have:** sütő vásárlás, merge, eladás, chefek 4 stattal, rebirth, mentés, 3–4 gamepass, FTUE.
**Nice-to-have később:** aurák, chef gacha, Index bónuszok, világok, trading.

---

## 15. Kockázatok és nyitott kérdések

| Kockázat | Kezelés |
|---|---|
| Túl hasonlít az eredetire | saját art, saját UI layout, saját nevek, schnitzel-specifikus mechanikák (klopfolás, panírtojás, nagyi), saját zene |
| Unalmas mid-game | eventek, questek, Gen upgrade-ek, chef-alvás interakció |
| Szerver lag sok entitástól | számalapú szimuláció, kliens-oldali vizuálok poolozva |
| Pay-to-win érzet | gamepassok kényelmi/gyorsító, nincs Robux-exkluzív progresszió-fal |
| Balance szétesik nagy számoknál | szimulátor + Config modulban minden szám + BigNum döntés előre |

**Nyitott kérdések, amiket érdemes eldönteni:**
1. Legyen-e **trading** (petek)? → növeli a retenciót, de scam-moderálás kell.
2. Hány játékos/szerver? (6 javasolt a telek-méret miatt)
3. Rewarded video ad – a célközönség és a Roblox szabályok szerint engedélyezett-e?
4. Világok témái a rebirth-ök után (Bécsi Kávéház, Magyar Lakodalom, Űr-büfé, Kalóz konyha?)
5. Legyen-e kooperatív elem (közös szerver-cél, pl. "A szerver 1M schnitzelt ad el → mindenki kap jutalmat")?

---

## Eddigi kész dolgok

> Állapot: 2026-11-13. A kód a `src/` mappában van (Rojo), minden szám a `src/shared/Config/` modulokban állítható.
> A vizuálok placeholderek (szürke dobozok, blokkos figurák) – a modelleket a másik fejlesztő készíti.
> Ahol eltértünk az eredeti tervtől, azt **Eltérés** jelöli.

### Alapok
- Rojo projekt + Wally csomagok (Vide, DataServiceTyped / ProfileStore, Networker, Signal), `rojo serve` működik.
- 6 játékos / szerver, mindenkinek saját telek; belépéskor automatikus kiosztás és teleport, tulajdonos tábla.
- Mentés ProfileStore-ral (Studióban alapból mock, nem ment; Studióban $1B kezdőpénz a teszteléshez).
- HUD (mobile-first): pénz (felpörgő számláló), nálad lévő schnitzel + értéke, bal oldali menü (Rebirth, Index, Petek, Aurák), fent navigáció (🏠 Telkem, 🥚 Tojások) és event időzítő.
- Számformátum (4.5): 1.2K, 15.6M, 3.4B …

### 3.1–3.3 Telek, sütők, merge
- Szimmetrikus telek: emelt platform, rajta 2 sütősor, köztük futószalag középre → csúszda → **Collector** a fal tövében.
- 15 sütőszint a tervbeli nevekkel; sütő felett név, szint, progress bar.
- 10 slot (kezdőpénz $100); bővítés 14 → 18 → 22-re az 1–3. rebirth jutalmaként (**Eltérés:** a terv pénzes / +5-ös bővítést nem írt elő pontosan).
- Vásárló gombok: 1 / 3 / 5 / 15 (merge nélkül) és 100 (Auto Merge); a 6. hely a Robux gombnak marad. A 100-as gomb tele sorban a legalacsonyabb sütőbe "vásárol bele" (ha ehhez ≤ 100 sütő kell – lásd lent: Félkész).
- MERGE pad: kaszkád merge, "Lv 7 – Ipari Fritőz!" felirat (a teljes animáció a 10. fejezetben).
- **Eltérés – gazdaság ("A" modell):** a sütő szintje duplázza a darabszámot **és** az árat is (szintenként 4× bevétel).

### 3.4 Ritkaságok
- Ezüst / Arany / Gyémánt / Nagyi Titkos Receptje minden sütésnél; a ritka darab színesen világít a szalagon, felirat a sütő felett, Nagyinál szerver-szintű chat üzenet.
- Esélytábla a falon a collector mellett.
- **Eltérés:** a ritkaság a darabszámot és az árat is szorozza, a kettő szorzata a tervbeli ár-szorzó (Ezüst 2×2.5, Arany 5×5, Gyémánt 10×15, Nagyi 100×100).

### 3.5 Eladás
- Collector (nincs kapacitás), halom a collectoron, felvételkor "+n" minőségenként; a nálad lévő schnitzel a fejeden tornyosul.
- Leadó asztal a pult előtt (repülő darabok animáció), az asztalon a pult készlete látszik.
- Pult: eladási sebesség (egész szám, min. +1 / +25% fejlesztésenként), pult szint + XP (szintlépéskor pénzbónusz, +2% ár, hosszabb sor), pénz raklap.
- Vendégek: a telek tulajdonosának Roblox barátai, az utcáról jönnek, sorba állnak, kiszolgálás után schnitzellel távoznak.
- Piros "!" a szűk keresztmetszeten (collector / eladó / sütők).

### 3.6 Chefek
- U alakú chef-részleg: +1 Chef (első $1 500, max 10), Stack (sütés/kör), Gyorsaság, Kitartás, Ébresztő – globális fejlesztések.
- Chefek a collectorból a leadó asztalra hordanak (szerver időalapú szimuláció, kliens rajzolja őket).
- Elalszanak ("Zzz"), 20 mp múlva felkelnek, vagy "Ébreszd fel!" prompttal azonnal + boost.

### 3.7 Sütő-generációk
- Generáció-tábla + "Generáció váltás" gomb: Gen2–Gen6 (1K / 10K / 50K / 200K / 1M vett sütő), ár ×1.8 generációnként.
- Váltáskor a régi, alacsonyabb sütők felfejlődnek az új alapszintre.

### 3.8 Rebirth + rebirth-fa
- Rebirth ablak (követelmény, jutalom, mi veszik el / mi marad, kétlépcsős megerősítés), fehér villanás + "x2 PÉNZ!" effekt.
- Pénzszorzó x(1 + rebirthek), +1 token, +4 slot az 1–3.-nál, +1 max chef a 3.-nál; teljes újrakezdés.
- **Eltérés:** a követelmény **az adott körben keresett pénz** ($1T → $300T → $1.2Qa → $2.8Qa, utána ×1.6), nem a vett sütők száma – különben végjátékban (minden slot Lv15) elakad.
- Rebirth-fa (külön fül): Pénz, Kezdőpénz, Kezdő chefek, Kezdő generáció, Offline idő, Offline arány – szintenként 1 token.

### 3.9 Petek
- Tojás tér az utca közepén, 4 tojás ($100K / $1M / $100M / $10B), 16 pet, 5 ritkaság; tojásnyitás animáció, legendás petnél chat bejelentés.
- Bónuszok: Pénz, Sütés (gyorsabb sütők), Szerencse, Chef sebesség; 3 aktív pet.
- Pet ablak: leltár (max 50), felszerelés, törlés, 5 azonos → arany pet (3× bónusz). A petek követik a játékost.

### 3.10 Aurák
- 8 aura (Gyakori → Mitikus), részecske-effekt a karakter körül (mindenki látja), dobás-animáció.
- Ticket: 10 perc játékidőnként ingyen + pénzért is dobható; duplikátum → szintlépés (max 5); 1 aktív aura.

### 3.11 Index
- Fülek: Sütők, Ritkaságok, Petek, Aurák; teljesítésért +10% / +10% / +15% / +15% pénz.
- **Még nincs mentve** (döntés: a végére), de ami megvan, az mindig felfedezettnek számít.

### 3.12 Random eventek
- 5–7 percenként (Studióban 60–90 mp), banner + színes keret, időzítő a HUD-on.
- Ebédcsúcs, Arany Olaj, Panírvihar (közös, az utcán), Ételkritikus (VIP vendég), Nagyi Látogatás, Áramszünet.

### 3.13 Offline kereset
- A becsült bevétel 30%-a, max 2 óra (rebirth-fával 60% / 12 óra); "Üdv újra!" ablak belépéskor.
- **Eltérés:** most csak sima Claim; az x2 / x10 a monetizációval jön.

### 4.4 Balance szimulátor
- `tools/sim/simulate.luau` (lune): a játék saját Config + Formulas moduljaival futtat egy "okos játékost", és kiírja a 4.3 mérföldköveket.
- `--gaps` kapcsoló: kiírja a leghosszabb várakozásokat (mikor, mire várt a játékos, milyen sütőkkel).
- **Eltérés:** sütőár 200 × 1.001ⁿ helyett **50 × (1 + n/10)²** (a régi árral a játék 4 perc alatt "elszállt"; az olcsóbb eleje a 30 mp-es szabály miatt kell, a 100. sütőtől ugyanannyi, mint a korábbi 200 × (1 + n/20)²).

### 4.3 Pacing hangolás (2026-11-13)
- Az első 10 percben a leghosszabb várakozás **1:30 → 27 mp** (cél ~30 mp).
- Új értékek: sütő alapár $50, kezdőpénz $100, első chef $1 500, Panírtojás $100K, Gen2 küszöb 1 000 sütő.
- Eredmény (szimulátor, medián): első merge 21 mp, első chef 3:17, Lv5 ~3 perc, első tojás ~5–7 perc, Gen2 ~18 perc, Rebirth 1 ~37–40 perc.
- **Eltérés a 4.3 céloktól:** az első merge (cél 30–45 mp) és a Lv5 (cél 6–8 perc) korábban jön – a 30 mp-es szabály fontosabb.

### Félkész (2026-11-13) – a végjátéki várakozás megszüntetése
- **Gond:** a végjátékban 20–45 percet kell várni a következő rebirthre, mert
  1. tele sornál a 100-as gomb csak akkor vesz, ha a legalacsonyabb sütőhöz ≤ 100 alapsütő kell (pl. Gen4-ben egy Lv11-hez már 128 kell), így a sütők elakadnak;
  2. ha már minden slot Lv15, nincs mit venni.
- **Döntés 1:** tele sornál a 100-as gomb annyit vesz, amennyi a legalacsonyabb sütő következő szintjéhez kell (akár 100-nál többet). *A szimulátorban kész, a játékban (OvenService.buyIntoLowest) még nincs.*
- **Döntés 2 – Csillagok:** ha a sor tele van és minden sütő Lv15, a 100-as gomb csillagot vesz a legkevesebb csillagú sütőre. Max 5★, csillagonként +50% érték (5★ = 3.5×), a rebirth nullázza. Az ár egy Lv15 sütő valós bevételének (pénzszorzók, pet sütési sebesség, ritkaság-átlag) X mp-e, csillagonként ×3.
  - Kész: `Config.Ovens.Stars`, `Formulas.starPrice / starTarget / starMultiplier / rarityValueMultiplier`, a `Formulas.production` csillagokkal, a szimulátor.
  - Hátravan: mentés (`ovenStars`), OvenService (gomb + felirat, sütés × csillag), RebirthService nullázás, ★ a sütők felett.
  - Legjobb eddigi beállítás (szimulátor): csillagár 120 mp × 3ⁿ, rebirth követelmény $2T / $600T / $3Qa / $8Qa → Rebirth 1 ~40 perc, Rebirth 2 ~1:41 óra, Rebirth 5 ~6:10 óra, a leghosszabb várakozás 37 → 17 perc. *Még nincs beírva a Configba* (most: PriceSeconds 600 × 2ⁿ, követelmény $1T / $300T / $1.2Qa / $2.8Qa).
- A GDD 4.1 / 4.2 táblái még a régi számokat mutatják.

### Későbbre hagyva
- Merge animáció és minden szép VFX (10. fejezet), hangok és zene (11.).
- Robux: gamepassok, Robux gombok, Robux tojás / aura dobás, Claim x10, Rebirth Skip (6. fejezet).
- FTUE (7.), napi jutalmak / questek / ranglisták (8.).
- Index mentése, chef ritkaságok (chef gacha), Főchef auto-merge, telek-skinek és világok.
- Balance: a végjátéki várakozás befejezése (lásd fent: Félkész).

---

*Utolsó frissítés: 2026-11-13*
