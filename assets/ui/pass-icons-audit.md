# Schnitzel Pass icon audit — 2026-11-16

Reviewed both Pass and Earn Pass XP tabs in Studio, including tiers 15 and 30.
The five follow-up icons were generated with built-in `image_gen`, uploaded, and integrated.
All are 1254 × 1254 RGBA PNGs with transparent corners; moderation is Approved.
Prompts: `pass-reward-icons-prompts.md`. Upload metadata: `icons-manifest.json`.

## Integrated

- `icons/schnitzel-ui-pass.png`: golden star with schnitzel emblem, 1254 × 1254 RGBA.
- `Ui.Icons.SeasonPass`: image `123967822702376`, decal `139318191443224`, moderation Approved.
- Used by the TopbarPlus Pass button, Pass header, and Pass tab.
- All three actual client GUI images reported `IsLoaded == true`.
- The plain tier star stays unchanged: the tier number overlays its center.

## Completed artwork — five icons

All new images follow `schnitzel-ui-icons.png`: thick rounded dark outlines,
bright colors, simple cel shading, creamy upper-left highlight, transparent alpha,
one centered object, no text, no button background, enough padding for 48px use.

| Priority | Integrated key / file | Replaced substitute | Artwork / usage |
|---|---|---|---|
| 1 | `PassXp` / `schnitzel-ui-pass-xp.png` | `Ui.Icons.Quests`, older blue book | Blue XP book or task book in the current icon style, with a simple golden star emblem. Earn Pass XP tab and header. Use a dedicated key so other Quests users are unaffected. |
| 2 | `SeasonHedgehog` / `schnitzel-ui-season-hedgehog.png` | Generic green `Ui.Icons.Pets` paw | Crispy Hedgehog portrait: warm brown/orange hedgehog with breaded schnitzel-like spines. Free tier 30 reward. Both current final rewards show the identical paw. |
| 2 | `SeasonGriffin` / `schnitzel-ui-season-griffin.png` | Same generic green paw | Golden Schnitzel Griffin portrait: gold griffin, recognizable eagle head and wings with schnitzel cues. Premium tier 30 reward. |
| 3 | `LemonZestTrail` / `schnitzel-ui-lemon-zest-trail.png` | Generic `Ui.Icons.Star` | Curved lemon-yellow and lime-green trail, with a clear lemon cue; matches Config.Shop.Trails.LemonZest colors. Premium tier 15 reward. |
| 3 | `GoldenEgg` / `schnitzel-ui-golden-egg.png` | `Ui.Icons.LuckBoost`, older studded gold egg with clover | Smooth golden egg in the current cartoon style, without a luck clover. Free tiers 15/25 and Premium tiers 7/14/20/25. Dedicated key distinguishes an egg reward from a luck boost. |

The portraits are based on Config.Pets. `SeasonPassWindow.rewardIcon` now uses
explicit per-pet and per-trail maps with generic fallbacks for future rewards.
The pet portrait changes apply to the Pass reward cards.

| Key | Image asset | Decal asset |
|---|---|---|
| PassXp | 135613592435419 | 111061028833768 |
| GoldenEgg | 103079801895752 | 73163801612639 |
| LemonZestTrail | 88256764839025 | 93267805617292 |
| SeasonHedgehog | 140393696072231 | 108031193474508 |
| SeasonGriffin | 110574327552854 | 134489519548311 |

## Existing icons that can be reused

- Cash: CoinBag / CoinChest; Aura Tickets: Ticket; Rebirth Tokens: RebirthToken.
- Free track label: Gift; Premium label/cards/button: Crown; countdown: Clock.
- XP cards: Play → Schnitzel; Merge Ovens → dedicated MergeOvens icon; Daily Reward → Gift;
  Playtime Gifts → Clock; Hatch Pets → Egg; Rebirth → Rebirth.
- All six XP card stickers and the XP header reported `IsLoaded == true`.
- Boosts already have appropriate Money/Luck/Bake potion images and Energy.
  Redrawing the three potions or the crown is optional style polish, not missing artwork.
- Checkmarks and the tier star remain useful generic status symbols.

## Validation

- Rojo build successful.
- Targeted `git diff --check` successful.
- Rojo-synchronized Studio Edit sources contained the new image mapping and both consumers.
- Playtest visually confirmed Pass, Earn Pass XP, tier 15 and tier 30.
- The new XP tab/header, Golden Egg, Lemon Zest Trail, and both pet portraits
  all reported `IsLoaded == true` in their actual client GUI instances.
- Preview only opened tabs and scrolled rewards; it did not claim or purchase rewards.
- Temporary preview LocalScript was discarded when stopping the playtest; Studio returned to Edit.

## Merge Ovens follow-up

The XP card now has its own two-oven icon with a green merging arrow instead of Upgrade.
File: `icons/schnitzel-ui-merge-ovens.png`; prompt: `merge-ovens-icon-prompt.md`.
Image `81165098929205`, decal `76312952595886`, moderation Approved.
The actual XP card ImageLabel loaded in playtest; Rojo build and targeted diff check passed.
