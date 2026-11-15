# UI ikonok

## Settings ikon (2026-11-15)

Új, átlátszó, 1254 × 1254 pixeles ezüst-kék fogaskerék:
`icons/schnitzel-ui-settings.png` (beépített `image_gen`, prompt:
`settings-icon-prompt.md`). A sarkok és a középső nyílás alfaértéke 0.
Roblox moderáció: Approved; image `137472960814779`, decal `76795026560040`.
Az `Ui.Icons.Settings` közös hivatkozás frissült, így a TopbarPlus Settings
gomb, a Settings fejléc és a Settings fül ugyanazt az új képet használja.
A Rojo build és a módosított fájlok `git diff --check` ellenőrzése sikeres.
A Studio Edit forrásban az új ID szerepel, a kép előtöltése Success.

## Pénzjutalom ikonok (2026-11-15)

A Daily Rewards és Playtime Gifts régi, studsos pénzesládáját és pénzeszsákját
új, sima felületű, vastag körvonalas ikonok váltották fel. Mindkét 1254 × 1254
pixeles, alfa csatornás PNG feltöltve Robloxra, moderációjuk Approved.
Az `Ui.Icons.CoinChest` és `Ui.Icons.CoinBag` az új image ID-ket használja;
a `RewardParts.icon` közös hivatkozásain keresztül mindkét jutalomablak frissül.
Fájlok: `icons/schnitzel-ui-coin-chest.png`, `icons/schnitzel-ui-coin-bag.png`.
Promptok: `money-reward-icons-prompts.md`; feltöltési adatok: `icons-manifest.json`.

Ellenőrzés: Rojo build és a módosított fájlok `git diff --check` ellenőrzése
sikeres. A Studio Edit DataModelben a szinkronizált Ui forrás az új ID-ket
tartalmazza. Mindkét kép `ContentProvider:PreloadAsync` lekérése Success;
a nem szülőzött próba-ImageLabel példányok `IsLoaded` értéke false maradt,
futó kliensbeli megjelenítési próbát nem végeztünk.

## Ajándék ikon (2026-11-15)

Új, átlátszó, 1254 × 1254 pixeles PNG: piros ajándékdoboz arany szalaggal és masnival
(`icons/schnitzel-ui-gift.png`, prompt: `gift-icon-prompt.md`). Feltöltve decalként
(`80383593414728`, moderáció: Approved), a kép ID: `111048535886079` (manifest: `Gift`).
A `Ui.Icons.Gift` és a `Ui.Icons.Daily` is ezt használja: a Daily Rewards és a Playtime Gifts
ablak (két fül) fejléce, a Daily fül gombja és a közös "Rewards" TopbarPlus ikon.
A korábbi Gift / Daily képek ID-i a régebbi manifest-bejegyzésekben megmaradtak.

## Random event ikonok (2026-11-15)

Mind a hat random event saját, átlátszó, 1254 × 1254 pixeles PNG-t kapott,
a meglévő készlet vastag sötét körvonalas, élénk rajzfilmes stílusában.
A képek a beépített `image_gen` eszközzel készültek; a végleges promptok:
`event-icons-prompts.md`. A fájlok az `icons/schnitzel-ui-event-*.png` képek
(a korábbi `event-timer` továbbra is az óraikon). Minden új feltöltés Approved;
az image/decal ID-k és a feltöltési műveletek az `icons-manifest.json` fájlban vannak.

| Event | Ui.Icons kulcs | Grafika |
| --- | --- | --- |
| Lunch Rush | EventLunchRush | Schnitzeles tányér evőeszközökkel és sebességcsíkokkal |
| Golden Oil | EventGoldenOil | Arany étolajos üveg |
| Breadcrumb Storm | EventBreadcrumbStorm | Felhőből hulló schnitzelek |
| Food Critic | EventFoodCritic | Lila cilinder és arany monokli |
| Grandma's Visit | EventGrandma | Mosolygó, szemüveges nagymama |
| Blackout | EventBlackout | Széthúzott kék csatlakozó |

A `Config.Events.List[*].Icon` közös `Ui.Icons` képhivatkozás lett.
Az `EventController` bannerében az emoji TextLabel helyett ImageLabel jelenik meg,
64 pixeles képdobozban, `ScaleType.Fit` értékkel. A HUD aktív eseménynél ugyanazt
az ikont mutatja 28 pixeles képdobozban; események között visszaáll az óra.

Ellenőrzés: mind a hat PNG alfa csatornás, átlátszó sarkú; a Rojo build és a
módosított fájlok `git diff --check` ellenőrzése sikeres. MCP playtestben mind a
hat kép a valódi banner és HUD ImageLabel példányán `IsLoaded == true` értéket
adott, a banner ikonja nem ér a címbe, az óra visszaállítása működik.
A Lunch Rush első betöltésénél még nem töltődött be 0,7 másodperc alatt,
az ismételt ellenőrzésben mindkét példánya betöltődött. A próbához a kliens
ideiglenes EventState attribútumokat kapott, majd az eredeti értékeket visszaállítottuk.

