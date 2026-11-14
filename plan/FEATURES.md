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
- [x] **Disenchanting** (added 2026-11-13), using **Auctionator's disenchant estimate** (`GetDisenchantPriceByItemID`; its disenchant rules are not verified for Forever, so values are labelled as Auctionator's estimate):
  - **Item tooltips:** a "Disenchant (Auctionator est.)" line; `/pcraft tooltip on|off` (checkbox in the settings window from 0.3).
  - **Bag window** (`/pcraft bags`, or "Bags" in the side panel): every disenchantable item in your bags with its disenchant estimate, AH price and merchant price per item; the option that pays most after the AH cut is marked. Soulbound items have no AH option.
  - **Craft and disenchant:** a third side-panel mode, "Disenchant", ranks recipes by crafting and disenchanting the product (estimate × quantity × (1 − AH cut) − reagent cost); also shown in the row tooltip and the recipe details.
- [x] **Debug mode, off by default.** Errors never pop up while playing; they are always written to a small error log. With debug mode on, they are also shown in chat. `/pcraft debug on|off` in 0.1, plus a checkbox in the settings window from 0.3; `/pcraft errors` shows the log. (Decided 2026-11-13.)

## Version 0.1, added before the first install (2026-11-13)

- [x] **Reagent bag free slots, off by default**: "(n)" on the reagent bag button, styled like Blizzard's backpack count. The normal bags use Forever's built-in "Show Free Bag Space" option (Options > Interface; one total on the backpack button), which Sylice uses for the normal bags (2026-11-13). Not checked: whether Blizzard's total also counts the reagent bag (if it does, the reagent slots are counted in both numbers).
- [x] **Settings window brought forward from 0.3** (our own window, see Requirements): disenchant tooltip line, reagent bag free slots, debug mode. `/pcraft settings` or the side panel's "Settings" button.

## Version 0.1-alpha.1 (fixes after Sylice's first test, 2026-11-13)

- [x] Mode switch is a dropdown (Per craft / Per stack / Disenchant) instead of a cycling button.
- [x] Windows use Blizzard's current frame style (ButtonFrameTemplate with portrait), like the profession window.
- [x] Recipe-details block moved to the bottom of the recipe details, so it no longer overlaps Auctionator's "To Craft" / "Profit" lines under the reagents.
- [x] A ProfitCraft tab at the bottom of the profession window's side-tab column shows/hides the panel (lit while open).
- [x] Profitable amounts show a green "+" (losses already showed a red "-").
- [x] Disenchant lookup also tries Auctionator's item-link function when the item-ID one returns nothing. Every item showed "not disenchantable" in the first test; cause not confirmed (see open questions).

## Version 0.2 (standalone: works without Auctionator)

- [x] **Our own AH scan**, so ProfitCraft works without Auctionator (decided 2026-11-13). Also gives the listing detail Auctionator's API doesn't expose.
- [x] **Our own merchant recording** of vendor buy prices, taken whenever a merchant window is open (the game only reveals buy prices there); used when Auctionator has no vendor price.
- [x] **AH prices: whichever is most recent, per item.** For each item, compare Auctionator's price (if Auctionator is installed and has one) with ProfitCraft's own scan data and use the newer one. If both are from the same day and can't be told apart (Auctionator's age may only be in whole days), use our own. (Decided 2026-11-13.)

## Requirements (apply to every version)

- **Works fully without Auctionator** (from 0.2 on; disenchant estimates stay Auctionator-only until ProfitCraft has its own Forever-verified disenchant table; 0.1 only loads cleanly without it and says it has no price source). ProfitCraft is a standalone addon; Auctionator is an optional, recommended source (`## OptionalDeps: Auctionator` in the `.toc`, so it loads first when installed, never `## Dependencies`). Auctionator's data is used when available. (Decided 2026-11-13.)
- **Closing the settings must not open the game menu.** ProfitCraft uses its own settings window, never Blizzard's settings panel (decided 2026-11-13). Cause: Blizzard's settings panel always reopens the game menu when it is closed (Forever UI source, `SettingsPanelMixin:TransitionBackOpeningPanel` → `ToggleGameMenu()`, called by both the Close button and Escape).

## Version 0.3

