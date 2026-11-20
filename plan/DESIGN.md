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
| 2 | 0.2 (final published 2026-11-19) | "Version 0.2": money window (beta.0), own AH scan, own merchant recording, "most recent per item" price choice, RapidFire | Auctionator and our own data; works without Auctionator |
| 3 | 0.3 | "Version 0.3: On Sale" (watched searches, hit list) | Same; history source open |
| 4 | 0.4 | "Version 0.4" (filters, hover breakdown, vendor comparison, crafted reagents, shopping list; was 0.3) | Same |

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
| `Scan.lua` | Data | AH scan data (0.2, section 9): follows Auctionator's scans or runs its own full scan (button on the AH window), keeps the snapshot of recipe items |
| `UI/Rapid.lua` | Window | RapidFire (0.2-beta.3): "RapidFire" button on the AH window, watch list panel, live commodity searches, deal popup with the buy key, purchase with quote check (FEATURES.md "Watch list & quick buy") |
| `History.lua` | Prices | 0.3: own price history per item and suffix, usual price, Auctionator fallback (section 13) |
| `OnSale.lua` | Data | 0.3: watched searches (parse, run, pace), hit check, hit list upkeep (section 13) |
| `UI/OnSale.lua` | Window | 0.3: On Sale button and panel (Hits, Searches), buy dialog (section 13) |
| `UI/MoneyWindow.lua` | Window | Currencies bar (code name: money window): money and up to 5 tracked currencies, right-click menu (0.2) |
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
  snapshot = {          -- 0.2: the latest detailed scan, per ruleset key, overwritten by each scan (section 9)
    ["<ruleset key>"] = {
      time   = 1763030400,
      levels = { [itemID] = { { 120, 400 }, { 125, 80 } } },  -- recipe items only: {price per unit, quantity}, cheapest first, capped
      onSale = { ... },                                         -- the scan's on-sale hits
    },
  },
  vendor = { [itemID] = 125 },   -- milestone 2: our own merchant buy prices (copper per item)
  onSale = {            -- 0.3 (section 13); one list for the account
    searches = { { name = "Mail 20-30 Knight", term = 'of the Knight;Armor/Mail;;;20;30;;;;;2;;;', on = true } },
  },
  history = {           -- 0.3 (section 13), per ruleset key
    ["<ruleset key>"] = { ["<itemID>:<suffix>"] = { today = { day = 20411, [14] = 4200, ... }, days = { [20410] = 4300, ... } } },
  },
}
```

- 0.1 stores only `version`, `settings` and `errors`; all prices come from Auctionator.
- The settings checkbox for Blizzard's own free-bag-space option stores nothing here: it reads and writes Blizzard's game setting `displayFreeBagSlots` (section 7).
- Forever has no classic realms: it has 4 rulesets, each a "megaserver" with its own data: Normal, PvP, Roleplay and Roleplay-PvP; all players of a ruleset share one AH (Sylice, 2026-11-13). Prices are kept per ruleset **and faction** (cross-faction AH assumed not shared until confirmed).
- **Ruleset key** (milestone 2) = `GetRealmName()` with the instance number ("Realm 7") removed, plus the faction: "CAMWOW US2 Realm 7 PvE" + Alliance → `CAMWOW US2 PvE|Alliance`. Removing only "Realm <number>" merges characters on different instances of the same ruleset, while keeping the rest of the name means Roleplay and Roleplay-PvP (names unknown; Sylice's guess: "Roleplay" or "RP") can't collide with Normal or PvP. The raw realm name is stored with the data, so the key can be corrected later.
- Size: the snapshot holds only recipe items and is replaced by every scan, so it doesn't grow. From 0.3 our own history is kept (section 13: 14 days, estimated 1-3 MB; check after a week). Until 0.3 no history was kept (Auctionator's was used, section 9). Earlier plan (dropped 2026-11-17): own prices with a pruning rule.
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
- **Create Profit Macro** button (0.2-beta.0), bottom right of ProfitCraft's own settings window only (the version number moved to the bottom left): `CreateMacro("PCraft", icon, "/pcraft [btn:2] settings; [btn:1]", false)` (general macro; Forever's own macro window uses `CreateMacro`, `Blizzard_MacroUI`). Icon: `Interface\Icons\Achievement_GuildPerk_MobileBanking` (a money bag; used by Forever's bank window, `Blizzard_UIPanels_Game/Camelot/BankFrame.xml`), passed as a file ID via `GetFileIDFromPath`. Disabled (tooltip still shown, `SetMotionScriptsWhileDisabled`) when a general or character macro named PCraft exists or all general slots are used; rechecked when the window opens and on `UPDATE_MACROS`. Since beta.1, hovering the PCraft macro on an action bar adds two lines (left-click / right-click) to its tooltip: a `hooksecurefunc` on `GameTooltip:SetAction`, which Blizzard's action buttons call on mouse-over and on their own 0.2 s tooltip refresh (`Blizzard_ActionBar/Shared/ActionButton.lua`, `TOOLTIP_UPDATE_TIME`), identified by `C_ActionBar.GetActionText(slot) == "PCraft"`; no polling. Action bar addons that build tooltips without `SetAction` don't get the lines. `/pcraft` evaluates macro conditions itself with `SecureCmdOptionParse` when its text contains "[" (nothing matching = nothing happens, like Blizzard's `/stopattack`).
- 0.2-beta.1: a "PRICES" heading (option type `title`) over the price-age slider, the new crumb slider (`crumbPercent`: 0.5/1/2/3%, default 1; a slider option may step through a `values` list) and the disenchant tooltip line; "Money window" shown as "Currencies bar".
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

## 9. AH scan data (0.2; decided 2026-11-17, replaces the earlier "own scan with own history" outline)

**Principle:** Auctionator keeps the history; ProfitCraft keeps only a small, current snapshot. With Auctionator, ProfitCraft never scans itself: it reads along with Auctionator's scan.

**Full scans on Forever.** `C_AuctionHouse.ReplicateItems()` downloads every auction ("should be used in place of an 'allItem' query to query the entire auction house"; browse searches are limited to 100 calls a minute and "should not be used to query the entire auction house", Forever API docs `AuctionHouseDocumentation.lua`). When the data is ready the game fires `REPLICATE_ITEM_LIST_UPDATE` to every addon listening, and any addon can read the listings with `C_AuctionHouse.GetNumReplicateItems()` / `GetReplicateItemInfo(index)`: name, texture, count, quality, level, minBid, buyoutPrice, owner, ownerFullName, itemID, hasAllInfo (Forever docs). Entries with `hasAllInfo = false` need their item data loaded first (Auctionator waits for it, `Source_ModernAH/FullScan/Mixins/Frame.lua`). **Works on Forever:** Auctionator's replicate mode finished with "Finished processing 6552 items" (Sylice, in game, 2026-11-17; knowledge file).

**With Auctionator** (installed and enabled, `C_AddOns.IsAddOnLoaded`):
- No ProfitCraft scan button.
- Auctionator has one scan routine per mode (Auctionator 346): `AuctionatorFullScanFrameMixin:InitiateScan` (replicate mode, option `replicate_scan_3`, label "Use alternate slower scan mode by default" in Advanced) and `AuctionatorIncrementalScanFrameMixin:InitiateScan` (summary mode, the default: one empty `SendBrowseQuery`, lowest price and quantity per item only). ProfitCraft hooks both (`hooksecurefunc` on the mixins; the frames are created from them when the AH opens). Internal Auctionator code: each hook checks the mixin exists and runs in `PC:Call`, so a renamed function only disables the message.
  - Replicate scan started -> ProfitCraft listens for `REPLICATE_ITEM_LIST_UPDATE`, reads the listings (its own pass over `GetReplicateItemInfo`; Auctionator reads them too, independently), prints "reading Auctionator's full scan..." and a short result ("done: N items on sale").
  - Summary scan started -> chat notice: summary scan detected; for exact reagent costs and on-sale detection switch Auctionator to its detailed scan: Auctionator settings > Advanced > "Use alternate slower scan mode by default". Prices keep coming from Auctionator's public API as in 0.1.
- Auctionator only listens to its own scans (it registers `REPLICATE_ITEM_LIST_UPDATE` in `RegisterForEvents` when it starts one), so a scan started by ProfitCraft would not update Auctionator. That is why ProfitCraft has no button when Auctionator is present.

**Without Auctionator:** a **Scan** button at the AH starts `ReplicateItems()` (full scans only; at most one per 15 minutes, the limit Auctionator also uses, `FullScan/Mixins/Frame.lua` `CanInitiate`; the button shows the wait). No history, so no On Sale; prices and profit work from the snapshot.

**Reading a scan** (both cases): one pass over all listings, in batches across frames so the game doesn't stall (thousands of listings; Auctionator also batches).
- ProfitCraft reports as soon as it has read the list, usually long before Auctionator's "Finished processing" (Auctionator builds a link and database key for every listing and stores them all). Same data: both start on the same `REPLICATE_ITEM_LIST_UPDATE`. Kept that way on purpose so On Sale alerts come immediately (Sylice, 2026-11-17).
- Listings of recipe items delivered incomplete (`hasAllInfo` false) are read again after `ITEM_DATA_LOAD_RESULT` for their item (requested with `C_Item.RequestLoadItemDataByID`), as Auctionator does; after 10 s without data the scan finishes anyway and the done message says how many were left out (0.2-beta.2).
- Per listing: price per unit = buyout / count; listings without a buyout (bid only) are skipped; **own listings are skipped** (owner = the player; when the owner isn't loaded yet the listing counts as someone else's).
- **Saved** (`ProfitCraftDB.snapshot[rulesetKey]`, overwritten by every scan): scan time; for the reagents and products of all recipes ProfitCraft has seen on the account, the cheapest price levels as {price per unit, quantity}, capped per item (CraftProfit's cap is 20 levels); the on-sale hits.
- **Not saved:** everything else. Each listing is checked once against the item's usual price (On Sale) and then dropped.
- Scale (Sylice's data, 2026-11-17): a full scan covers about 6,500 different items (Auctionator: 7,073 items, 1 MB); recipe items only, CraftProfit: 87 items' ladders, 18.5 KB.

**History** (with Auctionator only): `Auctionator.Database:GetPriceHistory(dbKey)` (per day: lowest price, highest of the daily lows, quantity) and `GetMeanPrice(dbKey, days)` (Auctionator 346, `Source/Database/Mixin.lua:155`, `205`), internal, so wrapped like the hooks. 21 days by default (Auctionator option). Used for 3-/7-day averages, trend and the On Sale "usual price". Random-suffix items: **checked 2026-11-19, it does not separate them on Forever** (all keys are plain item IDs; suffix keys only for Classic's old AH, `Source/Utilities/DBKeyFromLink.lua`). From 0.3 our own history is the main source and Auctionator's only a fallback (section 13).

**Prices from the snapshot** (both rules fall back to Auctionator's lowest price, or none, when there's no detailed scan):
- Reagent cost: needed quantity = recipe amount x crafts in the current mode (1, or enough for a full stack of the product); take price levels cheapest first until the quantity is covered; too few listed -> flagged "only N listed". Vendor price still wins when cheaper. Single units are counted: reagents can be bought by quantity (Sylice, 2026-11-17).
- Stackable items (`itemStackCount` > 1): price levels with less than the crumb limit of all units listed (setting, 0.5/1/2/3%, default 1%) are ignored, for reagent cost and sale price. Sale price = cheapest remaining level.
- Non-stackable items: sale price = the cheapest listing unless it is below the item's usual price by more than the BoE discount (Auctionator's 7-day mean, `GetMeanPrice(dbKey, 7)`); then the next listing.
- On Sale thresholds (sliders, own settings area): BoE discount 50-90% (5% steps, default 65%), reagent discount 40-75% (default 40%); reagents also must clear the crumb limit.
- "Most recent per item" (FEATURES.md) still decides between Auctionator's price and the snapshot.

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
- [ ] 0.2-beta.0 in game: the PCraft macro's icon shows (money bag) and right-click on the action bar opens the settings ([btn:2]); which currencies Forever has and whether they appear in the Add currency list; the colour picker's opacity slider changes the background live.
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

## 13. On Sale (0.3; decided and built 2026-11-19; published as 0.3-beta.0, not yet seen in game)

Files: `History.lua`, `OnSale.lua`, `UI/OnSale.lua`; `Scan.lua` hands every listing of other sellers to On Sale (an error there switches On Sale off for that scan only, so the snapshot is never affected). Tests: 66 checks in the harness (286 in all, 15 without Auctionator).

**Alerts on a new find:** sound (`SOUNDKIT.RAID_WARNING`), `FlashClientIcon()` (Blizzard's PvP queue / ready check use it), and a gold screen glow: a full-screen frame (strata FULLSCREEN, no mouse) with Blizzard's low-health texture `Interface\FullScreenTextures\LowHealth` (additive, `Blizzard_FrameXML/Mainline/LowHealthFrame.xml`) tinted gold, pulsing until the mouse is over the AH window, the On Sale panel or the buy dialog, or the finds are gone, or the AH closes. Settings `onSaleSound`, `onSaleGlow`.

What and why: `FEATURES.md` "Version 0.3". Goal: a character waits at the AH with the game in the background; ProfitCraft runs Sylice's searches on its own, plays a sound on a find, and Sylice buys with two clicks. Works without Auctionator.

### Searches

- **Stored as Auctionator's text format**, one string per search: `text;category;minItemLevel;maxItemLevel;minLevel;maxLevel;minCraftedLevel;maxCraftedLevel;minPrice;maxPrice;quality;tier;expansion;quantity` (field order from Auctionator 346 `Source/Search/Advanced.lua` `SplitAdvancedSearch`; divider `;`, `Source/Constants/Main.lua:9`); text in double quotes = exact match. ProfitCraft parses it with its own code (a data format, not copied code). Fields ProfitCraft doesn't use (crafted level, tier, expansion, quantity) are kept so a pasted search round-trips unchanged.
- **Categories** are Blizzard's: `category` is the path of names in Blizzard's global `AuctionCategories` joined with `/` (e.g. "Armor/Mail"), each category carrying its own `filters` (class, subclass, inventory type). This is how Auctionator resolves them too (`Source/Search/Categories.lua`); Forever defines the table in `Blizzard_AuctionHouseUI/Camelot/Blizzard_AuctionData.lua`. Category names are the client's language (English for all testers).
- **Paste in:** one search per line, or Auctionator's list export `ListName^search1^search2` (`Source/Shopping/ImportExport.lua`); the list name becomes a group label. Also the future outside tool's output (FEATURES.md "Side project").
- **Editor:** name, text + "exact" box, category dropdown (from `AuctionCategories`), level min/max, item level min/max, quality (minimum), on/off.
- **Running a search:** `C_AuctionHouse.SendBrowseQuery{ searchString, sorts, minLevel, maxLevel, filters = quality filters, itemClassFilters = the category's filters }` (Forever API docs, `AuctionHouseBrowseQuery`); more pages with `RequestMoreBrowseResults` until `HasFullBrowseResults()`. Results (`BrowseResultInfo`): `itemKey` (itemID, itemLevel, itemSuffix), `minPrice`, `totalQuantity`, `containsOwnerItem`. Item level and exact-name checks are done by ProfitCraft on the results (as Auctionator does; names from `C_AuctionHouse.GetItemKeyInfo`).
- **Pace:** one AH request at a time, at most one a second (Blizzard's limit is 100 searches a minute, Forever API docs). **RapidFire and On Sale never run together**: starting one stops the other (both drive the AH's single current search; built 2026-11-19 instead of sharing the pace). Each page counts as a request until known otherwise. Interval setting = pause between two searches (default 10 s); each search comes round every (number of active searches x interval). Shown in the status line ("5 searches, each every 50 s").
- **Pause** while the buy dialog is open, and for 30 s after anyone else's AH search: `hooksecurefunc` on `C_AuctionHouse.SendBrowseQuery`, `SendSearchQuery`, `SearchForItemKeys`, `SearchForFavorites`, `SendSellSearchQuery`; ProfitCraft's own calls are marked (`OnSale.Send`) so they don't count. This catches Blizzard's window and Auctionator alike. The request in flight is dropped (its answer would mix with theirs).
- **Quality** is read as "this or better" (Sylice: "Uncommon or better"); Auctionator reads its quality field as exactly that quality.
- **Stackable or gear** while the item data isn't cached (`C_Item.IsItemDataCachedByID`): weapons and armor (`GetItemInfoInstant` class 2/4) count as gear, everything else as stackable, so a full scan requests no item data.

### Fixes after Sylice's first full scan (2026-11-19, `data/screenshots/signal-2026-11-19-17-03-22-446.jpg`: 311 finds; released as `0.3.1` on 2026-11-19, not yet seen in game)

- **Suffix from the name, not the link:** "Engraved Cape of the Beast" got Auctionator's (suffix-mixed) usual price, so the link's suffixID field doesn't carry Forever's random suffix. Weapons and armour are now keyed by their full name in lower case (`OnSale:Variant`); a browse result whose name is unknown or lacks the suffix uses `#<itemSuffix>`. **Weapons and armour never use Auctionator's history.** Gear found by a full scan has no item key; clicking it first runs a browse search for its name and takes the result whose name matches.
- **Blank names:** the scan returns `""` as the name of items whose data isn't loaded; then the name comes from the item link (gear) or the item data (display).
- **Market check** (percent rule only): more than half of the units listed (stackable goods), or more than half of the listings when there are at least 3 (gear, full scans), under the On Sale price = the market moved, no find. Cause seen: prices fell since launch, and placeholder prices (99g 99s 98c) as an item's daily low.
- **Per-search rule, either/or** (Sylice): **percent** (own percent, empty = the settings by item type; own minimum profit, prefilled from the setting) or **fixed price** (at or under a price; no history, no crumb or market check, profit shown only when a usual price is known). Stored on the search (`rule`, `percent`, `minProfit`, `maxPrice`), not in the Auctionator text. Full scans use the settings.
- **Rounding:** limits use whole numbers (`usual * (100 - percent) / 100`); `usual * (1 - 0.8)` gave 19s 99c for a 1g usual price.
- Tab and Shift-Tab between the editor's fields (hidden ones skipped); Searches is the left page button, Finds the right.
- Tests: 303 checks + 15 without Auctionator.

### Smarter usual price and sorting (released as `0.3.2`, 2026-11-20)

Sylice: keep looking for deals across **all** items (full-scan finds stay for everything), but stop reporting prices that have simply come down (stacks of craftable potions), and sort the list. Rejected idea: comparing with "the current market" weighted by units listed (Sylice: 3000 Silk Cloth at 2s among 10,000 higher is the real price, not a sale; listings above it are just unsold).
- **Usual price = the lower of the 7-day median and the median of the last 2 days** (today's so far included), for our own history and Auctionator's. A price that has come down and stays there is the new usual within about two days; one cheap hour among normal ones barely moves it.
- **The recorded price of stackable goods is the floor without crumbs** (the cheapest level holding at least the crumb limit's share of all units; `OnSale:Floor`), from full scans and from the unit check of a candidate; a browse result that is a stackable candidate isn't recorded from its cheapest listing.
- History was already floor-based (cheapest listing per hour, not an average), so listings far above the floor never raised the usual price.
- **Sorting:** newest first by the minute (a scan's finds arrive together), then the biggest profit, unknown profit last.
- **Scroll bars:** Finds and Searches are Blizzard scroll lists (`PC:CreateScrollList`, now with an optional area to fill) with a scroll bar, instead of fixed rows scrolled only by the mouse wheel (Sylice: to see how long the list is).
- Not possible: knowing the price things **sell** at (the AH shows addons listings, not sales). Inferring sales from listings that disappear between checks would be a separate, bigger feature.
- Tests: 309 checks + 15 without Auctionator.

### Scan notices, 3 days in the last 7, local days (released as `0.3.3`, 2026-11-20)

- **Summary-scan notice** (Sylice: Auctionator's detailed scan is vital; no pop-up boxes, never on just opening the AH): only when Auctionator really runs a summary scan, a raid-warning style message (`RaidWarningFrame:AddMessage`, Forever `Blizzard_RaidWarning`, raid-warning colour) plus an orange chat line with the setting's path. Setting `scanWarning` (on by default, ON SALE column) turns it off.
- **History notice:** ProfitCraft notes each local day on which it reads a full scan (`ProfitCraftDB.scanDays[ruleset key]`). After a scan, while that's fewer than 3 of the last 7 days, an orange chat line says so (same setting). The On Sale panel shows "History: N of 7 days" at its top right (orange under 3, green from 3; tooltip explains).
- **Usual price needs 3 days with prices within the last 7 days** and uses only those days (was: any 3 of up to 14 stored days). Auctionator's history is limited to its last 7 days too (its day numbers count from `Auctionator.Constants.SCAN_DAY_0`).
- **Days and hours follow the local clock** (day changes at local midnight; was UTC, 19:00 for Sylice). Offset from `date("!*t")` with the summer-time flag carried over.
- Tests: 318 checks + 15 without Auctionator.

### History (own, per item and variant)

- **Key:** `itemID:variant` per ruleset key (section 6): variant 0, or for weapons and armour the full name in lower case (see the fixes above; was `itemID:suffix` in 0.3-beta.0). Item level is left out of the key: on Forever an item ID has one item level unless scaled; to revisit if results show several levels per item ID.
- **Samples:** each time ProfitCraft sees an item's cheapest price from other sellers (a browse result, or the lowest buyout per unit of that key in a full scan), it keeps it as that hour's sample (first sample per hour per key). Own listings: a browse row with `containsOwnerItem` is skipped for history (its minimum may be ours); full scans skip own listings as in section 9.
- **Daily price** = the median of that day's hourly samples. Using the lowest price of the day instead would follow every short-lived cheap listing that bots snap up, and a watch that searches every minute sees far more of those than a scan every few hours (Auctionator's daily low comes from scans), so the usual price would drift down.
- **Usual price** = the median of the last 7 daily prices, once there are at least 3 days. Kept: 14 days; a key not seen for 14 days is dropped.
- **Fallback while ours has < 3 days:** Auctionator's history (`Auctionator.Database:GetPriceHistory` / `GetMeanPrice`, internal, wrapped as in section 9) for stackable goods and for gear without a random suffix. Gear with a suffix: no usual price, no alert. Suffix known from `itemSuffix` (browse) or the item link (full scan).
- **Size:** today's hourly samples (<= 24 per key) plus one number per past day. A full scan covers about 6,500 items (section 9), more keys with suffixes; estimated 1-3 MB of saved data at 14 days. Check the real size after a week of use; if too big, keep history only for items matched by a search or recipe.

### Hits

- **Check:** a result is a hit when its price is at or under the usual price x (1 - discount) (gear 65%, reagents 40%, sliders) **and** the profit (usual price x (1 - AH cut) - price) is at least the minimum profit (default 50s).
- **Stackable goods** (browse rows show only the cheapest price): a candidate gets one item search (`SendSearchQuery`) to count the units at or under the On Sale price; the crumb limit (section 9) applies, so 100 cheap units among 50,000 never alert.
- **Full scans:** every listing is checked in memory while the scan is read (section 9); hits join the same list.
- **Hit list rows:** icon, name with suffix, price, usual price, profit, quantity (stackable), age ("12 s ago"), source (search name or "full scan"). Newest on top. Sound and taskbar flash only for new hits.
- **Self-maintaining:** each run of a search updates or removes its hits (gone, or price now above the On Sale price). Full-scan hits not covered by any search are re-checked in batches with `C_AuctionHouse.SearchForItemKeys(itemKeys, sorts)` (one request for many keys; whether it counts as one search: to check).
- **Buying:** click a row -> item search for that key (`SendSearchQuery`; gear results via `GetItemSearchResultInfo`: auctionID, buyoutAmount, owners) -> dialog "Buy N for X? (usual Y, profit Z)" -> click **Buy**: gear `C_AuctionHouse.PlaceBid(auctionID, buyoutAmount)`, stackable goods RapidFire's `StartCommoditiesPurchase` path with the quote check. Both are restricted (Forever API docs, `HasRestrictions`), so the call is the **first thing in the click** (knowledge file). The keep-at-least balance from RapidFire applies.

### Settings ("On Sale" area)

A second column of the settings window (`{ column = true }` in the option list; window width grows per column): gear discount (50-90%, default 65%), reagent discount (40-75%, default 40%), minimum profit (none, 10s, 25s, 50s (default), 1g, 2.5g, 5g, 10g), pause between searches (5 s, 10 s (default), 15 s, 30 s, 1 min, 2 min), sound on/off. Searches and the finds are in the On Sale panel. The buy dialog uses RapidFire's "keep at least" money.

### UI

An **"On Sale"** button on the AH window left of RapidFire's ("On Sale (3)" with finds) opens the On Sale panel at the AH window's right edge (one of the two panels at a time): pages **Finds** (newest first, mouse wheel scrolls; hover for details, click to buy) and **Searches** (on/off, Edit, x, New search, Paste searches), Start/Stop and a status line at the bottom. The editor's category menu is Blizzard's category tree, each submenu starting with "All <category>". Not running when the AH opens; stops when it closes, and the finds are cleared then.

### To check in game

- [ ] Browse search with category and level filters works as documented; whether each `RequestMoreBrowseResults` page counts toward the 100-a-minute limit.
- [ ] Browse results carry `itemSuffix` for random-suffix gear (one row per suffix), and `GetItemKeyInfo(itemKey).itemName` includes the suffix.
- [ ] How a suffix appears in a Forever item link (to match full-scan listings with browse keys).
- [ ] Server text search matches suffixes ("of the Knight" in Blizzard's search box; FEATURES.md).
- [ ] Idle logout while the watch runs (FEATURES.md).
- [ ] `FlashClientIcon` under Wine (Sylice expects it not to work).
- [ ] The gold glow shows (the low-health texture exists in Forever's client) and stops when the mouse reaches the AH window.
- [ ] `SearchForItemKeys` (re-check of full-scan finds) answers with the browse events (assumed: Blizzard's favourites search, `SearchForFavorites`, fills the browse list the same way). If not, those finds simply stay until the AH closes; clicking one still checks the live listings.
- [ ] Blizzard's own AH window doesn't send searches by itself while On Sale runs (that would show as "paused: someone else searched" without you searching).
- [ ] Full-scan finds of gear: the item key built from the link's suffix and `GetDetailedItemLevelInfo` finds the listings when clicked.
- [ ] Button and panel placement on the AH window.