## Állapot (2026-11-15)

Az eredeti 15 kivágott, átlátszó, 384 × 384 pixeles PNG feltöltve Robloxra és bekötve.
Az Auras gyémántját új energialáng és auragyűrű váltotta fel; a Rarities külön,
színes ritkaságkártyákat kapott. A két új, átlátszó kép 1254 × 1254 pixeles.
Az új képek a `icons/schnitzel-ui-auras-v2.png` és `icons/schnitzel-ui-rarities.png`
fájlban vannak; a beépített `image_gen` promptjai: `replacement-icons-prompts.md`.
Mindegyik feltöltött asset moderációja `Approved`.
Az eredeti ikonlap: `assets/ui/schnitzel-ui-icons.png`.
A külön képek: `assets/ui/icons/`.
Az `icons-manifest.json` tartalmazza a fájlokat, kivágási koordinátákat,
a tényleges image és decal asset ID-ket, valamint a feltöltési műveletek azonosítóit.
Újrafeltöltés helyett ezeket az ID-ket kell újrahasználni.

## Bekötés

- `src/shared/Ui.luau`: a közös `Ui.Icons` képhivatkozások; az új kulcsok `Auras` és `Rarities`.
- `src/client/UI/Hud.luau`: főmenü, navigáció, pénz, schnitzel, időzítő;
  a schnitzel emoji helyett képet használ, az animáció megmaradt.
- `src/client/UI/Kit.luau`: az összes ablak közös bezárógombja az új X képet használja.
- `src/client/UI/AurasWindow.luau`: a ticket-számláló az új jegyikont használja.
- Az Index, Rebirth, Pets és Auras fejlécei és fülei ugyanazokat a közös ikonokat használják.

| Ui.Icons kulcs | Ikon |
| --- | --- |
| Rebirth | Sárga/kék környilak |
| Index | Lila receptkönyv |
| Pets | Zöld mancs |
| Crystal | Lila kristály / Auras |
| Auras | Auragyűrűvel körülvett energialáng; a Crystal helyett minden Auras felületen |
| Rarities | Színes ritkaságkártyák; a Rarities fülön a Star helyett |
| Ovens | Narancsszínű sütő schnitzellel; az Ovens fülön az Energy helyett |
| RebirthToken | Lila-arany zseton Rebirth-környilakkal; a jutalomsorban a Star helyett |
| OvenSlots | Két sütő zöld pluszjellel; a sütőhely-jutalomsorban az Upgrade helyett |
| Baking | Narancssárga sütőkesztyű hőhullámokkal; inventory sütési bónusz |
| Luck | Zöld négylevelű lóhere; inventory szerencsebónusz |
| Chefs | Fehér szakácssapka kék szegéllyel; inventory chefsebesség-bónusz |
| Home | Piros helyjelölő / My Plot |
| Egg | Arany/krémszínű tojás |
| Coin | Arany érme |
| Schnitzel | Rántott hús citrommal |
| Clock | Óra / event timer |
| Energy | Villám |
| Star | Általános csillagikon |
| Upgrade | Zöld felfelé nyíl |
| RebirthCash | Érmecsoport / pénzszorzó |
| Ticket | Aura ticket |
| Close | Fehér X |

## Stílus és terjedelem

Csak a meglévő kezelőfelülethez készült új grafika. Az egyes petekhez,
sütőtípusokhoz és aurákhoz nem készültek külön illusztrációk.
Rajzfilmes stílus, vastag sötét körvonal, élénk színek,
egyszerű formák, enyhe árnyékolás, átlátszó háttér.
A gombok háttere és felirata nem része a képeknek.
A kivágást a `tools/split-ui-icons.ps1` végzi vizuálisan ellenőrzött, egyedi határokkal.
A script újragenerálja a manifestet is; újrafuttatás előtt őrizd meg a feltöltési adatokat.

## Roblox MCP és ellenőrzés

A Roblox MCP-kapcsolat működik. Cél:
place `127420394746207`, universe `10776638104`, tulajdonos `568256892`.
A feltöltés `open_cloud_invoke` használatával, a Studio saját hitelesítésével történt.
API-kulcsot nem használtunk és nem mentettünk a projektbe.

A feltöltési mappa engedélyezése után mind a 15 feltöltés sikerült.
A decal ID-kből a hozzájuk tartozó tényleges képhivatkozásokat olvastuk ki.
A Rojo szinkronizálta a négy módosított forrásfájlt; MCP-n ellenőriztük az egyezést.

Ellenőrzések:
- Mind a 15 PNG 384 × 384 pixeles, alfa csatornás és átlátszó sarkú.
- `rojo build` sikeres; `git diff --check` hibamentes.
- Studio playtestben mind a 15 kép `ImageLabel.IsLoaded == true`.
- A Rebirth, Index, Pets és Auras ablak megnyílt; a fejlécek, fülek,
  ticket- és bezáróikonok betöltődtek, négyzetes méretet és `ScaleType.Fit` értéket használnak.