- [x] "Profitable only" filter, search box, and filter by profession.
- [x] Hover breakdown for a recipe: cost, AH cut, net profit, stack net profit
- [x] "Sell to vendor instead" comparison (no listing fee; matters for cheap items).
- [x] Pricing reagents you can craft yourself at their crafting cost, limited depth.
- [x] Shopping list sent to Auctionator's shopping list. Without Auctionator: to be decided (e.g. ProfitCraft's own simple list).
- [x] Settings window (our own; see Requirements). Done early, in 0.1; 0.3 adds more options to it.
- [x] **Item tooltip prices**, with an on/off setting in the settings window (Sylice wants it, 2026-11-13). **One line per source, each with its own price and age** (e.g. "Auctionator: 1s 20c, updated today"; from 0.2 also "ProfitCraft scan: 1s 15c, 2 h ago"), like CraftProfit's tooltip, which shows Auctionator's price with its "Updated" age and its own scan separately. Possibly also merchant sell price, and for items you can craft: craft cost and profit (to decide before 0.3).

## Later / maybe

- [x] Price-age warnings ("this price is 9 days old"). From Auctionator's age function when its price is used; from our own scan time otherwise.
- [ ] A "cheapest 20%" average so one bait listing can't fake a price. Only possible with our own scan data (Auctionator's API gives one price per item, not the listings), so it would not apply to items priced from Auctionator.
- [ ] Minimap button (not in 0.1; to be decided later).
- [ ] Profit tags in Blizzard's recipe list: a small profit number next to each recipe name in the list on the left, like CraftProfit's. Separate from the recipe-details profit (0.1) and the side panel.

- [ ] **Listing deposit risk** (moved here 2026-11-13): show the 1s-per-listing deposit as money at risk if an item doesn't sell, per item and per stack, with the break-even quantity (e.g. "Cured Light Hide: 1 = −40c, stack of 20 = +9s, profitable from 3"). Left out of the main profit because the deposit is refunded on sale.

## Future (set aside)

- [ ] Levelling mode (cheapest cost per skill point).
- [ ] **Price history** from our own scans (needs 0.2): prices over days, a "normal" price (e.g. median of recent days) and a cheap/normal/high verdict for the current price. Profit stays based on the **current** price: prices can swing a lot within a day (Sylice saw Sharpening Wheels go from 74c to 1s 70c on 2026-11-13), so a multi-day average would misstate what a sale earns now. CraftProfit does this ("Normal price … learning, x of 7 days").- [ ] Craft queue / crafting from the side panel (maybe).

## Not doing

- TSM support.
- Manual price override (no need seen, 2026-11-13).
- A "sort by profit" checkbox in Blizzard's recipe list (it can only sort inside each category).

## Open questions

The deposit questions only matter for the "Listing deposit risk" item in "Later / maybe".

- [ ] **Does a stack count as one listing?** Does posting 20 or 40 Cured Light Hides at once cost 1s or more? Likely one deposit (Retail's commodity rule), untested in Forever. Sylice to test in game.
- [ ] **Is the deposit refunded on sale?** Web sources say yes; check in game (list a cheap item, see whether the 1s comes back with the sale money). If yes, the deposit only costs money on unsold auctions.
- [ ] **Unsold auctions: deposit lost or refunded?** Web sources disagree; treat as lost until seen.
- [ ] **Can buyers take part of a listing?** CraftProfit's 0.5.2 changelog mentions buying "1 of 860 Copper Rods" from a grouped row, which suggests partial buys.
- [ ] **The deposit above the 1s minimum** (item value? auction length?), and whether the 1s minimum changes to 1c (discussed by a developer, no patch note found).
- [ ] **Is the AH cut 5% in Forever?** Web sources say yes; not yet confirmed in game.
- [ ] **Can an addon ask Forever's AH what the deposit will be?** Check with an in-game command when building starts.
- [ ] **Why Auctionator gave no disenchant values** in the first test: does Auctionator's own tooltip show a disenchant price for those items? If not, Auctionator has no Forever disenchant data and ProfitCraft needs its own table.
- [ ] **Which Auctionator functions exist on Forever** (especially the price-age one)? Check in game when building starts.
- [ ] **What unit is Auctionator's price age in** (`GetAuctionAgeByItemID`): whole days, or something finer? Decides how often the same-day tie rule applies. Check with `/dump` in game.
