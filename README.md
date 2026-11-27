# ProfitCraft

A crafting-profit addon for World of Warcraft: Forever. It ranks the recipes you know by how much they earn, in a compact panel next to the profession window, and shows each recipe's profit and reagent costs in the recipe details.

At the Auction House it adds three tabs: **Recipes** (which recipes on the AH are worth buying), **Opportunities** (listings below what a vendor pays for them, and optionally listings far below their usual price) and **RapidFire** (quick buying of watched reagents).

**Status: in development** (version 0.4; every release is a pre-release). [Auctionator](https://www.curseforge.com/wow/addons/auctionator) is optional and recommended: with it, ProfitCraft uses Auctionator's prices and reads along when Auctionator scans the AH. Without it, ProfitCraft scans the AH itself.

## Install

With [WowUp](https://wowup.io): install from this repository's URL. Or download the `-forever.zip` from the latest release and unzip it into `_forever_/Interface/AddOns/`.

## Use

1. Scan the Auction House: with Auctionator, use its scan (its detailed scan gives the best prices, see "AH scans" below); without it, use ProfitCraft's **Full scan** button on the AH window. Merchant prices (thread, vials, ...) come from Auctionator, which records them when you visit merchants.
2. Open a profession. The ProfitCraft panel appears to the right of the profession window, with your learned recipes ranked by profit.
3. The mode button switches between **Per craft**, **Per stack** (one full stack of the product, or 10 of a product that doesn't stack) and **Disenchant** (craft it, then disenchant it). **Profitable only** at the top of the list hides recipes that lose money or have no price yet; the search box next to it shows only recipes whose name contains what you type.
4. Hover a recipe in the list for the sum: sale, AH cut, reagents, profit for one craft. Hold **Shift** to see it for a full stack (or 10).
5. Click a recipe to show it; the recipe details show its net profit and the cost of each reagent.

Hovering a recipe at a trainer, or a recipe item (in your bags, at the AH, in chat), shows its reagent cost, sale price and profit per craft, with the profit as a percentage of the cost.

**Disenchanting** (ProfitCraft's own estimate: the average value of the materials, from the Classic disenchant tables by item level, priced with current AH prices; not yet verified for Forever):

- Item tooltips can show a "Disenchant (est.)" line (off by default; turn on in Settings).
- **D/E Bags** (button in the panel, or `/pcraft bags`) lists every disenchantable item in your bags with its disenchant estimate, AH price and merchant price; the best option after the AH cut is marked.
- The panel's third mode, **Disenchant**, ranks recipes by crafting the item and disenchanting it.

**Free bag slots** (Settings, off by default): Blizzard's own count on the backpack is one total that includes the reagent bag. ProfitCraft can split it as "(reagent|normal)", e.g. "(6|24)", in the order the bags sit on the bag bar. Choices: Off, Blizzard only, ProfitCraft + Blizzard (the split on the reagent bag button, Blizzard's total on the backpack) and ProfitCraft only (the split on the backpack in place of Blizzard's total; Blizzard's own option stays on, so its count comes back if ProfitCraft is disabled).

**Currencies bar** (Settings or `/pcraft money`, off by default): a small movable bar with your money and up to 5 currencies of your choice; it grows to the left as you add currencies. Right-click it to add or remove currencies, lock its position, change its background colour and opacity, or hide it.

**Profit macro**: the "Create Profit Macro" button in ProfitCraft's settings window creates a macro "PCraft" for your action bar: left-click opens the profit list, right-click the settings.

**AH scans** (0.2): with Auctionator installed, ProfitCraft reads along when Auctionator runs its detailed scan (Auctionator settings > Advanced > "Use alternate slower scan mode by default"); after a summary scan it shows a notice (can be turned off in Settings > General). Without Auctionator, a **Full scan** button on the Auction House window does the scan (one every 15 minutes). ProfitCraft keeps only the prices of your recipes' reagents and products, without your own listings. From that data, a reagent costs what buying the quantity you need would cost, and tiny cheap amounts of stackable items (under 1% of all units listed, adjustable in Settings > General) are ignored, since they're gone before you could buy them.

**Auction House tabs:** ProfitCraft's tabs sit in a thin column at the bottom of the Auction House window's right edge; each opens its panel next to the window (one at a time). Their size is in Settings > General.

**RapidFire** (0.2): the RapidFire tab opens a watch list. Add reagents (item ID, drag from your bags, or shift-click a link), set a max price per unit and how much money to keep, then press Start. While the AH is open, ProfitCraft keeps checking those items; when some are listed at or under your max, a popup with a sound offers them, and the buy key (default Space, only while the popup shows) buys them: as many as are still there at or under your max, never more than your money above the amount to keep. If the price changed in the meantime, it doesn't buy and tells you. Every purchase needs your key press or click (Blizzard's rule). The panel keeps a running total of what RapidFire bought during this visit to the Auction House; when you leave, the totals are printed to chat.

**Opportunities** (0.4): the Opportunities tab has two pages, **Vendor** and **On Sale**.

**Vendor** (always on): every full scan is checked for listings that cost less than a vendor pays for them (e.g. 10 shirts at 4s 99c each that a vendor buys for 5s). The page lists them by profit, biggest first. Left-click one to see it in Blizzard's own Buy tab; right-click to check the live listings and buy everything still below vendor price, then sell it to any vendor. Things that don't stack are separate auctions: after each purchase the dialog offers the next one, so you just keep pressing Buy. It never buys at or above the vendor price, and never pays more than the price it shows. After a scan with finds, one chat line says how many there are and what buying and vendoring all of them would earn. No sound or glow.

The **Quick scan** button on the Vendor page does the same check without a full scan (and without its 15-minute wait): it reads every item's cheapest price, the way Auctionator's summary scan does, then checks the most promising items listed below vendor price (10 by default; Settings > Opportunities) for how many are that cheap and what they cost. Everything it finds is listed straight away with its cheapest price and profit per unit; checked items become full rows as their checks finish. Untick **Check top items** next to the button to skip the checks. You can buy while it runs. **Shift + left-click** a stackable find to have RapidFire watch it, at a max price just below what a vendor pays.

**Filters and protection:** tick **Stackable only** to hide items that don't stack; otherwise those only show when each one earns at least the minimum in Settings > Opportunities (10s by default). The tooltip says whether an item stacks. One purchase never costs more than **Max per purchase** (5g by default; bigger finds are offered in parts) and never takes your money below **Keep at least** (50s by default); both in Settings > Opportunities > Buying, any amount in gold and silver. When one of them stops or splits a purchase, a chat line says so. **Careful:** the game's item data gives some items a vendor price that merchants don't actually pay. ProfitCraft ships a list of the ones Forever's game data itself marks as having no vendor value (enchanting dusts and essences, rogue poisons, Blinding Powder and about 300 more), and also checks what's in your bags and bank (every character on the account) and learns which items merchants take and which they don't; items no merchant takes never count at a vendor price again (`/pcraft unsellable`). A find of an item newer than that shipped list and never seen in your bags or bank shows an orange **!**: nothing has checked its vendor price yet, so check before buying a lot of it.

Finds on both pages expire after 30 minutes (Settings > Opportunities: 10 minutes to 4 hours); then the page asks you to run a full scan again.

**On Sale** (experimental, **off by default**): finds listings far below their usual price, so you can wait at the AH with the game in the background. Turn it on in Settings > Opportunities:
- **Manual List**: alerts only for items your own searches cover. Searches work like Auctionator's advanced search (text, category, level and item level range, quality), each with its own rule: a fixed price ("at or under 30s") or a discount below the usual price. You can paste in Auctionator searches.
- **Full Auto**: judges every item a full scan finds.

ProfitCraft keeps its own price history per item (and per random suffix, such as "of the Bear"), recorded from full scans and searches; an item's usual price needs at least 3 days with prices in the last 7. Auctionator's history fills in for stackable goods until then. Each find shows the price, the usual price and the possible profit; click it to check the live listings and buy. New finds play a sound and make the screen glow gold for a few seconds (both can be turned off). Opening the AH runs one quick pass through your searches (at most once a minute); **Start** keeps checking them until you stop or leave. RapidFire and the On Sale watch never run at the same time.

**Recipes** (0.3): the Recipes tab scans the AH for recipes of your professions and lists them by profit (per stack or per craft), with the profit as a percentage of the cost and how many crafts it takes to pay for the recipe. Click a column header to sort, tick **Hide known** to leave out recipes you already know, and click a row to buy.

**Settings** (`/pcraft settings`, the panel's Settings button, or Blizzard's Options > AddOns > ProfitCraft) are in three pages: General, Crafting profit and Opportunities.

How profit is calculated: sale price × number made − reagent cost. The sale price is whichever pays more: the AH price after the 5% AH cut, or what a vendor pays; tooltips mark it (AH) or (Vend). Each reagent costs the lower of its merchant price and its AH price. The listing deposit is left out, because it is refunded when the item sells. Recipes with a missing price are listed last and never counted as profitable.

## Commands

- `/pcraft`: show or hide the panel (with a profession window open)
- `/pcraft settings`: open the settings window (also the "Settings" button in the panel)
- `/pcraft bags`: disenchant values of the items in your bags
- `/pcraft money`: show or hide the currencies bar
- `/pcraft tooltip on|off`: the disenchant line in item tooltips
- `/pcraft debug on|off`: show errors in chat as they happen (off by default)
- `/pcraft errors`: list logged errors; `/pcraft errors clear` empties the log
- `/pcraft unsellable`: items ProfitCraft learned no merchant takes (plus how many are on the shipped list); `/pcraft unsellable clear` forgets the learned ones

## License

MIT, see `LICENSE`.
