# ProfitCraft: design

How ProfitCraft is built. **What** it does is in `FEATURES.md`; this file is the **how**. Matches version 0.1-alpha.4 (2026-11-13); sections marked "milestone 2" or "later" are not built yet.

Target: World of Warcraft: Forever, `## Interface: 16001`. API facts marked **(Forever source)** were checked in Blizzard's own Forever UI code (Gethe/wow-ui-source, branch `forever`, build 1.60.1 (70938)); **(PsiLab)** means confirmed in game with PsiLab; **(check in game)** means not confirmed yet.

## 1. Principles

These follow from the problems found in ForeverProfit and CraftProfit; the full list is in section 11.

1. **Calculate once, re-read many times.** Profit is calculated when prices or recipes change, never because the user scrolled, switched mode, or selected a recipe. Those only re-read stored results.
2. **Parts announce changes; they don't call each other.** A price change is announced as a message; whoever cares (profit calculation, windows) listens. Data code never calls window code.
3. **Only public interfaces.** Blizzard's API and Auctionator's public API (`Auctionator.API.v1.*`). Blizzard's frames are never modified; ProfitCraft adds its own frames next to or inside them and follows Blizzard's code only through `hooksecurefunc`/`HookScript` (runs after Blizzard's code, changes nothing of it).
4. **Errors are quiet while playing, but never lost.** Errors in ProfitCraft's code are caught where game events, messages, hooks and clicks are handed to the parts, so they never pop up during normal play. Every caught error is written to a small error log (section 6). With **debug mode** on, they are also printed in chat as they happen. Debug mode: `/pcraft debug on|off` and a checkbox in the settings; off by default. (Decided 2026-11-13.) Blizzard's own Lua error window only appears when the `scriptErrors` setting is on (Forever source: `Blizzard_ScriptErrorsFrame.lua`; it was off on Sylice's client, PsiLab).
5. **Saved data has a version number from day one**, is split by ruleset where prices differ, and has a size limit.
6. **Nothing is assumed from Vanilla, Classic or Retail.** Every API used is checked in the Forever source or in game first.
7. **Blizzard's current look.** Windows, buttons, dropdowns and tabs use Blizzard's current templates, so ProfitCraft looks like the profession window it sits next to (Sylice, 2026-11-13).

## 2. Milestones

| Milestone | Version | Contents | Price sources |
|---|---|---|---|
| 1 | 0.1 | "Version 0.1" and its alphas in `FEATURES.md`; next: alpha.4 with ProfitCraft's own disenchant estimate (section 12) | Auctionator only for AH and merchant prices (all testers have it installed and scan with it) |
| 2 | 0.2 | "Version 0.2": money window (beta.0), own AH scan, own merchant recording, "most recent per item" price choice | Auctionator and our own data; works without Auctionator |
| 3 | 0.3 | "Version 0.3" | Same |

Auctionator is listed as `## OptionalDeps: Auctionator`, not `## Dependencies`, so the structure is already standalone: price lookups go through one price module with one "source" per data provider, and milestone 2 adds sources without changing anything else. Without Auctionator, 0.1 loads normally, says once in chat that it has no price source, and the panel says so too.

Releases are GitHub pre-releases (all of them, finals included; AGENTS.md) at github.com/PsiGaming/ProfitCraft named like `v0.2-beta.N`, with one zip `ProfitCraft-v0.2-beta.N-forever.zip` (the `plan/` folder is left out via `.gitattributes`). Sylice decides version numbers.

## 3. Files and parts

All code shares one private namespace (`local addonName, PC = ...`). The only globals are the saved data (`ProfitCraftDB`), the slash command, and the names of our own windows where Blizzard requires one (Escape-to-close): `ProfitCraftPanel`, `ProfitCraftBags`, `ProfitCraftSettings`.

| File | Part | Job |
|---|---|---|
| `Core.lua` | Core | Namespace, one event frame that hands game events to the parts, a small message system (`PC:Send(msg, ...)` / `PC:Listen(msg, fn)`), debouncing, error log, money formatting (`FormatMoney`; `FormatProfit` adds a green "+" to gains), slash command |
| `Data.lua` | Data | Loads `ProfitCraftDB`, fills default settings, runs version upgrades; `PC:SetSetting` announces `SETTINGS_CHANGED` |
| `Sources/Auctionator.lua` | Source | Wraps Auctionator's public API (AH price, price age, merchant price); announces `PRICES_CHANGED` when Auctionator's data changes and notes that time per realm (`ProfitCraftDB.lastScan`) |
| `Sources/ItemData.lua` | Source | Names, icons, stack sizes and merchant sell prices from Blizzard's item data; requests missing item data once (items that fail to load are not requested again) |
| `Disenchant.lua` | Prices | ProfitCraft's disenchant table (quality × armor/weapon × item level) and the average value of disenchanting one item, priced with AH prices (section 12) |
| `Prices.lua` | Prices | One question for everyone: "what does item X cost / sell for?" Applies the rules in section 5 |
| `Recipes.lua` | Recipes | Reads the open profession's learned recipes and reagents; announces `PROFESSION_OPENED`, `RECIPES_CHANGED`, `PROFESSION_CLOSED` |
| `Profit.lua` | Profit | Calculates and stores one result per recipe; keeps a ranked list per mode |
| `UI/Window.lua` | Window | Shared helpers: window in Blizzard's current frame style, scrolling list, footer |
| `UI/Panel.lua` | Window | The side panel (ranked list) and the ProfitCraft side tab on the profession window; a warning banner above the list when Auctionator is missing, there are no AH prices, or the last scan is 48 hours old or more (Auctionator's whole-day price age until ProfitCraft has seen a scan) |
| `UI/Details.lua` | Window | Profit block in Blizzard's recipe details |
| `UI/Tooltip.lua` | Window | Disenchant line in item tooltips |
| `UI/RecipeTooltip.lua` | Window | Cost and profit lines on trainer tooltips (Spell tooltip data, id = recipe ID) and recipe item tooltips (the ItemSpellTriggerLearn line's spellID = recipe ID); uses `Recipes:Load` and `Profit:Evaluate`. BoP products: no sale lines |
| `UI/Bags.lua` | Window | "D/E Bags": disenchantable items in the bags with disenchant / AH / merchant values |
| `UI/MoneyWindow.lua` | Window | Money window: money and up to 5 tracked currencies, right-click menu (0.2) |
| `UI/BagSpace.lua` | Window | Free bag slots split as (reagent\|normal) on the reagent bag or backpack button |
| `UI/Settings.lua` | Window | The settings page, shown in our own window and in Blizzard's Options > AddOns |
| `Sources/Scan.lua`, `Sources/Merchant.lua` | Source | Milestone 2 (not built): our own AH scan and merchant buy-price recording |

## 4. When things are recalculated

| Event | What happens |
|---|---|
| Profession window opens, recipes change (`TRADE_SKILL_SHOW`, `TRADE_SKILL_LIST_UPDATE`, `NEW_RECIPE_LEARNED`; Forever source) | Recipes re-reads the list: all recipes of the open profession via `C_TradeSkillUI.GetAllRecipeIDs`, keeping those with `GetRecipeInfo(id).learned` (not `GetFilteredRecipeIDs`, which follows the window's search and filters; PsiLab). Opening the window fires about 3 `TRADE_SKILL_LIST_UPDATE` within 0.2 s (PsiLab), so these are combined into one re-read 0.3 s later. Only if the list actually changed: `RECIPES_CHANGED`. `PROFESSION_OPENED` is sent one frame after `TRADE_SKILL_SHOW`, once Blizzard has built its window |
| Auctionator finishes a scan (`Auctionator.API.v1.RegisterForDBUpdate` callback; fires after each scan, PsiLab) | `PRICES_CHANGED` |
| Item data arrives (`GET_ITEM_INFO_RECEIVED` for an item ProfitCraft asked for) | `ITEM_DATA_CHANGED` (combined, 0.3 s) |
| The AH cut setting changes | `SETTINGS_CHANGED`; other settings don't recalculate anything |
| `RECIPES_CHANGED` / `PRICES_CHANGED` / `ITEM_DATA_CHANGED` / AH cut | Profit recalculates **once**, 0.2 s after the last of several messages, and only while a profession window is open |
| Profession window closes (`TRADE_SKILL_CLOSE`) | Recipes and results are dropped, so the next profession opened never shows the previous one's list; reopening reads and calculates afresh |
| Results recalculated | Open windows redraw from the stored results |
| Scroll, switching mode (per craft / per stack / disenchant), selecting a recipe | Re-read stored results only; no recalculation |

A reverse index (reagent → recipes) to recalculate only affected recipes is not built: recalculating one profession's list once per price update is cheap.

## 5. Price rules

**Sale price of a crafted item:** its AH price (Auctionator). Milestone 2: the most recent of Auctionator's and our own price, per item; on a same-day tie (Auctionator's age may only be in whole days), our own.

**Reagent cost:** the lower of its merchant buy price and its AH price (the recipe details and the trainer/recipe tooltips mark each reagent "(Vend)" or "(AH)" in front of its amount, beta.1).
- Merchant buy price: Auctionator's recorded merchant price (milestone 2: or our own recording). The game only reveals buy prices while a merchant window is open. Can be fractional per item (e.g. 4.6c, PsiLab).
- If no merchant price is known, the AH price is used; with neither, the reagent is "missing".
- Basic and automatic reagent slots count (`Enum.CraftingReagentType` Basic = 1, Automatic = 3); optional and finishing reagents don't. A slot that accepts several items uses the cheapest.

**Merchant sell price:** `sellPrice` from `C_Item.GetItemInfo` (Forever source); used in D/E Bags. Item data may not be loaded yet; then it is requested (`C_Item.RequestLoadItemDataByID`) and filled in on `GET_ITEM_INFO_RECEIVED` (Forever source).

**Profit per craft:** `sale price × output quantity × (1 − AH cut) − sum of reagent costs`.

**Profit per stack:** `profit per craft ÷ output quantity × stack size`, where the stack size is `itemStackCount` from `C_Item.GetItemInfo` (Forever source) for the crafted item; items that don't stack have 1.

**Craft and disenchant:** `disenchant value per item × output quantity × (1 − AH cut) − reagent cost` (the materials are sold on the AH). Nil when the product can't be disenchanted. The disenchant value is ProfitCraft's own estimate (`Disenchant.lua`, section 12).

- AH cut: a setting (`ahCut`), default 5% (web sources; **check in game**); no window control yet.
- Output quantity: recipes can make more than one item (Forever source: `quantityMin`/`quantityMax`; e.g. Smelt Bronze ×2, PsiLab). A fixed amount counts as is; a random range (Heavy Dynamite 1-5) counts at its average, with the range in the tooltip (decided 2026-11-13).
- No listing deposit (refunded on sale; see `FEATURES.md`).
- A recipe with any missing price has no profit number; it is listed as incomplete and sorted below all complete ones, never shown as profitable.

## 6. Saved data

One account-wide saved variable, `ProfitCraftDB`:

```lua
ProfitCraftDB = {
  version  = 1,         -- data layout version; Data.lua upgrades older layouts step by step
  settings = {          -- shared by all characters
    debug = false,                -- errors also printed in chat
    profitMode = "craft",         -- side panel mode: "craft" | "stack" | "disenchant"
    ahCut = 0.05,                 -- AH cut on sales
    panelShown = true,            -- side panel open next to the profession window
    tooltipDisenchant = false,    -- disenchant line in item tooltips (off by default from alpha.4, as in Auctionator)
    moneyWindow = false,          -- money window shown (0.2)
    freeSlots = "none",           -- ProfitCraft's free-slot split: "none" | "reagent" (on the reagent bag button) | "backpack" (in place of Blizzard's count); was reagentBagFreeSlots (true -> "reagent") until database version 2 (rc.0)
  },
  money    = { x = 900, y = 500, locked = false, bg = { r = 0, g = 0, b = 0, a = 0.5 }, currencies = { 101, 102 } },
                        -- money window (0.2): top-right corner, lock, background, tracked currency IDs; one list for all characters
  errors   = { ... },   -- error log: the last 50 caught errors (message, where, time, ProfitCraft version), newest first; repeats of the same error only increase a count
  rulesets = {          -- milestone 2: our own AH data, per ruleset (see below)
    ["<ruleset key>"] = {
      prices = { [itemID] = { price = 1234, qty = 20, time = 1763030400 } },
    },
  },
  vendor = { [itemID] = 125 },   -- milestone 2: our own merchant buy prices (copper per item)
}
```

- 0.1 stores only `version`, `settings` and `errors`; all prices come from Auctionator.
- The settings checkbox for Blizzard's own free-bag-space option stores nothing here: it reads and writes Blizzard's game setting `displayFreeBagSlots` (section 7).
- Forever has no classic realms: it has 4 rulesets, each a "megaserver" with its own data: Normal, PvP, Roleplay and Roleplay-PvP; all players of a ruleset share one AH (Sylice, 2026-11-13). Prices are kept per ruleset **and faction** (cross-faction AH assumed not shared until confirmed).
- **Ruleset key** (milestone 2) = `GetRealmName()` with the instance number ("Realm 7") removed, plus the faction: "CAMWOW US2 Realm 7 PvE" + Alliance → `CAMWOW US2 PvE|Alliance`. Removing only "Realm <number>" merges characters on different instances of the same ruleset, while keeping the rest of the name means Roleplay and Roleplay-PvP (names unknown; Sylice's guess: "Roleplay" or "RP") can't collide with Normal or PvP. The raw realm name is stored with the data, so the key can be corrected later.
- Size limit (milestone 2): prices not updated for a set number of days and not used by any recipe ProfitCraft has seen are removed at login.
- Recipe data is not saved: it is read live when the profession window opens.

## 7. Windows

All windows use Blizzard's current templates (all present in the Forever source): `ButtonFrameTemplate` (portrait with ProfitCraft's gold-coin icon, title bar, inset; the same family as the profession window), `UIPanelButtonTemplate`, `UICheckButtonTemplate`, `WowStyle1DropdownTemplate` (with `SetupMenu`/`CreateRadio`), `LargeSideTabButtonTemplate`, and `WowScrollBoxList` with `MinimalScrollBar` for scrolling lists (handles row reuse itself; ForeverProfit's hand-made scrolling skipped rows). The first version used the older `BasicFrameTemplateWithInset`; Sylice asked for the current look (alpha.1).

**Side panel (ranked list)**
- Fixed to the right of Blizzard's profession window (`ProfessionsFrame`), to the right of Forever's own profession side tabs (`ProfessionsOverviewTab`, `Professions1Tab`..`7Tab`, anchored to the window's top-right; Camelot `Blizzard_ProfessionsFrame.xml`). Same height as the window; not movable.
- Shown only with a recipe list: hidden when the trade skill closes and while Forever's professions overview page (`ProfessionsFrame.BookPage`) is shown; back when it closes.
- Compact: 320 px wide (ForeverProfit: 620 px plus a 176 px sidebar). One row per recipe: icon, name (shortened if long), profit. Detail goes in the row tooltip (quantity range, profit per craft and per stack, AH price, reagent cost, craft-and-disenchant, items without a price). Clicking a row opens that recipe (`C_TradeSkillUI.OpenRecipe`).
- Sorted by profit for the chosen mode, incomplete recipes last.
- Header: a **dropdown** for the mode (Per craft / Per stack / Disenchant, with a tooltip per option; saved in `settings.profitMode`), then **D/E Bags** and **Settings** buttons (Settings in the top-right corner). Per-stack rows show the stack size ("x20"). Profits show a green "+" or red "-".
- Footer: profession, number of recipes, how many are priced; "Auctionator not found" without Auctionator.
- The close button hides the panel and remembers it (`settings.panelShown`).

**ProfitCraft side tab** (shows/hides the panel)
- A `LargeSideTabButtonTemplate` tab with the gold-coin icon, lit while the panel is open, on the profession window's right edge.
- Placement: the **next free slot from the bottom**: the lowest slot is 10 px above the window's bottom edge (where What's Training puts its tab by default; `addons/reference/WhatsTraining`, `Crafting/Crafting.lua:197`); if another addon's frame occupies that spot in the tab column, the tab moves up above it, 2 px apart. Re-placed after Blizzard's `RefreshRightTabs` and on every panel update (decided by Sylice, alpha.3).

**Recipe details block**
- In Blizzard's recipe details (`ProfessionsFrame.CraftingPage.SchematicForm`; Camelot layout, 360×484 at Sylice's scale): net profit per craft, craft-and-disenchant (when known), and one line per reagent with its cost and "vendor"/"AH".
- Sits at the **bottom** of the recipe details, 44 px up (clear of Blizzard's Track Recipe checkbox), aligned with the reagents, growing upward. It keeps 36 px free under the reagents for other addons' lines: Auctionator draws "To Craft" and "Profit" lines right under the reagents, which overlapped ProfitCraft's first placement (Sylice's screenshots, alpha.0). Lines that don't fit are left out; hidden when the recipe has no basic reagents.
- Follows the selected recipe with `hooksecurefunc(SchematicForm, "Init")`.

**Item tooltips**
- A "Disenchant" line on item tooltips (`TooltipDataProcessor.AddTooltipPostCall` for item tooltips, item ID from `tooltipData.id`; Forever source). On/off in the settings, off by default (alpha.4). Shown as "Disenchant (est.)".

**D/E Bags window** (`/pcraft bags`, or the panel's D/E Bags button)
- Movable `ButtonFrameTemplate` window, closes with Escape. Lists every disenchantable item in the bags (backpack, bags 1-4 and reagent bag: `Enum.BagIndex.Backpack` .. `NUM_TOTAL_EQUIPPED_BAG_SLOTS`), combined per item, with disenchant value, AH price (none for soulbound items) and merchant price per item; the option that pays most after the AH cut is marked. Refreshes on `BAG_UPDATE_DELAYED` and price changes.

**Free bag slots** (rc.0; replaced alpha.0's reagent bag count)
- Blizzard's count on the backpack (Options > Interface, "Show Free Bag Space", game setting `displayFreeBagSlots`; `C_Container.CalculateTotalNumberOfFreeBagSlots()`) is one total that includes the reagent bag (Sylice in game, 2026-11-17). ProfitCraft splits that total as "(reagent|normal)": reagent = the reagent bag's free slots, normal = Blizzard's total minus that, so the two always add up to Blizzard's number. Order as on the bag bar (reagent bag on the left, Sylice). Without a reagent bag: "(normal)".
- One settings dropdown sets both Blizzard's setting and ours (`freeSlots`): Off (Blizzard off, `none`), Blizzard only (on, `none`), ProfitCraft + Blizzard (on, `reagent`: the split on `CharacterReagentBag0Slot`, nothing there without a reagent bag), ProfitCraft only (on, `backpack`: the split on `MainMenuBarBackpackButton`).
- "ProfitCraft only" hides Blizzard's count by setting its text (`MainMenuBarBackpackButton.FreeSlots`) to alpha 0 and **keeps Blizzard's setting on**, so Blizzard's count is back as soon as ProfitCraft is disabled or removed (Sylice's requirement). Blizzard only shows/hides that text (`MainMenuBarBackpackMixin:SetCountShown`, Forever source `Blizzard_MainMenuBarBagButtons/Shared/MainMenuBarBagButtons.lua`), never changes its alpha. Restored to alpha 1 when another choice is picked.
- Styled like Blizzard's count (`NumberFontNormal`, "(n)", 10 px below centre), drawn on our own overlay frames. Updates one frame after `BAG_UPDATE_DELAYED`, like Blizzard's own count.

**Money window** (0.2-beta.0, Sylice 2026-11-17)
- One row, no border: money on the right (`PC:FormatMoney(GetMoney())`), up to 5 tracked currencies to its left (icon + amount, `C_CurrencyInfo.GetCurrencyInfo`), each new one further left. Anchored by its **top-right corner**, so it grows leftwards; after a drag it is re-anchored the same way. Updates on `PLAYER_MONEY` and `CURRENCY_DISPLAY_UPDATE`. Hovering a currency shows Blizzard's tooltip (`GameTooltip:SetCurrencyByID`).
- Off by default: settings checkbox "Money window", `/pcraft money`, or "Hide" in its menu.
- Right-click anywhere (also on a currency): **Add currency** (submenu: the character's Currency tab list, `C_CurrencyInfo.GetCurrencyListSize/GetCurrencyListInfo`, headers skipped, already tracked ones left out; disabled at 5; currencies in sections collapsed in the Currency tab aren't in the game's list, and ProfitCraft says so rather than opening them), **Remove currency**, **Lock/Unlock position** (locked: dragging does nothing), **Background colour...** (Blizzard's colour picker with opacity: `ColorPickerFrame:SetupColorPickerAndShow`, `hasOpacity`; Cancel restores), **Hide**. Menus: `MenuUtil.CreateContextMenu` (Forever's character window uses it).
- Saved account-wide in `ProfitCraftDB.money` (section 6); a tracked currency the current character doesn't have shows 0.

**Settings**
- One list of options, built into two identical pages (approach seen in Questie, `addons/reference/Questie`, `Modules/Options/QuestieOptionsEngine.lua`; our own code):
  - ProfitCraft's own movable window (`/pcraft settings`, or the panel's Settings button). Closing it just closes it: it never goes through Blizzard's settings panel, whose close always reopens the game menu (Forever source: `SettingsPanelMixin:TransitionBackOpeningPanel` → `ToggleGameMenu()`). Closes with Escape (`UISpecialFrames`).
  - The same page under Blizzard's Options > AddOns > ProfitCraft (`Settings.RegisterCanvasLayoutCategory` + `Settings.RegisterAddOnCategory`, Forever source). Closing that returns to the game menu, which is where the user came from.
- Each page re-reads the values when shown and after any change (`SETTINGS_CHANGED`, and `CVAR_UPDATE` for the mirrored game setting), so the two never disagree.
- Options (beta.0), in three sections separated by divider lines: (1) price warning age slider and disenchant tooltip line, (2) free bag slots (a dropdown since rc.0), (3) money window (0.2), (4) debug mode. Details: disenchant line in item tooltips (off by default from alpha.4; existing installs keep their saved choice); price warning age (slider Off/1/2/3/4 days, default 2; Blizzard's `MinimalSliderWithSteppersTemplate`); free bag slots (dropdown: Off / Blizzard only / ProfitCraft + Blizzard / ProfitCraft only, default Off; writes Blizzard's `displayFreeBagSlots` with `C_CVar` and ProfitCraft's `freeSlots`, see "Free bag slots" above); debug mode (off).

## 8. Slash command

`/pcraft` (decided 2026-11-13). Avoids `/pc` (ProfitCrafter Forever), `/profitcraft` (ProfitCrafting), `/cf` and `/cp` (CraftProfit) and `/fp` (ForeverProfit).

| Command | Does |
|---|---|
| `/pcraft` | Show or hide the side panel (with a profession window open) |
| `/pcraft settings` | Open or close the settings window |
| `/pcraft bags` | Open or close the D/E Bags window |
| `/pcraft money` | Show or hide the money window |
| `/pcraft tooltip on\|off` | Disenchant line in item tooltips |
| `/pcraft debug on\|off` | Print errors in chat as they happen |
| `/pcraft errors` | List logged errors; `/pcraft errors clear` empties the log |
| anything else | Version and the command list |

## 9. Own AH scan (milestone 2, outline only)

Decided in detail when milestone 2 starts. Direction:
- Searches only the items ProfitCraft needs (outputs and reagents of known recipes), not the whole AH.
- Started by the user with a button at the AH, never automatically; can be stopped; respects the AH's request limits (`AUCTION_HOUSE_THROTTLED_SYSTEM_READY`, Forever source).
- Records the lowest price, quantity listed and time per item (and the listing detail needed for a "cheapest 20%" average, if that feature is kept).
- Forever has both per-item searches (`C_AuctionHouse.SendSearchQuery` with commodity/item search results) and a full download (`C_AuctionHouse.ReplicateItems`) (Forever source); which suits best is tested then.

## 10. Checks before or during building (in game)

Results from PsiLab (2026-11-13) are in `knowledge/forever-vs-vanilla.md`, "Addon API".

- [x] Interface version on the live client is 16001 (build 1.60.1 (70938)). PsiLab, 2026-11-13.
- [x] Listing recipes: `GetFilteredRecipeIDs` returns only what the window currently lists (it follows the window's search and filters); `GetAllRecipeIDs` returns all recipes of the open profession, learned and unlearned; `GetRecipeInfo(id).learned` separates the learned ones. PsiLab, 2026-11-13.
- [x] Auctionator 346 on Forever: all 21 `Auctionator.API.v1` functions present; `RegisterForDBUpdate` fires after each AH scan; merchant prices are recorded. PsiLab, 2026-11-13.
- [x] Auctionator's disenchant prices don't work on Forever: Auctionator 346 treats Forever as Retail and its Retail D/E code only knows WoD to Shadowlands items. Sylice in game and Auctionator's code, 2026-11-13. See section 12.
- [x] Saved variables load and save normally on build 70938. PsiLab, 2026-11-13.
- [x] Reading the ruleset: `GetRealmName()` = "CAMWOW US2 Realm 7 PvE" (ruleset at the end), `GetRealmID()` = 6933. PsiLab, 2026-11-13.
- [x] All players of a ruleset share one AH (Sylice, 2026-11-13).
- [x] ProfitCraft's windows, dropdown, side tab, settings in Blizzard's AddOns options and reagent bag count work in game (Sylice, alpha.1-alpha.2, 2026-11-13).
- [x] Own disenchant estimate and material list, trainer and recipe item tooltips, BoP handling work in game (Sylice, alpha.4-alpha.5, 2026-11-14).
- [ ] `GetAuctionAgeByItemID` unit: returned 0 for prices from the same day; check again the day after a scan (expected: 1).
- [ ] AH cut on sale is 5%.
- [ ] Is the AH shared between Horde and Alliance? Assumed not. Only matters for 0.2 (own scan data).
- [x] Blizzard's free-bag-space number on the backpack also counts the reagent bag (Sylice in game, 2026-11-17). Led to the rc.0 split.
- [ ] 0.2-beta.0 in game: which currencies Forever has and whether they appear in the Add currency list; the colour picker's opacity slider changes the background live.
- [ ] rc.0 in game: "(6|24)" fits on the reagent bag button; "ProfitCraft only" really hides Blizzard's count (relies on Forever loading `Shared/MainMenuBarBagButtons.lua`, inferred from its `.toc`, where camelot-specific files are separate) and it returns when another choice is picked.
- [x] Disenchant: item level decides the materials (Forever client's table is ordered by item level, forevermastery.com; all Classic sources agree). 2026-11-13, section 12.
- [x] Essences convert both ways (3 lesser <-> 1 greater), repeatedly. Sylice in game, 2026-11-13.
- [ ] Disenchant odds on Forever match the Classic table (section 12; quick check: a green weapon of item level 21-30 gives Greater Magic Essence, not Astral).

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


## 12. Disenchant values (alpha.4, built 2026-11-13)

### Why Auctionator can't be the source
- ProfitCraft 0.1 used `Auctionator.API.v1.GetDisenchantPriceByItemID` / `...ByItemLink`. On Forever both return nothing for every item.
- Cause (Auctionator 346's code, 2026-11-13): `Source/Constants/Main.lua:56` sets `IsRetail` for Forever ("temporary fix assigning retail to mainline"), so Forever loads Auctionator's Retail disenchant code (`Source_Mainline/Enchant/`), which has tables only for WoD, Legion, BfA and Shadowlands items. Forever items count as original-expansion items, so the lookup returns nothing. That matches the "WoD, Legion, BfA & Shadowlands only" setting text Sylice saw. Auctionator's Classic table (`Source_Classic/Enchant/`) exists but is not loaded on Forever. If Auctionator fixes this, its values may start working; ProfitCraft keeps its own either way.
- **Decision (Sylice, 2026-11-13): no separate addon; ProfitCraft builds its own estimate.**

### What ProfitCraft does (`Disenchant.lua`)
1. Reads quality, item level and item class with `C_Item.GetItemInfo` (from the exact link when there is one).
2. Only green, blue and purple armor and weapons; anything else, or an item level outside the table, gives no value.
3. Finds the row for quality × armor/weapon × **item level**. Each row lists material, chance %, min and max amount (each amount equally likely).
4. Value = sum over materials of AH price × chance × (min + max) / 2, rounded to whole copper. If any material has no AH price, there is no value (as with recipes: never show an incomplete number).
5. Essences: 3 lesser ↔ 1 greater convert both ways (Sylice in game), so each counts at whichever form sells for more: lesser = max(lesser, greater / 3), greater = max(greater, 3 × lesser); if only one form has a price, the other is derived from it.
6. Used by the tooltip line (off by default, as in Auctionator), D/E Bags and the craft-and-disenchant mode. Labelled "(est.)".

### Where the table comes from
Typed in by us from public game facts; no code copied from Auctionator (All Rights Reserved) or Disenchant Buddy (GPLv3).
- Base: [Warcraft Wiki "Disenchanting tables"](https://warcraft.wiki.gg/wiki/Disenchanting_tables) (by item level), which matches [foreverdb.net enchanting](https://foreverdb.net/profession/enchanting) (labelled "Classic data").
- Cross-checked row by row against the Classic tables of Auctionator and Disenchant Buddy; where they differ, the majority wins:
  - Green weapons, item level 21-30: **Greater Magic Essence** (both addons) instead of the wiki's Astral essences.
  - Green weapons, item level 51-65: dust 20% / essence 75% / shard 5% (adds up to 100%; the wiki has 22/75/3, Auctionator 22/75/5).
  - Purple armor 61-92: 1-2 Nexus Crystals, even split (wiki and Auctionator). Purple weapons 61-92: 33% one, 67% two (all three).
  - Blue 56-86: Large Brilliant Shard 99.5%, Nexus Crystal 0.5% (Disenchant Buddy's Classic rows). The wiki's rows above item level 65 use TBC materials that don't exist at level 60, so they are not used.
- Item level, not required level: the Forever client's table is ordered by item level ([forevermastery.com](https://forevermastery.com/en/tools/disenchant)); wow-professions.com's required-level brackets are the same table shifted by 5.
- Ranges covered: green 1-65, blue 1-86, purple 40-92.
- Not yet confirmed for Forever: the odds and amounts (the server rolls the loot; the client does not contain it).

### Later
- Confirm the odds with real disenchants (quick check: a green weapon of item level 21-30).
- Possibly learn from the player's own disenchants (switch to own odds after enough samples, as ForeverForge Auction and Forever Simple Market do).
