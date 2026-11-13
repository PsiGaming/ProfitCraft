# ProfitCraft: design (draft)

How ProfitCraft is built. **What** it does is in `FEATURES.md`; this file is the **how**. Draft of 2026-11-13, for review.

Target: World of Warcraft: Forever, `## Interface: 16001`. API facts marked **(Forever source)** were checked in Blizzard's own Forever UI code (Gethe/wow-ui-source, branch `forever`, build 1.60.1 (70938)); facts marked **(check in game)** are not confirmed yet.

## 1. Principles

These follow from the problems found in ForeverProfit and CraftProfit; the full list is in section 11.

1. **Calculate once, re-read many times.** Profit is calculated when prices or recipes change, never because the user scrolled, searched, filtered or sorted. Those only re-read stored results.
2. **Parts announce changes; they don't call each other.** A price change is announced as a message; whoever cares (profit calculation, windows) listens. Data code never calls window code.
3. **Only public interfaces.** Blizzard's API and Auctionator's public API (`Auctionator.API.v1.*`). Blizzard's recipe list is never modified; ProfitCraft adds its own frames next to Blizzard's.
4. **Errors are quiet while playing, but never lost.** Errors in ProfitCraft's code are caught where game events and messages are handed to the parts, so they never pop up during normal play. Every caught error is written to a small error log (section 6). With **debug mode** on, they are also printed in chat as they happen. Debug mode: `/pcraft debug on|off` (0.1) and a checkbox in the settings window (0.3); off by default. (Decided 2026-11-13.) For comparison, Blizzard's own Lua error window only appears when the `scriptErrors` setting is on (Forever source: `Blizzard_ScriptErrorsFrame.lua`).
5. **Saved data has a version number from day one**, is split by ruleset where prices differ, and has a size limit.
6. **Nothing is assumed from Vanilla, Classic or Retail.** Every API used is checked in the Forever source or in game first.

## 2. Milestones

| Milestone | Version | Contents | Price sources |
|---|---|---|---|
| 1 | 0.1 | "Version 0.1" in `FEATURES.md` | Auctionator only (all testers have it installed and scan with it) |
| 2 | 0.2 | "Version 0.2": own AH scan, own merchant recording, "most recent per item" price choice | Auctionator and our own data; works without Auctionator |
| 3 | 0.3 | "Version 0.3" | Same |

Even in 0.1, Auctionator is listed as `## OptionalDeps: Auctionator`, not `## Dependencies`, so the structure is already standalone: price lookups go through one price module with one "source" per data provider, and milestone 2 adds sources without changing anything else. Without Auctionator, 0.1 loads normally and says once in chat that it has no price source.

## 3. Files and parts

All code shares one private namespace (`local addonName, PC = ...`). The only globals are the saved data (`ProfitCraftDB`), the slash command, and the names of our own frames where Blizzard requires one (e.g. for Escape-to-close).

| File | Part | Job |
|---|---|---|
| `Core.lua` | Core | Namespace, one event frame that hands game events to the parts, a small message system (`PC:Send(msg, ...)` / `PC:Listen(msg, fn)`), slash command |
| `Data.lua` | Data | Loads `ProfitCraftDB`, fills defaults, runs version upgrades, prunes old data |
| `Recipes.lua` | Recipes | Reads the open profession's recipes and reagents from Blizzard's API; announces `RECIPES_CHANGED` |
| `Prices.lua` | Prices | One question for everyone: "what does item X cost / sell for, from which source, how old?" Asks the sources and applies the rules in section 5 |
| `Sources/Auctionator.lua` | Source | Wraps Auctionator's public API; announces `PRICES_CHANGED` when Auctionator's data changes |
| `Sources/ItemData.lua` | Source | Merchant sell price from Blizzard's item data |
| `Sources/Scan.lua`, `Sources/Merchant.lua` | Source | Milestone 2: our own AH scan and merchant buy-price recording |
| `Profit.lua` | Profit | Calculates and stores one result per recipe; keeps the ranked list |
| `UI/Panel.lua` | Window | The compact ranked side panel |
| `UI/Details.lua` | Window | Profit block in Blizzard's recipe details |
| `UI/Settings.lua` | Window | Our own settings window |

## 4. When things are recalculated

