# ProfitCraft: design

How ProfitCraft is built. **What** it does is in `FEATURES.md`; what was done and when, including designs that were later replaced, is in `WORKLOG.md`. This file describes version `0.3.9`.

Target: World of Warcraft: Forever, `## Interface: 16001`. API facts marked **(Forever source)** were checked in Blizzard's own Forever UI code (Gethe/wow-ui-source, branch `forever`, build 1.60.1 (70938)); **(PsiLab)** means confirmed in game with PsiLab; **(check in game)** means not confirmed yet.

## 1. Principles

These follow from the problems found in ForeverProfit and CraftProfit; the full list is in section 11.

1. **Calculate once, re-read many times.** Profit is calculated when prices or recipes change, never because the user scrolled, switched mode, or selected a recipe. Those only re-read stored results.
2. **Parts announce changes; they don't call each other.** A price change is announced as a message; whoever cares (profit calculation, windows) listens. Data code never calls window code.
3. **Only public interfaces** where possible: Blizzard's API and Auctionator's public API (`Auctionator.API.v1.*`). Blizzard's frames are never modified; ProfitCraft adds its own frames next to or inside them and follows Blizzard's code only through `hooksecurefunc`/`HookScript` (runs after Blizzard's code, changes nothing of it). The few uses of Auctionator internals (scan hooks, price history; sections 9 and 13) are wrapped so a change in Auctionator only switches that feature off.
4. **Errors are quiet while playing, but never lost.** Errors in ProfitCraft's code are caught where game events, messages, hooks and clicks are handed to the parts (`PC:Call`), so they never pop up during normal play. Every caught error is written to a small error log (section 6). With **debug mode** on, they are also printed in chat as they happen. Blizzard's own Lua error window only appears when the `scriptErrors` setting is on (Forever source: `Blizzard_ScriptErrorsFrame.lua`; it was off on the author's client, PsiLab).
5. **Saved data has a version number**, is split by ruleset where prices differ, and has a size limit.
6. **Nothing is assumed from Vanilla, Classic or Retail.** Every API used is checked in the Forever source or in game first.
7. **Blizzard's current look.** Windows, buttons, dropdowns and tabs use Blizzard's current templates, so ProfitCraft looks like the profession window it sits next to (2026-11-13).

## 2. Milestones

| Milestone | Contents | State |
|---|---|---|
| 0.1 | Profit list, recipe details, tooltips, own disenchant estimate | Done (closed at `0.1-rc.0`) |
| 0.2 | Currencies bar, own AH scan data, pricing rules, RapidFire | Done (`0.2`); own merchant recording and the gear sale-price rule were planned but not built |
| 0.3 | On Sale, AH tabs, Recipes panel, settings pages | Done (last `0.3.9`) |
| 0.4 | 0.4.0: Opportunities (Vendor finds, On Sale moved in; section 16); profit list: AH or vendor, search box, Shift tooltip, 10 for non-stacking products (section 17). Later in 0.4: item tooltip prices | Current (`0.4.0-beta.10`, in testing) |

Auctionator is listed as `## OptionalDeps: Auctionator`, not `## Dependencies`: price lookups go through one price module (`Prices.lua`) with one source per data provider. Without Auctionator, prices come from ProfitCraft's own full scan (section 9) and merchant prices are unknown.

Releases: GitHub pre-releases, tag `v0.4.0-beta.10`, zip `ProfitCraft-0.4.0-beta.10-forever.zip` built with `git archive --prefix=ProfitCraft/` (`plan/`, `.gitattributes` and `.editorconfig` are left out via `.gitattributes`). The author decides version numbers.

## 3. Files and parts

All code shares one private namespace (`local addonName, PC = ...`). The only globals are the saved data (`ProfitCraftDB`), the slash command, and the names of our own windows where Blizzard requires one (Escape-to-close, `UISpecialFrames`): `ProfitCraftPanel`, `ProfitCraftBags`, `ProfitCraftSettings`, `ProfitCraftRapidFire`, `ProfitCraftOnSale`, `ProfitCraftRecipes`, plus their popups and edit boxes (`ProfitCraftRapidFire*`, `ProfitCraftOnSale*`).

| File | Part | Job |
|---|---|---|
| `Core.lua` | Core | Namespace, one event frame that hands game events to the parts, a small message system (`PC:Send(msg, ...)` / `PC:Listen(msg, fn)`), debouncing, error log, money formatting (`FormatMoney`; `FormatProfit` adds a green "+" to gains), slash command |
| `Data.lua` | Data | Loads `ProfitCraftDB`, fills default settings, runs version upgrades; `PC:SetSetting` announces `SETTINGS_CHANGED` |
| `Sources/Auctionator.lua` | Source | Wraps Auctionator's public API (AH price, price age, merchant price); announces `PRICES_CHANGED` when Auctionator's data changes and notes that time per realm (`ProfitCraftDB.lastScan`) |
| `Sources/ItemData.lua` | Source | Names, icons, stack sizes and merchant sell prices from Blizzard's item data; requests missing item data once (items that fail to load are not requested again) |
| `Prices.lua` | Prices | One question for everyone: "what does item X cost / sell for?" Applies the rules in sections 5 and 9 |
| `Scan.lua` | Data | AH scan data (section 9): follows Auctionator's scans or runs its own full scan (button on the AH window), keeps the snapshot of recipe items, hands listings to On Sale |
| `History.lua` | Prices | Own price history per item and variant, usual price, Auctionator fallback (section 13) |
| `OnSale.lua` | Data | On Sale: watched searches (parse, run, pace), modes, hit check, hit list upkeep (section 13) |
| `Disenchant.lua` | Prices | ProfitCraft's disenchant table (quality × armor/weapon × item level) and the average value of disenchanting one item, priced with AH prices (section 12) |
| `Recipes.lua` | Recipes | Reads the open profession's learned recipes and reagents; announces `PROFESSION_OPENED`, `RECIPES_CHANGED`, `PROFESSION_CLOSED` |
| `Profit.lua` | Profit | Calculates and stores one result per recipe; keeps a ranked list per mode; `Profit:Evaluate` for single recipes (tooltips, Recipes panel) |
| `UI/Window.lua` | Window | Shared helpers: window in Blizzard's current frame style, scrolling list (`PC:CreateScrollList`), footer |
| `UI/Panel.lua` | Window | The side panel (ranked list), its "Profitable only" row and warning banner, and the ProfitCraft side tab on the profession window |
| `UI/Details.lua` | Window | Profit block in Blizzard's recipe details |
| `UI/Tooltip.lua` | Window | Disenchant line in item tooltips |
| `UI/RecipeTooltip.lua` | Window | Cost and profit lines on trainer tooltips (Spell tooltip data, id = recipe ID) and recipe item tooltips (the ItemSpellTriggerLearn line's spellID = recipe ID); uses `Recipes:Load` and `Profit:Evaluate`. BoP products: no sale lines |
| `UI/Bags.lua` | Window | "D/E Bags": disenchantable items in the bags with disenchant / AH / merchant values |
| `UI/BagSpace.lua` | Window | Free bag slots split as (reagent\|normal) on the reagent bag or backpack button |
| `UI/MoneyWindow.lua` | Window | Currencies bar (code name: money window): money and up to 5 tracked currencies, right-click menu |
| `UI/AHTabs.lua` | Window | The column of ProfitCraft's tabs at the AH window's right edge, one panel open at a time (section 14) |
| `UI/Rapid.lua` | Window | RapidFire: AH tab, watch list panel, live commodity searches, deal popup with the buy key, purchase with quote check, history panel (section 15) |
| `UI/OnSale.lua` | Window | On Sale AH tab and panel (Finds, Searches), search editor, buy dialog (section 13) |
| `UI/AHRecipes.lua` | Window | Recipes AH tab and panel (section 14) |
| `UI/Settings.lua` | Window | The settings, in three pages, shown in our own window and in Blizzard's Options > AddOns |

Planned but never made: `Sources/Merchant.lua` (our own merchant buy-price recording).

| File | Part | Job |
|---|---|---|
| `Vendor.lua` | Data | Vendor finds: full-scan collector (listings below vendor price), the find list, the chat line (section 16) |
| `UI/Vendor.lua` | Window | The Vendor page of the Opportunities panel (section 16) |

## 4. When things are recalculated

| Event | What happens |
|---|---|
| Profession window opens, recipes change (`TRADE_SKILL_SHOW`, `TRADE_SKILL_LIST_UPDATE`, `NEW_RECIPE_LEARNED`; Forever source) | Recipes re-reads the list: all recipes of the open profession via `C_TradeSkillUI.GetAllRecipeIDs`, keeping those with `GetRecipeInfo(id).learned` (not `GetFilteredRecipeIDs`, which follows the window's search and filters; PsiLab). Opening the window fires about 3 `TRADE_SKILL_LIST_UPDATE` within 0.2 s (PsiLab), so these are combined into one re-read 0.3 s later. Only if the list actually changed: `RECIPES_CHANGED`. `PROFESSION_OPENED` is sent one frame after `TRADE_SKILL_SHOW`, once Blizzard has built its window |
| Auctionator finishes a scan (`Auctionator.API.v1.RegisterForDBUpdate` callback; fires after each scan, PsiLab), or ProfitCraft finishes reading a scan | `PRICES_CHANGED` |
| Item data arrives (`GET_ITEM_INFO_RECEIVED` for an item ProfitCraft asked for) | `ITEM_DATA_CHANGED` (combined, 0.3 s) |
| The AH cut setting changes | `SETTINGS_CHANGED` |
| `RECIPES_CHANGED` / `PRICES_CHANGED` / `ITEM_DATA_CHANGED` / AH cut | Profit recalculates **once**, 0.2 s after the last of several messages, and only while a profession window is open |
| Profession window closes (`TRADE_SKILL_CLOSE`) | Recipes and results are dropped, so the next profession opened never shows the previous one's list; reopening reads and calculates afresh |
| Results recalculated | Open windows redraw from the stored results |
| Scroll, switching mode (per craft / per stack / disenchant), "Profitable only", selecting a recipe | Re-read stored results only; no recalculation |

A reverse index (reagent → recipes) to recalculate only affected recipes is not built: recalculating one profession's list once per price update is cheap.

## 5. Price rules

**Sale price of a crafted item:** its AH price: the most recent of Auctionator's and our own scan's price, per item; on a same-day tie (Auctionator's age may only be in whole days), our own (`Prices.lua`; the scan rules are in section 9).

**Reagent cost:** the lower of its merchant buy price and its AH cost for the needed quantity (the recipe details and the trainer/recipe tooltips mark each reagent "(Vend)" or "(AH)" in front of its amount).
- Merchant buy price: Auctionator's recorded merchant price (`GetVendorPriceByItemID`). The game only reveals buy prices while a merchant window is open. Can be fractional per item (e.g. 4.6c, PsiLab).
- If no merchant price is known, the AH price is used; with neither, the reagent is "missing".
- Basic and automatic reagent slots count (`Enum.CraftingReagentType` Basic = 1, Automatic = 3); optional and finishing reagents don't. A slot that accepts several items uses the cheapest.

**Merchant sell price:** `sellPrice` from `C_Item.GetItemInfo` (Forever source); used in D/E Bags. Item data may not be loaded yet; then it is requested (`C_Item.RequestLoadItemDataByID`) and filled in on `GET_ITEM_INFO_RECEIVED` (Forever source).

**Profit per craft:** `sale price × output quantity × (1 − AH cut) − sum of reagent costs`.

**Profit per stack:** `profit per craft ÷ output quantity × stack size`, where the stack size is `itemStackCount` from `C_Item.GetItemInfo` (Forever source) for the crafted item; items that don't stack have 1. Reagents are costed for the quantity a stack needs (section 9).

**Craft and disenchant:** `disenchant value per item × output quantity × (1 − AH cut) − reagent cost` (the materials are sold on the AH). Nil when the product can't be disenchanted (section 12).

- AH cut: a setting (`ahCut`), default 5% (web sources; **check in game**); no window control.
- Output quantity: recipes can make more than one item (Forever source: `quantityMin`/`quantityMax`; e.g. Smelt Bronze ×2, PsiLab). A fixed amount counts as is; a random range counts at its average, with the range in the tooltip.
- No listing deposit (refunded on sale; see `FEATURES.md`).
- A recipe with any missing price has no profit number; it is listed as incomplete and sorted below all complete ones, never shown as profitable.

## 6. Saved data

One account-wide saved variable, `ProfitCraftDB`:

```lua
ProfitCraftDB = {
  version  = 4,         -- data layout version; Data.lua upgrades older layouts step by step
  settings = {          -- shared by all characters; the full list with defaults is DEFAULT_SETTINGS in Data.lua
    debug = false,                -- errors also printed in chat
    profitMode = "craft",         -- side panel mode: "craft" | "stack" | "disenchant"
    ahCut = 0.05,                 -- AH cut on sales
    panelShown = true,            -- side panel open next to the profession window
    profitableOnly = false,       -- side panel: only recipes with a known profit above 0
    tooltipDisenchant = false,    -- disenchant line in item tooltips
    moneyWindow = false,          -- currencies bar shown
    freeSlots = "none",           -- ProfitCraft's free-slot split: "none" | "reagent" (on the reagent bag button) | "backpack" (in place of Blizzard's count)
    staleDays = 2,                -- price warning age in days, 0 = off
    crumbPercent = 1,             -- crumb limit, % of units listed (section 9)
    onSaleMode = "off",           -- "off" | "manual" | "auto"
    -- On Sale (section 13): onSaleGear = 70, onSaleReagent = 45, onSaleMinProfit = 5000, onSaleMaxProfit = -1 (Auto),
    -- onSaleInterval = 10, onSaleSound = true, onSaleGlow = true, historyReminder = true
    summaryScanWarning = true,    -- notice when Auctionator runs a summary scan
    recipesProfitMode = "stack", recipesHideKnown = false,  -- Recipes panel at the AH
    ahTabSize = 24,               -- AH tab icon size in px, 24-44
  },
  money    = { x = 900, y = 500, locked = false, bg = { r = 0, g = 0, b = 0, a = 0.5 }, currencies = { 101, 102 } },
                        -- currencies bar: top-right corner, lock, background, tracked currency IDs; one list for all characters
  errors   = { ... },   -- error log: the last 50 caught errors (message, where, time, ProfitCraft version), newest first; repeats of the same error only increase a count
  lastScan = { ["<realm>"] = time },  -- time of the last Auctionator scan seen, for the price warning banner
  snapshot = {          -- the latest detailed scan, per ruleset key, overwritten by each scan (section 9)
    ["<ruleset key>"] = {
      time   = 1763030400,
      levels = { [itemID] = { { 120, 400 }, { 125, 80 } } },  -- recipe items only: {price per unit, quantity}, cheapest first, capped
      totals = { [itemID] = 480 },                              -- all units listed (for the crumb limit)
    },
  },
  recipeItems  = { [itemID] = true },      -- reagents and products of all recipes seen on the account (what the snapshot keeps)
  recipeOfItem = { [itemID] = recipeID },  -- recipe item -> recipe it teaches (Recipes panel)
  rapidFire = { items = { ... }, minBalance = 2500, interval = 5, sound = true, key = "SPACE", tolerance = 0 },
  onSale = {            -- one list for the account (section 13)
    searches = { { name = "Mail 20-30 Knight", term = 'of the Knight;Armor/Mail;;;20;30;;;;;2;;;', on = true } },
    nextID = 2,
  },
  history = {           -- per ruleset key (section 13)
    ["<ruleset key>"] = { ["<itemID>:<variant>"] = { today = { day = 20411, [14] = 4200, ... }, days = { [20410] = 4300, ... } } },
  },
  scanDays = { ["<ruleset key>"] = { [<local day>] = true } },  -- days with a full scan read (history notice)
}
```

- Upgrades (`Data.lua`): 2 = `reagentBagFreeSlots` (true) -> `freeSlots = "reagent"`; 3 = On Sale defaults 65 / 40 -> 70 / 45, `scanWarning` -> `summaryScanWarning` + `historyReminder`; 4 = `onSaleEnabled` -> `onSaleMode` ("auto" / "off").
- The free-bag-slots dropdown also writes Blizzard's own game setting `displayFreeBagSlots` (section 7), which is not stored here.
- Forever has no classic realms: it has 4 rulesets, each a "megaserver" with its own data: Normal, PvP, Roleplay and Roleplay-PvP; all players of a ruleset share one AH (2026-11-13). Prices are kept per ruleset **and faction** (cross-faction AH assumed not shared until confirmed).
- **Ruleset key** = `GetRealmName()` with the instance number ("Realm 7") removed, plus the faction: "CAMWOW US2 Realm 7 PvE" + Alliance → `CAMWOW US2 PvE|Alliance`. Removing only "Realm <number>" merges characters on different instances of the same ruleset, while keeping the rest of the name means Roleplay and Roleplay-PvP (names unknown; the author's guess: "Roleplay" or "RP") can't collide with Normal or PvP. The raw realm name is stored with the data, so the key can be corrected later.
- Size: the snapshot holds only recipe items and is replaced by every scan, so it doesn't grow. The price history keeps 14 days (section 13; estimated 1-3 MB; check the real size after a week of use).
- Recipe data is not saved: it is read live when the profession window opens.

## 7. Windows

All windows use Blizzard's current templates (all present in the Forever source): `ButtonFrameTemplate` (portrait with ProfitCraft's gold-coin icon, title bar, inset; the same family as the profession window), `UIPanelButtonTemplate`, `UICheckButtonTemplate`, `WowStyle1DropdownTemplate` (with `SetupMenu`/`CreateRadio`), `LargeSideTabButtonTemplate`, and `WowScrollBoxList` with `MinimalScrollBar` for scrolling lists (handles row reuse itself; ForeverProfit's hand-made scrolling skipped rows). `PC:CreateWindow` creates windows hidden.

**Side panel (ranked list)**
- Fixed to the right of Blizzard's profession window (`ProfessionsFrame`), to the right of Forever's own profession side tabs (`ProfessionsOverviewTab`, `Professions1Tab`..`7Tab`, anchored to the window's top-right; Camelot `Blizzard_ProfessionsFrame.xml`). Same height as the window; not movable.
- Shown only with a recipe list: hidden when the trade skill closes and while Forever's professions overview page (`ProfessionsFrame.BookPage`) is shown; back when it closes.
- Compact: 320 px wide. One row per recipe: icon, name (shortened if long), profit. Detail goes in the row tooltip (quantity range, profit per craft and per stack, AH price, reagent cost, craft-and-disenchant, items without a price). Clicking a row opens that recipe (`C_TradeSkillUI.OpenRecipe`).
- Sorted by profit for the chosen mode, incomplete recipes last.
- **Click a row:** `ProfessionsFrame.CraftingPage.RecipeList:SelectRecipe(C_TradeSkillUI.GetRecipeInfo(recipeID), true)`, as Blizzard's own list selects: the row is selected and scrolled to, the list fires `ProfessionsRecipeListMixin.Event.OnRecipeSelected` and the crafting page shows it (`Blizzard_ProfessionsRecipeList.lua:138-183`, `Blizzard_ProfessionsCrafting.lua:436`). It returns nothing when the recipe isn't in Blizzard's list (hidden by its search or filters); then `C_TradeSkillUI.OpenRecipe`. Why not `OpenRecipe` first: in game it did nothing for 10-20 s after the window opened, with `IsDataSourceChanging()` false and Blizzard's own list working at once (2026-11-24; the cause inside the game isn't known). Crafting isn't restricted on Forever (no `HasRestrictions` in `TradeSkillUIDocumentation.lua`; ForeverProfit calls `CraftRecipe` from its own code), so selecting from addon code shouldn't block Blizzard's Create button: to confirm in game. Selecting this way works at once (confirmed in game, 2026-11-24).
- Header: a **dropdown** for the mode (Per craft / Per stack / Disenchant, with a tooltip per option; saved in `settings.profitMode`), then **D/E Bags** and **Settings** buttons (Settings in the top-right corner). Per-stack rows show the stack size ("x20"). Profits show a green "+" or red "-".
- **"Profitable only"** checkbox in a row at the top of the list (`profitableOnly`): hides recipes without a known profit above 0 in the chosen mode; "n of m" on the right. The header row was full and the footer's status line needs its width, so the list starts 24 px lower; the warning banner sits below the row. Forever's menus also support checkbox entries (`CreateCheckbox`, Camelot ReputationFrame.lua), but a menu entry is easy to miss.
- **Warning banner** above the list: no AH prices yet (without Auctionator and without a snapshot: points to the Full scan button), or the newest scan (Auctionator's, noted in `lastScan`, or our own) is older than the `staleDays` setting; until ProfitCraft has seen a scan, Auctionator's whole-day price age is used.
- Footer: profession, number of recipes, how many are priced.
- The close button hides the panel and remembers it (`settings.panelShown`).

**ProfitCraft side tab** (shows/hides the panel)
- A `LargeSideTabButtonTemplate` tab with the gold-coin icon, lit while the panel is open, on the profession window's right edge.
- Placement: the **next free slot from the bottom**: the lowest slot is 10 px above the window's bottom edge (where What's Training puts its tab by default; `addons/reference/WhatsTraining`, `Crafting/Crafting.lua:197`); if another addon's frame occupies that spot in the tab column, the tab moves up above it, 2 px apart. Re-placed after Blizzard's `RefreshRightTabs` and on every panel update.

**Recipe details block**
- In Blizzard's recipe details (`ProfessionsFrame.CraftingPage.SchematicForm`; Camelot layout, 360×484 at the author's scale): net profit per craft, craft-and-disenchant (when known), and one line per reagent with its cost and source.
- Sits at the **bottom** of the recipe details, 44 px up (clear of Blizzard's Track Recipe checkbox), aligned with the reagents, growing upward. It keeps 36 px free under the reagents for other addons' lines: Auctionator draws "To Craft" and "Profit" lines right under the reagents (the author's screenshots). Lines that don't fit are left out; hidden when the recipe has no basic reagents.
- Follows the selected recipe with `hooksecurefunc(SchematicForm, "Init")`.

**Item tooltips**
- A "Disenchant (est.)" line on item tooltips plus the materials (`TooltipDataProcessor.AddTooltipPostCall` for item tooltips, item ID from `tooltipData.id`; Forever source). On/off in the settings, off by default.
- Trainer and recipe item tooltips (`UI/RecipeTooltip.lua`): reagent lines with the source in front, AH price, profit per craft and craft-and-disenchant. The profit as a percentage of the reagent cost is added in grey, left of the amount so the right-aligned money values stay lined up, e.g. `(+114%) +4s 55c`; whole percent; nothing when the cost is unknown or zero.

**D/E Bags window** (`/pcraft bags`, or the panel's D/E Bags button)
- Movable `ButtonFrameTemplate` window, closes with Escape. Lists every disenchantable item in the bags (backpack, bags 1-4 and reagent bag: `Enum.BagIndex.Backpack` .. `NUM_TOTAL_EQUIPPED_BAG_SLOTS`), combined per item, with disenchant value, AH price (none for soulbound items) and merchant price per item; the option that pays most after the AH cut is marked. Refreshes on `BAG_UPDATE_DELAYED` and price changes.

**Free bag slots**
- Blizzard's count on the backpack (Options > Interface, "Show Free Bag Space", game setting `displayFreeBagSlots`; `C_Container.CalculateTotalNumberOfFreeBagSlots()`) is one total that includes the reagent bag (seen in game, 2026-11-17). ProfitCraft splits that total as "(reagent|normal)": reagent = the reagent bag's free slots, normal = Blizzard's total minus that, so the two always add up to Blizzard's number. Order as on the bag bar (reagent bag on the left). Without a reagent bag: "(normal)".
- One settings dropdown sets both Blizzard's setting (with `C_CVar`) and ours (`freeSlots`): Off (Blizzard off, `none`), Blizzard only (on, `none`), ProfitCraft + Blizzard (on, `reagent`: the split on `CharacterReagentBag0Slot`, nothing there without a reagent bag), ProfitCraft only (on, `backpack`: the split on `MainMenuBarBackpackButton`).
- "ProfitCraft only" hides Blizzard's count by setting its text (`MainMenuBarBackpackButton.FreeSlots`) to alpha 0 and **keeps Blizzard's setting on**, so Blizzard's count is back as soon as ProfitCraft is disabled or removed (the author's requirement). Blizzard only shows/hides that text (`MainMenuBarBackpackMixin:SetCountShown`, Forever source `Blizzard_MainMenuBarBagButtons/Shared/MainMenuBarBagButtons.lua`), never changes its alpha. Restored to alpha 1 when another choice is picked.
- Styled like Blizzard's count (`NumberFontNormal`, "(n)", 10 px below centre), drawn on our own overlay frames. Updates one frame after `BAG_UPDATE_DELAYED`, like Blizzard's own count.

**Currencies bar** (code name: money window)
- One row, no border: money on the right (`PC:FormatMoney(GetMoney())`), up to 5 tracked currencies to its left (icon + amount, `C_CurrencyInfo.GetCurrencyInfo`), each new one further left. Anchored by its **top-right corner**, so it grows leftwards; after a drag it is re-anchored the same way. Updates on `PLAYER_MONEY` and `CURRENCY_DISPLAY_UPDATE`. Hovering a currency shows Blizzard's tooltip (`GameTooltip:SetCurrencyByID`).
- Off by default: settings checkbox "Currencies bar", `/pcraft money`, or "Hide" in its menu.
- Right-click anywhere (also on a currency): **Add currency** (submenu: the character's Currency tab list, `C_CurrencyInfo.GetCurrencyListSize/GetCurrencyListInfo`, headers skipped, already tracked ones left out; disabled at 5; currencies in sections collapsed in the Currency tab aren't in the game's list, and ProfitCraft says so rather than opening them), **Remove currency**, **Lock/Unlock position** (locked: dragging does nothing), **Background colour...** (Blizzard's colour picker with opacity: `ColorPickerFrame:SetupColorPickerAndShow`, `hasOpacity`; Cancel restores), **Hide**. Menus: `MenuUtil.CreateContextMenu` (Forever's character window uses it).
- Saved account-wide in `ProfitCraftDB.money` (section 6); a tracked currency the current character doesn't have shows 0.

**Settings**
- One list of options (`OPTIONS` in `UI/Settings.lua`), built into two identical pages (approach seen in Questie, `addons/reference/Questie`, `Modules/Options/QuestieOptionsEngine.lua`; our own code):
  - ProfitCraft's own movable window (`/pcraft settings`, or the panel's Settings button). Closing it just closes it: it never goes through Blizzard's settings panel, whose close always reopens the game menu (Forever source: `SettingsPanelMixin:TransitionBackOpeningPanel` → `ToggleGameMenu()`). Closes with Escape (`UISpecialFrames`).
  - The same page under Blizzard's Options > AddOns > ProfitCraft (`Settings.RegisterCanvasLayoutCategory` + `Settings.RegisterAddOnCategory`, Forever source). Closing that returns to the game menu, which is where the user came from.
- **Three pages** (2026-11-21): page buttons General / Crafting profit / On Sale at the top (lit = current), one column wide (`COLUMN_WIDTH`, for small screens); markers `{ page = "..." }` in the option list, `{ title = "..." }` for section headings; the window is as tall as the tallest page. Blizzard's Options > AddOns page gets the same pages.
  - **General:** INTERFACE (Currencies bar, Free bag slots), AUCTION HOUSE (tab size, ignore cheap amounts (crumb limit), warn about summary scans), TROUBLESHOOTING (debug).
  - **Crafting profit:** PRICES (stale-price warning: slider Off/1/2/3/4 days, Blizzard's `MinimalSliderWithSteppersTemplate`), TOOLTIPS (disenchant estimate).
  - **On Sale:** the mode dropdown, then WHAT COUNTS AS ON SALE (single items %, stackable %, minimum and maximum profit), WATCH (pause between searches), ALERTS (sound, glow, thin-history reminder). Options with `requires = OnSaleOn` (a function) are greyed out while the mode is Off (`SetEnabled`; Blizzard's `MinimalSliderWithSteppersMixin:SetEnabled` greys the slider; labels `GameFontDisable`). A slider option may step through a `values` list.
- Each page re-reads the values when shown and after any change (`SETTINGS_CHANGED`, and `CVAR_UPDATE` for the mirrored game setting), so the two never disagree.
- **Version and "Create Profit Macro"** at the bottom of ProfitCraft's own window (version bottom left, button bottom right): `CreateMacro("PCraft", icon, "/pcraft [btn:2] settings; [btn:1]", false)` (general macro; Forever's own macro window uses `CreateMacro`, `Blizzard_MacroUI`). Icon: `Interface\Icons\Achievement_GuildPerk_MobileBanking` (a money bag; used by Forever's bank window, `Blizzard_UIPanels_Game/Camelot/BankFrame.xml`), passed as a file ID via `GetFileIDFromPath`. Disabled (tooltip still shown, `SetMotionScriptsWhileDisabled`) when a general or character macro named PCraft exists or all general slots are used; rechecked when the window opens and on `UPDATE_MACROS`.
- **PCraft macro tooltip:** hovering the PCraft macro on an action bar adds two lines (left-click / right-click): a `hooksecurefunc` on `GameTooltip:SetAction`, which Blizzard's action buttons call on mouse-over and on their own 0.2 s tooltip refresh (`Blizzard_ActionBar/Shared/ActionButton.lua`, `TOOLTIP_UPDATE_TIME`), identified by `C_ActionBar.GetActionText(slot) == "PCraft"`; no polling. Action bar addons that build tooltips without `SetAction` don't get the lines. `/pcraft` evaluates macro conditions itself with `SecureCmdOptionParse` when its text contains "[" (nothing matching = nothing happens, like Blizzard's `/stopattack`).

## 8. Slash command

`/pcraft` (decided 2026-11-13). Avoids `/pc` (ProfitCrafter Forever), `/profitcraft` (ProfitCrafting), `/cf` and `/cp` (CraftProfit) and `/fp` (ForeverProfit).

| Command | Does |
|---|---|
| `/pcraft` | Show or hide the side panel (with a profession window open) |
| `/pcraft settings` | Open or close the settings window |
| `/pcraft bags` | Open or close the D/E Bags window |
| `/pcraft money` | Show or hide the currencies bar |
| `/pcraft tooltip on\|off` | Disenchant line in item tooltips |
| `/pcraft debug on\|off` | Print errors in chat as they happen |
| `/pcraft errors` | List logged errors; `/pcraft errors clear` empties the log |
| anything else | Version and the command list |

## 9. AH scan data

**Principle:** ProfitCraft keeps only a small, current snapshot of recipe items; its price history (section 13) is separate. With Auctionator, ProfitCraft never scans itself: it reads along with Auctionator's scan.

**Full scans on Forever.** `C_AuctionHouse.ReplicateItems()` downloads every auction ("should be used in place of an 'allItem' query to query the entire auction house"; browse searches are limited to 100 calls a minute and "should not be used to query the entire auction house", Forever API docs `AuctionHouseDocumentation.lua`). When the data is ready the game fires `REPLICATE_ITEM_LIST_UPDATE` to every addon listening, and any addon can read the listings with `C_AuctionHouse.GetNumReplicateItems()` / `GetReplicateItemInfo(index)`: name, texture, count, quality, level, minBid, buyoutPrice, owner, ownerFullName, itemID, hasAllInfo (Forever docs). Entries with `hasAllInfo = false` need their item data loaded first (Auctionator waits for it, `Source_ModernAH/FullScan/Mixins/Frame.lua`). **Works on Forever:** Auctionator's replicate mode finished with "Finished processing 6552 items" (in game, 2026-11-17; knowledge file).

**With Auctionator** (installed and enabled, `C_AddOns.IsAddOnLoaded`):
- No ProfitCraft scan button.
- Auctionator has one scan routine per mode (Auctionator 346): `AuctionatorFullScanFrameMixin:InitiateScan` (replicate mode, option `replicate_scan_3`, label "Use alternate slower scan mode by default" in Advanced) and `AuctionatorIncrementalScanFrameMixin:InitiateScan` (summary mode, the default: one empty `SendBrowseQuery`, lowest price and quantity per item only). ProfitCraft hooks both (`hooksecurefunc` on the mixins; the frames are created from them when the AH opens); hooks seen working in game 2026-11-17. Internal Auctionator code: each hook checks the mixin exists and runs in `PC:Call`, so a renamed function only disables the message.
  - Replicate scan started -> ProfitCraft listens for `REPLICATE_ITEM_LIST_UPDATE`, reads the listings (its own pass over `GetReplicateItemInfo`; Auctionator reads them too, independently), prints "reading Auctionator's full scan..." and a short result ("done: N items on sale").
  - Summary scan started -> **summary-scan notice**: a raid-warning style message (`RaidWarningFrame:AddMessage`, Forever `Blizzard_RaidWarning`, raid-warning colour) plus an orange chat line with the setting's path. Setting `summaryScanWarning` (on by default). Prices keep coming from Auctionator's public API.
- Auctionator only listens to its own scans (it registers `REPLICATE_ITEM_LIST_UPDATE` in `RegisterForEvents` when it starts one), so a scan started by ProfitCraft would not update Auctionator. That is why ProfitCraft has no button when Auctionator is present.

**Without Auctionator:** a **Full scan** button next to the AH's money display starts `ReplicateItems()` (full scans only; at most one per 15 minutes, the limit Auctionator also uses, `FullScan/Mixins/Frame.lua` `CanInitiate`; the button shows the wait).

**Reading a scan** (both cases): one pass over all listings, in batches across frames so the game doesn't stall (thousands of listings; Auctionator also batches).
- ProfitCraft reports as soon as it has read the list, usually long before Auctionator's "Finished processing" (Auctionator builds a link and database key for every listing and stores them all). Same data: both start on the same `REPLICATE_ITEM_LIST_UPDATE`. Kept that way on purpose so On Sale alerts come immediately (2026-11-17).
- Listings of recipe items delivered incomplete (`hasAllInfo` false) are read again after `ITEM_DATA_LOAD_RESULT` for their item (requested with `C_Item.RequestLoadItemDataByID`), as Auctionator does; after 10 s without data the scan finishes anyway and the done message says how many were left out.
- Per listing: price per unit = buyout / count; listings without a buyout (bid only) are skipped; **own listings are skipped** (owner = the player in any of the likely name forms; when the owner isn't loaded yet the listing counts as someone else's).
- **Saved** (`ProfitCraftDB.snapshot[rulesetKey]`, overwritten by every scan): scan time; for the reagents and products of all recipes ProfitCraft has seen on the account (`recipeItems`), the cheapest price levels as {price per unit, quantity}, capped per item (CraftProfit's cap is 20 levels), and the total units listed.
- Every listing of other sellers is also handed to On Sale (section 13), which checks it and adds to the price history; an error there switches On Sale off for that scan only, so the snapshot is never affected. On Sale finds are kept in memory, not saved.
- Scale (the author's data, 2026-11-17): a full scan covers about 6,500 different items (Auctionator: 7,073 items, 1 MB); recipe items only, CraftProfit: 87 items' ladders, 18.5 KB.

**Live prices from AH searches** (`Scan.lua`, `Scan:GetLive`; 2026-11-24): `COMMODITY_SEARCH_RESULTS_UPDATED` / `_ADDED` (`GetCommoditySearchResultInfo`: unit price, quantity minus `numOwnerItems`; total = `GetCommoditySearchResultsQuantity` minus own) and `ITEM_SEARCH_RESULTS_UPDATED` / `_ADDED` (`GetItemSearchResultInfo`: `buyoutAmount` per item x `quantity`, own rows left out) reach every addon, whoever searched. For items in `recipeItems` the levels (as in the snapshot, at most `MAX_LEVELS`) are saved with the time seen in `PC.db.livePrices[ruleset key][itemID]`, and `PRICES_CHANGED` recalculates. **Browse searches** (`AUCTION_HOUSE_BROWSE_RESULTS_UPDATED` / `_ADDED`; Auctionator's Shopping tab and Search button run these, Auctionator 346 `DirectSearchProviderMixin.lua:75`): each row of a recipe item gives one level `{ minPrice, totalQuantity }` (all units at the cheapest price, as Auctionator counts; rows with own listings included, their cheapest price is the one to beat), one `PRICES_CHANGED` per page. `ScanLevels` takes the newer of the live entry and the snapshot for each item, then applies Auctionator's later-day rule and the crumb limit as before (a one-level browse entry is never cut by it).

**Prices from the snapshot** (`Prices.lua`; without a detailed scan both fall back to Auctionator's lowest price, or none):
- The snapshot is used for an item unless Auctionator's price is from a later day (`GetAuctionAgeByItemID`); same day: ours.
- Reagent cost: needed quantity = recipe amount x crafts in the current mode (1, or enough for a full stack of the product); take price levels cheapest first until the quantity is covered; too few listed -> flagged "only N listed" (the rest counted at the dearest kept price). Vendor price still wins when cheaper. Single units are counted: reagents can be bought by quantity (2026-11-17).
- Stackable items (`itemStackCount` > 1): price levels with less than the crumb limit of all units listed (setting, 0.5/1/2/3%, default 1%) are ignored, for reagent cost and sale price; if every level is below it (a scattered market), all levels are used. Sale price = cheapest remaining level.
- Non-stackable items: sale price = the cheapest listing. (Planned and not built: skip a listing far below the item's usual price.)

**Auctionator's history** (internal, `Auctionator.Database:GetPriceHistory(dbKey)`: per day lowest price, highest of the daily lows, quantity; Auctionator 346, `Source/Database/Mixin.lua:155`; 21 days by default, an Auctionator option), wrapped like the hooks; used only as On Sale's fallback for stackable goods (section 13). Its day numbers count from `Auctionator.Constants.SCAN_DAY_0`. Random-suffix items: Auctionator does **not** separate them on Forever (all keys in the author's saved file are plain item IDs; suffix keys only for Classic's old AH, `Source/Utilities/DBKeyFromLink.lua`, with its suffix table in `Data_Vanilla/Suffixes.lua`; checked 2026-11-19).

## 10. Checks before or during building (in game)

Results from PsiLab (2026-11-13) are in `knowledge/forever-vs-vanilla.md`, "Addon API".

- [x] Interface version on the live client is 16001 (build 1.60.1 (70938)). PsiLab, 2026-11-13.
- [x] Listing recipes: `GetFilteredRecipeIDs` returns only what the window currently lists (it follows the window's search and filters); `GetAllRecipeIDs` returns all recipes of the open profession, learned and unlearned; `GetRecipeInfo(id).learned` separates the learned ones. PsiLab, 2026-11-13.
- [x] Auctionator 346 on Forever: all 21 `Auctionator.API.v1` functions present; `RegisterForDBUpdate` fires after each AH scan; merchant prices are recorded. PsiLab, 2026-11-13.
- [x] Auctionator's disenchant prices don't work on Forever: Auctionator 346 treats Forever as Retail and its Retail D/E code only knows WoD to Shadowlands items. Seen in game and in Auctionator's code, 2026-11-13. See section 12.
- [x] Saved variables load and save normally on build 70938. PsiLab, 2026-11-13.
- [x] Reading the ruleset: `GetRealmName()` = "CAMWOW US2 Realm 7 PvE" (ruleset at the end), `GetRealmID()` = 6933. PsiLab, 2026-11-13.
- [x] All players of a ruleset share one AH (2026-11-13).
- [x] ProfitCraft's windows, dropdown, side tab, settings in Blizzard's AddOns options and reagent bag count work in game (2026-11-13).
- [x] Own disenchant estimate and material list, trainer and recipe item tooltips, BoP handling work in game (2026-11-14).
- [ ] `GetAuctionAgeByItemID` unit: returned 0 for prices from the same day; check again the day after a scan (expected: 1).
- [ ] AH cut on sale is 5%.
- [ ] Is the AH shared between Horde and Alliance? Assumed not (section 6).
- [x] Blizzard's free-bag-space number on the backpack also counts the reagent bag (seen in game, 2026-11-17).
- [ ] The PCraft macro's icon shows (money bag) and right-click on the action bar opens the settings ([btn:2]); which currencies Forever has and whether they appear in the Add currency list; the colour picker's opacity slider changes the background live.
- [ ] "(6|24)" fits on the reagent bag button; "ProfitCraft only" really hides Blizzard's count (relies on Forever loading `Shared/MainMenuBarBagButtons.lua`, inferred from its `.toc`, where camelot-specific files are separate) and it returns when another choice is picked.
- [x] Disenchant: item level decides the materials (Forever client's table is ordered by item level, forevermastery.com; all Classic sources agree). 2026-11-13, section 12.
- [x] Essences convert both ways (3 lesser <-> 1 greater), repeatedly. In game, 2026-11-13.
- [ ] Disenchant odds on Forever match the Classic table (section 12; quick check: a green weapon of item level 21-30 gives Greater Magic Essence, not Astral).
- More checks for On Sale and the Recipes panel: sections 13 and 14.

## 11. Mistakes found in other addons, and our rule against each

From the code review of ForeverProfit v1.8.0 and CraftProfit 0.5.2 (2026-11-13). Every design decision above should be checked against this list.

### ForeverProfit v1.8.0

| # | Mistake | Our rule |
|---|---|---|
| 1 | Recalculates everything far too often: each refresh recalculates every recipe three times, and refreshes run on every mouse-wheel tick and every keystroke in the search box. | Calculate once, re-read many times (section 4). Scrolling, searching, filtering and sorting never recalculate. |
| 2 | Broken scrolling: the rows move with the scrolled content and the data is also shifted by the scroll amount, so scrolling down skips entries (worked out from its `UI.lua`, not yet seen in game). | Use Blizzard's `WowScrollBoxList`, which handles row reuse itself; no hand-made scrolling. |
| 3 | Depends on Auctionator's private code for price history and for starting a scan; any Auctionator update can break it. | Auctionator's public API wherever it has what we need; the few internal uses are wrapped so a change only switches that feature off (principle 3). |
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

## 12. Disenchant values

### Why Auctionator can't be the source
- `Auctionator.API.v1.GetDisenchantPriceByItemID` / `...ByItemLink` return nothing for every item on Forever.
- Cause (Auctionator 346's code, 2026-11-13): `Source/Constants/Main.lua:56` sets `IsRetail` for Forever ("temporary fix assigning retail to mainline"), so Forever loads Auctionator's Retail disenchant code (`Source_Mainline/Enchant/`), which has tables only for WoD, Legion, BfA and Shadowlands items. Forever items count as original-expansion items, so the lookup returns nothing. That matches the "WoD, Legion, BfA & Shadowlands only" setting text the author saw. Auctionator's Classic table (`Source_Classic/Enchant/`) exists but is not loaded on Forever. If Auctionator fixes this, its values may start working; ProfitCraft keeps its own either way.
- Decision (2026-11-13): no separate addon; ProfitCraft has its own estimate.

### What ProfitCraft does (`Disenchant.lua`)
1. Reads quality, item level and item class with `C_Item.GetItemInfo` (from the exact link when there is one).
2. Only green, blue and purple armor and weapons; anything else, or an item level outside the table, gives no value.
3. Finds the row for quality × armor/weapon × **item level**. Each row lists material, chance %, min and max amount (each amount equally likely).
4. Value = sum over materials of AH price × chance × (min + max) / 2, rounded to whole copper. If any material has no AH price, there is no value (as with recipes: never show an incomplete number).
5. Essences: 3 lesser ↔ 1 greater convert both ways (seen in game), so each counts at whichever form sells for more: lesser = max(lesser, greater / 3), greater = max(greater, 3 × lesser); if only one form has a price, the other is derived from it.
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

## 13. On Sale

Files: `History.lua`, `OnSale.lua`, `UI/OnSale.lua`; `Scan.lua` hands every listing of other sellers to On Sale (section 9). What and why: `FEATURES.md` "On Sale".

### Modes
- `onSaleMode`: "off" (default) / "manual" / "auto"; dropdown on the settings' On Sale page: **Off**, **Manual List**, **Full Auto (Experimental)**. `OnSale:GetMode()`. Changing the mode stops the watch and clears the finds.
- **Off:** the Opportunities panel's On Sale page shows only "On Sale is off" (section 16), full scans create no On Sale collector (no finds, no price history, no scan days, no history reminder), the watch won't start.
- **Manual List:** full scans record price history for everything, but only listings a **switched-on search covers** can become finds, judged by **that search's rule** (fixed price or its percent) and attributed to it (`from` = search ID). `OnSale:CoveringSearch(itemID, name, quality, parsed)`: text (name contains / exact), category (Blizzard's `AuctionCategories` filters `{ classID, subClassID, inventoryType }`, `Blizzard_AuctionData.lua`, against `GetItemInfoInstant` and `GetItemInventoryTypeByID`), quality (the scan's `qualityID`, Forever API docs `GetReplicateItemInfo`), level / item level ranges (`GetItemInfo`; unloaded items with a level range in the search aren't covered, the watch finds them). Searches are parsed once per scan (`ParsedSearches`). A full-scan find under a fixed-price rule skips the crumb / market / 3-listings checks, as watch finds do.
- **Full Auto:** every listing of a full scan is judged with the settings' percentages; watch results by their search's rule.

### Quick check on opening the AH
- Manual List and Full Auto: 2 s after `AUCTION_HOUSE_SHOW` (after Blizzard's own first search), one pass through the switched-on searches (`OnSale:Start(true)`, `roundOnly`: 1 s between requests, stops after the last search and its item checks; status "checking your searches (n of m)"), **at most once a minute** (`GetTime`). Not while RapidFire runs. The continuous watch starts only with Start.

### Searches
- **Stored as Auctionator's text format**, one string per search: `text;category;minItemLevel;maxItemLevel;minLevel;maxLevel;minCraftedLevel;maxCraftedLevel;minPrice;maxPrice;quality;tier;expansion;quantity` (field order from Auctionator 346 `Source/Search/Advanced.lua` `SplitAdvancedSearch`; divider `;`, `Source/Constants/Main.lua:9`); text in double quotes = exact match. ProfitCraft parses it with its own code (a data format, not copied code). Fields ProfitCraft doesn't use (crafted level, tier, expansion, quantity) are kept so a pasted search round-trips unchanged.
- **Per-search rule**, stored on the search (`rule`, `percent`, `minProfit`, `maxPrice`), not in the Auctionator text: **percent** (own percent, empty = the settings by item type; own minimum profit, prefilled from the setting) or **fixed price** (at or under a price; no history, no crumb or market check; profit shown only when a usual price is known). Full scans in Full Auto use the settings.
- **Categories** are Blizzard's: `category` is the path of names in Blizzard's global `AuctionCategories` joined with `/` (e.g. "Armor/Mail"), each category carrying its own `filters` (class, subclass, inventory type). This is how Auctionator resolves them too (`Source/Search/Categories.lua`); Forever defines the table in `Blizzard_AuctionHouseUI/Camelot/Blizzard_AuctionData.lua`. Category names are the client's language (English for all testers).
- **Paste in:** one search per line, or Auctionator's list export `ListName^search1^search2` (`Source/Shopping/ImportExport.lua`); the list name becomes a group label.
- **Editor:** name, text + "exact" box, category dropdown (Blizzard's category tree, each submenu starting with "All <category>"), level min/max, item level min/max, quality (minimum), rule, on/off. Tab / Shift-Tab move between the fields (hidden ones skipped).
- **Running a search:** `C_AuctionHouse.SendBrowseQuery{ searchString, sorts, minLevel, maxLevel, filters = quality filters, itemClassFilters = the category's filters }` (Forever API docs, `AuctionHouseBrowseQuery`); more pages with `RequestMoreBrowseResults` until `HasFullBrowseResults()`. Results (`BrowseResultInfo`): `itemKey` (itemID, itemLevel, itemSuffix), `minPrice`, `totalQuantity`, `containsOwnerItem`. Item level and exact-name checks are done by ProfitCraft on the results (as Auctionator does; names from `C_AuctionHouse.GetItemKeyInfo`).
- **Pace:** one AH request at a time, at most one a second (Blizzard's limit is 100 searches a minute, Forever API docs). **RapidFire and On Sale never run together**: starting one stops the other (both drive the AH's single current search). Each page counts as a request until known otherwise. Interval setting = pause between two searches (default 10 s); each search comes round every (number of active searches x interval), shown in the status line ("5 searches, each every 50 s").
- **Pause** while the buy dialog is open, and for 30 s after anyone else's AH search: `hooksecurefunc` on `C_AuctionHouse.SendBrowseQuery`, `SendSearchQuery`, `SearchForItemKeys`, `SearchForFavorites`, `SendSellSearchQuery`; ProfitCraft's own calls are marked (`OnSale.Send`) so they don't count. This catches Blizzard's window and Auctionator alike. The request in flight is dropped (its answer would mix with theirs). Other ProfitCraft jobs (the Recipes scan) pause the watch with `OnSale:SetBusy`.
- **Quality** is read as "this or better" ("Uncommon or better"); Auctionator reads its quality field as exactly that quality.

### Item variants and stackable / single
- **Weapons and armour are keyed by their full name in lower case** (`OnSale:Variant`), because the item link's suffixID field doesn't carry Forever's random suffix ("Engraved Cape of the Beast" got Auctionator's suffix-mixed price). A browse result whose name is unknown or lacks the suffix uses `#<itemSuffix>`. Other items: variant 0.
- **Blank names:** a full scan returns `""` as the name of items whose data isn't loaded; then the name comes from the item link (gear) or the item data (display).
- **Stackable or single** (`IsStackable`) while the item data isn't cached (`C_Item.IsItemDataCachedByID`), so a full scan requests no item data: Container (1), Weapon (2), Armor (4) and Recipe (9) count as single items (`GetItemInfoInstant` class; Enum.ItemClass, Forever API docs), everything else as stackable.

### History and usual price (`History.lua`)
- **Key:** `itemID:variant` per ruleset key (section 6). Item level is left out of the key: on Forever an item ID has one item level unless scaled; to revisit if results show several levels per item ID.
- **Samples:** each time ProfitCraft sees an item's cheapest price from other sellers (a browse result, or the cheapest listing of that key in a full scan), it keeps it as that hour's sample (first sample per hour per key). For **stackable goods the recorded price is the floor without crumbs** (the cheapest level holding at least the crumb limit's share of all units; `OnSale:Floor`), from full scans and from the unit check of a candidate; a browse result that is a stackable candidate isn't recorded from its cheapest listing. Own listings: a browse row with `containsOwnerItem` is skipped for history (its minimum may be ours); full scans skip own listings (section 9).
- **Daily price** = the median of that day's hourly samples. Using the lowest price of the day instead would follow every short-lived cheap listing that bots snap up, and a watch that searches every minute sees far more of those than a scan every few hours (Auctionator's daily low comes from scans), so the usual price would drift down.
- **Usual price** = the lower of the median of the last 7 daily prices and the median of the last 2 days (today's so far included), using only days with prices **within the last 7 days**, and only when there are at least 3 such days. A price that has come down and stays there is the new usual within about two days; one cheap hour among normal ones barely moves it. Kept: 14 days; a key not seen for 14 days is dropped.
- **Days and hours follow the local clock** (day changes at local midnight). Offset from `date("!*t")` with the summer-time flag carried over.
- **Fallback while ours has < 3 days: Auctionator's history, for stackable goods only** (`GetLimit`: `GetUsual(..., stackable)`; `Auctionator.Database:GetPriceHistory`, section 9), the same 7-day / 2-day rule, limited to its last 7 days. Single items wait for our own 3 days: Auctionator's daily lows for thin markets (recipes) are mostly one seller's asking price, and it mixes random suffixes.
- **Scan days:** ProfitCraft notes each local day on which it reads a full scan (`ProfitCraftDB.scanDays[ruleset key]`). After a scan, while that's fewer than 3 of the last 7 days, an orange chat line says so (setting `historyReminder`). The On Sale panel shows "History: N of 7 days" at its top right (orange under 3, green from 3); its tooltip explains which items need ProfitCraft's own history. This counts only full-scan days; finds for stackable goods can come from Auctionator's history before that.
- **Size:** today's hourly samples (<= 24 per key) plus one number per past day. A full scan covers about 6,500 items (section 9), more keys with suffixes; estimated 1-3 MB of saved data at 14 days. Check the real size after a week of use; if too big, keep history only for items matched by a search or recipe.

### Finds (hits)
- **Percent rule:** a listing is a find when its price is at or under the usual price x (1 - discount) (single items 70%, stackable goods 45% by default; sliders) **and** the profit (usual price x (1 - AH cut) - price) is at least the minimum profit (default 50s) and at most the **maximum profit** (`onSaleMaxProfit`: Auto (-1, default), 5g, 10g, 20g, 50g, 100g, Unlimited (0); Auto = 1.5x `GetMoney()` at the moment of judging). Limits use whole numbers (`usual * (100 - percent) / 100`).
- **Market check** (percent rule): more than half of the units listed (stackable goods), or more than half of the listings when there are at least 3 (single items, full scans), under the On Sale price = the market moved, no find. Seen causes: prices that fell since launch, and placeholder prices (99g 99s 98c) as an item's daily low.
- **More than 3 listings at or under the On Sale price = not on sale** (`MAX_CHEAP_LISTINGS`; single items, percent rule). Full scans count listings directly. Watch searches: a browse row only has the cheapest price and the total listed, so a single item with more than 3 listed gets one item search (`SendSearchQuery(itemKey)`, task `verifyItem`, read on `ITEM_SEARCH_RESULTS_UPDATED`) counting other sellers' buyouts at or under the price (`OnSale:CheckItem`) before it counts.
- **Stackable goods** (browse rows show only the cheapest price): a candidate gets one item search (`SendSearchQuery`) to count the units at or under the On Sale price; the crumb limit (section 9) applies, so 100 cheap units among 50,000 never alert.
- **Fixed-price rule:** at or under the search's price; none of the checks above.
- **Full scans:** every listing is checked in memory while the scan is read (section 9); finds join the same list.
- **Finds list rows:** icon, name with suffix, price, usual price, profit, quantity (stackable), age ("12 s ago"), source (search name or "full scan"). Sorted newest first by the minute (a scan's finds arrive together), then the biggest profit, unknown profit last. A Blizzard scroll list (`PC:CreateScrollList` with an optional area to fill) with a scroll bar.
- **Self-maintaining:** each run of a search updates or removes its finds (gone, or price now above the On Sale price). Full-scan finds not covered by any search are re-checked in batches with `C_AuctionHouse.SearchForItemKeys(itemKeys, sorts)` (one request for many keys; whether it counts as one search: to check). Finds are in memory only and cleared when the AH closes.

### Buying
- Click a find -> item search for that key (`SendSearchQuery`; gear results via `GetItemSearchResultInfo`: auctionID, buyoutAmount, owners) -> dialog "Buy N for X? (usual Y, profit Z)" -> click **Buy**: gear `C_AuctionHouse.PlaceBid(auctionID, buyoutAmount)`, stackable goods RapidFire's `StartCommoditiesPurchase` path with the quote check. Both are restricted (Forever API docs, `HasRestrictions`), so the call is the **first thing in the click** (knowledge file). RapidFire's keep-at-least balance applies.
- Gear found by a full scan has no item key; clicking it first runs a browse search for its name and takes the result whose name matches.
- `OnSale:InspectHit` (optional title, note, gone text, chat prefix, anchor) is also used by the Recipes panel (section 14).

### Alerts
- On a new find: sound (`SOUNDKIT.RAID_WARNING`, setting `onSaleSound`), `FlashClientIcon()` (Blizzard's PvP queue / ready check use it, `Blizzard_LFGUtil/Mainline/PVPHelper.lua`), and a gold screen glow (setting `onSaleGlow`): a full-screen frame (strata FULLSCREEN, no mouse) with Blizzard's low-health texture `Interface\FullScreenTextures\LowHealth` (additive, `Blizzard_FrameXML/Mainline/LowHealthFrame.xml`) tinted gold, pulsing until the mouse is over the AH window, the On Sale panel or the buy dialog, or the finds are gone, or the AH closes.
- Sound while the game is in the background needs Blizzard's "Sound in Background" (CVar `Sound_EnableSoundWhenGameIsInBG`, Forever settings source); ProfitCraft says so when the watch starts and it is off.

### Not possible
- Knowing the price things **sell** at: the AH shows addons listings, not sales. Inferring sales from listings that disappear between checks would be a separate, bigger feature.

### To check in game
- [ ] Browse search with category and level filters works as documented; whether each `RequestMoreBrowseResults` page counts toward the 100-a-minute limit.
- [ ] Browse results carry `itemSuffix` for random-suffix gear (one row per suffix), and `GetItemKeyInfo(itemKey).itemName` includes the suffix.
- [ ] How a suffix appears in a Forever item link (to match full-scan listings with browse keys).
- [ ] Server text search matches suffixes ("of the Knight" in Blizzard's search box; FEATURES.md).
- [ ] Idle logout while the watch runs (FEATURES.md).
- [ ] `FlashClientIcon` under Wine (the author expects it not to work).
- [ ] The gold glow shows (the low-health texture exists in Forever's client) and stops when the mouse reaches the AH window.
- [ ] `SearchForItemKeys` (re-check of full-scan finds) answers with the browse events (assumed: Blizzard's favourites search, `SearchForFavorites`, fills the browse list the same way). If not, those finds simply stay until the AH closes; clicking one still checks the live listings.
- [ ] Blizzard's own AH window doesn't send searches by itself while On Sale runs (that would show as "paused: someone else searched" without you searching).
- [ ] Full-scan finds of gear: the item key built from the link's suffix and `GetDetailedItemLevelInfo` finds the listings when clicked.
- [ ] Manual List and the quick check on opening the AH (0.3.9, not yet tested in game).

## 14. AH tabs and the Recipes panel

### AH tabs (`UI/AHTabs.lua`)
- A thin column of small icon CheckButtons outside the AH window's right edge, **always visible**, at its bottom (8 px above the AH window's lower edge; top to bottom by each tab's `order`: Recipes 1, Opportunities 2, RapidFire 3, 2026-11-24), 1 unit from the window's edge (`EDGE`).
- **Size:** setting `ahTabSize`, icon 24-44 px in steps of 4, default 24. The slot frame is icon x 47/37 (Forever's character-window slot proportions); tabs are stacked one frame + 4 px apart, so they never overlap at any size; the column is frame + 8 px wide and the panels open that far right of the AH window (`PC.AHTabs:Place`, `PC.AHTabs.PANEL_OFFSET`), re-placed when the size changes. The count badge uses a larger font from 36 px.
- Forever's own side tab (`LargeSideTabButtonTemplate`) is sized from the `common-sidetab` atlas at runtime: **atlas 55 x 60 px** (the author's `/dump C_Texture.GetAtlasInfo("common-sidetab")`, 2026-11-20; file 8124215), so the tab is 55 x 55 (`CalculateTabSizeBasedOnTabArt`: width as is, height - 5) with a 50 px icon (`interiorExtent` default). Forever's version of that template is wider than Retail's ("Camelot tabs are wider", `Blizzard_SharedXML`), which is why ProfitCraft draws its own small tabs; its slider at 44 px gives a 56 px frame, about the same size.
- Drawn like Forever's character-window buttons (Camelot `PaperDollFrame.xml`): `Interface\Buttons\UI-Quickslot2` frame, `ButtonHilight-Square` on hover, `CheckButtonHilight` when checked. `SetCheckedTexture` takes the texture only (Forever API docs, `SimpleCheckboxAPIDocumentation`), so the blend mode is set with `GetCheckedTexture():SetBlendMode("ADD")`; otherwise its dark parts cover the icon. The open panel's tab also gets a gold frame (`SetVertexColor` on the slot frame).
- The open panel's tab is checked (lit); clicking it again closes the panel; clicking another tab switches panels in place (one at a time, `AH_PANEL_SHOWN`). The Opportunities tab shows the number of Vendor and On Sale finds as a small badge; hovering shows name and help.
- Panels register with `PC.AHTabs:Register{ key, title, icon, help, order, panel(), open(), count(), shown() }` (`shown()` optional; no tab uses it now). Icons: RapidFire `Ability_Hunter_RunningShot`, Opportunities `INV_Misc_Note_01`, Recipes `INV_Scroll_03`.
- Without Auctionator, ProfitCraft's own "Full scan" button stays next to the AH's money display (no clash reported).

### Recipes panel (`UI/AHRecipes.lua`)
- Panel `ProfitCraftRecipes` (480 x 580) right of the tabs. A profit column inside Blizzard's browse list was rejected: the list sorts server-side (each header carries an `Enum.AuctionHouseSortOrder`, `AuctionHouseTableBuilder.GetBrowseListLayout`), so a profit sort would mean reordering Blizzard's internal results from addon code (taint risk next to protected buying).
- **Scan recipes:** the character's professions (`GetProfessions` / `GetProfessionInfo`, as Forever's own profession window, Camelot `Blizzard_ProfessionsFrame.lua`), each matched by name to the Recipe subclass of the same name (`C_Item.GetItemSubClassInfo(Enum.ItemClass.Recipe, n)`; Book skipped; no hard-coded IDs). One `SendBrowseQuery` per profession (`itemClassFilters { classID = 9, subClassID }`), more pages with `RequestMoreBrowseResults` until `HasFullBrowseResults` (at most 20), one AH request a second, 10 s timeout per answer. On Sale's watch is paused meanwhile (`OnSale:SetBusy`); refused while RapidFire runs. Requests go through `OnSale.Send` (marked as ProfitCraft's own). Stop button while scanning. Results stay until the next scan in the session.
- **Recipe of an item:** the `ItemSpellTriggerLearn` line (type 38) of `C_TooltipInfo.GetItemByID(itemID)` (Forever API docs; the same line ProfitCraft's recipe tooltip reads, confirmed by PsiLab from bag items; **not yet confirmed in game for `GetItemByID`**). Not loaded yet: item data requested, read again on `ITEM_DATA_CHANGED`. Cached in `ProfitCraftDB.recipeOfItem`.
- **Per row:** the same `Profit:Evaluate` as the recipe tooltip: profit, % of the reagent cost, "pays off after" = ceil(recipe price / profit per craft) crafts; BoP products "BoP", enchants "no item", missing prices "no price", unread "?". The same item listed in several results: cheapest counts. Known recipes (`C_TradeSkillUI.GetRecipeInfo(id).learned`; without the profession window open **not confirmed in game**) marked "(known)" in grey; "Hide known" checkbox (`recipesHideKnown`, off by default).
- **Per stack / Per craft** dropdown (`recipesProfitMode`, "stack" by default): per stack = `Profit:Evaluate`'s `profitStack`, shown with a grey `x20`; the column header follows ("Profit / stack" / "Profit / craft") and sorting follows the shown value; % and "pays off" don't change with the mode. The status line sits above the bottom row (dropdown, Hide known, Scan recipes); columns: Recipe 170, AH price 76, Profit 100, % 46, Pays off 60.
- **Sorting:** clickable headers with Blizzard's AH sort arrow (`auctionhouse-ui-sortarrow`, flipped as `AuctionHouseTableHeaderStringMixin:SetArrowState` does); default profit, best first; click again to reverse; unknown values always last.
- **Hover:** the item's tooltip (with ProfitCraft's recipe lines), listed count and cheapest price, pays-off line, known. **Click:** On Sale's buy dialog (`OnSale:InspectHit`), the cheapest listing at or under the listed price, bought with `PlaceBid` from the Buy button.

## 15. RapidFire (`UI/Rapid.lua`)

What and why: `FEATURES.md` "RapidFire".

- **Searching:** each watched item with `C_AuctionHouse.SendSearchQuery` (Blizzard's limit is 100 searches a minute, Forever API docs), at most one request a second across items. While the deal popup shows, only the offered item is searched (every second), so the AH's current search is that item, as when buying through Blizzard's window. The watched item's search stays open: the AH pushes changes (`COMMODITY_SEARCH_RESULTS_UPDATED`, Forever docs; what Auctionator shows updating in the background) and ProfitCraft also refreshes it (`RefreshCommoditySearchResults`, not restricted).
- **"Stackable"** is judged by the item's stack size, because `C_AuctionHouse.GetItemCommodityStatus` needs a bag slot (Forever docs).
- **Quantity at the press:** from the live listings at that moment: all units at or under the max, minus your own (`numOwnerItems` in `CommoditySearchResultInfo`), capped by the keep-at-least balance.
- **Buy key:** `SetOverrideBindingClick` on the popup's Buy button, set when the popup shows and removed as soon as it closes; not changed in combat.
- **Vendor flips** (watched from the Vendor page, Shift + left-click: `Rapid:AddItem(itemID, vendorPrice)`, max = vendor price - 1c; saved as `entry.vendorPrice`): `Ceiling(entry)` = the lower of the max and vendor price - 1c, used for the deal (`GetDeal`), and the quote limit is capped at `(vendorPrice - 1) x quantity` after the price tolerance, so such an item is never bought at or above what a vendor pays (2026-11-24). A max raised by hand doesn't lift that cap; removing the item and adding it by hand does.
- **Purchase:** two steps, quote (`C_AuctionHouse.StartCommoditiesPurchase(itemID, quantity, unitPrice)`, Blizzard's own call, `Blizzard_AuctionHouseFrame.lua`) then `ConfirmCommoditiesPurchase` when the quote keeps every unit at or under the max (exact cost of the listings meant, not an average, within the price tolerance) and the money at or above the keep-at-least balance; else `CancelCommoditiesPurchase` (not restricted) and the reason. `StartCommoditiesPurchase` and `PlaceBid` have `HasRestrictions = true` (Forever API docs): the call must be the first thing in the key press or click, before the button is greyed or anything printed (knowledge file); only the quote step is flagged, so one press per purchase is expected (to be seen in game; else a second press confirms).
- **Time limits:** no quote within 5 s or no result within 10 s cancels and says so. A Blizzard block (`ADDON_ACTION_BLOCKED` / `ADDON_ACTION_FORBIDDEN`) is reported in chat; `/pcraft debug on` prints every purchase step.
- **One request per state of the listings:** after a press the Buy button stays greyed until fresh listings arrive.
- **History panel:** in memory only; 15-second clock slots, so only the newest bar changes and the chart scrolls one bar per 15 s; all bars rescale together when a new lowest or highest price enters or leaves the 15 minutes.
- **Session summary:** from RapidFire's own purchases (the game reports purchases made with Blizzard's or Auctionator's buttons without item, quantity or price); reset when the AH closes.
- **Saved** in `ProfitCraftDB.rapidFire` (section 6), one list for the account. Not saved: whether RapidFire is running. Saved data is written at logout or `/reload`, so a crash loses changes since then.

## 16. Opportunities and Vendor finds (0.4.0, built 2026-11-24, not yet tested in game)

What and why: `FEATURES.md` "Opportunities".

### Names
- Displayed names only: AH tab "Opportunities" (title and help), panel title "ProfitCraft Opportunities", settings page "Opportunities" with an "On Sale" section. Internal names stay: `OnSale.lua`, `UI/OnSale.lua`, `PC.OnSale`, the `onSale*` settings, the tab key `onsale`, the frame `ProfitCraftOnSale`. No saved-data upgrade.

### Files
- `Vendor.lua` (Data): the full-scan collector for Vendor finds and the find list (`PC.Vendor`: `NewScanCollector`, `GetHits` sorted, `GetHit`, `RemoveHit`, `Bought`, `GetScanTime`); announces `VENDOR_CHANGED`.
- `UI/Vendor.lua` (Window): the Vendor page, built into the Opportunities panel by `UI/OnSale.lua` (`PC.VendorUI:CreatePage(parent)`, `Refresh`).
- `UI/OnSale.lua`: the panel gets two page buttons at the top, **Vendor** and **On Sale**; On Sale's own controls (Searches / Finds buttons, history label, Start/Stop, status line, its four views) live on the On Sale page unchanged. Opens on Vendor (default; the last page is kept for the session). With On Sale Off the On Sale page shows one line: "On Sale is off. Turn it on in Settings > Opportunities." The tab registration has no `shown()` (always on; only On Sale can be switched off); `count()` = On Sale finds + Vendor finds. A change of `onSaleMode` re-shows the current page.

### Reading a full scan (`Scan.lua`)
- `reading.vendor = PC.Vendor:NewScanCollector()` on every full scan, whatever the On Sale mode (On Sale's collector stays mode-dependent). `ReadListing` hands each listing of other sellers with a buyout to it (`index, itemID, buyout, count, name`) in its own `pcall`; its first error switches only the Vendor collector off for that scan and is logged ("Vendor scan"), as with On Sale's. `Finish` calls the collector's `Finish`.
- The check uses the listing's **buyout and count directly** (a listing is a find when `buyout < sellPrice * count`), not Scan's rounded unit price, since margins can be one copper.

### Vendor collector (`Vendor.lua`)
- **Vendor price:** `PC.Items:GetSellPrice(itemID)` (`C_Item.GetItemInfo`, 11th value; 0 = vendors don't buy it, nil = not loaded).
- **Key:** `itemID:variant`, variant as On Sale (`OnSale:Variant`: 0, or gear's full name in lower case; a blank scan name taken from the item link); gear whose name can't be told is left out, as On Sale does.
- **Loaded items** are judged in `Add`; listings of items not loaded yet are kept as `{ variant, name, buyout, count }` per item (`GetSellPrice` has already requested the item data, `Sources/ItemData.lua`) and judged on `ITEM_DATA_CHANGED`; 10 s after the scan's end whatever hasn't loaded is dropped (count shown with `/pcraft debug on`).
- **Per key:** units, cost (sum of buyouts) and listings of the listings below vendor price; vendor value = sellPrice × units; profit = vendor value − cost.
- **Finish:** the list is replaced by this scan's finds (a scan without finds empties it), scan time noted, `VENDOR_CHANGED`. Finds from item data arriving later are added without re-adding finds bought or found gone meanwhile. In memory only; not cleared when the AH closes.
- **Expiry:** setting `opportunityExpiry` (minutes: 10, 30 default, 60, 120, 240; slider at the top of the Opportunities settings page), shared with On Sale. Vendor: `IsExpired()` once `scanTime` is that old; `GetHits` / `GetHit` then return nothing, `ExpiredFor()` gives the seconds since. A one-shot `C_Timer` just after the expiry sends `VENDOR_CHANGED` so the page and badge update by themselves; changing the setting re-sends and reschedules. On Sale (`OnSale.lua`): a find is live while `time() - hit.seen` is under the expiry (`seen` is renewed whenever a scan or search finds it again); `GetHits` lists live finds only; `OnSale:ExpiredFor()` when every find has expired; `AddHit` schedules one `ONSALE_CHANGED` just after. Expired On Sale finds stay in memory until the AH closes (cleared then, as before). Page messages: Vendor "The last scan expired X ago. Please run a full scan again."; On Sale "The last finds expired X ago. Please run a full scan again (or Start)." (`PC:FormatAge`: "5 min", "2 h", "1 h 30 min").
- **Chat:** one line per scan with finds, at `Finish`: "Vendor: N items below vendor price, +X if you buy and vendor all of them (Opportunities tab)." (no spam). Nothing when there are none; finds arriving later don't print again.

### Quick scan (`Vendor.lua`, `Vendor:QuickScan`)
- Modelled on Auctionator's summary scan (Auctionator 346, read for the approach only: `Source_ModernAH/IncrementalScan/Mixins/Frame.lua`): `C_AuctionHouse.SendBrowseQuery{ searchString = "", sorts = {}, filters = {}, itemClassFilters = {} }`, then `RequestMoreBrowseResults` after each `AUCTION_HOUSE_BROWSE_RESULTS_UPDATED` / `_ADDED` until `HasFullBrowseResults()`. Auctionator expects up to 500 results per batch (`SummaryBatchSize`), so about 13-14 requests for ~6,500 items (estimate; the chat line reports the real count).
- **Pacing:** every request waits until `C_AuctionHouse.IsThrottledMessageSystemReady()` (Forever API docs), resumed on `AUCTION_HOUSE_THROTTLED_SYSTEM_READY` and retried every second, as Auctionator's request queue does (`Source/AH/Mixins/Queue.lua`, `Source_ModernAH/AH/Mixins/Throttling.lua`). Requests go through `OnSale.Send` (marked as ProfitCraft's own). 10 s without an answer: the browse step stops the scan; a candidate's search is skipped (counted in the chat line).
- **Candidates:** browse results (`itemKey`, `minPrice`, `totalQuantity`), each item key once, battle pets left out; a candidate when `minPrice` < the vendor price. A browse result has only the cheapest price, so no item with a listing below vendor price is missed. Items whose data isn't loaded get one more look when the browse step ends.
- **Only the top candidates** (setting `quickScanChecks`: 5, 10 default, 20; the author's tests: 45 browse pages / 22,000+ results, then 171 candidate checks, about as long as a full scan): candidates ranked by `(vendor price - minPrice) x totalQuantity`, the most a candidate could earn.
- **Live list:** each browse page's candidates go in as unchecked entries (`Collector:AddUnchecked`: `unchecked`, `cheapest`, `profit` = per unit) and are published at once (the first page replaces the old list). `GetHits` sorts checked finds first (by profit), then unchecked ones by profit per unit. A candidate's entry stays unchecked until its check answers: the first listing `Judge` adds turns it into a checked one (`Checked`), else `Collector:EndCheck` does with 0 units, and `Publish` then removes it. A timed-out check leaves it unchecked. At the end, with checks on, `Collector:DropUnchecked`; with checks off (`quickScanDetail` false, "Check top items" checkbox on the Vendor page) the unchecked entries stay. Unchecked rows: "?" units, "@ cheapest", "+profit/u"; buying one removes it (`Vendor:Bought`). The chat line gives a total only for checked finds.
- **Per candidate** (the top ones), one `SendSearchQuery` (price order; only the first page of results is read, cheapest first). Commodity or not: `Vendor:IsCommodity` (the game's `GetItemKeyInfo(...).isCommodity`, as Blizzard's Buy tab decides; stack size only when the key info isn't there), also used for the buy dialog. Either kind of answer for the candidate's item ends the wait (an answer of the unexpected kind used to wait out the timeout). Commodities by `MakeItemKey(itemID)`, read on `COMMODITY_SEARCH_RESULTS_UPDATED` / `_ADDED` (`unitPrice`, `quantity` minus `numOwnerItems`); others by the browse key (with its suffix), read on `ITEM_SEARCH_RESULTS_UPDATED` / `_ADDED` (`buyoutAmount`, `quantity`, `containsOwnerItem`; **`buyoutAmount` is the price of one item and a row stands for `quantity` items**: the author's screenshot 2026-11-24, Blizzard's list showing Small Blue Pouch, which doesn't stack, as "2s 49c, 22"; Blizzard's Buy button pays one row's `buyoutAmount`, `Blizzard_AuctionHouseFrame.lua`), variant from `GetItemKeyInfo(itemKey).itemName`. Listings below vendor price go into a normal Vendor collector (`Judge`), which then publishes: the Vendor list is replaced, the expiry restarts, the usual Vendor chat line, plus "Quick scan done: N items on the AH, M with listings below vendor price, C checked; R requests, S s.". Gear finds keep their browse key, so buying them needs no name lookup.
- **One AH job at a time:** refused while RapidFire or the Recipes scan runs, or the buy dialog is open; the On Sale watch is paused (`OnSale:SetBusy`; the dialog's and the scan's ends keep it paused while the other is still on); RapidFire and the Recipes scan refuse while it runs; the AH closing stops it. Button greyed while it runs; status line next to it (`VENDOR_QUICKSCAN`).
- **Buying during a scan** (2026-11-24: a find is gone if you can't react at once): `OnSale:InspectHit` is allowed for finds with an item key (every quick-scan find has one); `Request` sends nothing new while the dialog is open (status "paused while you buy", retried every second; a request already in flight is answered normally) and carries on after it closes. Not allowed during a scan: finds without an item key (the dialog's browse search, and left-click's name search, would replace the browse results the scan is still reading). Left-click with an item key (`SelectBrowseResult`, an item search) is allowed; it isn't paced with the scan, so an unlucky throttle could drop one of the two requests (the scan then skips that check after its timeout; the Buy tab can be clicked again).
- **Side effect (from reading Auctionator 346's code, not seen in game):** Auctionator's summary-scan frame processes every browse result it sees into its price database (`AuctionatorIncrementalScanFrameMixin:OnEvent` / `NextStep` -> `Database:ProcessScan`), so a quick scan probably also refreshes Auctionator's prices (cheapest price per item, as its summary scan does).
- To check in game: number of requests and time; whether the whole browse arrives as documented on Forever; whether Blizzard's AH window shows the quick scan's results in its browse list while it runs.

### Vendor page (`UI/Vendor.lua`)
- Header: "N finds in the scan of HH:MM, x min ago - click one to buy it"; "No listings below vendor price in the last scan (HH:MM, x min ago)."; "No full scan read yet: run Auctionator's detailed scan." / "...: use the Full scan button." (without Auctionator).
- Column labels, then a `PC:CreateScrollList` list. Columns: icon + name (with suffix), units, cost, profit. Sorted by profit, biggest first, then name. No column sorting in 0.4.0.
- Hover: name, units and listings, cost, vendor value (vendor price each), profit, "Click to buy".

### Filters (`Vendor.lua`)
- `Vendor:IsSingle(itemID, commodity)`: stack size 1 from the item data (the commodity flag while it isn't loaded). `Vendor:PassesFilters(itemID, commodity, perItem)`: stackable goods always; single items not with `vendorStackableOnly`, else when `perItem >= vendorMinSingleProfit`. `GetHits` returns the shown finds and how many are hidden (the header shows "(N hidden by filters)"); the badge and `Summary` use it. The quick scan ranks only candidates that pass (per item = vendor price - cheapest). Settings changes send `VENDOR_CHANGED`.

### Spend protection (`UI/OnSale.lua` dialog, settings)
- `buyMaxPerPurchase` (copper, 0 = none, default 5g): `SpendCap(hit)` (nil for `hit.noSpendCap`, the Recipes panel), `SpendLimit(hit)` = the lower of the cap and the money above "keep at least"; used by `ReadCommodityOffer` (marks `offer.capped` when more was there) and `ReadItemOffer`; `Binding(hit, price)` says which limit stops a price ("cap" or "keep"), `TooDear` turns that into the dialog's message; `Buy` refuses an offer over the cap (plain check). A capped stackable offer counts as buy-next (`BuysNext`), so the next part is offered after each purchase.
- **Chat note** (2026-11-24): `NoteLimit(state, which, blocked)` prints one line per dialog (`state.limitNoted`) when a limit stops a purchase or makes it smaller than what's listed, naming the limit, its amount and where to change it (Settings > Opportunities > Buying; for keep at least also the RapidFire panel). RapidFire prints nothing: its popup already says what it keeps, and its panel holds the amount.
- "Keep at least" stays one amount, `PC.db.rapidFire.minBalance` (default 50s on a fresh install); the settings option (`keepAtLeast`, gold and silver boxes) reads and writes it through `option.get` / `option.set`; RapidFire's money input follows on `SETTINGS_CHANGED` "keepAtLeast".
- **Money options in the settings** (`money = true`, 2026-11-24: sliders too restrictive for amounts): Blizzard's `MoneyInputFrameTemplate` with the copper box hidden (`MoneyInputFrame_SetCopperShown`, Forever source `Blizzard_MoneyFrame/Shared/MoneyInputFrame.lua`), named `ProfitCraftSettingsMoney<n>` (the template names its boxes after the frame). Saved on every change; `Sync` refills them except while one of their boxes has the focus (rewriting would move the cursor).

### Items no merchant takes (`Sources/ItemData.lua`)
- `PC.db.unsellable[itemID]` = "bags" or "merchant". `Items:GetSellPrice` returns 0 for them, so every vendor price use follows (Vendor finds, `Profit.lua`'s AH-or-vendor, the dialog's `VendorSafe`, RapidFire's `Ceiling`, which also checks `Items:IsUnsellable` for vendor flips saved before).
- Learned from bags on `BAG_UPDATE_DELAYED`: `C_Container.GetContainerItemInfo(...).hasNoValue` on an item whose item data has a sell price above 0 (Forever API docs; Blizzard's bag code reads the field; confirmed in game: `true` for every Blinding Powder stack, 2026-11-24, knowledge file "Merchants"). From merchants: `hooksecurefunc(C_Container, "UseContainerItem")` while `MerchantFrame` is shown notes the item; a `UI_ERROR_MESSAGE` within 2 s that is `ERR_VENDOR_DOESNT_BUY` (or contains "doesn't want") marks it. Learning prints one chat line, sends `ITEM_UNSELLABLE` (Vendor finds of it go) and `PRICES_CHANGED`. `/pcraft unsellable [clear]`.
- Why not the tooltip: Forever shows no sell price in tooltips outside a merchant (2026-11-24); Auctionator's "Vendor" line uses the same item data that was wrong.
- **Shipped list** (`Sources/NoVendorValue.lua`, generated; 2026-11-24): `PC.NO_VENDOR_VALUE[itemID] = true` for every item in Forever's `ItemSparse` table (wago.tools, product `wowf`) with `SellPrice` above 0 and `Flags_1` bit `0x1000` ("no vendor value"); 328 items at build 1.60.1.71091 (enchanting dusts, essences and shards, rogue poisons and Blinding Powder, legendaries, Forever-added copies of common items). The flag matches `hasNoValue` on both items checked in game (Blinding Powder, Strange Dust). `Items:IsUnsellable` = learned, or listed and not seen sellable in the bags (`PC.db.sellable` overrules the list, in case the flag is wrong for an item). `Learn` stays silent for listed items (nothing new). `/pcraft unsellable` counts the list; `clear` doesn't touch it. **Regenerate after a Forever patch:** `python3 -I plan/tools/no_vendor_value.py [build]` (newest `wowf` build by default; `plan/` isn't in the zip). `PC.NO_VENDOR_VALUE_MAX_ID` (291874 at that build) is the highest item ID in the data: `Items:IsVerifiedSellable` = not unsellable and (ID up to it, or `PC.db.sellable`), so the orange "!" only marks items newer than the data and never carried (2026-11-24). Assumption, not checked across patches: Blizzard gives new items higher IDs (the Forever-added copies are 2879xx); an item hotfixed to "no vendor value" below the cutoff would pass until the list is regenerated or the bags learn it.
- **Verified sellable** (`PC.db.sellable[itemID] = true`, account-wide; `Items:IsVerifiedSellable`): the same scan (`BAG_UPDATE_DELAYED`, `PLAYER_ENTERING_WORLD`, `ITEM_DATA_CHANGED`, and the bank tabs, `Enum.BagIndex.CharacterBankTab_1` and up, on `BANKFRAME_OPENED` / `PLAYERBANKSLOTS_CHANGED` while open) marks every item with a sell price above 0 and no `hasNoValue` (sends `ITEM_SELLABLE`); a learned unsellable item never counts as verified. Verified also when the shipped data covers the item (above). A **warning only**: Vendor rows of unverified items get an orange "!" and a tooltip line, the buy dialog a note, RapidFire a chat warning when one is sent over; nothing is blocked (the author rejected test buys). RapidFire's `Ceiling` is 0 only for items learned unsellable.

### Showing and buying
- **Left-click** -> Blizzard's Buy tab for the item: with an item key, first `SetDisplayMode(Buy)` (Blizzard's listing panel only sends its search in its `OnShow`, `Blizzard_AuctionHouseItemList.lua`, so it must open anew each time; without this only the first click searched, 2026-11-24), then `AuctionHouseFrame:SelectBrowseResult{ itemKey, minPrice = cheapest }` (what Blizzard's browse list calls on a row click, Forever `Blizzard_AuctionHouseFrame.lua`; Auctionator 346 calls it the same way, `Source_ModernAH/Tabs/Buying/Commodity/Mixins/Main.lua`), then `AuctionHouseFrame.displayMode = nil` as Auctionator does (its note: "prevents bag items breaking in some scenarios"). Gear from a full scan has no item key: `SetDisplayMode(Buy)`, `SetSearchText(name)`, `SearchBar:StartSearch()`. Refused while a quick scan runs. To check in game: no Blizzard block or broken bag clicks afterwards; Blizzard's search box still takes shift-clicked links.
- **Right-click** -> `OnSale:InspectHit(hit)` with `key = "vendor:" .. itemID .. ":" .. variant`, `itemKey` (stackable goods: `C_AuctionHouse.MakeItemKey(itemID)`; gear: none, found by a browse search for its name as On Sale's gear finds), `limit = sellPrice - 1` per unit (strictly below vendor price), `dialogTitle = "ProfitCraft Vendor"`, `prefix = "Vendor"`, `goneText = "No longer below vendor price."`, `vendorPrice = sellPrice`. Stackable goods: every unit of others at or under the limit within the budget (`ReadCommodityOffer`); gear: the cheapest such listing (`ReadItemOffer`).
- **Buy next** (`hit.buyNext`, Vendor finds; items only): `Bought` keeps the dialog open (`LookForNext`): offer cleared, Buy greyed, a fresh `SendSearchQuery` sent only after `AUCTION_HOUSE_PURCHASE_COMPLETED`, so the next offer (`ReadItemOffer`, cheapest at or under the limit) can't be the auction just bought; no auction IDs are remembered, since one Blizzard row can stand for several items. `AUCTION_HOUSE_SHOW_ERROR` (refused, e.g. someone faster) also looks for the next (`Failed(message, retry)`); a Blizzard block still stops. Running totals in the dialog (`state.boughtCount`, `boughtTotal`); one chat line when the dialog closes (`Report`). No answer within 5 s: the dialog says so and closes, the row stays.
- **Vendor safety** (`VendorSafe(hit, total, quantity)`: `total < vendorPrice x quantity`): checked in `Buy` right before the purchase call (a plain check, allowed before the call) and on the commodity quote (`COMMODITY_PRICE_UPDATED`: cancelled with "it would no longer earn anything at a vendor"), on top of the limit `vendorPrice - 1` that keeps such listings out of offers. Hits without `vendorPrice` (On Sale, Recipes) always pass.
- Changes to the shared dialog in `UI/OnSale.lua`:
  - `ShowOffer`: with `hit.vendorPrice`, the note reads "Vendor pays X each - profit Y" for the offered quantity (vendorPrice × quantity − total).
  - `Gone` and `Bought` call `hit.remove(hit)` / `hit.bought(hit, offer)` when the hit has them, else `OnSale:RemoveHit` as now. Vendor hits: `bought` takes the bought units and cost off the row (removed at 0 units), `remove` removes the row. The Recipes panel's hits are unaffected.

### On Sale's screen glow
- The glow's `OnUpdate` also stops it once it has run **5 s** (`GLOW_SECONDS`); the existing stops stay (mouse over the AH window, the panel or the buy dialog; no finds left; AH closed). A new find restarts it.

### To check in game
- [ ] The vendor price in item data matches what a merchant pays (the author's yellow shirt: 5s).
- [ ] Random-suffix gear sells to a vendor for the base item's price (item data is per item ID).
- [ ] The glow's colour: the author sees red; the tint is gold.

## 17. Profit list changes (0.4.0, built 2026-11-24, not yet tested in game)

What and why: `FEATURES.md` "Version 0.4.0".

### AH or vendor, whichever pays more (`Profit.lua`)
- Per item made: `saleNet` = the higher of `salePrice x (1 - cut)` (AH) and `vendorPrice` (`PC.Items:GetSellPrice`; 0 or not loaded = none); `saleHow` = "ah" or "vendor"; a tie counts as vendor. Bind-on-pickup products: vendor only (they have no AH price). No AH price but a vendor price: the vendor price counts and the recipe is complete. Neither: missing (bound products: "can't be sold", not missing).
- `profitCraft = saleNet x quantity - cost`; `BatchProfit` uses `saleNet`. `salePrice` (AH price) stays in the result for display.
- Disenchant mode is unchanged (craft, disenchant, sell the materials on the AH).
- Where the sale shows: row tooltip (`UI/Panel.lua`, the "Sale" line), recipe details (`UI/Details.lua`: "(AH)" / "(Vend)" in front of "Net profit per craft"), recipe tooltips (`UI/RecipeTooltip.lua`: "Sale price" with the source in front, the AH price before its cut or the vendor price), the Recipes panel (`UI/AHRecipes.lua`: profit only). Sources are shown as reagent sources are (`Prices:FormatReagent`).
- Item data loading: a product whose item data isn't loaded yet has no vendor price; `ITEM_DATA_CHANGED` already triggers a recalculation.

### Per stack for products that don't stack
- `result.stackSize` stays the real stack size; `result.batch` = the stack size when it is above 1, else **10** (`Profit.NON_STACK_BATCH`). `BatchProfit` (was the per-stack calculation) prices the reagents for `ceil(batch / quantity)` crafts together, counts the reagent cost per item made times `batch` (`result.batchCost`) and gives `profitStack = saleNet x batch - batchCost`. Per stack mode, its sort, "Profitable only" in that mode, the Recipes panel's per-stack column and the Shift tooltip use it. Labels: "x20" for stacks, "x10" for the rest.

### Row tooltip (`UI/Panel.lua`)
- Lines, per craft: "Sale (2 x 1s)" with "(AH) 2s"; "AH cut (5%)" -10c (left out when the vendor price counts); "Reagents" -1s 20c; "Profit per craft" +70c. Then craft-and-disenchant and missing prices. Incomplete results show the reagent cost per craft, and "Bind on pickup, no vendor price: can't be sold" where it applies.
- **Shift:** the same lines for `batch` items ("Profit per stack of 20" / "Profit per 10"), with `batchCost` as the reagents. `IsShiftKeyDown()` when the tooltip is built; `MODIFIER_STATE_CHANGED` (LSHIFT / RSHIFT) rebuilds the tooltip of the row under the mouse while it is shown. A grey line while Shift isn't held: "Hold Shift: per stack of 20" (or "per 10").

### Search box (`UI/Panel.lua`)
- A search box (Blizzard's `SearchBoxTemplate`, `Blizzard_SharedXML/Shared/InputBox/InputBoxTemplates.xml`; Forever's own recipe list uses it, `Blizzard_ProfessionsRecipeList.xml`), 110 px, right of "Profitable only"; `HookScript("OnTextChanged")` keeps the template's own handling. Filters the shown rows by recipe name, plain text, any case (`string.find(name:lower(), text:lower(), 1, true)`), on every keystroke; only re-reads the stored results (section 1, "Fast by design"). Not saved; cleared when the profession window closes. The "n of m" count counts what both filters leave.
