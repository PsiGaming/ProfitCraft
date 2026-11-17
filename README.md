# ProfitCraft

A crafting-profit addon for World of Warcraft: Forever. It ranks the recipes you know by how much they earn, in a compact panel next to the profession window, and shows each recipe's profit and reagent costs in the recipe details.

**Status: alpha.** Version 0.1 gets all its prices from [Auctionator](https://www.curseforge.com/wow/addons/auctionator), so Auctionator must be installed and you need to scan the Auction House with it. Later versions will also work without Auctionator.

## Install

With [WowUp](https://wowup.io): install from this repository's URL. Or download the `-forever.zip` from the latest release and unzip it into `_forever_/Interface/AddOns/`.

## Use

1. Scan the Auction House with Auctionator. Visiting merchants also lets Auctionator record their prices (thread, vials, ...).
2. Open a profession. The ProfitCraft panel appears to the right of the profession window, with your learned recipes ranked by profit.
3. The mode button switches between **Per craft**, **Per stack** (one full stack of the product) and **Disenchant** (craft it, then disenchant it).
4. Click a recipe to show it; the recipe details show its net profit and the cost of each reagent.

**Disenchanting** (ProfitCraft's own estimate: the average value of the materials, from the Classic disenchant tables by item level, priced with Auctionator's AH prices; not yet verified for Forever):

- Item tooltips can show a "Disenchant (est.)" line (off by default; turn on in Settings).
- **D/E Bags** (button in the panel, or `/pcraft bags`) lists every disenchantable item in your bags with its disenchant estimate, AH price and merchant price; the best option after the AH cut is marked.
- The panel's third mode, **Disenchant**, ranks recipes by crafting the item and disenchanting it.

**Free bag slots** (Settings, off by default): Blizzard's own count on the backpack is one total that includes the reagent bag. ProfitCraft can split it as "(reagent|normal)", e.g. "(6|24)", in the order the bags sit on the bag bar. Choices: Off, Blizzard only, ProfitCraft + Blizzard (the split on the reagent bag button, Blizzard's total on the backpack) and ProfitCraft only (the split on the backpack in place of Blizzard's total; Blizzard's own option stays on, so its count comes back if ProfitCraft is disabled).

**Currencies bar** (Settings or `/pcraft money`, off by default): a small movable bar with your money and up to 5 currencies of your choice; it grows to the left as you add currencies. Right-click it to add or remove currencies, lock its position, change its background colour and opacity, or hide it.

**Profit macro**: the "Create Profit Macro" button in ProfitCraft's settings window creates a macro "PCraft" for your action bar: left-click opens the profit list, right-click the settings.

**AH scans** (0.2): with Auctionator installed, ProfitCraft reads along when Auctionator runs its detailed scan (Auctionator settings > Advanced > "Use alternate slower scan mode by default"); after a summary scan it says so in chat. Without Auctionator, a **Full scan** button on the Auction House window does the scan (one every 15 minutes). ProfitCraft keeps only the prices of your recipes' reagents and products, without your own listings. From that data, a reagent costs what buying the quantity you need would cost, and tiny cheap amounts of stackable items (under 1% of all units listed, adjustable in Settings > Prices) are ignored, since they're gone before you could buy them. Price history comes from Auctionator.

How profit is calculated: AH price of the product × number made × (1 − 5% AH cut) − reagent cost. Each reagent costs the lower of its merchant price and its AH price. The listing deposit is left out, because it is refunded when the item sells. Recipes with a missing price are listed last and never counted as profitable.

## Commands

- `/pcraft`: show or hide the panel (with a profession window open)
- `/pcraft settings`: open the settings window (also the "Settings" button in the panel)
- `/pcraft bags`: disenchant values of the items in your bags
- `/pcraft money`: show or hide the currencies bar
- `/pcraft tooltip on|off`: the disenchant line in item tooltips
- `/pcraft debug on|off`: show errors in chat as they happen (off by default)
- `/pcraft errors`: list logged errors; `/pcraft errors clear` empties the log

## License

MIT, see `LICENSE`.