| Event | What happens |
|---|---|
| Profession window opens, recipes change (`TRADE_SKILL_SHOW`, `TRADE_SKILL_LIST_UPDATE`, `NEW_RECIPE_LEARNED`; Forever source) | Recipes re-reads the recipe list (all learned recipes via `GetAllRecipeIDs` + `learned`, not the window's filtered list). Only if it actually changed: `RECIPES_CHANGED`. Opening the window fires about 3 `TRADE_SKILL_LIST_UPDATE` within 0.2 s (PsiLab), so these are combined into one re-read |
| Auctionator's data changes | `PRICES_CHANGED` |
| A setting that affects profit changes (e.g. AH cut) | `SETTINGS_CHANGED` with the setting's name; settings that don't affect profit trigger nothing |
| `RECIPES_CHANGED` / `PRICES_CHANGED` / profit setting | Profit marks results as stale and recalculates **once**, at most a short moment later (several messages in a row cause one recalculation), and only while the profession window is open; otherwise when it next opens |
| Results recalculated | Windows that are open redraw from the stored results |
| Scroll, search, filter, selecting a recipe | Read stored results only; no recalculation |

Profit keeps a reverse index (reagent → recipes that use it), so a price change for one item can recalculate just the recipes that use it. Whether that is worth it over recalculating the open profession is decided once real timings are known; recalculating one profession's list once per price update is cheap.

How Auctionator announces data changes is **(check in game)**: its API documentation lists a "database updated" registration (`Auctionator.API.v1.RegisterForDBUpdate`). Fallback: re-read prices when the profession window opens and after an Auctionator scan finishes.

## 5. Price rules

**Sale price of a crafted item:** its AH price. Milestone 2: the most recent of Auctionator's and our own price, per item; on a same-day tie (Auctionator's age may only be in whole days), our own.

**Reagent cost:** the lowest of its vendor buy price and its AH price.
- Vendor buy price: Auctionator's recorded vendor price (milestone 2: or our own recording). The game only reveals buy prices while a merchant window is open.
- If no vendor price is known, the AH price is used and marked as such; if there is no AH price either, the reagent is "missing".

**Merchant sell price** (for "Sell to vendor instead", later): `sellPrice` from `C_Item.GetItemInfo` (Forever source). Item data may not be loaded yet; then it is requested (`C_Item.RequestLoadItemDataByID`) and filled in on `GET_ITEM_INFO_RECEIVED` (Forever source).

**Profit per craft:** `sale price × output quantity × (1 − AH cut) − sum of reagent costs`.

**Profit per stack** (the side panel's per-stack mode): `profit per craft ÷ output quantity × stack size`, where the stack size is `itemStackCount` from `C_Item.GetItemInfo` (Forever source) for the crafted item. Items that don't stack have a stack size of 1. Profit stores per-item profit and stack size for every recipe, so switching between per craft and per stack only re-sorts the stored results; it never recalculates.
- AH cut: a setting, default 5% (web sources; **check in game**).
- Output quantity: recipes can make more than one item; the recipe data has a minimum and maximum quantity (Forever source: `quantityMin`/`quantityMax` in the trade skill types). A fixed amount (Rough Dynamite ×2, Crafted Light Shot ×200) counts as is; a random range (Heavy Dynamite 1-5) counts at its average, with the range in the tooltip (decided 2026-11-13).
- No listing deposit (refunded on sale; see `FEATURES.md`).
- A recipe with any missing price has no profit number; it is listed as incomplete and sorted below all complete ones, never shown as profitable.

## 6. Saved data

One account-wide saved variable, `ProfitCraftDB`:

```lua
ProfitCraftDB = {
  version  = 1,         -- data layout version; Data.lua upgrades older layouts step by step
  settings = { ... },   -- shared by all characters (includes debug = false, profitMode = "craft" | "stack")
  errors   = { ... },   -- error log: the last 50 caught errors (message, where, time, ProfitCraft version), newest first; repeats of the same error only increase a count
  rulesets = {          -- milestone 2: our own AH data, per ruleset (see below)
    ["<ruleset key>"] = {
      prices = { [itemID] = { price = 1234, qty = 20, time = 1763030400 } },
    },
  },
  vendor = { [itemID] = 125 },   -- milestone 2: our own merchant buy prices (copper per item)
}
```

- 0.1 stores only `version` and `settings`; all prices come from Auctionator.
- Forever has no classic realms: it has 4 rulesets, each a "megaserver" with its own data: Normal, PvP, Roleplay and Roleplay-PvP; all players of a ruleset share one AH (Sylice, 2026-11-13). Prices are kept per ruleset **and faction** (cross-faction AH assumed not shared until confirmed).
- **Ruleset key** = `GetRealmName()` with the instance number ("Realm 7") removed, plus the faction: "CAMWOW US2 Realm 7 PvE" + Alliance → `CAMWOW US2 PvE|Alliance`. Removing only "Realm <number>" merges characters on different instances of the same ruleset, while keeping the rest of the name means Roleplay and Roleplay-PvP (names unknown) can't collide with Normal or PvP. The raw realm name is stored with the data, so the key can be corrected later if Forever's naming turns out different.
- Size limit (milestone 2): prices not updated for a set number of days and not used by any recipe ProfitCraft has seen are removed at login.
- Recipe data is not saved: it is read live when the profession window opens.

## 7. Windows

All windows use Blizzard's standard templates (all present in the Forever source): `ButtonFrameTemplate` / `PortraitFrameTemplate`, `UICheckButtonTemplate`, `UIPanelButtonTemplate`, `InputBoxTemplate`, `MinimalSliderWithSteppersTemplate`, and `WowScrollBoxList` with `MinimalScrollBar` for scrolling lists.

**Side panel (ranked list)**
- Attached to the right edge of Blizzard's profession window (`ProfessionsFrame`; Forever has its own version of it, Forever source), opens and closes with it, can be detached and moved; its position is saved.
- Compact: fixed width of about 320 px in 0.1 (ForeverProfit: 620 px plus a 176 px sidebar). Long names are shortened, full name in the tooltip. A resize grip (Forever source: `PanelResizeButtonTemplate`, `SetResizable`/`SetResizeBounds`) can come later if names get cut off. One row per recipe: icon, name, profit. Detail goes in the hover tooltip, not in extra columns.
- Sorted by profit, incomplete recipes last. Clicking a row selects that recipe in Blizzard's window.
- Header button toggles **per craft / per stack**; the profit column follows it and per-stack rows show the stack size ("×20"). The mode is saved in `settings.profitMode`.
- Uses `WowScrollBoxList`, Blizzard's current scrolling list, which handles row reuse itself (ForeverProfit's hand-made scrolling skipped rows).

