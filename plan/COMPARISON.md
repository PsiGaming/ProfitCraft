# Feature comparison: ForeverProfit, CraftProfit, ProfitCraft

Reviewed 2026-11-13 from the addons' code (ForeverProfit v1.8.0, CraftProfit 0.5.2). The ProfitCraft column follows `FEATURES.md` (0.1, 0.2, 0.3 = planned version). "Not in the list" means a feature the other addons have that has not been proposed for ProfitCraft.

| Feature | ForeverProfit v1.8.0 | CraftProfit 0.5.2 | ProfitCraft (planned) |
|---|---|---|---|
| Where it shows | Its own wide window to the right of the profession window | Inside Blizzard's profession window | Compact side panel, plus profit in the recipe details |
| One ranked list across all categories | Yes | No: sorts only within each category | **0.1** |
| Net profit and cost per reagent in the recipe details | No | Yes | **0.1** |
| Listing deposit counted (refunded on sale) | No | No | No; deposit risk display is Later |
| Profit per stack (toggle) | No | No (Shift in tooltips shows stack totals of prices only) | **0.1** |
| Deposit risk, break-even quantity | No | No | Later |
| Price sources | TSM (default), Auctionator, own scan, manual | Own scan, Auctionator, TSM, "auto" | 0.1: Auctionator; 0.2: most recent of Auctionator and own scan (Auctionator optional) |
| AH cut | 5% (setting) | 5% (setting) | 5% (to be confirmed in game) |
| Missing prices flagged, never counted as profit | Yes | Yes | **0.1** |
| Vendor prices for reagents | From Auctionator | Learned at merchants, plus a built-in table | **0.1**: Auctionator's record; **0.2**: own record when Auctionator has none |
| How often it recalculates | Everything, on every scroll and keystroke | Everything, on any price or setting change | Only when prices or recipes change |
| Filters and search | Profitable only, search, by profession | Profitable only (in Blizzard's Filter menu) | 0.3 |
| Hover breakdown | Market info | Yes | 0.3 (adds stack profit) |
| Sell to vendor instead | No | Yes (AH/vendor toggle) | 0.3 |
| Pricing reagents you can craft yourself | Up to 3 levels | Up to 3 levels | 0.3 |
| Shopping list | Sent to Auctionator | Its own AH panel | 0.3 (sent to Auctionator) |
| Settings | Slash commands only | Blizzard's Options panel | 0.3 |
| Price-age warnings | Yes ("stale" flag) | Yes | Later |
| "Cheapest 20%" average against bait listings | No | Yes | Later (own scan data only) |
| Own AH scan | Fallback | Full scan plus deeper search | **0.2** (needed to work without Auctionator) |
| Profit tags in Blizzard's recipe list | No | Yes | Later, unchecked |
| Disenchant value (tooltips, bag list, craft-and-disenchant ranking) | No | Separate addon by the same author (CraftShuffle) | **0.1** (Auctionator's estimate) |
| Levelling mode | Yes | No | Future |
| TSM | Yes (default) | Yes | Not doing |
| Manual price override | Yes | No | Not doing |
| Craft queue, craft from the window | Yes | No | Future (maybe) |
| Item tooltip prices | No | Yes | 0.3 (on/off setting; content to be decided) |
| Trainer profit and payback | No | Yes | Not in the list |
| Price per reagent before the craft stops paying | No | Yes | Not in the list |
| Minimap button | Yes | No | Later (to be decided) |
