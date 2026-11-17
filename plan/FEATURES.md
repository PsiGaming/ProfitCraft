# ProfitCraft: feature list (draft)

Check the features to keep; delete or move the rest. Based on the review of ForeverProfit v1.8.0 and CraftProfit 0.5.2 (2026-11-13). Both subtract the 5% AH cut; neither counts the listing deposit, which is refunded on sale (decided 2026-11-13: ProfitCraft leaves it out too, since items are expected to sell).

## Version 0.1 (Auctionator only)

All testers (Sylice and friends) have Auctionator installed and scan with it (decided 2026-11-13).

- [x] **One ranked list** of every recipe across all categories, sorted by real profit, so the top 5 are visible at a glance. In its own **compact** side panel attached to the profession window, much narrower than ForeverProfit's (a 620 px window plus a 176 px sidebar); Blizzard's recipe list is not modified. Fixed width in 0.1; long names are shortened and shown in full in the tooltip (a resize grip can come later if names get cut off).
- [x] **Profit inside the recipe details** (the right-hand side of the profession window, like CraftProfit): net profit for the selected recipe and the cost of each reagent. No "sort by profit" checkbox in Blizzard's list; sorting is the side panel's job.
- [x] **Real profit:** sale − AH cut (5%) − reagent cost. The listing deposit is left out (refunded when the item sells); see "Later / maybe".
- [x] **Recipes that make several items:** a fixed amount (Rough Dynamite ×2, Crafted Light Shot ×200) counts as is; a random range (Heavy Dynamite 1-5) counts at its average, with the range shown in the tooltip. (Decided 2026-11-13.)
- [x] **Missing prices are flagged**, never counted as profit.
- [x] **Per craft / per stack toggle** in the side panel (a button in its header; no entry in the settings window). Per stack shows the profit for one full stack of the crafted item, with the stack size shown (e.g. "×20"); the ranking re-sorts by the chosen mode. The stack size is read from the item data (`itemStackCount` from `C_Item.GetItemInfo`); items that don't stack (e.g. gear) have a stack size of 1, so both modes show the same. The last mode used is remembered. (Decided 2026-11-13.)
- [x] **AH prices from Auctionator**, through its public API.
- [x] **Vendor prices.** A reagent costs the **lower** of its merchant buy price (Auctionator's recorded price) and its AH price; with no merchant price known, the AH price is used; with neither, it is "missing". (Decided 2026-11-13; the reagent lines show "vendor" or "AH".) Sell price (what a merchant pays): Blizzard's item data (`sellPrice` from `C_Item.GetItemInfo`), used in the bag window.
- [x] **Fast by design:** prices are calculated once, and again only when prices or recipes change. Sorting, filtering, scrolling and searching only re-read the saved results.
- [x] **Slash command `/pcraft`.** (Decided 2026-11-13.)
- [x] **Disenchanting** (added 2026-11-13). First used Auctionator's disenchant estimate, which is empty on Forever; since alpha.4 ProfitCraft's own estimate (`Disenchant.lua`, DESIGN.md section 12):
  - **Item tooltips:** a "Disenchant (est.)" line with the possible materials; off by default; `/pcraft tooltip on|off` or the settings window.
  - **Bag window** (`/pcraft bags`, or "Bags" in the side panel): every disenchantable item in your bags with its disenchant estimate, AH price and merchant price per item; the option that pays most after the AH cut is marked. Soulbound items have no AH option.
  - **Craft and disenchant:** a third side-panel mode, "Disenchant", ranks recipes by crafting and disenchanting the product (estimate × quantity × (1 − AH cut) − reagent cost); also shown in the row tooltip and the recipe details.
- [x] **Debug mode, off by default.** Errors never pop up while playing; they are always written to a small error log. With debug mode on, they are also shown in chat. `/pcraft debug on|off` in 0.1, plus a checkbox in the settings window from 0.3; `/pcraft errors` shows the log. (Decided 2026-11-13.)

## Version 0.1, added before the first install (2026-11-13)

- [x] **Reagent bag free slots, off by default**: "(n)" on the reagent bag button, styled like Blizzard's backpack count. The normal bags use Forever's built-in "Show Free Bag Space" option (Options > Interface; one total on the backpack button), which Sylice uses for the normal bags (2026-11-13). Blizzard's total turned out to include the reagent bag (Sylice, 2026-11-17); replaced in 0.1-rc.0 (below).
- [x] **Settings window brought forward from 0.3** (our own window, see Requirements): disenchant tooltip line, reagent bag free slots, debug mode. `/pcraft settings` or the side panel's "Settings" button.

## Version 0.1-alpha.1 (fixes after Sylice's first test, 2026-11-13)

- [x] Mode switch is a dropdown (Per craft / Per stack / Disenchant) instead of a cycling button.
- [x] Windows use Blizzard's current frame style (ButtonFrameTemplate with portrait), like the profession window.
- [x] Recipe-details block moved to the bottom of the recipe details, so it no longer overlaps Auctionator's "To Craft" / "Profit" lines under the reagents.
- [x] A ProfitCraft tab at the bottom of the profession window's side-tab column shows/hides the panel (lit while open).
- [x] Profitable amounts show a green "+" (losses already showed a red "-").
- [x] Disenchant lookup also tries Auctionator's item-link function when the item-ID one returns nothing. Every item showed "not disenchantable" in the first test; cause not confirmed (see open questions).

## Version 0.1-rc.0 (2026-11-17; release candidate: the last fix before the final 0.1)

- [x] **Free bag slots split** (Sylice, 2026-11-17). Blizzard's backpack count includes the reagent bag, so the reagent bag checkbox and the Blizzard-mirror checkbox are replaced by one dropdown, "Free bag slots": **Off**, **Blizzard only**, **ProfitCraft + Blizzard** ("(reagent|normal)" on the reagent bag button, Blizzard's total on the backpack) and **ProfitCraft only** ("(reagent|normal)" on the backpack in place of Blizzard's total). Reagent first, as the bags sit on the bar. "ProfitCraft only" hides Blizzard's number without turning Blizzard's option off, so the count comes back if ProfitCraft is disabled or removed. Installs that had the reagent bag count on start on "ProfitCraft + Blizzard". To check in game: whether "(6|24)" fits on the small reagent bag button.

## Version 0.1-beta.1 (2026-11-14)

- [x] Trainer and recipe item tooltips list each reagent with its price and source, the source in front so the amounts stay right-aligned: "4 x Copper Bar   (AH) 3s 80c", "2 x Coarse Thread   (Vend) 20c" (the cheaper of the two is used, as before). Replaces the "No AH price: ..." line; a reagent without a price shows "no price".
- [x] Wording (Sylice, 2026-11-14): "AH price" becomes **"Auction price"** (tooltips, side panel row tooltip, recipe details); reagent sources are **"(AH)"** / **"(Vend)"** (short, Sylice), in front of the amount, everywhere, also in the recipe details. "Auction price" (not Auctionator's "Auction") keeps ProfitCraft's lines distinguishable from Auctionator's. Banners and the D/E Bags "AH" column are unchanged.

## Version 0.1-beta.0 (2026-11-14; 0.1 is feature-complete, so betas get fixes only and new features go to 0.2)

- [x] **Price warning banner** at the top of the side panel's list: Auctionator not installed ("required"), no AH prices yet, or prices 48 hours old or more ("scan the AH with Auctionator"). ProfitCraft notes the time of each Auctionator scan per realm (Auctionator's DB-update callback); until it has seen one, it falls back to Auctionator's price age in whole days.
- [x] **Setting: how old prices may get before the banner warns**, a slider in the settings window: Off, 1, 2 (default), 3, 4 days. Whole days only, because Auctionator's price age counts whole days (Sylice, 2026-11-14). Off only hides the old-prices warning; "Auctionator is required" and "No AH prices yet" still show.

## Version 0.1-alpha.5 (2026-11-14; all confirmed working in game by Sylice, 2026-11-14)

- [x] Disenchant tooltip also lists what the item can disenchant into (chance, amount, material), like Auctionator's breakdown; with "?" as the value when a material has no AH price.
- [x] Trainer tooltips: hovering a recipe at a trainer shows reagent cost, AH price of the product, profit per craft and craft-and-disenchant, to decide whether it is worth training.
- [x] Recipe item tooltips (bags, AH, chat links): the same lines, to decide whether to learn, train or sell the recipe.
- [x] Bind-on-pickup products show "can't be sold" / "BoP" instead of an AH price and sale profit, in the new tooltips, the side panel and the recipe details; craft-and-disenchant is still shown.

## Version 0.1-alpha.4 (2026-11-13; disenchant values confirmed working in game by Sylice, 2026-11-14)

- [x] ProfitCraft's own disenchant estimate (`Disenchant.lua`): its own table by quality, armor/weapon and item level, priced with AH prices; replaces Auctionator's disenchant lookup, which is empty on Forever. Used by the tooltip line, D/E Bags and the Disenchant mode. Shown as an estimate until confirmed for Forever.
- [x] Essences count at whichever form sells for more (3 lesser = 1 greater, both ways).
- [x] The disenchant line in item tooltips is off by default for new installs (as in Auctionator).

## Version 0.1-alpha.3 (2026-11-13)

- [x] ProfitCraft's side tab takes the next free slot **from the bottom** of the profession window's right edge (bottom slot 10 px up, like What's Training's; moves up above any other addon's frame already in that column), instead of under Blizzard's profession tabs.
- [x] Settings: a "Free slots on the backpack button (Blizzard)" checkbox that mirrors Blizzard's own "Show Free Bag Space" (game setting `displayFreeBagSlots`); ProfitCraft stores nothing for it, and it follows changes made in Blizzard's Interface options.

## Version 0.1-alpha.2 (2026-11-13)

- [x] ProfitCraft's side tab takes the next free slot under Blizzard's profession tabs instead of a fixed spot (it overlapped What's Training's tab, which sits 10 px from the bottom).
- [x] Side panel: Settings button in the top-right corner; the bag window's button is renamed "D/E Bags" (window title "ProfitCraft: D/E Bags").
- [x] Settings are also in Blizzard's Options > AddOns > ProfitCraft: the same page as ProfitCraft's own window, built from one option list, both always in sync (the approach Questie uses; reimplemented, not copied).

## Version 0.2 (profit works without Auctionator; history and on-sale need it)

From 0.2 on there are no alphas: each beta adds features, rc = done, fixes only (Sylice, 2026-11-17).

- [x] **Money window** (0.2-beta.0; Sylice, 2026-11-17): a small movable window with your money and up to **5** tracked currencies (ProfitCraft's own limit; Blizzard's backpack tracking has no fixed limit on Forever, it fits as many as the backpack is wide), growing to the left as currencies are added. Off by default (settings checkbox, `/pcraft money`). Right-click anywhere: Add currency (pop-out list of the character's currencies), Remove currency, Lock/Unlock position, Background colour (any colour, fully transparent to solid), Hide. One list for all characters. Design: DESIGN.md "Money window".
- [x] **Create Profit Macro** (0.2-beta.0; Sylice, 2026-11-17): a small button in the bottom-right corner of ProfitCraft's settings window creates a general (account-wide) macro **"PCraft"** with a money bag icon (not coins): left-click opens the profit list (`/pcraft`), right-click the settings. Greyed out with the tooltip "Macro already exists" when a macro named PCraft exists (general or character), and "No free general macro slot" when all general slots are used. Design: DESIGN.md "Settings".
- [x] **Settings: "PRICES" heading with the crumb slider; "Money window" renamed "Currencies bar"** (0.2-beta.1; Sylice, 2026-11-17). The setting key stays `moneyWindow` and the command `/pcraft money`, so saved choices keep working.
- [x] **PCraft macro tooltip** (0.2-beta.1, committed, not released; Sylice, 2026-11-17): hovering the PCraft macro on an action bar adds "Left-click: profit list" and "Right-click: ProfitCraft settings" under its name (macros have no tooltip text of their own).
- [x] **AH scan: listen to Auctionator, own button only without it** (built in 0.2-beta.1, hooks seen working in game 2026-11-17; beta.2 re-reads incomplete listings; Sylice, 2026-11-17; replaces the 2026-11-13 plan of a separate own scan with its own history). Design: DESIGN.md section 9.
  - **With Auctionator** (installed and enabled): **no ProfitCraft scan button.** ProfitCraft reads along when Auctionator scans, so one click updates both (no scanning with two addons).
    - Auctionator's **detailed scan** (its "replicate" mode; setting: Auctionator > Advanced > "Use alternate slower scan mode by default"): ProfitCraft reads every listing of that scan and says so in chat ("reading Auctionator's full scan... done").
    - Auctionator's **summary scan** (its default): ProfitCraft prints a chat notice that a summary scan was detected and that the detailed mode gives exact reagent costs and on-sale detection, naming the setting above. ProfitCraft then keeps using Auctionator's normal prices, as in 0.1.
  - **Without Auctionator:** ProfitCraft's own **Scan** button at the AH, full scans only (one every 15 minutes, the game's limit; shows the wait).
  - **History comes from Auctionator** (21 days of daily lowest price and quantity per item, kept by Auctionator anyway): 3- and 7-day averages, trend, the "usual price" for On Sale. ProfitCraft keeps **no history of its own** for now (can be added later). Read through Auctionator's internal functions (no public API for it), wrapped so a change in Auctionator only switches these features off.
  - **What ProfitCraft saves from a scan:** only what it needs, i.e. the cheapest price levels (with quantities) of the reagents and products of your known recipes, the scan time, and the on-sale hits. Everything else in the scan is only looked at during the scan. Your own listings are left out (each listing has its seller).
  - Size, for scale (Sylice's data, 2026-11-17): a full scan covers about 6,500 different items; Auctionator keeps 7,073 items in 1 MB; CraftProfit, which also keeps only recipe items, 87 items' price ladders in 18.5 KB.
- [x] **Reagent cost = what buying the needed quantity costs** (built in 0.2-beta.1; Sylice, 2026-11-17; replaces the "cheapest 20%" idea, which averages over a share of all supply and can misstate cost): needed quantity = the recipe's amount x the crafts of the current mode (1 craft, or enough crafts for a stack of the product); take other sellers' listings cheapest first until that quantity is reached. Example: 1,000 stacks at 1s -> 1s per unit, whatever is listed above. Too little listed -> "only N listed". The vendor price still wins when cheaper. Partial buys work for reagents (Sylice, 2026-11-17), so single units are counted.
- [x] **Sale price = the cheapest price really competing with you** (same date), by item type (Sylice, 2026-11-17: reagents and one-off gear behave differently; prices on the megaserver move fast, so tiny cheap amounts can't realistically be caught):
  - **Stackable items** (reagents, bars, potions, cloth...): price levels holding less than **1% of all units listed** ("crumbs") are ignored, in the sale price **and** the reagent cost (and the reagent On Sale check). Example: 50,000 Silk Cloth, 100 at 1s, the rest from 1s 50c: the 100 are ignored. Setting: 0.5% / 1% / 2% / 3%, default 1%, in the settings' "Prices" section.
  - **Non-stackable items** (gear): the cheapest listing, unless it is far below the item's usual price (Auctionator's 7-day average of daily lows); then the next listing.
  - Prices from a scan are as old as the scan; their age is shown next to them.
- Without a detailed scan (summary mode, or no scan data): both rules fall back to the lowest price, as in 0.1.
- [x] **Our own merchant recording** of vendor buy prices, taken whenever a merchant window is open (the game only reveals buy prices there: item data has only the sell price, Forever API docs); used when Auctionator has no vendor price. Fills itself as you visit vendors. **No pre-filled vendor price table** (Sylice, 2026-11-14): no Forever source for buy prices found, and reagents from vendors you never visit fall back to the AH price or show as missing.
- [ ] **Feed our scan into Auctionator's data** (Sylice's idea, 2026-11-14: our scan may be more thorough). **Not possible through Auctionator's public API** (checked in Auctionator 346, `Source/API/v1/`): it only reads prices, ages, vendor prices and disenchant values, runs searches and edits shopping lists; nothing writes prices. The only way would be writing into Auctionator's internal saved price database, which is undocumented and could corrupt its data whenever Auctionator changes. Not doing unless Auctionator adds a write function. ProfitCraft itself still uses its own newer scan prices (next item).
- [x] **AH prices: whichever is most recent, per item.** For each item, compare Auctionator's price (if Auctionator is installed and has one) with ProfitCraft's own scan data and use the newer one. If both are from the same day and can't be told apart (Auctionator's age may only be in whole days), use our own. (Decided 2026-11-13.)

## RapidFire: watch list & quick buy (built in 0.2-beta.3; Sylice, 2026-11-17)

Named **RapidFire** (Sylice, 2026-11-17): a mode of our own, named without the negative ring of the usual AH-addon term. The name is used everywhere (files, code, texts); the watch list saved under the earlier name is not carried over.

Built as designed below, plus: up to 10 watched items; new items start with max 0 (never bought until a max is set); a scan keeps going while the popup shows, and when the deal is gone it flashes "Opportunity gone" and closes (Sylice); after a purchase it flashes "Bought N for X". "Stackable" is judged by the item's stack size, since `C_AuctionHouse.GetItemCommodityStatus` needs a bag slot (Forever docs).

Changes after Sylice's first test (2026-11-17, released as 0.2-beta.4):
- **Bug: a purchase could hang** (Buy greyed out, popup stuck, scanning paused): no quote ever arrived and there was no time limit. Now: the purchase call matches Blizzard's (`StartCommoditiesPurchase(itemID, quantity, unitPrice)`, Blizzard_AuctionHouseFrame.lua); while the popup shows only the offered item is searched (every second), so the AH's current search is that item, as when buying through Blizzard's window; no quote within 5 s or no result within 10 s cancels and says so; a Blizzard block (`ADDON_ACTION_BLOCKED`/`FORBIDDEN`) is reported in chat; `/pcraft debug on` prints every purchase step. Cause still unknown until the next test.
- **Interval slider** 1 s, 3 s, 5 s, 10 s, 30 s, 1 m, 5 m (default 5 s), takes effect at once; each item is checked at most every N seconds for N active items (Sylice), so at most one search a second.
- **History panel** right of the RapidFire panel, for the item clicked in the list: bar chart of the cheapest price per check over the last 15 minutes with the max price as a yellow line; now, average, lowest dip (and when), highest, trend. In memory only (a session).
- **Layout:** smaller rows; Start/Stop small, on the bottom line with the status. **Popup** opens over the RapidFire panel; it can be dragged and remembers its position.
- History chart fix (beta.6): bars are fixed 15-second slots of the clock, so a bar no longer jumps up and back as time passes (Sylice saw that in beta.5); only the newest bar changes, and the chart scrolls one bar per 15 s. All bars still rescale together when a new lowest or highest price enters or leaves the 15 minutes.


- [ ] **Watch list:** items with a **max price** each (e.g. Silk Cloth, 1s 20c) and one **minimum balance** for the account (e.g. never spend below 25s). While the AH window is open, ProfitCraft searches the watched items every few seconds (`C_AuctionHouse.SendSearchQuery`; Blizzard's limit is 100 searches a minute, Forever API docs).
- [ ] **Buy window:** when listings at or under the max appear, a window pops up with what you'd get ("Silk Cloth: 240 at <= 1s 20c, 2g 88s") and a big **Buy** button, plus a **sound** (setting).
- [ ] **Key:** a setting, default **Space**. The key only means "Buy" **while the buy window is showing** (`SetOverrideBindingClick`, removed as soon as the window closes), so Space jumps normally otherwise, also at the AH. Not changed in combat.
- [ ] **No unattended buying:** Blizzard restricts buying (`StartCommoditiesPurchase` and `PlaceBid` have `HasRestrictions = true`, Forever API docs; a guide reports every buy needs a click on Forever), so each purchase needs your key press or click. Fully automatic buying is not built.
- [ ] **Safety on every purchase:** reagents are bought in two steps (quote: `StartCommoditiesPurchase`, then `ConfirmCommoditiesPurchase`); ProfitCraft confirms only when the quoted total keeps every unit at or under the max and your money at or above the minimum balance, else cancels and says why (someone bought first, price rose). Only the quote step is flagged as restricted, so one key press per purchase is likely; to be seen in game (else a second press confirms).
- [ ] **Live listings and automatic partial buys** (Sylice, 2026-11-17): the watched item's search stays open; the AH pushes changes (`COMMODITY_SEARCH_RESULTS_UPDATED`, Forever docs; what Auctionator shows updating in the background) and ProfitCraft also refreshes it every few seconds (`RefreshCommoditySearchResults`, not restricted). On the key press the quantity is taken from the live listings at that moment: all units at or under the max, minus your own (`numOwnerItems` in `CommoditySearchResultInfo`), capped by the minimum balance. So if 50 of 100 were sold before the press, it buys the remaining 50 without asking.
- [ ] **Strict price check:** the quote is compared with the exact cost of the listings meant to be bought (not an average), so no unit is paid above the max. If someone bought in the split second between press and quote, ProfitCraft cancels (`CancelCommoditiesPurchase`, not restricted) and the window shows what's left; the next press buys that (starting a purchase needs a press each time).
- [ ] **UI** (Sylice, 2026-11-17):
  - A **"RapidFire"** button in the bottom-right corner of the AH window opens/closes the **RapidFire panel**, attached to the AH window's right edge.
  - Watch list rows: on/off checkbox (pause), icon and name, **max price** (editable), **"now"** (current cheapest live price), **[x]** to remove.
  - Adding items: drop an item from the bags onto the panel, shift-click an item link (bags, chat, AH results, recipe reagents), or **Add item ID** (type the ID; name and icon load from the game; only stackable AH goods, checked with `C_AuctionHouse.GetItemCommodityStatus`).
  - Below the list: keep-at-least balance, check interval (3 / 5 / 10 s, default 5; slowed down automatically so the searches stay under 100 a minute), sound on/off, buy key (default Space), **Start / Stop**, and a status line ("RapidFire: 2 items, each every 5 s"). RapidFire stops when the AH closes.
  - **Deal popup** above the AH window: item, quantity at or under the max, total, money left afterwards, big **BUY (Space)** button; closes by itself after the purchase or when the deal is gone.
  - To test early: whether ProfitCraft's background searches change what the AH window itself shows while you browse; if so, pause RapidFire during manual searches.
  - **Saved** in `ProfitCraftDB`, one list for the account (like the currencies bar): items with max price and on/off, keep-at-least balance (applies to whichever character buys), interval, sound, buy key. Not saved: whether RapidFire is running (always starts stopped, stops when the AH closes). Saved data is written at logout or `/reload`, so a crash loses changes since then.
- Reagents (stackable) first; gear (one-off listings, `PlaceBid`) later if wanted.

## Requirements (apply to every version)

- **Works without Auctionator** for prices and profit (from 0.2 on); **price history, trends and On Sale need Auctionator** (Sylice, 2026-11-17: its history is used instead of keeping our own). Earlier wording: works fully without Auctionator (from 0.2 on; disenchant estimates use ProfitCraft's own table from alpha.4 but still need Auctionator's AH prices until 0.2; 0.1 only loads cleanly without it and says it has no price source). ProfitCraft is a standalone addon; Auctionator is an optional, recommended source (`## OptionalDeps: Auctionator` in the `.toc`, so it loads first when installed, never `## Dependencies`). Auctionator's data is used when available. (Decided 2026-11-13.)
- **Closing the settings must not open the game menu.** ProfitCraft's own commands and buttons open its own settings window, never Blizzard's settings panel (decided 2026-11-13). The same settings page is also listed in Blizzard's Options > AddOns, for people who look there; closing that one returns to the game menu, which is where they came from. Cause: Blizzard's settings panel always reopens the game menu when it is closed (Forever UI source, `SettingsPanelMixin:TransitionBackOpeningPanel` → `ToggleGameMenu()`, called by both the Close button and Escape).

## Version 0.3

- [x] "Profitable only" filter, search box, and filter by profession.
- [x] Hover breakdown for a recipe: cost, AH cut, net profit, stack net profit
- [x] "Sell to vendor instead" comparison (no listing fee; matters for cheap items).
- [x] Pricing reagents you can craft yourself at their crafting cost, limited depth.
- [x] Shopping list sent to Auctionator's shopping list. Without Auctionator: to be decided (e.g. ProfitCraft's own simple list).
  - **Must not interfere with Auctionator's own crafting tools** (Sylice, 2026-11-14). Auctionator already adds a block to Blizzard's recipe details ("To Craft" / "Profit" lines and a **[Search]** button that searches the AH for the selected recipe's product and reagents; `Source_Mainline/CraftingInfo/Professions.lua`). ProfitCraft's list must not replace, cover or duplicate that button; it should only add what Auctionator lacks (e.g. several recipes at once, quantities minus what's in the bags).
  - Open: whether the shopping list is still worth building given Auctionator's button (asked 2026-11-14).
- [x] Settings window (our own; see Requirements). Done early, in 0.1; 0.3 adds more options to it.
- [x] **Item tooltip prices**, with an on/off setting in the settings window (Sylice wants it, 2026-11-13). **One line per source, each with its own price and age** (e.g. "Auctionator: 1s 20c, updated today"; from 0.2 also "ProfitCraft scan: 1s 15c, 2 h ago"), like CraftProfit's tooltip, which shows Auctionator's price with its "Updated" age and its own scan separately. Possibly also merchant sell price, and for items you can craft: craft cost and profit (to decide before 0.3).

## Price sharing (after our own AH scan: 0.3 or later; Sylice, 2026-11-14)

- [ ] **Share the latest AH scan prices with other ProfitCraft users** through addon messages (invisible to players).
- [ ] **Settings:** sharing on/off; **outgoing** and **incoming** separately (e.g. share outwards but never accept others' data).
- [ ] **Who to share with**, each on/off: **Friends**, **Party**, **Guild**, **Custom** (a list of character names typed into a box).
- Notes from the first look (2026-11-14), to settle before building:
  - Forever has `C_ChatInfo.SendAddonMessage(prefix, message, chatType, target)` (Forever API docs); party and guild are channels, but there is no "friends" channel: each online friend (and each Custom name) gets messages one by one (whisper type). QuestTogether already uses party addon messages on Forever.
  - **Volume:** a full scan is thousands of prices, and addon messages are small (255 bytes each) and rate-limited by the game (the API returns a "throttled" result). Needs compact encoding, sending in the background, and probably only prices newer than what the other side has.
  - **Same AH only:** prices must be tagged with the AH they came from (ruleset/realm and faction, if the AH is per faction: still an open question) and ignored when they don't match the receiver's AH.
  - **Trust:** received prices can be wrong or deliberately fake. Keep them apart from our own scan, use them only when newer than what we have, and never let them overwrite our own scan of the same day; show where a price came from.
  - **Names:** Forever characters have first and last names (`UnitFullName` returns both, knowledge file); how names must be written for whispers and Custom-list matching is not known yet.
  - **Protocol version** in every message, so older and newer ProfitCraft versions don't misread each other.
  - **Protocol idea** (from a Claude web chat Sylice shared, 2026-11-14; matches the notes above): announce "I have a scan from time T" to the party when a scan ends or someone joins; whoever has older data asks for "everything after my time"; the sender sends only items scanned since then; the receiver keeps, per item, whichever price is newer and rejects bad data (non-numeric IDs, prices out of range, timestamps in the future).
  - **Libraries** that would do the chunking, throttling, encoding and compression: AceComm (with ChatThrottleLib), LibSerialize, LibDeflate. Licences not yet checked for use in MIT ProfitCraft; using them is a choice to make (ProfitCraft is written from scratch, but libraries are not other addons).
  - **APIs present in Forever's UI source** (checked 2026-11-14): `C_ChatInfo.InChatMessagingLockdown`, `C_FriendList.GetFriendInfo` / `GetFriendInfoByIndex`, `C_BattleNet.GetFriendGameAccountInfo`, `C_BattleNet.SendGameData` (Battle.net friends; the old `BNSendGameData` is only a deprecated wrapper on Forever, `Blizzard_DeprecatedBattleNet/Deprecated_BattleNet.lua`), `Ambiguate`. Presence in the source is not proof they behave as on Retail.
  - **Sender names:** Retail sends "Name-Realm"; Forever characters have first and last names, so the format of `sender` and of friends-list names must be checked in game before any friends/Custom matching.

## "On Sale" detector (possibly 0.4; Sylice, 2026-11-14)

- [ ] **On Sale settings: an area of its own in the settings** (Sylice, 2026-11-17), with sliders. "Usual price" = Auctionator's 7-day average of daily lows; the discount is how far below it a listing must be:
  - **BoE gear discount:** 50-90% in 5% steps, default **65%** (on sale at 35% of the usual price or less).
  - **Reagent discount:** 40-75%, default **40%** (on sale at 60% of the usual price or less); 5% steps assumed.
  - Reagents also need a real share of the supply to be cheap (the crumb limit above), so a stack of 100 among 50,000 never alerts.
- [ ] **Spot listings far below their usual price** while ProfitCraft reads a detailed scan (Auctionator's, or its own without Auctionator; every listing is checked in memory, only the hits are saved, so dropped BoE greens are found too), e.g. level 20-30 mail "of the Knight" that usually sells for 1g+ listed at 10-20s, and list them in a separate **"On Sale" window** with the possible profit (usual price after the AH cut, minus the listing price).
- [ ] **Reagents on sale too** (Sylice, 2026-11-17): the same check for reagents, e.g. a usual price of 1s 75c and listings now at 1s 25c or less = "buy reagents now". Needs the same price history (3- and 7-day averages, trend up/down), so one design for both: **Auctionator's history** (decided 2026-11-17, see Version 0.2). Usual price for an item = from Auctionator's daily lows; what counts as "on sale" (e.g. how far below) is decided when building.
- Notes from the first look (2026-11-14):
  - **Addons can't download anything while the game runs**, so "known data sources" can only come in two ways: (1) a snapshot of outside averages shipped inside the addon (stale between releases; needs a Forever source and permission to use its data; foreverdb.net shows per-realm price history from player scans, terms not checked), or (2) **ProfitCraft's own price history** from its scans (the "Price history" item under Future), helped by price sharing. (2) is the realistic base; (1) only to fill gaps, if at all.
  - Needs **individual listings**: Auctionator's API gives one price per item; the listings come from reading a detailed scan (0.2).
  - Without Auctionator there is no history, so no On Sale (decided 2026-11-17).
  - **Random suffixes** ("of the Knight", "of the Bear", ...) share one item ID but sell for different prices, so the history must be kept per item **and suffix**. Auctionator handles suffixes for Vanilla-type games (`Data_Vanilla/Suffixes.lua`); how suffixes appear in Forever's item links and AH results is not checked yet.
  - "Usual price" should be robust against bait listings and sparse data: e.g. the median of recent days, only when there are enough days/listings, and a minimum discount (e.g. 50% below) before an item counts as "on sale".

- Decided 2026-11-17: the crumb limit (0.5-3%) goes in a small **"Prices"** section of the settings, not the On Sale area, because it changes profit numbers too; it ships with the scan reading, before On Sale. The On Sale area holds only the two discount sliders.

## Later / maybe

- [x] Price-age warnings ("this price is 9 days old"). From Auctionator's age function when its price is used; from our own scan time otherwise.
- Dropped 2026-11-17: a "cheapest 20%" average (CraftProfit's "depth value"). Replaced by the two pricing rules in Version 0.2 (reagent cost for the quantity needed; sale price skipping bait); Sylice: a share of all supply is the wrong measure for crafting profit.
- [ ] Minimap button (not in 0.1; to be decided later).
- [ ] Profit tags in Blizzard's recipe list: a small profit number next to each recipe name in the list on the left, like CraftProfit's. Separate from the recipe-details profit (0.1) and the side panel.

- [ ] **Listing deposit risk** (moved here 2026-11-13): show the listing deposit as money at risk if an item doesn't sell, per item and per stack, with the break-even quantity (e.g. "Cured Light Hide: 1 = −40c, stack of 20 = +9s, profitable from 3"). Left out of the main profit because the deposit is refunded on sale. Less relevant since Forever dropped the 1s minimum deposit (Sylice, 2026-11-17): the example above assumed it.

## Future (set aside)

- [ ] Levelling mode (cheapest cost per skill point).
- [ ] **Price history** (from Auctionator's history since 2026-11-17, see Version 0.2; an own history may come later): prices over days, a "normal" price (e.g. median of recent days) and a cheap/normal/high verdict for the current price. Profit stays based on the **current** price: prices can swing a lot within a day (Sylice saw Sharpening Wheels go from 74c to 1s 70c on 2026-11-13), so a multi-day average would misstate what a sale earns now. CraftProfit does this ("Normal price … learning, x of 7 days").- [ ] Craft queue / crafting from the side panel (maybe).

## Not doing

- TSM support.
- Manual price override (no need seen, 2026-11-13).
- A "sort by profit" checkbox in Blizzard's recipe list (it can only sort inside each category).

## Open questions

The deposit questions only matter for the "Listing deposit risk" item in "Later / maybe".

- [ ] **Does a stack count as one listing?** Does posting 20 or 40 Cured Light Hides at once pay one deposit or one per item? Likely one deposit (Retail's commodity rule), untested in Forever. Sylice to test in game.
- [ ] **Is the deposit refunded on sale?** Web sources say yes; check in game (list a cheap item, see whether the deposit comes back with the sale money). If yes, the deposit only costs money on unsold auctions.
- [ ] **Unsold auctions: deposit lost or refunded?** Web sources disagree; treat as lost until seen.
- [x] **Can buyers take part of a listing?** Yes for reagents: Sylice bought 2 of about 90 Silk Cloth (in game, 2026-11-17). Reagent cost counts single units.
- [ ] **How the deposit is calculated** (item value? auction length?). The 1s minimum is gone (Sylice, 2026-11-17).
- [ ] **Is the AH cut 5% in Forever?** Web sources say yes; not yet confirmed in game.
- [ ] **Can an addon ask Forever's AH what the deposit will be?** Check with an in-game command when building starts.
- [x] **Why Auctionator gave no disenchant values:** its disenchant prices only cover later expansions, not Forever (Sylice, 2026-11-13). ProfitCraft builds its own estimate next; see `DESIGN.md` section 12.
- [ ] **Which Auctionator functions exist on Forever** (especially the price-age one)? Check in game when building starts.
- [ ] **What unit is Auctionator's price age in** (`GetAuctionAgeByItemID`): whole days, or something finer? Decides how often the same-day tie rule applies. Check with `/dump` in game.