**Recipe details block**
- A small block in the recipe details of Blizzard's window (`ProfessionsFrame.CraftingPage.SchematicForm`; Forever has its own layout of it, Forever source): net profit and the cost of each reagent.
- Placed relative to Blizzard's frames, not at hard-coded pixel offsets; how it coexists with other addons that add rows there is tested in game. Sylice's client also runs CraftProfit, whose own panel (`cpPanel`, 304×151) sits in the same recipe-details area (PsiLab, 2026-11-13); disable CraftProfit while testing ProfitCraft, or account for it.

**Settings window**
- Our own window, never Blizzard's settings panel: closing Blizzard's panel always reopens the game menu (Forever source: `SettingsPanelMixin:TransitionBackOpeningPanel` → `ToggleGameMenu()`).
- Closes with Escape by adding its name to `UISpecialFrames` (Forever source).
- Opened by the slash command and a button on the side panel.

## 8. Slash command

`/pcraft` (decided 2026-11-13). Subcommands so far: `/pcraft` (open/close the side panel), `/pcraft debug on|off`, `/pcraft errors` (print the error log; `/pcraft errors clear` empties it). Avoids `/pc` (ProfitCrafter Forever), `/profitcraft` (ProfitCrafting), `/cf` and `/cp` (CraftProfit) and `/fp` (ForeverProfit).

## 9. Own AH scan (milestone 2, outline only)

Decided in detail when milestone 2 starts. Direction:
- Searches only the items ProfitCraft needs (outputs and reagents of known recipes), not the whole AH.
- Started by the user with a button at the AH, never automatically; can be stopped; respects the AH's request limits (`AUCTION_HOUSE_THROTTLED_SYSTEM_READY`, Forever source).
- Records the lowest price, quantity listed and time per item (and the listing detail needed for a "cheapest 20%" average, if that feature is kept).
- Forever has both per-item searches (`C_AuctionHouse.SendSearchQuery` with commodity/item search results) and a full download (`C_AuctionHouse.ReplicateItems`) (Forever source); which suits best is tested then.

## 10. Checks before or during building (in game)

Results from PsiLab (2026-11-13) are in `knowledge/forever-vs-vanilla.md`, "Addon API".

