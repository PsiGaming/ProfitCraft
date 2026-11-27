# Feature comparison: ForeverProfit, CraftProfit, ProfitCraft

Reviewed 2026-11-13 from the addons' code (ForeverProfit v1.8.0, CraftProfit 0.5.2); the two other addons' columns have not been rechecked since. The ProfitCraft column was updated to version `0.3.9` on 2026-11-24: a version number in bold = built in that version; "0.4", "Later", "Future" = planned in `FEATURES.md`, not built. "Not in the list" means a feature the other addons have that has not been proposed for ProfitCraft.

| Feature | ForeverProfit v1.8.0 | CraftProfit 0.5.2 | ProfitCraft (0.3.9) |
|---|---|---|---|
| Where it shows | Its own wide window to the right of the profession window | Inside Blizzard's profession window | Compact side panel, plus profit in the recipe details |
| One ranked list across all categories | Yes | No: sorts only within each category | **0.1** |
| Net profit and cost per reagent in the recipe details | No | Yes | **0.1** |
| Listing deposit counted (refunded on sale) | No | No | No; deposit risk display is Later |
| Profit per stack (toggle) | No | No (Shift in tooltips shows stack totals of prices only) | **0.1** |
| Deposit risk, break-even quantity | No | No | Later |
| Price sources | TSM (default), Auctionator, own scan, manual | Own scan, Auctionator, TSM, "auto" | **0.1**: Auctionator; **0.2**: most recent of Auctionator and own scan (Auctionator optional) |
| AH cut | 5% (setting) | 5% (setting) | 5% (to be confirmed in game) |
| Missing prices flagged, never counted as profit | Yes | Yes | **0.1** |
| Vendor prices for reagents | From Auctionator | Learned at merchants, plus a built-in table | **0.1**: Auctionator's record (own record planned for 0.2, not built) |
| How often it recalculates | Everything, on every scroll and keystroke | Everything, on any price or setting change | Only when prices or recipes change |
| Filters and search | Profitable only, search, by profession | Profitable only (in Blizzard's Filter menu) | **0.3.9**: Profitable only; search: 0.4 |
| Hover breakdown | Market info | Yes | **0.1**: row tooltip (profit per craft and stack, AH price, reagent cost); full breakdown with AH cut: 0.4 |
| Sell to vendor instead | No | Yes (AH/vendor toggle) | 0.4 |
| Pricing reagents you can craft yourself | Up to 3 levels | Up to 3 levels | 0.4 |
| Shopping list | Sent to Auctionator | Its own AH panel | 0.4 (sent to Auctionator) |
| Settings | Slash commands only | Blizzard's Options panel | **0.1**: own window plus Blizzard's Options > AddOns; three pages since **0.3.8** |
| Price-age warnings | Yes ("stale" flag) | Yes | **0.1-beta.0**: warning banner, age setting |
| "Cheapest 20%" average against bait listings | No | Yes | Dropped; **0.2**: crumb limit and quantity-based reagent cost instead |
| Own AH scan | Fallback | Full scan plus deeper search | **0.2**: reads Auctionator's detailed scan, own Full scan button without Auctionator |
| Profit tags in Blizzard's recipe list | No | Yes | Later, unchecked |
| Disenchant value (tooltips, bag list, craft-and-disenchant ranking) | No | Separate addon by the same author (CraftShuffle) | **0.1** (own estimate since alpha.4) |
| Levelling mode | Yes | No | Future |
| TSM | Yes (default) | Yes | Not doing |
| Manual price override | Yes | No | Not doing |
| Craft queue, craft from the window | Yes | No | Future (maybe) |
| Item tooltip prices | No | Yes | 0.4 (on/off setting; content to be decided) |
| Trainer profit and payback | No | Yes | **0.1-alpha.5**: trainer and recipe item tooltips; **0.3.7**: "pays off after" in the Recipes panel at the AH |
| Price per reagent before the craft stops paying | No | Yes | Not in the list |
| Minimap button | Yes | No | Later (to be decided) |
| AH deal finding (On Sale), quick buy (RapidFire) | Not part of the 2026-11-13 review | Not part of the 2026-11-13 review | **0.2**: RapidFire; **0.3**: On Sale |
