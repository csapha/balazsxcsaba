# 🧊 Sell a Schnitzel – Voxel modell bibliával

> Ez a dokumentum az összes schnitzel típust, sütőt, pultot, futószalagot és kiegészítő propot tartalmazza **Blender-ben elkészíthető voxel modell leírásokkal**.
> Cél: egyszerű, kockás (voxel) stílus, de **kidolgozott**, vagyis minden modellnek legyen 2–3 olyan részlete, amiről első ránézésre felismerhető.
> Kapcsolódó dokumentum: [Sell_a_Schnitzel_Fejlesztesi_Terv.md](Sell_a_Schnitzel_Fejlesztesi_Terv.md)

---

## Tartalom

1. [Általános voxel szabályok](#1-általános-voxel-szabályok)
2. [Blender workflow lépésről lépésre](#2-blender-workflow-lépésről-lépésre)
3. [Közös színpaletta](#3-közös-színpaletta)
4. [A schnitzel "alapmodell" sablon](#4-a-schnitzel-alapmodell-sablon)
5. [Az összes schnitzel típus](#5-az-összes-schnitzel-típus)
6. [Ritkaság-változatok (palettacsere)](#6-ritkaság-változatok-palettacsere)
7. [Sütők (15 szint)](#7-sütők-15-szint)
8. [Pultok (eladóhely szintek)](#8-pultok-eladóhely-szintek)
9. [Futószalag és gyűjtőtálca](#9-futószalag-és-gyűjtőtálca)
10. [Egyéb propok](#10-egyéb-propok)
11. [Elnevezés, export, Roblox import checklist](#11-elnevezés-export-roblox-import-checklist)
12. [Gyártási sorrend (prioritás)](#12-gyártási-sorrend-prioritás)

---

## 1. Általános voxel szabályok

| Szabály | Érték |
|---|---|
| **Kis tárgyak (schnitzelek, köretek, tányér)** | 1 voxel = **0.0625 stud** (1/16) |
| **Nagy tárgyak (sütők, pult, szalag, gombok)** | 1 voxel = **0.125 stud** (1/8) |
| Arány | mindig pontosan 2:1 → a két sűrűség együtt is egységes stílust ad |
| Schnitzel tipikus méret | 28–36 voxel széles → ~2 stud |
| Sütő tipikus méret | 32×24×28 voxel → 4×3×3.5 stud |
| Árnyalás | **nincs smooth shading**, csak flat, minden voxel egy szín |
| Textúra | **1 db közös palettatextúra** (32×32 px), UV-k a pixelekre zsugorítva |
| Poligon cél | schnitzel < 1 500 tri, sütő < 5 000 tri, pult < 6 000 tri |
| Körvonal | nincs fekete outline geometria – a sötétebb "árnyék-voxelek" adják a kontúrt |

### A "kidolgozott voxel" 5 szabálya
1. **Dithering:** egy felület soha ne legyen egyszínű. A panír pl. 3–4 árnyalat véletlenszerűen keverve (60% / 25% / 10% / 5%).
2. **Peremárnyék:** a modell alsó rétege és szélei 1 árnyalattal sötétebbek → kontúr hatás outline nélkül.
3. **Csúcsfény:** a legfelső kiálló voxelek 1 árnyalattal világosabbak (fény felülről jön).
4. **Egyenetlen sziluett:** a schnitzel széle sosem egyenes – 1–2 voxeles bemélyedések, "hullámos" szél.
5. **Felismerési kulcs:** minden típusnál van 1 "hero detail" (pl. cordon bleu kettévágva, sonka + olvadó sajt), ami nagyobb és élénkebb színű, mint a többi részlet.

---

## 2. Blender workflow lépésről lépésre

### 2.1 Projekt beállítás (egyszer)
1. `Scene Properties → Units`: Unit System **None**, így 1 Blender egység = 1 voxel.
2. Viewport: `Overlays → Grid` Scale 1, Subdivisions 1.
3. Snap: `Snap to Increment`, **Absolute Grid Snap** bekapcsolva.
4. Készíts egy `VOXEL` nevű 1×1×1 kockát, ami alapelemként szolgál.
5. Készítsd el a **paletta textúrát**: 32×32 px PNG (`T_Palette_Schnitzel.png`), minden pixel egy szín a 3. fejezet táblázatából. Material: `M_Palette`, Image Texture → Closest interpoláció (**fontos, különben elmosódik!**).

### 2.2 Két módszer a modellezésre

**A) Kézi voxel (pontos, ajánlott a kis tárgyakhoz)**
1. Rajzold meg felülnézetben a sziluettet: `VOXEL` kockákat duplikálsz (`Shift+D`, snap), vagy:
2. Gyorsabb: készíts egy **Plane-t**, `Subdivide` a szükséges felbontásra, töröld a sziluetten kívüli face-eket, `Extrude` Z-ben a vastagságra.
3. Rétegenként (Z) extrudálj és törölj → domborulatok, töltelék, öntet.
4. Színezés: face select módban jelöld ki a face-eket, UV Editorban `UV → Snap → Selection to Cursor`, és tedd a kurzort a megfelelő paletta-pixelre.

**B) Remesh Blocks (gyors, organikusabb formákhoz: mártás, csont, gomba)**
1. Modellezz egy sima, alacsony poligonos formát (vagy sculpt).
2. `Add Modifier → Remesh → Mode: Blocks`, Octree Depth 5–6, Scale 0.9 → kockás lesz.
3. `Apply`, majd az eredményt színezd az A) módszer 4. pontja szerint.
4. Ügyelj, hogy a voxelméret egyezzen a többi modellel (a bounding box méretét előre állítsd be a voxel számra).

> Alternatíva: aki gyorsabban dolgozik **MagicaVoxel**-ben, ott modellezhet `.vox`-ba, OBJ exporttal áthozza Blenderbe, és csak a takarítás + palettatextúra-csere marad. A leírások mindkét eszközre érvényesek (rétegenkénti felépítés).

### 2.3 Takarítás és optimalizálás
1. `Mesh → Clean Up → Merge by Distance` (0.001).
2. **Belső face-ek törlése:** `Select → Select All by Trait → Interior Faces` → Delete.
3. Poligonszám csökkentés: `Limited Dissolve` **Delimit: UV** bekapcsolva (csak az azonos színű, egy síkban lévő face-eket olvasztja össze).
4. `Shade Flat`, Normals: `Recalculate Outside`.
5. Pivot: schnitzelnél a **talp közepén**, sütőnél a **talp közepén, elöl a középvonalon**.

### 2.4 Export
- FBX, `Apply Scalings: FBX Units Scale`, Forward: -Z, Up: Y, csak Selected Objects.
- Méretezés Robloxban: kis tárgy 0.0625, nagy tárgy 0.125 stud/voxel (lásd 11. fejezet).

---

## 3. Közös színpaletta

A kódokat (`P01`…) használják a modell leírások. Egy 32×32-es textúrában bőven elfér.

### Panír / sült húsok
| Kód | Név | Hex |
|---|---|---|
| P01 | Panír sötét (perem) | `#8A4E1A` |
| P02 | Panír alap | `#C27F2C` |
| P03 | Panír közép | `#D99A3D` |
| P04 | Panír világos | `#ECB85A` |
| P05 | Panír csúcsfény / morzsa | `#F7D584` |
| P06 | Panko világos (tonkatsu) | `#F0C978` |
| P07 | Tojásos bunda (párizsi) | `#F2C54A` |
| P08 | Tojásos bunda sötét | `#D9A12E` |

### Hús belső
| Kód | Név | Hex |
|---|---|---|
| H01 | Sertés hús | `#F0D3C2` |
| H02 | Sertés hús árnyék | `#D9B3A0` |
| H03 | Csirke hús | `#F6E6CF` |
| H04 | Borjú hús | `#E8C3AE` |
| H05 | Sonka rózsaszín | `#F29BA3` |
| H06 | Sonka sötét szél | `#D96F7C` |
| H07 | Csont | `#F4EEDC` |
| H08 | Csont árnyék | `#D6CBAE` |

### Sajt, tojás, zsír
| Kód | Név | Hex |
|---|---|---|
| S01 | Olvadt sajt | `#FFD84A` |
| S02 | Sajt árnyék | `#F0B92A` |
| S03 | Mozzarella | `#FFF4D6` |
| S04 | Mozzarella pirult folt | `#E8B060` |
| S05 | Tojásfehérje | `#FFFFFF` |
| S06 | Tojássárgája | `#FFB21A` |
| S07 | Fokhagymás vaj (kijevi) | `#E5E89A` |
| S08 | Fűszeres vaj zöld pötty | `#6FA83A` |
| S09 | Camembert héj | `#F4F1E8` |

### Mártások, zöldségek
| Kód | Név | Hex |
|---|---|---|
| M01 | Paradicsomszósz | `#D93A2B` |
| M02 | Paradicsomszósz sötét | `#A82418` |
| M03 | Gombamártás | `#A87A52` |
| M04 | Gomba szelet | `#D9C2A0` |
| M05 | Gomba szelet sötét | `#8A6A4A` |
| M06 | Tejszínes mártás | `#F2E6C8` |
| M07 | Paprikamártás | `#E8562A` |
| M08 | Zöldpaprika | `#5AB33A` |
| M09 | Pirospaprika csík | `#E8322A` |
| M10 | Tonkatsu szósz | `#5A2A12` |
| M11 | Curry | `#C8861E` |
| M12 | Ananász | `#FFD23F` |
| M13 | Ananász sötét | `#E0A82A` |
| M14 | Káposzta | `#D8EFA8` |
| M15 | Káposzta sötét | `#9FCC6A` |
| M16 | Citrom héj | `#FFE14D` |
| M17 | Citrom hús | `#FFF3A0` |
| M18 | Petrezselyem | `#3E9A2E` |
| M19 | Petrezselyem világos | `#6CC24A` |
| M20 | Kapribogyó | `#6B7A2A` |
| M21 | Szardella | `#8C6A5A` |
| M22 | Krumplisaláta / burgonya | `#F2DC8A` |
| M23 | Karfiol | `#F4EFD9` |
| M24 | Áfonya lekvár | `#9A1E3A` |
| M25 | Rizs | `#FAFAF2` |

### Kenyér, tányér, prop anyagok
| Kód | Név | Hex |
|---|---|---|
| K01 | Zsemle héj | `#C9822F` |
| K02 | Zsemle héj sötét | `#9C5E1E` |
| K03 | Zsemle bél | `#F6E3B8` |
| T01 | Tányér fehér | `#F7F7F2` |
| T02 | Tányér árnyék | `#D8DCE0` |
| T03 | Tányér kék perem | `#3A6FD9` |
| F01–F04 | Fa (sötét→világos) | `#5A3418` `#7A4A22` `#9C6634` `#BE8550` |
| A01–A04 | Acél (sötét→világos) | `#4A5058` `#727A84` `#A2AAB4` `#D4DAE0` |
| R01–R03 | Rozsda | `#7A3A1A` `#A8572A` `#C9783E` |
| G01–G02 | Üveg (sötét, csillanás) | `#2A3A4A` `#8FD0FF` |
| E01 | Izzó narancs (sütő belső fény, neon) | `#FF8A1E` |
| E02 | Láng kék | `#3AA8FF` |
| X01–X03 | Arany | `#B8861A` `#F2C230` `#FFE98A` |
| X04–X06 | Gyémánt | `#3AA8D9` `#7FE0FF` `#E0FAFF` |
| X07–X09 | Ezüst | `#8A939C` `#C9D3DD` `#F2F6FA` |
| N01–N06 | Szivárvány (Nagyi) | `#FF4A5A` `#FF9A2A` `#FFE04A` `#5AD94A` `#4AA8FF` `#B45AFF` |
| W01 | Fehér | `#FFFFFF` |
| B01 | Fekete (szem, gomb) | `#1E1E24` |

---

## 4. A schnitzel "alapmodell" sablon

Minden panírozott schnitzel ebből indul, ezért **ezt kell először tökéletesre csinálni**.

**Méret:** 32 × 22 × 3 voxel (szélesség × mélység × magasság) → ~2 × 1.4 stud.

**Sziluett (felülnézet):** szabálytalan, "lapított tojás / falevél" alak, a jobb felső része kicsit szélesebb.
- A széleken 3–5 helyen 1–2 voxeles **bemélyedés** (hullámos szél).
- Két szemközti oldalon 1–1 kis **"fül"** (2×2 voxeles kiugrás) – ettől néz ki kiklopfolt húsnak.

**Rétegek (alulról):**
| Z | Tartalom |
|---|---|
| 0 | teljes sziluett, 1 voxellel kisebb a peremnél → **P01** (sötét alj) |
| 1 | teljes sziluett. Perem: **P01/P02** keverve, belső: **P02** (oldalról ez látszik) |
| 2 | sziluett 1 voxellel beljebb húzva (lekerekített él). Felület dithering: 55% **P03**, 25% **P02**, 15% **P04**, 5% **P05** |
| 3 (díszítés) | 12–18 db **egy voxeles morzsa-dudor** szórva a tetején (**P04/P05**), és 2–3 db 2×1-es "buborék" (**P05**) – ez adja a ropogós hatást |

**Hero detail lehetőségek:**
- "Harapás" – egy sarokból kerek kivágás, ahol a hús látszik (**H01** belül, **H02** peremen). Kirakati / Index ikonhoz használd.
- "Kettévágva" – a modell fele, a vágott felületen 1 voxel panír keret + belül hús.

**Tipp:** az alapsablont készítsd el **3 sziluett-variánsban** (A: levél, B: ovális, C: szív alakú), hogy a futószalagon ne legyen minden darab egyforma.

---

## 5. Az összes schnitzel típus

### 5.1 Típuslista és játékbeli szerep

| # | Típus | Eredet | Játék szerep | Prioritás |
|---|---|---|---|---|
| 1 | Sertés rántott hús | HU/AT | Lv1 sütő | MVP |
| 2 | Rántott csirkemell | HU | Lv2 sütő | MVP |
| 3 | Párizsi szelet | HU | Lv3 sütő | MVP |
| 4 | Bécsi szelet (borjú, citrommal) | AT | Lv4 sütő | MVP |
| 5 | Cordon Bleu | FR/CH | Lv5 sütő | MVP |
| 6 | Rántott sajt (trappista) | HU | Lv6 sütő | MVP |
| 7 | Holstein szelet | DE | Lv7 sütő | MVP |
| 8 | Vadász schnitzel (gombamártás) | DE | Lv8 sütő | MVP |
| 9 | Paprikás schnitzel | DE/HU | Lv9 sütő | MVP |
| 10 | Milánói borda (csontos) | IT | Lv10 sütő | MVP |
| 11 | Hawaii schnitzel | DE | Lv11 sütő | Alpha |
| 12 | Parmigiana | IT/US | Lv12 sütő | Alpha |
| 13 | Tonkatsu | JP | Lv13 sütő | Alpha |
| 14 | Óriás tányérlelógó rántott hús | HU | Lv14 sütő | Alpha |
| 15 | Schnitzel Torony ("A Végső") | fantasy | Lv15 sütő | Alpha |
| 16 | Kijevi csirke | UA | event / világ 2 | Live |
| 17 | Zágrábi szelet | HR | event / világ 2 | Live |
| 18 | Tejszínes schnitzel (Rahmschnitzel) | AT/DE | event | Live |
| 19 | Milanesa a la Napolitana | AR | világ 3 | Live |
| 20 | Katsu curry | JP | világ 3 | Live |
| 21 | Schnitzelsemmel (zsemlében) | AT | pult bónusz termék | Live |
| 22 | Rántott camembert áfonyával | CZ/HU | event | Live |
| 23 | Rántott karfiol | HU | vega event | Live |
| 24 | Rántott gomba | HU | vega event | Live |
| 25 | Kukoricapelyhes csirke | HU | event | Live |
| 26 | Sörbundás schnitzel | DE/HU | event (Oktoberfest) | Live |
| 27 | Natúr szelet (panír nélkül) | – | vicces "hiba" termék / küldetés | Live |
| 28 | Rántott ponty | HU | karácsonyi event | Live |
| 29 | Rántott tofu | – | vega event | Live |

> A ritkaságok (Ezüst / Arany / Gyémánt / Nagyi Titkos Receptje) **nem külön modellek**, hanem palettacserék minden típusra (6. fejezet).

### 5.2 Részletes modell leírások

Formátum minden típusnál: **Méret · Alap · Felépítés · Hero detail · Paletta**.

---

#### 1. Sertés rántott hús (Lv1)
- **Méret:** 32×22×3 (+1 morzsa réteg)
- **Alap:** alapsablon A (levél) sziluett.
- **Felépítés:** pontosan az alapsablon, kicsit sötétebb panír (több P02, kevesebb P04) → "egyszerű, házi".
- **Hero detail:** jobb alsó sarokban **harapásnyi kivágás** (r=4 voxel félkör), ott látszik a rózsaszínes-fehér hús (H01, peremen H02), és 1 voxeles panírkeret körülötte.
- **Paletta:** P01–P05, H01, H02.

#### 2. Rántott csirkemell (Lv2)
- **Méret:** 30×18×4 – vastagabb, keskenyebb.
- **Alap:** **könnycsepp** sziluett (a csirkemell formája: egyik vége lekerekített, másik elvékonyodó).
- **Felépítés:** 4 rétegű: a közepén 1 réteggel magasabb "domb" (Z3 a közepén 14×8 területen) → kidomborodó mell.
- **Hero detail:** a vastag végén **ferde vágás**, a vágott lapon nagyon világos csirkehús (H03) 1 voxeles P02 kerettel.
- **Paletta:** P02–P05 (világosabb panír, több P04), H03.

#### 3. Párizsi szelet (Lv3)
- **Méret:** 32×22×3.
- **Alap:** alapsablon B (ovális).
- **Felépítés:** **nincs morzsa!** A felület sima, sárga tojásos bunda: 70% P07, 20% P08, 10% S06.
- **Hero detail:** a tetején 3–4 db **szabálytalan "tojásfolt" sziget** (2–4 voxeles, S06 sötétebb sárga), és a peremen 2–3 helyen **lelógó tojáscsepp** (1 voxeles kiugrás lefelé, Z0 alá ne menjen). A sárga szín miatt rögtön elkülönül a többitől.
- **Paletta:** P07, P08, S06, H01.

#### 4. Bécsi szelet (Lv4)
- **Méret:** 36×24×3 – nagyobb és vékonyabb ("tányérnyi").
- **Alap:** alapsablon A, de **erősen hullámos szél** (8–10 bemélyedés) és sok "buborék" (a bécsi szelet panírja hullámosan elválik a hústól).
- **Felépítés:** Z3 rétegen 6–8 db **2×3-as hosszúkás buborék** (P04 teteje, P05 csúcsfény) → ez a bécsi szelet ismertetőjegye.
- **Hero detail:** **citromkarika** a tetején: 8×8 voxeles kör, 1 vastag. Külső gyűrű M16, belül M17, 6 db "cikk" vonal (M16 sugárirányban). Mellette **petrezselyem-csokor**: 4–5 voxeles M18/M19 szabálytalan folt.
- **Paletta:** P01–P05, M16, M17, M18, M19.

#### 5. Cordon Bleu (Lv5)
- **Méret:** 28×20×6 – vastag, "töltött tasak".
- **Alap:** ovális sziluett, a teteje **domború** (Z3–Z5 fokozatosan kisebb ovális rétegek, mint egy párna).
- **Felépítés:** **kettévágott** modell! A darab "eleje" egy egyenes vágott felület (X tengely mentén).
  - Vágott felület rétegei alulról: 1 voxel P02 (alsó panír) → 1 voxel H01 (hús) → **1 voxel H05 sonka** (szélén H06) → **2 voxel S01 sajt** → 1 voxel H01 → 1 voxel P02 (felső panír).
- **Hero detail:** a sajt **kifolyik** a vágott felületből: 3 db sajtcsepp (S01, alján S02) 1–3 voxel hosszan lelóg a vágott élről, egy pedig kis tócsát alkot a schnitzel előtt (5×3 voxel, 1 vastag). **Ez a legfontosabb felismerési jel – legyen nagy és élénk!**
- **Paletta:** P01–P05, H01, H05, H06, S01, S02.

#### 6. Rántott sajt (Lv6)
- **Méret:** 24×16×6 – **téglatest** forma (sajt szelet!).
- **Alap:** lekerekített sarkú téglatest (a sarkokról 1 voxel lecsípve).
- **Felépítés:** panír minden oldalon, a teteje dithering (P03/P04/P05).
- **Hero detail:** az egyik sarka **letörve / kiharapva**, ahonnan **hosszú sajt-szál** nyúlik ki: 1×1 voxeles S01 lánc, 6–8 voxel hosszan, kicsit lefelé hajolva, a végén 2×2 csepp. Mellette kis **tartármártás pötty** (3×3, W01/S03 keverve).
- **Paletta:** P01–P05, S01, S02, W01, S03.

#### 7. Holstein szelet (Lv7)
- **Méret:** 32×22×3 alap + feltétek (össz. magasság 6).
- **Alap:** bécsi szelet alap (4. modell) citrom nélkül.
- **Felépítés:**
  - **Tükörtojás** a közepén: fehérje 12×10 szabálytalan "felhő" alak (S05, peremen T02 árnyék), 1 vastag; a sárgája 4×4 kupola (2 réteg: 4×4, majd 2×2), S06, egy csúcsfény voxellel (W01).
  - **2 db szardella** keresztben a tojáson: 1×8-as csíkok (M21), X alakban.
  - **4–5 kapribogyó**: 1×1×1 M20 voxelek a tojás körül.
- **Hero detail:** a tükörtojás – legyen nagy, ez a sziluettből is látszik.
- **Paletta:** P01–P05, S05, S06, M20, M21, T02.

#### 8. Vadász schnitzel (Lv8)
- **Méret:** 32×22×5.
- **Alap:** alapsablon B.
- **Felépítés:** a schnitzel 60%-át **barna gombamártás** borítja (M03), szabálytalan folt, ami a jobb oldalon **lefolyik a peremen** (2 helyen 2 voxeles csepp).
- **Hero detail:** 5–6 db **gombaszelet** a mártásban: mindegyik "esernyő" alakú szelet oldalnézetből (M04 belső, M05 körvonal), 4×3 voxeles, állítva vagy fektetve, kicsit kilógva a mártásból. Egy kis petrezselyem szórás (M18 1-es voxelek).
- **Paletta:** P01–P05, M03, M04, M05, M18.

#### 9. Paprikás schnitzel (Lv9)
- **Méret:** 32×22×5.
- **Alap:** alapsablon C (szív) sziluett.
- **Felépítés:** narancsvörös **paprikamártás** (M07, árnyék M02) a schnitzel közepén.
- **Hero detail:** **paprikacsíkok**: 6–8 db hosszúkás (1×5, 1×6) csík felváltva zöld (M08) és piros (M09), ferdén szétszórva, néhány hajlítva ("C" alak). Egy **egész kis zöldpaprika** a szélén (4×4×5, M08, tetején 1×1×2 szár F02) – ettől azonnal "paprikás".
- **Paletta:** P01–P05, M07, M02, M08, M09, F02.

#### 10. Milánói borda (Lv10)
- **Méret:** 34×22×3 + csont.
- **Alap:** **csepp alakú** sziluett, a keskeny végén kilógó csonttal.
- **Felépítés:** a panír aranyabb, vajban sült (több P04, P05).
- **Hero detail:** **csont**: a keskeny végből 8 voxel hosszan kilóg, 2×2 keresztmetszet, a végén 3×3-as "bütyök" (H07, árnyék H08). Ez a "rajzfilm hús" ikonikus jele. Mellette fél citrom (8×4×4 félkör, M16/M17).
- **Paletta:** P02–P05, H07, H08, M16, M17.

#### 11. Hawaii schnitzel (Lv11)
- **Méret:** 32×22×6.
- **Alap:** alapsablon B.
- **Felépítés (alulról):** schnitzel → 1 réteg sonka (24×16, H05, széle H06, kicsit kilóg az egyik oldalon) → **ananászkarika** (10×10 gyűrű, közepén 4×4 lyuk, M12, belső perem M13, sugárirányú M13 vonalak) → **olvadt sajt** lepel a tetején (S01), a széleken 4 helyen lecsurogva.
- **Hero detail:** az ananászkarika lyukában egy **piros koktélcseresznye** (3×3×3, M01 + W01 csillanás). Az ananász + cseresznye kombó egyértelmű.
- **Paletta:** P01–P05, H05, H06, M12, M13, S01, S02, M01.

#### 12. Parmigiana (Lv12)
- **Méret:** 32×22×5.
- **Alap:** alapsablon B.
- **Felépítés:** paradicsomszósz réteg (M01, peremen M02) a schnitzel 80%-án, majd **mozzarella foltok**: 4–5 db szabálytalan 5×5–7×7 folt (S03), pirult barna pöttyökkel (S04).
- **Hero detail:** 3 db **bazsalikomlevél** a tetején (3×4 voxeles csepp forma, M18, középen M19 ér). Piros-fehér-zöld = olasz → azonnal felismerhető.
- **Paletta:** P01–P05, M01, M02, S03, S04, M18, M19.

#### 13. Tonkatsu (Lv13)
- **Méret:** 36×20×4 (+ köret).
- **Alap:** hosszúkás téglalap, lekerekített végekkel.
- **Felépítés:** **5 csíkra szeletelve**! Minden csík 6 voxel széles, köztük **1 voxeles rés**, a szeletek kicsit ferdén eltolva (mint a tányéron). A szeletek tetején **panko**: világosabb, durvább (P06, P05, sok 1-es morzsa-dudor, 25% fedés).
- **Hero detail:** a szeletek vágott oldalán látszik a hús (H01, 1 voxel P06 keret). Mögötte **vágott káposzta-halom** (14×8×5 kupac M14/M15 dithering, szálas felület), a szeleteken átlósan **barna tonkatsu szósz** csík (M10, 1 voxel széles zigzag).
- **Paletta:** P06, P05, P04, H01, M14, M15, M10.

#### 14. Óriás tányérlelógó rántott hús (Lv14)
- **Méret:** tányér 36×36×2, a hús 48×38×3 – **szélesebb, mint a tányér**.
- **Alap:** kerek tányér (T01, peremen T03 kék csík, alul T02), rajta a schnitzel, ami **minden irányban lelóg** és a peremén lefelé hajlik (a lelógó részek 1 réteggel lejjebb).
- **Felépítés:** extra hullámos szél, sok buborék, 2 citromszelet.
- **Hero detail:** a lelógás. Egy **kis krumplisaláta kupac** (M22, M18 pötty) "beszorítva" a tányér szélén, alig fér el → humor.
- **Paletta:** P01–P05, T01–T03, M16, M17, M22, M18.

#### 15. Schnitzel Torony – "A Végső" (Lv15)
- **Méret:** 26×20×24 – magas!
- **Alap:** 5 különböző schnitzel egymásra rakva (kicsinyített változatok: rántott hús, cordon bleu, párizsi, rántott sajt, bécsi), mindegyik kicsit elforgatva.
- **Felépítés:** a rétegek között sajt (S01) csepeg le, a tetején citromkarika és egy **kis arany korona** (6×6×4, X01–X03).
- **Hero detail:** a torony tetején átszúrva egy **nyárs / zászló** (1×1×8 F03 + 4×3 zászló piros-fehér). A rétegek színei (sárga párizsi, vágott cordon bleu) messziről is "mindent bele" hatást adnak.
- **Paletta:** minden panír + S01, H05, P07, X01–X03, W01, M01.

---

#### 16. Kijevi csirke
- **Méret:** 26×14×10 – **hengeres / tojásdad tekercs**.
- **Alap:** Remesh Blocks módszer: elnyújtott tojás forma, Octree depth úgy, hogy 10 voxel magas legyen.
- **Hero detail:** **kettévágva**, a vágott lapon: külső 1 voxel panír, 2 voxel csirke (H03), a közepén 4×4 **zöldfűszeres vaj mag** (S07 alap, S08 pöttyök), ami **kifolyik** egy 4×6-os tócsába elöl. Zöld vaj = Kijevi.
- **Paletta:** P02–P05, H03, S07, S08.

#### 17. Zágrábi szelet
- **Méret:** 30×16×7.
- **Alap:** **feltekert** schnitzel (tekercs), mint egy rúd.
- **Hero detail:** a vágott végén **spirál** látszik: panír → hús → sonka → sajt → hús csigavonalban (rétegenként felváltva H04, H05, S01). Különbség a cordon bleu-tól: kerek keresztmetszet + spirál.
- **Paletta:** P01–P05, H04, H05, S01.

#### 18. Tejszínes schnitzel
- **Méret:** 32×22×5.
- **Felépítés:** **natúr (nem panírozott)** sült hús: barnásabb, sima (H04 + P01 "sült" csíkok rácsmintában – grillnyom), és **krémfehér mártás** (M06) bőven ráöntve, lefolyik.
- **Hero detail:** a mártásban 3–4 kis **gombafej** (M04) és **zöldbors / petrezselyem** pöttyök, plusz egy **mártásos merőkanál** a tányér szélén (opcionális).
- **Paletta:** H04, P01, M06, M04, M18.

#### 19. Milanesa a la Napolitana
- **Méret:** 34×24×5.
- **Felépítés:** schnitzel → paradicsomszósz → **sonka csík** (H05) → mozzarella teljes lepel (S03), sok pirult folt (S04) → **zöld olajbogyó** 2–3 db (3×3×3, M20).
- **Hero detail:** egy **sült krumpli halom** mellette (8–10 db 1×1×5 rudacska, M22, végükön P04) – argentin stílus.
- **Paletta:** P01–P05, M01, H05, S03, S04, M20, M22.

#### 20. Katsu curry
- **Méret:** tányér 38×26×2 + rizs + katsu.
- **Felépítés:** ovális mélytányér (T01) bal fele **rizs kupola** (14×12×6, M25, T02 árnyék), jobb fele **curry** (M11, sötétebb M03 pöttyök, sárgarépa kockák 2×2 E01 színben), a kettő határán **szeletelt katsu** (tonkatsu 4 szelet kisebben).
- **Hero detail:** rizs fehér + curry sárga-barna + katsu csíkok → egyértelmű.
- **Paletta:** T01, T02, M25, M11, M03, E01, P06, H01.

#### 21. Schnitzelsemmel
- **Méret:** 26×26×14.
- **Felépítés:** **császárzsemle**: alsó fél (K01 héj, K03 bél a vágásnál) → saláta levél (M15/M19 hullámos perem, kilóg) → schnitzel (kétoldalt jócskán kilóg!) → felső fél: kupola, tetején a **császárzsemle 5 ágú csillag-bevágás** (K02 sötét vonalak a kupolán).
- **Hero detail:** a zsemlénél jóval szélesebb kilógó schnitzel + csillagminta a tetején.
- **Paletta:** K01–K03, M15, M19, P01–P05.

#### 22. Rántott camembert áfonyával
- **Méret:** 20×20×6 – **kerek korong** vagy **háromszög cikk** (válassz: a cikk felismerhetőbb).
- **Felépítés:** sajt cikk forma, panírral.
- **Hero detail:** a hegyes vége levágva, ott fehér héj (S09) + krémes belső (S03) kifolyik; mellette **áfonyalekvár pötty** (6×6×2, M24, csillanás W01).
- **Paletta:** P02–P05, S09, S03, M24.

#### 23. Rántott karfiol
- **Méret:** 14×14×12 egy darab, a modell 3 darabból álló kupac.
- **Felépítés:** Remesh Blocks: "fa" alakú rózsák – vastag szár (M23) és bárányfelhő-szerű fej, panírral fedve (P03/P04, 30%-ban átlátszik a M23 fehér).
- **Hero detail:** a "fa" sziluett (szár + fodros fej).
- **Paletta:** M23, P02–P04.

#### 24. Rántott gomba
- **Méret:** egy gomba 10×10×9, a modell 4–5 db egy kis tálkában.
- **Felépítés:** kalap (kupola, panír) + rövid vaskos tönk (panír), az egyik **kettévágva** (M04 belső, M05 körvonal, ahogy a gomba metszete kinéz).
- **Hero detail:** a vágott gomba "kalap+tönk" metszete + tartármártás pötty.
- **Paletta:** P02–P05, M04, M05, W01.

#### 25. Kukoricapelyhes csirke
- **Méret:** 30×18×4.
- **Felépítés:** csirkemell forma (2. modell), de a felület **nagy, lapos pelyhek**: 2×2 és 3×2-es, 1 voxellel kiemelt, kicsit megdöntött lapok (P04, P05, szélük P02) egymásra halmozva, mint pikkely.
- **Hero detail:** a pelyhes "pikkelyes" textúra – durvább, mint bármelyik másik panír.
- **Paletta:** P02, P04, P05, H03.

#### 26. Sörbundás schnitzel
- **Méret:** 30×20×5.
- **Felépítés:** a bunda **puffadt, buborékos**: a tetején 8–10 db 3×3×2-es kidudorodás (P04, P05), a peremen "fodros" lecsorgások. Színe világosabb arany.
- **Hero detail:** mellette egy **mini söröskorsó** (6×6×9, G02 üveg, M12 sör, W01 hab a tetején kifolyva) → Oktoberfest event.
- **Paletta:** P02–P05, G02, M12, W01.

#### 27. Natúr szelet (vicces "elrontott")
- **Méret:** 32×22×2.
- **Felépítés:** **panír nélküli**, szürkés-rózsaszín hús (H01/H02), rajta grillcsíkok (P01).
- **Hero detail:** a tetején egy kis **izzadságcsepp / szomorú arc** (2 B01 pont + ív) → "elfelejtetted bepanírozni" humor (küldetés / easter egg).
- **Paletta:** H01, H02, P01, B01.

#### 28. Rántott ponty (karácsony)
- **Méret:** 30×16×4.
- **Felépítés:** **halfilé** sziluett (egyik vége ferdén levágva, a másik farokszerűen elkeskenyedő), panírral.
- **Hero detail:** a vágott végén fehér halhús (W01/T01) **réteges ívekkel** (T02 vonalak), mellette citrom + kis fenyőág (M18) és piros szalag (M01).
- **Paletta:** P02–P05, W01, T01, T02, M16, M18, M01.

#### 29. Rántott tofu
- **Méret:** 16×16×6, 3 kocka egy tányérkán.
- **Felépítés:** tökéletes kockák panírral, az egyik félbevágva: belül S03 krémfehér, szivacsos (pár T02 lyukacska).
- **Hero detail:** szabályos kocka forma + szezámmag pöttyök (W01) + szójaszósz tálka (M10).
- **Paletta:** P02–P05, S03, T02, W01, M10.

---

## 6. Ritkaság-változatok (palettacsere)

**Nem kell új modell!** Ugyanaz a mesh, másik palettatextúra (`T_Palette_Silver.png` stb.), ahol a panír- és hússzíneket átfested. Robloxban: `MeshPart.TextureID` csere + effektek.

| Ritkaság | Panír P01–P05 cseréje | Extra | Roblox effekt |
|---|---|---|---|
| **Ezüst** | X07, X07, X08, X09, W01 | húsrészek maradnak | `Material = Metal` hatás, 2–3 Sparkle partikula, halvány fehér `PointLight` |
| **Arany** | X01, X01, X02, X02, X03 | sajt/mártás is aranyabb | arany csillag partikula, sárga `PointLight`, lassú forgás a szalagon |
| **Gyémánt** | X04, X04, X05, X05, X06 | | `Transparency 0.15` a felső réteg, kék fénycsóva (Beam felfelé), kristály csilingelés |
| **Nagyi Titkos Receptje** | szivárvány: az átló mentén N01→N06 sávok | gőzfelhő szív alakú voxel partikula | pulzáló színátmenet (`TextureID` animáció helyett `Highlight` színezés script), szív partikulák, szerver announce |

**Plusz modellelem csak a Nagyi változathoz (opcionális):** egy apró **nagyi fejkendő / szív felhő** voxel prop (6×6×4), ami a schnitzel felett lebeg.

---

## 7. Sütők (15 szint)

### 7.1 Közös sütő sablon

**Méret:** 32 × 24 × 28 voxel (Sz×M×Ma), nagy sűrűség (0.125 stud) → 4 × 3 × 3.5 stud.
A sütősor slotjai 4.5 stud szélesek, a sütők elférnek köztük.

**Kötelező elemek (minden sütőn ugyanott, hogy a játékos megtanulja olvasni):**
1. **Talp / lábak** (Z0–Z2): 4 db 3×3 láb vagy teljes talapzat.
2. **Test** (Z2–Z24): doboz, 1 voxeles **sötétebb élekkel** (kontúr).
3. **Ajtó / ablak** elöl (Y=0 lap): 18×12 voxeles ablak, **G01 üveg**, belül E01 **izzó narancs fény** (a belső hátfal E01 + P04 voxelek), és benne egy kis schnitzel sziluett (6×4).
4. **Kezelőpanel** jobb oldalt vagy felül: 2–3 tekerőgomb (2×2×1, B01/A03), kis kijelző.
5. **Kiömlő nyílás** elöl alul, ahonnan a schnitzel a szalagra "kiugrik" (6×2 rés, sötét belső).
6. **Szint-jelölő hely**: a tetején 8×4-es lapos felület a BillboardGui alá (ne legyen ott díszítés).

**Animációhoz külön mesh-ként exportáld:** az ajtót (nyílik kiadáskor), a tekerőgombokat (forognak), a fritőz kosarakat (fel-le mozognak).

### 7.2 Szintenkénti leírás

| Lv | Név | Méret | Felépítés és hero detail | Paletta |
|---|---|---|---|---|
| 1 | **Rozsdás Lábas** | 24×24×18 (kisebb!) | Nem doboz: egy **horpadt lábas** egy egyszerű **gázrózsán** (4 lábú fémváz + kék láng E02 alatta). A lábas oldalán 3–4 rozsdafolt (R01–R03), egy **horpadás** (2×3 voxel befelé), a nyele 1×8 kilógó fa (F02). A lábasban olaj (P04) + félig kilógó schnitzel. | A01–A03, R01–R03, F02, E02, P04 |
| 2 | **Kempingfőző** | 26×22×20 | Zöld (M08 árnyalatai) kis bőröndszerű doboz kinyitott fedéllel (szélfogó), mellette **kék gázpalack** (6×6×10, E02/A02 kupak). Rajta serpenyő. | M08, M18, A02, E02, B01 |
| 3 | **Téglasütő** | 32×24×28 | **Téglafal minta**: 4×2-es téglák (M02/R02/R03 felváltva), köztük 1 voxeles habarcs (T02). Elöl **íves sütőnyílás** (boltív, lépcsőzetes voxel ív), benne izzó parázs (E01, M01). A tetején kis **kémény** (4×4×6) füsttel. | R02, R03, M02, T02, E01 |
| 4 | **Acél Serpenyő / Acélsütő** | 32×24×28 | Rozsdamentes doboz (A02–A04, szálcsiszolt csíkok A03/A04 felváltva vízszintesen), **nagy ablak**, fekete fogantyú elöl (1×14 B01), digitális kijelző (B01 háttér, M08 "88:88" pixelszámok). | A01–A04, B01, M08, G01 |
| 5 | **Nagyi Tűzhelye** | 32×24×30 | **Retro zománcos** tűzhely: krémszínű (T01/S03) test, **lekerekített sarkok**, piros (M01) szegélycsík, felül 4 főzőlap (fekete karikák), **virágmintás** kerámia csempe a hátfalon (3 kis piros-zöld virág). Rajta egy **kockás konyharuha** (piros-fehér 2×2 kocka) lóg a fogantyún. | T01, S03, M01, M18, B01 |
| 6 | **Olajsütő** | 30×24×28 | **Sárga fritőz** (S01/S02): nyitott tetejű olajkád, benne P04 olaj **buborékokkal** (W01/P05 1-es voxelek kiemelve), **2 fémkosár nyéllel** kilógva a tetején (A03 rács, B01 nyél). | S01, S02, A03, B01, P04, P05 |
| 7 | **Ipari Fritőz** | 36×26×32 (nagyobb) | Hosszú acél egység (A01–A04) **4 kosárral**, felette **elszívó ernyő** (csonkagúla, A02, 2 oszlopon), nyomásmérő óra (4×4 kör, W01 számlap, M01 mutató), sárga-fekete **figyelmeztető csík** a lábazaton. | A01–A04, S01, B01, M01 |
| 8 | **Réz Serpenyő / Rézsütő** | 32×24×30 | Réz test (R03 + `#E89A5A` + `#F6C08A` csillanás), **szegecsek** (1-es kiemelt voxelek szabályos rácsban), elöl rézből **kör alakú hajóablak**, oldalt **csövek** (2×2, kanyargós), egy gőzszelep fütyülővel a tetején. Steampunk. | réz árnyalatok, G01, A02 |
| 9 | **Arany Fritőz** | 32×24×30 | Olajsütő (Lv6) formája, de **aranyból** (X01–X03), a kosárnyelek fekete-arany, a tetején **kis korona** dísz, oldalán dombornyomott schnitzel-címer. Csillanás voxelek (X03/W01) az éleken. | X01–X03, B01, P04 |
| 10 | **Gyémánt Fritőz** | 32×24×32 | **Kristály** test: a sarkokon nagy, csiszolt **gyémánt facetták** (lépcsős átlós lapok X04–X06), átlátszó üvegszerű oldalfalak (Robloxban Transparency 0.2 külön mesh), belül **kék láng** (E02). Tetején egy lebegő 4×4×6 gyémánt. | X04–X06, E02, W01 |
| 11 | **Vulkán Fritőz** | 34×26×34 | Sziklás, **sötét bazalt** test (B01, `#3A2A2A`, `#5A3A30`), a repedésekben **izzó láva** (E01, M01, S06) erek, a tetején kráter, amiből **láva-olaj** buborékol. Alul lávatócsa. | B01, sötét kő, E01, M01, S06 |
| 12 | **Jégsárkány Sütő** | 34×26×34 | Jégtömb test (X05/X06/W01, áttetsző), elöl a sütőnyílás egy **sárkányfej szája** (fogak W01, szem M24 izzó), belül **lila tűz** (N06, `#E08AFF`). Tetején jégcsapok, oldalt 2 kis szárny. | X05, X06, W01, N06, M24 |
| 13 | **Űr-Fritőz** | 34×34×28 | **UFO / repülő csészealj** forma: lapos kör (lépcsőzetes voxel korong), felül üvegkupola (G02) benne egy kis schnitzel "pilóta", a perem mentén **neon lámpák** (N04, N05, E02 felváltva), alatta 3 lábas leszállóláb + kék traktorsugár (Beam effekt). | A02–A04, G02, N04, N05, E02 |
| 14 | **Kvantum Klopfoló** | 32×24×36 | Futurisztikus fekete-lila doboz (B01, N06), a tetején egy **lebegő, forgó óriás klopfoló** (külön mesh), a test oldalán **glitch-csíkok** (eltolt voxel sávok, N05/N01), elöl kör alakú portál (N06 → W01 gyűrűk). | B01, N06, N05, N01, W01 |
| 15 | **A Végső Schnitzelgép** | 40×30×40 (legnagyobb) | Monumentális gép: arany talapzat (X01–X03), **szivárványos** (N01–N06 vízszintes sávok) fő test, elöl hatalmas ablak egy forgó schnitzel-tornyot mutatva, a tetején **nagyi-szobor** (egyszerű voxel figura fejkendővel és fakanállal, 10×8×12), két oldalt kémények szív alakú gőzzel. | X01–X03, N01–N06, W01, M01 |

**Merge szint-változat tipp:** minden sütő szinthez 2 állapotot exportálj: `Idle` és `Active` (ajtó nyitva, láng nagyobb) → a sütő "lélegzik".

---

## 8. Pultok (eladóhely szintek)

A pult a GDD szerint XP-vel szintet lép. 5 vizuális stádium (pl. Lv1–9, 10–24, 25–49, 50–99, 100+).

**Közös méret:** 48 × 32 × 40 voxel (0.125 stud) → 6 × 4 × 5 stud. Az eladóablak elöl, a vendégsor felé néz; hátul a pult, ahova a játékos/chef leteszi a schnitzelt (**lerakó zóna**: 16×8 voxeles világosabb lap, jól láthatóan jelölve).

| Stádium | Név | Leírás |
|---|---|---|
| 1 | **Fa Standolás** | Egyszerű piaci stand: 4 fa oszlop (F02), fapult (F03/F04 deszkacsíkok, 1 voxel rés köztük), **piros-fehér csíkos ponyva** (2 voxeles csíkok, M01/W01) lejtősen, elöl kézzel írt tábla ("SCHNITZEL" – fehér pixelbetűk F01 táblán), a pulton egy tálca és egy **régi pénztárgép** (6×5×5, A02, B01 gombok). |
| 2 | **Büfékocsi / Büfé ablak** | Doboz alakú kioszk: világos rózsaszín-fehér (T01 + `#F6C8D0`) falak, nagy elülső **ablak** keret (A03), felhajtott fedél ernyőként, az ablakpárkányon **ketchup és mustár flakon** (3×3×6, M01 és S01, fehér kupak), szalvétatartó, kis **menütábla** (B01, színes pixelsorok). |
| 3 | **Bisztró Pult** | Tégla alsó rész (R02/R03), fa felső pult (F03), felette **zöld vászon napellenző** (M18/M19 csíkos), 2 kis **villanykörte füzér** (W01 + E01 izzók), a pulton üveg vitrin (G02) benne 3 schnitzel, egy citromos tál. |
| 4 | **Bécsi Kávéház** | Elegáns: sötét fa (F01/F02) faragott (lépcsőzetes) díszlécek, **arany** (X02) szegélyek, márvány pult (T01 + T02 erezet), **sárgaréz kávégép** a sarokban, kis **csillár** a tető alatt, a tetején kovácsoltvas felirattartó. |
| 5 | **Schnitzel Birodalom Drive-in** | Retro amerikai stílus neonnal: fehér-piros test, **forgó óriás schnitzel cégér** a tetőn (16×12×3, külön mesh, forog), neon keret (N01/N05), 2 kiadóablak, tetőn reflektorok. |

**Kiegészítők a pult mellé:**
- **Vendégsor korlát**: 1×1 oszlopok (A03) + vörös kötél (M02) moduláris elemként.
- **XP / szint tábla tartó**: 12×2×16 keret a pult fölött (BillboardGui-nak hely).

---

## 9. Futószalag és gyűjtőtálca

Minden szalag elem **moduláris**, 16 voxel (2 stud) hosszú rácsra illesztve, hogy a sütő slotokkal egyezzen.

### 9.1 Egyenes szalag szegmens
- **Méret:** 16 × 12 × 6 voxel (H × Sz × Ma).
- **Felépítés:**
  - Két oldalsó **acél keret** (A02, 1 voxel vastag, 6 magas), tetején 1 voxeles A04 csillanás.
  - Középen a **gumiszalag**: 16×10 voxel, 1 vastag, sötétszürke (`#3A3E46`), **vízszintes bordákkal** (minden 2. sor 1 árnyalattal sötétebb).
  - A szalagon **fehér nyilak / chevronok** (W01, 3 voxel széles V alak) – EZEK KÜLÖN TEXTÚRÁN legyenek, hogy Robloxban animálni lehessen (lásd tipp).
  - Oldalt kívül **3 db henger-tengely vége** látszik (2×2 kör A03, közepén B01 pont).
  - Lábak: minden szegmens elején 2 db 2×2×4 láb (A01).
- **Tipp az animációhoz:** a gumiszalag felületét egy külön, lapos `Part` + `Texture` (nyíl textúra) tegye ki, és scriptből `OffsetStudsV` változtatással gördítsd → valódi mozgás, olcsón.

### 9.2 Kanyar szegmens (90°)
- **Méret:** 16 × 16 × 6, negyedkör alakú szalag, a külső keret lépcsőzetes ívvel (voxel kör), belül kis henger.

### 9.3 Végelem / kezdőelem
- **Kezdő:** zárt vég egy lekerekített **görgővel** (2 voxel átmérőjű henger keresztben) és kis motorházzal (6×6×6, M01 piros, kis szellőzőrács B01).
- **Vég / lejtő:** a szalag 4 voxellel lefelé lejt a gyűjtőtálcába.

### 9.4 Sütő slot talapzat
- **Méret:** 36 × 28 × 3 (a sütő alá).
- A szalag mögött, egy szinttel magasabban; peremén sárga-fekete (S01/B01) csíkos szegély, közepén egy sötét **szám-jelölő** hely (Slot 1–25).
- **Üres slot állapot:** halvány szellem-körvonal (külön mesh, félátlátszó) "+" jellel.

### 9.5 Gyűjtőtálca (schnitzel kupac)
- **Méret:** 40 × 28 × 8.
- Nagy acél **sütőtepsi** forma: perem 2 voxel magas (A03, élein A04), belül sütőpapír (T01, enyhe gyűrődés: 1-es T02 vonalak).
- **Kupac-állapotok** (külön mesh-ek, a töltöttség szerint cseréld): 0%, 25%, 50%, 75%, 100% – egymásra dobált schnitzelek (a 3 sziluett-variánsból kicsinyítve), 100%-nál púpozott halom, ami túlcsordul.
- Oldalán **kapacitás-kijelző** hely (BillboardGui).

### 9.6 Merge Pad
- **Méret:** 48 × 32 × 4.
- Lekerekített sarkú vastag párna (lépcsős voxel lekerekítés), lila-mályva (`#B48CC8`, `#9A70B0` perem, `#D4B8E4` teteje), a tetején **domború "MERGE" felirat** pixelbetűkkel (W01, 1 voxel kiemelve, B01 árnyék alatta 1 eltolással), két oldalt **keresztbe tett klopfoló ikon**.
- A peremen 1 voxeles fénycsík (N06) – Robloxban Neon anyag, lüktet, ha van merge-elhető pár.

---

## 10. Egyéb propok

| Prop | Méret | Leírás | Paletta |
|---|---|---|---|
| **Vásárló gomb (rálépős)** | 24×24×4 | Szürke foglalat (A03/A04, ferde peremmel) + **piros párnás gomb** (M01, teteje `#FF6A5A`, alul M02), lekerekített sarkok. Lenyomott állapot külön mesh (2 voxellel alacsonyabb). | A03, A04, M01, M02 |
| **Robux gomb** | 24×24×4 | Ugyanaz, **sárga** (S01/S02/X03). | S01, S02, X03 |
| **Fejlesztő gomb** (chef) | 24×24×4 | Ugyanaz, **kék** (N05) vagy zöld (N04) – kategóriánként más szín. | N04, N05 |
| **Pénz raklap** | 32×24×4 + pénz | Fa raklap (F02/F03 deszkák, 3 talpgerenda). **Pénz kötegek**: 6×3×2 téglák (zöld `#4AB84A`, középen W01 és S01 csík = papírszalag). 5 állapot: üres / 1 köteg / kis halom / nagy halom / túlcsorduló hegy. | F02, F03, zöld, W01, S01 |
| **Tányér** | 20×20×2 | Kerek, T01, T02 alj, T03 kék perem csík. Index ikonokhoz és tálaláshoz. | T01–T03 |
| **Citromkarika** | 8×8×1 | Lásd Bécsi szelet. Külön prop, díszítéshez. | M16, M17 |
| **Klopfoló (húsklopfoló)** | 8×8×24 | Fa nyél (F02/F03, 2×2), fém fej (8×8×6, A02–A04) a tetején **piramis-tüskés** mintával (1-es voxelek sakktábla mintában kiemelve). **Merge VFX-hez óriásra skálázva!** | F02, F03, A02–A04 |
| **Fakanál** | 4×3×20 | Ovális kanálfej + vékony nyél (F03/F04). Chef ébresztéshez. | F03, F04 |
| **Panírtojás (pet tojás)** | 14×14×18 | Tojás forma (lépcsős), alsó fele **panírral** bevonva (P02–P05 dithering, hullámos határ), felső fele fehér tojáshéj (W01/T02) **cikcakk repedéssel**. Ritkaságonként palettacsere. | P02–P05, W01, T02 |
| **Chef sapka** (kozmetikum) | 12×12×14 | Magas fehér szakácssapka, puffadt tetővel (3 "felhő" domb), szalag alul (T02). | W01, T02 |
| **Schnitzel trail darab** | 2×2×1 | Morzsa voxel partikula textúrához / mesh partikulához. | P04, P05 |
| **Menütábla / cégér** | 24×4×16 | Krétatábla (B01 + fa keret F02), pixelírással. | B01, F02, W01 |
| **Kockás asztal** (díszlet) | 24×24×14 | Fa asztal, piros-fehér kockás abrosz (2×2 kockák), lelógó sarkok. | F02, M01, W01 |
| **Olajos hordó** (díszlet) | 12×12×16 | Sárga hordó (S01) "OLAJ" felirattal, fém abroncs (A02). | S01, A02 |
| **Lisztes zsák / morzsás zsák** | 12×8×14 | Vászonzsák (T01/S03), felső része bekötve, "MORZSA" felirat, kiszóródott morzsa a lábánál. | T01, S03, P04 |

---

## 11. Elnevezés, export, Roblox import checklist

### 11.1 Elnevezés
```
SM_Schnitzel_01_SertesRantott
SM_Schnitzel_05_CordonBleu
SM_Oven_L05_NagyiTuzhelye        (+ _Door, _Knob, _Basket külön)
SM_Counter_S2_BufeAblak
SM_Conveyor_Straight / _Curve90 / _Start / _End
SM_Tray_Fill_000 / _025 / _050 / _075 / _100
SM_Prop_Klopfolo
T_Palette_Base.png / T_Palette_Silver.png / T_Palette_Gold.png / T_Palette_Diamond.png / T_Palette_Nagyi.png
```

### 11.2 Blender ellenőrzőlista minden modell előtt export
- [ ] Voxel méret pontosan illeszkedik a rácsra (nincs fél voxel).
- [ ] Merge by Distance + belső face-ek törölve.
- [ ] Limited Dissolve Delimit: UV-val lefuttatva.
- [ ] Minden face UV-ja egy palettapixelen belül van.
- [ ] Shade Flat, normálok kifelé.
- [ ] Pivot a talp közepén, elöl a középvonalon (sütőnél a kiömlő nyílás felé néz -Y).
- [ ] Poligon limit rendben (lásd 1. fejezet).
- [ ] Animálandó részek külön objektumként, értelmes névvel.

### 11.3 Roblox import
- **Méretezés:** importálás után a `MeshPart.Size` = voxelszám × 0.0625 (kis tárgy) vagy × 0.125 (nagy tárgy). Pl. schnitzel 32×22×3 → `2 × 1.375 × 0.1875` stud.
- **CollisionFidelity:** schnitzelek és díszletek `Box`, sütők/pult `Hull`; szalagon guruló schnitzeleknél `CanCollide = false`, `CanQuery = false`, `CanTouch = false` (teljesítmény!).
- **RenderFidelity:** `Performance` a schnitzeleknél (sok példány), `Automatic` a sütőknél.
- **Textúra:** a paletta 32×32 PNG – Robloxban a textúra szűrés miatt érdemes 4x-esre (128×128) nagyítani **nearest neighbour**-ral exportálás előtt, különben a színhatárok elmosódhatnak.
- **Ritkaság csere:** a `TextureID` cserélhető futásidőben, egy modell = 5 kinézet.
- **Instancing:** ugyanaz a MeshId sok példányban olcsó – ezért fontos, hogy minden schnitzel típus 1 mesh legyen.

---

## 12. Gyártási sorrend (prioritás)

| Sorrend | Modell | Miért |
|---|---|---|
| 1 | Paletta textúra + schnitzel alapsablon (3 sziluett) | minden erre épül |
| 2 | Futószalag (egyenes, vég), gyűjtőtálca, slot talapzat, vásárló gomb, merge pad, pénz raklap | prototípushoz kell |
| 3 | Sütő Lv1–Lv5 + schnitzel 1–5 | első 10 perc élménye (FTUE) |
| 4 | Pult stádium 1–2 | |
| 5 | Klopfoló (merge VFX) | a "juice" kulcseleme |
| 6 | Sütő Lv6–Lv10 + schnitzel 6–10 | MVP vége |
| 7 | Ritkaság paletták (Ezüst, Arany, Gyémánt, Nagyi) | |
| 8 | Panírtojás, chef sapka, fakanál | pet és chef rendszerhez |
| 9 | Sütő Lv11–15 + schnitzel 11–15, pult 3–5 | Alpha |
| 10 | Event schnitzelek (16–29), díszletek | Live ops, update-enként 2–4 db |

**Becsült idő (1 közepes tapasztalatú voxel modellező):**
schnitzel ~1–2 óra/db, sütő ~3–5 óra/db, pult ~4–6 óra/stádium, szalag modulok összesen ~4 óra.
**MVP összesen (≈ 10 schnitzel + 10 sütő + 2 pult + szalag/propok): kb. 70–90 munkaóra.**

---

*Utolsó frissítés: 2026-11-12*
