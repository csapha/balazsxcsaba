# +1 Steal a Gem — Architektúra

> Jelenlegi szelet: **bányászat** (ütés -> érc -> felvétel) + csákány a kézben.
> **Nincs HUD** egyelőre — a Shop / Backpack / stats panelek később jönnek vissza.
> A lopás/telek rendszer erre épül rá később (lásd a végén a roadmapet).

---

## Szerkezet

```
src/
  shared/                       ReplicatedStorage.Shared
    Config/
      Game.luau                 globális konstansok (időzítők, limitek, UI színek)
      Ores.luau                 ércek: odds, ár, szín, template (Gem_*)
      Pickaxes.luau             csákány szintek: ár, luck, speed
    Format.luau                 szám formázás (1.2K / 3.4M / $)
    Hierarchy.luau              path alapú find / ensureFolder segédek
    Signal.luau                 mini signal (Connect / Fire)
    Net.luau                    RemoteEvent-ek központi kezelése

  server/                       ServerScriptService.Server
    init.server.luau            bootstrap (sorrend: adat -> világ -> logika)
    Services/
      PlayerData.luau           session state + mutációk + Changed signal (persistence-ready)
      ClientSync.luau           leaderstats + adat snapshot kiküldése
      PickaxeService.luau       csákány Tool a játékos kezébe (spawn/respawn)
      OreService.luau           érc spawn a kő mellé, felvétel, despawn
      MiningService.luau        ütés validálás, roll, effekt remote
      EconomyService.luau       érc eladás, csákány vásárlás

  client/                       StarterPlayerScripts.Client
    init.client.luau            bootstrap
    Controllers/
      MiningController.luau     csákány-ütés: swing (animáció vagy procedural) + MineRequest
      EffectsController.luau    részecskék, lebegő "+1"
```

A Rojo a `default.project.json` alapján köti be ezeket a helyekre.

---

## Studio struktúra és path-ok

```
Workspace
  Map/Mine/MineRock          a bányakő (ezt üti a játékos)
  Drops                      runtime: ide kerülnek az érc dropok

ServerStorage
  Templates/Pickaxes/DefaultPickaxe   a Tool sablonja
  Templates/Gems/Gem_<Rarity>         az érc modellek sablonjai
```

A path-ok a `Game.Paths` táblában vannak; a lookup mindenhol fallbackol
(ReplicatedStorage.Assets, majd Workspace), hogy egy áthelyezés ne törjön el semmit.

---

## Adatfolyam

```
Ütés (csákány a kézben, kattintás/tap -> Tool.Activated)
  -> kliens: swing animáció -> MineRequest (nincs irány, csak jelzés)
  -> MiningService (szerver): cooldown -> távolság a bányakőhöz -> csákány a kézben?
     -> Ores.roll(luck, csak a létező Gem_* modellek) -> PlayerData.registerHit
  -> OreService.spawnOre: a Gem_* sablon klónja a kő mellé
  -> OreMined remote: környékbeli kliensek effektje (részecske + "+1 Név")

Felvétel (nincs prompt: a gemhez odasétálsz -> Touched)
  -> OreService.collect: owner check -> magnet (a gem odarepül) -> PlayerData.addOre
  -> OrePicked remote: kliens effekt

Eladás / csákány vásárlás (amíg nincs HUD, UI-ból nem elérhető)
  -> SellOre / BuyPickaxe remote -> EconomyService

Minden adatváltozás:
  PlayerData.sync -> PlayerData.Changed signal
    -> ClientSync: leaderstats frissítés + DataChanged remote a kliensre
```

---

## Remote-ok (ReplicatedStorage.Remotes)

| Név | Irány | Tartalom |
|---|---|---|
| `DataChanged` | szerver -> kliens | teljes snapshot: cash, pickaxe, inventory, stats.hits |
| `Notify` | szerver -> kliens | üzenet szöveg (opcionális Color3) |
| `MineRequest` | kliens -> szerver | (nincs payload) — ütés jelzése; a szerver a távolságot ellenőrzi |
| `OreMined` | szerver -> kliens | `{ oreId, position }` — ütés effekt |
| `OrePicked` | szerver -> kliens | `{ oreId, position }` — felvétel effekt |
| `BuyPickaxe` | kliens -> szerver | `tierId: string` |
| `SellOre` | kliens -> szerver | `oreId: string` |

