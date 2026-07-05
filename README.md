# The Alchemist's Ledger — Gate to Sovngarde

A single-page alchemy reference for **Gate to Sovngarde**: every ingredient's
effects and a live-recomputed ranking of the highest-value potions and poisons
for your skill, perks and gear.

## Deploy (GitHub Pages)

Drop these into a repo and enable Pages (Settings -> Pages -> deploy from branch):

```
index.html
data/gtsae.json
data/gtsce.json
```

The page **loads its datasets at runtime**, so it must be served over http
(GitHub Pages, or any local server such as `python3 -m http.server`). Opening
`index.html` straight off disk will fail the fetch - that's expected.

## Datasets

Three tabs, all Gate to Sovngarde:

| Tab | Source file | Notes |
|-----|-------------|-------|
| **GTS** | `data/gtsae.json` | Base GTS - Anniversary Edition / Creation Club ingredients hidden. Derived from the GTS+AE export for now (see below). |
| **GTS + AE** | `data/gtsae.json` | The complete ingredient set with Anniversary Edition enabled. |
| **GTS CE** | `data/gtsce.json` | Community Edition (requires AE). Its own export, loaded independently. |

Switching tabs never reloads the page. GTS and GTS + AE share one build (the base
tab just hides AE content), so toggling between them is instant; each source file
is built once and cached, so returning to it is instant too.

### The dataset registry

Everything is driven by two objects near the top of the script in `index.html`:

```js
const SOURCES = { gtsae:'data/gtsae.json', gtsce:'data/gtsce.json' };
const DATASETS = {
  gts:   { label:'GTS',      src:'gtsae', excludeAE:true  },
  gtsae: { label:'GTS + AE', src:'gtsae', excludeAE:false },
  gtsce: { label:'GTS CE',   src:'gtsce', excludeAE:false },
};
```

To **add or replace a dataset**, edit only these objects (and add a matching
`<button data-tab="...">` in the `#srcSeg` control). Datasets are never merged.

### Dropping in a true Base GTS export

When you have a clean base-GTS export, add it as its own file and repoint the tab:

```js
const SOURCES = { gts:'data/gts.json', gtsae:'data/gtsae.json', gtsce:'data/gtsce.json' };
// gts: { label:'GTS', src:'gts', excludeAE:false }   // no longer derived
```

No other code changes.

## Producing / refreshing a dataset (`ExportGTSAlchemy.pas`)

1. Open **SSEEdit / xEdit** and load your full GTS (or CE) load order; wait for
   *Background Loader: finished*.
2. Right-click any plugin -> **Apply Script** -> `ExportGTSAlchemy` -> OK. It walks
   the whole load order (selection doesn't matter) and writes
   `Edit Scripts/gts_alchemy.json`, logging the ingredient count.
3. Drop that file in as `data/gtsae.json` (or `data/gtsce.json`). Done - the page
   processes the raw export in the browser, so there's no build step.

The exporter records, per ingredient: name, EditorID, FormID, origin + winning
plugin; and per effect: the **resolved MGEF EditorID and FormID**, cost,
magnitude, duration and flags. Recipes are matched on that magic-effect identity,
not the display name - so effects that merely share a name (e.g. the three
different "Night Eye" effects) never wrongly combine.

## How values are computed

For each potion, every effect shared by two or more reagents is kept; for a shared
effect the strongest reagent instance wins. Gold follows the game's formula -
`baseCost x (mag x dur/10)^1.1` per effect, summed - with skill, the Alchemist
perk, Fortify Alchemy gear, and Benefactor / Physician / Poisoner applied first.
The primary (naming) effect is the highest-potency one and decides potion vs poison.

Client-side processing drops non-craftable items (24-hour "eaten" food buffs and
test/debug records) and tags each ingredient Vanilla / CC-AE / Mod for filtering.

## Performance

At 400-450+ ingredients an exhaustive 3-reagent search is ~13 million combinations.
Instead the worker caps the search to the top ~180 ingredients by best-effect value
(an ingredient outside that set can't form a top potion), builds only effect-sharing
combinations, and keeps a bounded top-N without sorting the whole space. It all runs
in a Web Worker so the UI stays responsive.

## Known caveats

- **Perk scaling is vanilla-style** pending Adamant's alchemy-tree numbers. Give me
  the Adamant magnitudes and they slot straight into `powerFactor`.
- **Gold is a relative potency ranking.** GTS applies a global value reduction that
  may live in a game setting rather than the ingredient records, so treat the
  numbers as ordering, not exact sale price.
- The base **GTS** tab is derived by hiding AE/CC content from the GTS+AE export;
  a handful of edge cases may differ until a dedicated base-GTS export is dropped in.
- Rarity / "farmable" tags are best-effort.
- GTS "dynamic" crafting (enhanced stats / impurities) is not modelled.

- Made for the GTS community.