- [x] Interface version on the live client is 16001 (build 1.60.1 (70938)). PsiLab, 2026-11-13.
- [x] Listing recipes: `GetFilteredRecipeIDs` returns only what the window currently lists (it follows the window's search and filters), so ProfitCraft can't use it for a complete ranking. `GetAllRecipeIDs` exists and returns much more per profession. PsiLab, 2026-11-13.
- [x] `GetAllRecipeIDs` returns only the open profession's recipes (learned and unlearned); `GetRecipeInfo(id).learned` separates the learned ones, which match the window's list. PsiLab alpha.1, 2026-11-13.
- [x] Auctionator 346 on Forever: all 21 `Auctionator.API.v1` functions present; `RegisterForDBUpdate` fires after each AH scan; vendor prices are recorded. PsiLab, 2026-11-13.
- [ ] `GetAuctionAgeByItemID` unit: returned 0 for prices from the same day; check again the day after a scan (expected: 1).
- [ ] AH cut on sale is 5%.
- [x] Reading the ruleset: `GetRealmName()` = "CAMWOW US2 Realm 7 PvE" (ruleset at the end), `GetRealmID()` = 6933. PsiLab, 2026-11-13.
- [x] All players of a ruleset share one AH (Sylice, 2026-11-13); key decided above.
- [ ] Is the AH shared between Horde and Alliance? Assumed not. Only matters for 0.2 (own scan data).
- [ ] Is the AH shared between factions (affects the ruleset key)? Sylice is checking.
- [x] Saved variables load and save normally on build 70938 (PsiLab's data survived `/reload`). PsiLab, 2026-11-13.

## 11. Mistakes found in other addons, and our rule against each

From the code review of ForeverProfit v1.8.0 and CraftProfit 0.5.2 (2026-11-13). Every design decision above should be checked against this list.

### ForeverProfit v1.8.0

| # | Mistake | Our rule |
|---|---|---|
| 1 | Recalculates everything far too often: each refresh recalculates every recipe three times, and refreshes run on every mouse-wheel tick and every keystroke in the search box. | Calculate once, re-read many times (section 4). Scrolling, searching, filtering and sorting never recalculate. |
| 2 | Broken scrolling: the rows move with the scrolled content and the data is also shifted by the scroll amount, so scrolling down skips entries (worked out from its `UI.lua`, not yet seen in game). | Use Blizzard's `WowScrollBoxList`, which handles row reuse itself; no hand-made scrolling. |
| 3 | Depends on Auctionator's private code for price history and for starting a scan; any Auctionator update can break it. | Only Auctionator's public API (`Auctionator.API.v1.*`). |
| 4 | No fallback: if its chosen source (TSM) has no price for an item, it never tries another. | Prices are looked up per item across all available sources (section 5). |
| 5 | Data mixed: AH prices aren't separated by realm, and the queue and manual prices are shared by every character. | AH data is stored per ruleset (section 6); each piece of saved data has a deliberate scope (account, ruleset or character). |
| 6 | Errors are swallowed: failures only show in debug mode, so bugs stay hidden. | Errors stay quiet while playing but are always written to the error log, and debug mode shows them in chat (principle 4). |

### CraftProfit 0.5.2

| # | Mistake | Our rule |
|---|---|---|
| 1 | Writes into Blizzard's own file: at every logout it copies its whole database into `Blizzard_Console_SavedVars`, as a workaround for a Forever build that didn't load addon saved data, and still does it after that was fixed. Hides data in a file shared by everyone on the PC, with fragile merge code. | Only our own saved variable (`ProfitCraftDB`). Never write into Blizzard's or another addon's data. If saved data ever fails to load, report it; no hidden workarounds. |
| 2 | Brute-force trainer lookup: calls a game function for every spell ID from 1 to 1,500,000, checking its time limit only every 1,000 IDs. | No brute-force searches over ID ranges. Ask the game for the specific thing; if it can't be found, say so. Long jobs are split into small steps. |
| 3 | "Auto" price source never falls back: it treats Auctionator and TSM as always having data. | A source answers per item ("I have a price for this item, from this time") or "no price"; never "I am available, so I have everything". |
| 4 | Edits Blizzard's recipe list directly for its filter and sort, relying on Blizzard's internal code; a Forever build already broke an earlier hook. | Blizzard's recipe list is never modified (principle 3); sorting lives in our own side panel. |
| 5 | Saved data stored twice (account file and every character's file); its version number is never used for upgrades; history limits differ (30 in memory, 3 saved). | One copy of each piece of data; the version number drives step-by-step upgrades in `Data.lua`; one limit per kind of data, the same in memory and on disk. |
| 6 | Hard-coded pixel positions for Forever's recipe pane, plus guesses about other addons' frames. | Place our frames relative to Blizzard's frames, not at fixed pixel offsets; test alongside other addons in game. |

### Good ideas worth reimplementing (our own code, no copying)

- From ForeverProfit: long jobs split across frames; recipes with missing prices are never shown as profitable.
- From CraftProfit: a private namespace with one event frame and an internal message system; protection against bait listings; per-reagent break-even prices; an AH scan that respects the AH's request limits.