- A HUD menü-, navigációs, pénz-, schnitzel- és óraikonjai betöltődtek.
- A közvetlen `PreloadAsync` stringlistás próba Failure státuszt adott;
  ezt a tényleges GUI-példányok sikeres betöltésével külön ellenőriztük.
- A Selene ellenőrzés nem futott le, mert a Roblox API dump letöltése sikertelen volt.
- Képernyővezérlést nem használtunk.

## Pets / Auras igazítás és új ikonok

A menüikonok mérete alapból a gombfelület 88%-a. Az Auras nagyobb átlátszó
margója miatt 102%-os képdobozt használ; a látható grafikák szélessége így közel azonos.
A középpont a gombfelület `(0.5, 0.46)` pontja. A Pets és Auras eltérő PNG-margóit
a `Hud.MENU_ICON_ANCHORS` kompenzálja; a `Kit.button` támogatja az `IconPosition`
és `IconAnchorPoint` paramétereket, a többi gomb alapértékei megmaradtak.

Az új PNG-k és a Pets látható tartományát alfa >= 128 küszöbbel mértük.
MCP playtestben a Pets és Auras látható középpontjának eltérése 0.001 pixel alatti,
mindkettő látható grafikája a gombon belül, a felirat fölött marad.
Az új Auras kép a menüben, fejlécben és Index fülön is betöltődött;
a Rarities kép az Index fülön betöltődött. A build és `git diff --check` sikeres.
Az eredeti Crystal asset a manifestben történeti hivatkozásként megmaradt,
de az Auras menü, ablakfejléc és Index fül már az új képet használja.

## Ovens, Rebirth Token és Oven Slots

Három külön, átlátszó 1254 × 1254 pixeles PNG készült a beépített `image_gen`
eszközzel, az eredeti ikonlap stílusát követve. Fájlok és promptok:
`oven-token-icons-prompts.md`. Mindhárom Roblox-feltöltés moderációja Approved,
az image és decal ID-k, valamint a feltöltési műveletek a manifestben vannak.

Az Index Ovens füle `Ui.Icons.Ovens` képet használ. A Rebirth Token jutalom
`Ui.Icons.RebirthToken`, a sütőhely-jutalom `Ui.Icons.OvenSlots` képet kapott.
MCP playtestben mindhárom kép a tényleges GUI-példányában betöltődött,
`ScaleType.Fit` értékkel: az Ovens fülön kb. 51, a jutalomsorokban kb. 30 pixeles
képdobozban. A build és a `git diff --check` sikeres. Képernyővezérlést nem használtunk.

## Collector világfelirat

A Collector hússzámlálójában megmaradt hús-emoji helyett külön ImageLabel
használja a meglévő `Ui.Icons.Schnitzel` képet; új feltöltésre nem volt szükség.
A `Billboard.new` opcionális `Line.icon` mezője a képet és a szöveget egy középre
igazított sorban helyezi el, a felirat szélességéhez és a nézőtávolsághoz méretezve.
A `SellService` `ShowIcon` attribútuma üres Collectornál elrejti a képet,
az `empty` felirat pedig középen marad.

MCP playtestben az üres állapot, `1 ($2)`, `76 740 ($239.6M)` és
`999 999 999 999 ($999.9T)` minták ellenőrizve: a kép betöltődik, a szöveg elfér,
nincs átfedés, a képből és szövegből álló sor középen marad.
Az ellenőrzés ideiglenes feliratokat használt, játékosadatokat nem módosított.

## Pets inventory bónuszsor

Három új, átlátszó, 1254 × 1254 pixeles ikon készült a beépített `image_gen`
eszközzel: `icons/schnitzel-ui-baking.png`, `icons/schnitzel-ui-luck.png`,
`icons/schnitzel-ui-chefs.png`. A végleges promptok: `bonus-icons-prompts.md`.
Mindhárom asset moderációja Approved, az ID-k és feltöltési műveletek a manifestben vannak.

A `PetsWindow` inventory feletti bónuszsora a Money, Baking, Luck és Chefs nevek
helyett képet és százalékot mutat. A Money a meglévő Coin képet használja.
Az Active számláló megmaradt, a négy százalék továbbra is a `State.pets()` alapján,
a `Formulas.petBonuses` függvénnyel frissül. Az ikonok 28 pixeles képdobozban
vannak; a százalékok betűmérete a rendelkezésre álló helyhez igazodik.

MCP playtestben mind a négy kép betöltődött, a négy érték teljesen elfért,
az ikon és a százalék között kb. 4 pixel szabad hely maradt, és minden csoport
a bónuszsoron belül maradt. A build és a módosított források `git diff --check`
ellenőrzése sikeres. Képernyővezérlést nem használtunk.