A remote-okat a `Net.luau` hozza létre a szerveren, a kliens `Net.get(name)`-mel várja.

---

## Adatmodell (PlayerData)

```lua
{
    version = 1,
    cash = 0,
    pickaxe = "Default",
    inventory = { common = 0, amethyst = 0, ... },  -- [oreId] = db
    stats = { hits = 0, mined = {} },
}
```

- **Session-only egyelőre**: `Game.Persistence = false` — nincs DataStore betöltés/mentés.
  A kód út készen áll (load/save/autosave + BindToClose), csak a flaget kell true-ra állítani.
- Ha persistence be van kapcsolva: DataStore kulcs `u_<UserId>`, mentés 60 mp-enként + kilépéskor + BindToClose-kor.
- A játék UI szövegei **angolul** vannak (a játék angol nyelvű lesz); a kód kommentek magyarok.

---

## Konfiguráció

### Ércek (`Ores.luau`)

| id | tier | odds | érték | template |
|---|---|---|---|---|
| common | 1 | 60.0 | $2 | Gem_Common |
| amethyst | 2 | 25.0 | $8 | Gem_Amethyst |
| sapphire | 3 | 10.0 | $30 | Gem_Sapphire |
| emerald | 4 | 3.5 | $150 | Gem_Emerald |
| ruby | 5 | 1.0 | $800 | Gem_Ruby |
| diamond | 6 | 0.4 | $4000 | Gem_Diamond |
| starstone | 7 | 0.1 | $25000 | Gem_Starstone |

A `template` mező mondja meg, melyik modellt spawnolja. A keresés sorrendje:
`ReplicatedStorage.Assets` -> `Workspace`. Ha egyik sincs meg, gömb placeholdert használ.

### Csákányok (`Pickaxes.luau`)

| id | ár | luck | speed |
|---|---|---|---|
| Default | $0 | 0.0 | 1.00 |
| Stone | $100 | 0.25 | 1.15 |
| Iron | $500 | 0.6 | 1.30 |
| Gold | $2000 | 1.2 | 1.50 |
| Diamond | $8000 | 2.5 | 1.75 |
| Star | $40000 | 5.0 | 2.00 |

A luck a `Ores.roll`-ban a magasabb tierű ércek súlyát növeli: `w = odds * (1 + luck * (tier - 1))`.

---

## Világban lévő modellek (kézzel importálva)

- `Workspace.MineRock` — a kő, amit ütni kell (a `MinePrompt` ProximityPromptot a script teszi rá, ha nincs)
- `Workspace.DefaultPickaxe` — a csákány modell (később Tool-ként kerül a játékos kezébe)
- `Workspace.Gem_*` — az érc modellek (a script innen klónozza őket)

---

## Futtatás

```bash
rojo serve          # Studio-ban: Rojo plugin -> Connect
```

Studio-ban a Workspace-ben hagyni kell a modelleket (`MineRock`, `Gem_*`); a scriptek név alapján keresik.

---

## Roadmap (a következő szeletek)

1. **Telkek (tycoon)** — `PlotService`: telkenként `MineRock` + `Tray` + `Vault`, a mine/ore/question csak a telek tulajdonosának
2. **Tálca / Vault** — nyers érc a tálcán (lopható), vault slotok (biztos), csiszolás -> pénz
3. **Lopás** — carry, raid cap, cooldown, tier-gate, wanted állapot, őr NPC (patrol -> suspicion -> chase)
4. **Trade** — érc/csere rendszer
5. **Zónák** — mélység szerinti rarity pool (a `Ores.luau` zónánként szűrve)
6. **Eventek** — Heist Hour, meteor, dupla mutáció
7. **Szerver-announce** — Mythic/Secret drop kihirdetése az egész szervernek
