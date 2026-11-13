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

**Disenchanting** (estimates from Auctionator, not yet verified for Forever):

- Item tooltips show a "Disenchant (Auctionator est.)" line.
- **Bags** (button in the panel, or `/pcraft bags`) lists every disenchantable item in your bags with its disenchant estimate, AH price and merchant price; the best option after the AH cut is marked.
- The panel's third mode, **Disenchant**, ranks recipes by crafting the item and disenchanting it.

How profit is calculated: AH price of the product × number made × (1 − 5% AH cut) − reagent cost. Each reagent costs the lower of its merchant price and its AH price. The listing deposit is left out, because it is refunded when the item sells. Recipes with a missing price are listed last and never counted as profitable.

## Commands

- `/pcraft`: show or hide the panel (with a profession window open)
- `/pcraft bags`: disenchant values of the items in your bags
- `/pcraft tooltip on|off`: the disenchant line in item tooltips
- `/pcraft debug on|off`: show errors in chat as they happen (off by default)
- `/pcraft errors`: list logged errors; `/pcraft errors clear` empties the log

## License

MIT, see `LICENSE`.
