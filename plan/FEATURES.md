# ProfitCraft: features

What ProfitCraft does and what is planned. How it is built: `DESIGN.md`. What was done and when: `WORKLOG.md`.

**State (2026-11-24):** latest release `0.4.0-beta.7` (2026-11-24), in testing (sections "Opportunities" and "Version 0.4.0" below). `[x]` = built, `[ ]` = not built.

Started from the review of ForeverProfit v1.8.0 and CraftProfit 0.5.2 (2026-11-13; `COMPARISON.md`). Both subtract the 5% AH cut; neither counts the listing deposit, which is refunded on sale. ProfitCraft leaves it out too, since items are expected to sell (decided 2026-11-13).

## Requirements (apply to every version)

- **Works without Auctionator** (decided 2026-11-13; On Sale too since 2026-11-19). Auctionator is optional and recommended (`## OptionalDeps: Auctionator`, never `## Dependencies`); its data is used when available. All testers (the author and friends) have it and scan with it.
- **Closing the settings must not open the game menu.** ProfitCraft's own commands and buttons open its own settings window, never Blizzard's settings panel (decided 2026-11-13). The same page is also listed in Blizzard's Options > AddOns for people who look there; closing that one returns to the game menu, which is where they came from. Cause: Blizzard's settings panel always reopens the game menu when closed (Forever UI source, `SettingsPanelMixin:TransitionBackOpeningPanel` → `ToggleGameMenu()`).
- **Fast by design:** prices are calculated once, and again only when prices or recipes change. Sorting, filtering and scrolling only re-read the saved results.
- **Errors never pop up while playing**; they always go to a small error log. **Debug mode** (off by default; `/pcraft debug on|off` or the settings) also shows them in chat; `/pcraft errors` lists the log. (Decided 2026-11-13.)

## Profit at the profession window

- [x] **One ranked list** of every recipe across all categories, sorted by real profit, in a **compact side panel** to the right of the profession window (much narrower than ForeverProfit's 620 px window plus 176 px sidebar). Blizzard's recipe list is not modified. Fixed width; long names are shortened and shown in full in the tooltip.
- [x] **Modes** (a dropdown in the panel's header; the last one used is remembered): **Per craft**; **Per stack** (profit for one full stack of the product, stack size shown, e.g. "×20"; read from the item data, items that don't stack count 10); **Disenchant** (craft the item, then disenchant it). The ranking re-sorts by the chosen mode. (Decided 2026-11-13.)
- [x] **"Profitable only"** checkbox at the top of the list (off by default): hides recipes that lose money or have no price yet, in the chosen mode; shows "n of m".
- [x] **Row tooltip:** quantity range, the sale as a breakdown (Version 0.4.0: per craft, Shift for a stack or 10), craft-and-disenchant, items without a price. Click a row to open the recipe, selected the way Blizzard's own recipe list does it (2026-11-24: the old way did nothing for 10-20 s after opening the window, while Blizzard's list worked at once); a recipe hidden by Blizzard's search or filters is opened the old way.
- [x] **Profit inside the recipe details** (like CraftProfit): net profit for the selected recipe, craft-and-disenchant, and the cost of each reagent with its source. No "sort by profit" checkbox in Blizzard's list; sorting is the panel's job.
- [x] **Real profit:** sale − reagent cost, the sale being the higher of the AH price after its 5% cut and the vendor price (Version 0.4.0). The listing deposit is left out (see "Later / maybe").
- [x] **Recipes that make several items:** a fixed amount (Rough Dynamite ×2, Crafted Light Shot ×200) counts as is; a random range (Heavy Dynamite 1-5) counts at its average, with the range shown in the tooltip. (Decided 2026-11-13.)
- [x] **Missing prices are flagged**, never counted as profit; such recipes are listed last.
- [x] **Bind-on-pickup products** count at their vendor price; without one they show "can't be sold" / "BoP" instead of a sale profit (panel, recipe details, tooltips). Craft-and-disenchant is still shown.
- [x] **Price warning banner** above the list: no AH prices yet (without Auctionator it points to ProfitCraft's Full scan button), or prices too old ("scan the Auction House with Auctionator / with ProfitCraft's Full scan button"). Setting: how old prices may get before it warns, Off / 1 / 2 (default) / 3 / 4 days; whole days because Auctionator's price age counts whole days (2026-11-14). Off only hides the old-prices warning.
- [x] A **ProfitCraft side tab** on the profession window shows / hides the panel (lit while open), in the next free slot from the bottom of the window's right edge.
- Wording (2026-11-14): **"Auction price"** (not Auctionator's "Auction", so ProfitCraft's lines can be told apart); reagent sources **"(AH)"** / **"(Vend)"**, in front of the amount so the amounts stay right-aligned.

## Prices

- [x] **AH prices: whichever is most recent, per item**: Auctionator's price or ProfitCraft's own scan data; on a same-day tie (Auctionator's age may only be in whole days), our own. (Decided 2026-11-13.)
- [x] **Live prices from AH searches** (2026-11-24: Auctionator's Search showed Bolt of Mageweave losing money, but the list kept +28s from the morning's scan, since a same-day tie goes to ProfitCraft's data): any AH search updates ProfitCraft's prices for the reagents and products of your recipes it shows, and the list recalculates at once: single-item searches (Blizzard's Buy tab, ProfitCraft's buy dialog, RapidFire) with their price levels, and browse searches (Auctionator's Shopping tab and Search button, Blizzard's search box, the quick scan) with each item's cheapest price, counted for every unit as Auctionator does (beta.6 missed browse searches, so Auctionator's searches didn't count: 2026-11-24). ProfitCraft uses whichever is newer per item: that search or the last full scan.
- [x] **Reagent cost = what buying the needed quantity costs** (2026-11-17): needed quantity = the recipe's amount × the crafts of the current mode (1, or enough for a stack of the product); other sellers' listings are taken cheapest first. Example: 1,000 stacks at 1s -> 1s per unit, whatever is listed above. Too little listed -> "only N listed". Reagents can be bought by quantity (the author bought 2 of about 90 Silk Cloth, 2026-11-17), so single units are counted.
- [x] **Vendor prices:** a reagent costs the **lower** of its merchant buy price and its AH cost; with no merchant price, the AH price; with neither, it is "missing". Merchant buy prices come **from Auctionator** (which records them at merchants). (Decided 2026-11-13.)
- [x] **Crumb limit for stackable items** (reagents, bars, potions, cloth...): price levels holding less than **1% of all units listed** are ignored, in the sale price **and** the reagent cost, because on the megaserver tiny cheap amounts are gone before anyone can buy them (2026-11-17). Example: 50,000 Silk Cloth, 100 at 1s, the rest from 1s 50c: the 100 are ignored. Setting: 0.5 / 1 / 2 / 3%, default 1%.
- [x] **Sale price of stackable items** = the cheapest level left after the crumb limit. Prices from a scan are as old as the scan; their age is shown.
- [ ] **Sale price of gear** = the cheapest listing unless it is far below the item's usual price, then the next listing. **Not built:** gear's sale price is simply the cheapest listing.
- [ ] **Our own merchant recording** of vendor buy prices, taken whenever a merchant window is open (the game only reveals buy prices there; item data has only the sell price, Forever API docs), used when Auctionator has none. **Not built:** without Auctionator every reagent is priced from the AH. **No pre-filled vendor price table** (2026-11-14): no Forever source for buy prices found.
- Without a detailed scan (Auctionator's summary mode, or no scan data) both scan rules fall back to the lowest price.

## AH scan

- [x] **With Auctionator:** no ProfitCraft scan button; ProfitCraft reads along when Auctionator scans, so one click updates both.
  - Auctionator's **detailed scan** (its "replicate" mode; Auctionator > Advanced > "Use alternate slower scan mode by default"): ProfitCraft reads every listing and says so in chat ("reading Auctionator's full scan... done"). It reports before Auctionator finishes, on purpose, so On Sale alerts come at once (2026-11-17).
  - Auctionator's **summary scan** (its default): a raid-warning style notice plus an orange chat line naming the setting above (the detailed scan is vital; no pop-up boxes, never on just opening the AH). Setting to turn it off. Prices then come from Auctionator as usual.
- [x] **Without Auctionator:** a **Full scan** button at the AH (one every 15 minutes, the game's limit; shows the wait).
- [x] **What is saved:** only the cheapest price levels (with quantities) of the reagents and products of recipes seen on the account, and the scan time; own listings left out. Everything else in the scan is only looked at during the scan (On Sale checks it and adds to its price history). Scale (the author's data, 2026-11-17): a full scan covers about 6,500 different items; Auctionator keeps 7,073 items in 1 MB; CraftProfit, recipe items only, 87 items' price ladders in 18.5 KB.

## Tooltips

- [x] **Trainer tooltips** (hovering a recipe at a trainer) and **recipe item tooltips** (bags, AH, chat links): each reagent with price and source ("4 x Copper Bar   (AH) 3s 80c", "no price" when unknown), the product's AH price, profit per craft and craft-and-disenchant, with the profit as a percentage of the reagent cost in grey (e.g. `(+114%) +4s 55c`; the author: to compare recipes' efficiency). To decide whether to train, learn or sell a recipe.
- [x] **Disenchant line** in item tooltips, "Disenchant (est.)", off by default (as in Auctionator); setting or `/pcraft tooltip on|off`. It also lists what the item can disenchant into (chance, amount, material; "?" when a material has no AH price), always shown (2026-11-14).

## Disenchanting

- [x] **ProfitCraft's own disenchant estimate** (Auctionator's is empty on Forever): a table by quality, armor/weapon and item level, priced with AH prices; shown as an estimate until confirmed for Forever. Essences count at whichever form sells for more (3 lesser = 1 greater, both ways).
- [x] **D/E Bags** window (`/pcraft bags`, or "D/E Bags" in the side panel): every disenchantable item in your bags with its disenchant estimate, AH price and merchant price per item; the option that pays most after the AH cut is marked. Soulbound items have no AH option.
- [x] **Craft and disenchant:** the panel's Disenchant mode, the row tooltip and the recipe details (estimate × quantity × (1 − AH cut) − reagent cost).

## Bags, money and the macro

- [x] **Free bag slots** (settings dropdown; 2026-11-17): Blizzard's backpack count includes the reagent bag, so ProfitCraft can split it as "(reagent|normal)", reagent first as the bags sit on the bar. Choices: **Off**, **Blizzard only**, **ProfitCraft + Blizzard** (the split on the reagent bag button, Blizzard's total on the backpack) and **ProfitCraft only** (the split on the backpack in place of Blizzard's total). "ProfitCraft only" hides Blizzard's number without turning Blizzard's option off, so the count comes back if ProfitCraft is disabled or removed. To check in game: whether "(6|24)" fits on the small reagent bag button.
- [x] **Currencies bar** (2026-11-17): a small movable bar with your money and up to **5** tracked currencies (ProfitCraft's own limit), growing to the left. Off by default (settings, `/pcraft money`). Right-click: Add currency, Remove currency, Lock/Unlock position, Background colour (any colour, transparent to solid), Hide. One list for all characters.
- [x] **Create Profit Macro** (2026-11-17): a button in ProfitCraft's settings window creates a general macro **"PCraft"** with a money bag icon: left-click opens the profit list, right-click the settings. Greyed out with a reason when a PCraft macro exists or all general macro slots are used. Hovering the macro on an action bar adds "Left-click: profit list" / "Right-click: ProfitCraft settings" (macros have no tooltip text of their own).

## Auction House tabs

- [x] ProfitCraft's AH features are **tabs in a thin column at the bottom of the AH window's right edge**, always visible, top to bottom: **Recipes**, **Opportunities** (a badge with the number of Vendor and On Sale finds) and **RapidFire** last (2026-11-24). Each opens its panel right of the column, one at a time; the open panel's tab is lit. Why there: buttons in the AH window's corners were covered by Blizzard's and Auctionator's own buttons (2026-11-20).
- [x] **Tab size** setting: icon 24-44 px, default 24 (the author capped it at Forever's own side-tab size).

## RapidFire: watch list & quick buy

Named **RapidFire** (2026-11-17): named without the negative ring of the usual AH-addon term.

- [x] **Watch list:** up to 10 stackable items, each with a **max price** per unit (new items start at max 0, never bought until a max is set) and an on/off box, plus one **keep-at-least balance** for the account (never spend below it). Add items by item ID, dragging from the bags, or shift-clicking a link.
- [x] **Checking:** while the AH is open and RapidFire is started, the watched items are searched; **interval slider** 1 s, 3 s, 5 s (default), 10 s, 30 s, 1 m, 5 m; each item at most every N seconds for N active items, so at most one search a second (Blizzard's limit is 100 a minute, Forever API docs). Stops when the AH closes; always starts stopped. Never runs together with On Sale's watch (starting one stops the other).
- [x] **Deal popup** (movable, remembers its position) with a sound when listings at or under the max appear: item, quantity, total, money left afterwards, a big **Buy** button. The **buy key** (default **Space**) only means "Buy" **while the popup shows**, so Space jumps normally otherwise; not changed in combat. The popup flashes "Opportunity gone" when the deal disappears and "Bought N for X" after a purchase.
- [x] **No unattended buying:** Blizzard restricts buying (`HasRestrictions`, Forever API docs), so every purchase needs a key press or click; the purchase call is the first thing in that click, otherwise Forever blocks it (knowledge file). One request per state of the listings: pressing again sends nothing until fresh listings arrive.
- [x] **Live listings and automatic partial buys** (2026-11-17): the quantity is taken from the live listings at the moment of the press: all units at or under the max, minus your own, capped by the keep-at-least balance. If 50 of 100 were sold before the press, it buys the remaining 50 without asking.
- [x] **Strict price check:** the AH's quote is compared with the exact cost of the listings meant to be bought, so no unit is paid above the max; if someone bought first, it cancels and shows what's left. **Price tolerance** slider 0 / 5 / 10 / 15 / 20 / 25%, default 0%: if the price moved before the AH answers, the same press still buys when the average per unit is at most that much above the max.
- [x] Time limits (no quote within 5 s, no result within 10 s cancels and says so), Blizzard block reports in chat, `/pcraft debug on` prints every purchase step.
- [x] **History panel** for the item clicked in the list: bar chart of the cheapest price per check over the last 15 minutes (15-second clock slots) with the max price as a yellow line; now, average, lowest dip (and when), highest, trend. Session only.
- [x] **Session summary:** what RapidFire bought during this AH visit (total, each item with units and cost); printed to chat when the AH closes. RapidFire's own purchases only.
- Saved account-wide: the items with max price and on/off, keep-at-least balance, interval, sound, buy key, tolerance. Gear (one-off listings) is not supported; later if wanted.
- To check in game: whether ProfitCraft's background searches change what the AH window shows while you browse.

## Opportunities (0.4.0; in beta since 2026-11-24, `0.4.0-beta.7`)

Decided 2026-11-24: the On Sale tab becomes **Opportunities**, with a second kind of find, **Vendor**: listings that cost less than a vendor pays for them. Found by chance: 10 yellow shirts listed at 4s 99c each, which a vendor buys for 5s each. On Sale stays as it is, inside Opportunities, and can stay Off while Vendor is used. Why merged rather than a separate Vendor tab: one place for "buy cheap at the AH" finds, and Opportunities keeps its Vendor page if On Sale is dropped or rebuilt later.

- [x] **Opportunities tab and panel** replace the On Sale tab. **Always on**: it can't be switched off; only its On Sale part can. Two page buttons at the top: **Vendor** (the main page; the panel opens on it) and **On Sale** (today's On Sale panel unchanged: Searches, Finds, history, Start/Stop, status line). With On Sale Off, its page says so and points to the settings. The tab's badge counts the finds of both pages.
- [x] **Settings page "On Sale" renamed "Opportunities"**; its current contents become its "On Sale" section. Only displayed names change; saved settings keep their names, so nothing is converted and existing searches and settings carry over.
- [x] **Vendor finds:** every full scan (Auctionator's detailed scan, or ProfitCraft's Full scan) checks every listing of other sellers; a listing whose buyout is below what a vendor pays for its items is a find. Vendor price = the game's item data (taken as correct; the author will see in testing if it isn't). Items vendors don't buy (price 0) never count. Profit = vendor price × units − cost: no AH cut, no deposit.
- [x] **Vendor list:** one row per item (gear: per item and suffix, as On Sale), with units, cost and profit (vendor value in the tooltip), **sorted by profit, biggest first**. No sound or glow. **One chat line per scan with finds** (no spam, just how many and what they'd earn): "Vendor: 12 items below vendor price, +1g 20s if you buy and vendor all of them (Opportunities tab)."; nothing when there are none. The tab's badge counts them.
- [x] **Left-click a row: show it in Blizzard's Buy tab** (2026-11-24: to see the real listings before buying). Right-click buys.
- [x] **Quick buy** (like On Sale's finds): right-click a row -> ProfitCraft checks the item's live listings -> "Buy N for X?" with what the vendor pays and the profit -> **Buy**. Stackable goods: all units still below vendor price, as far as the money above RapidFire's "keep at least" goes, in one purchase. Items that don't stack (each is its own auction, and Blizzard requires a click per purchase): the cheapest listing still below vendor price, and after each purchase **the dialog offers the next one** (2026-11-24: "I can just spam that button"); the Buy button stays greyed until fresh listings arrive, the next offer only comes from a search sent after the purchase is confirmed, and if the AH refuses one (someone faster) it looks for the next. One chat line for everything bought in the dialog. Bought units come off the row; a row with nothing left, or found gone, is removed.
- [x] **Shift + left-click a stackable find: watch it with RapidFire** (2026-11-24: e.g. 130 Sharpening Stones at 2c that a vendor buys for 3c), at a max of one copper below the vendor price; an item already watched gets that max. RapidFire then never pays as much as a vendor gives for it, whatever its price tolerance. Only stackable goods (RapidFire's own limit; the author: the better way anyway).
- [x] **Safety** (2026-11-24): never pays more than the price shown (items: the listing's own buyout; stackable goods: the AH's quote is checked against the offer, as RapidFire does), and never buys at or above the vendor price: only listings below it are offered, and a separate check before every purchase and on the AH's quote refuses anything whose price per unit isn't below the vendor price.
- [x] **Spend protection** (2026-11-24, after 200 Blinding Powder for 2.4g, most of the character's money, that no merchant would take): **Max per purchase** (Vendor and On Sale buy dialog; any amount in gold and silver, empty or 0 = no limit, default 5g): a bigger find is offered in parts, one press each (the next part after each purchase); a single item dearer than the cap isn't offered. Not for the Recipes panel (a deliberate buy) or RapidFire. **Keep at least** (default 50s) shown in Settings > Opportunities too, also as gold and silver boxes: the same amount as RapidFire's, used by every ProfitCraft purchase. When either limit stops a purchase in the buy dialog or makes it smaller than what's listed, **one chat line** says so and where to change it (2026-11-24).
- [x] **Items no merchant takes** (same cause: the item data gave Blinding Powder a sell price of 1s 25c, Auctionator's "Vendor" line too, but the merchant said it doesn't want it): ProfitCraft learns them and from then on counts them at no vendor price anywhere (Vendor page, profit list, buy dialog, RapidFire vendor flips). Learned from the bags (the game's "no value" flag on a bag item; confirmed in game 2026-11-24: `true` on every Blinding Powder stack) and from merchants (selling one that the merchant refuses). `/pcraft unsellable` lists them, `/pcraft unsellable clear` forgets them.
- [x] **Verified vendor prices** (2026-11-24): an item counts as verified when the shipped game data covers it (see the next item), or once it's been in the bags or the bank (any character on the account; the bank when opened) with the game saying a merchant takes it (no "no value" flag, a sell price above 0); the list builds itself from what you carry, from the first login with this version on (no history before that). Vendor finds of unverified items show an orange **"!"**, and the tooltip and buy dialog say the vendor price isn't verified; **buying works as usual** (the author rejected test buys of one unit: "buy one single item of every single item I ever come across? No."). Max per purchase and keep at least limit what a wrong price can cost. RapidFire warns when an unverified item is sent over.
- [x] **Shipped list of items no merchant takes** (2026-11-24): 328 items that Forever's own game data marks as having no vendor value although they list a sell price (enchanting dusts, essences and shards, rogue poisons, Blinding Powder, ...) count as unsellable from the start, without ever being carried: never Vendor finds, never priced at a vendor. Confirmed on Blinding Powder and Strange Dust. Your bags overrule it if the game ever says a listed item does sell. Regenerated from the game data after Forever patches. The game data also counts as verification: the orange "!" (and the "not verified" notes) only shows for items newer than the data the list was made from (a higher item ID) and never carried (2026-11-24: "less intrusive").
- [x] **Filters** (2026-11-24: "188 bronze cuirass ... no way I'm buying 188 individual items and vendoring them all"): **Stackable only** checkbox on the Vendor page (off by default) hides items that don't stack; **Single items: min profit each** (Settings > Opportunities; off / 1s / 5s / 10s / 25s / 50s / 1g, default 10s) shows items that don't stack only when each one earns at least that. Stackable goods always show. The header says how many finds the filters hide; the badge and chat line count only what is shown; the quick scan doesn't spend its checks on hidden items.
- [x] **Tooltip says whether it stacks**: "Stacks up to 20", or "Doesn't stack: 188 separate items to buy, carry and sell" ("I don't have a clue if it's stackable").
- [x] The list is **replaced by each full scan** (a scan without finds empties it); it survives closing the AH, since scans are allowed only every 15 minutes, and is not saved (a `/reload` clears it). Its header shows when the scan was read.
- [x] **Quick scan** button on the Vendor page (2026-11-24: to sit at the AH and press it every few minutes while testing): a Vendor check without a full scan and without its 15-minute wait, modelled on Auctionator's summary scan. It reads every item's cheapest price (the author's test: 45 pages, over 22,000 results), then checks the most promising items listed below vendor price (ranked by what they could earn at most: profit per unit × units listed; setting **Quick scan checks**: 5 / 10 (default) / 20) for how many units are that cheap and what they cost. **Live:** while the AH is read, every item found below vendor price is listed at once as an unchecked row ("?" units, "@ cheapest", profit per unit), best profit per unit first (to react to something good during the scan); each checked item then becomes a full row as its check answers, above the unchecked ones; at the end the unchecked rows go (a profit per unit without a quantity is no use afterwards). **"Check top items"** checkbox next to the button (on by default): off = no detailed checks, the scan ends after reading the AH and the unchecked rows stay. Checking every candidate took about as long as a full scan (171 checks in the first test). Its finds replace the Vendor list, as a full scan's do; chat gets the Vendor line plus one line with what the scan cost ("Quick scan done: N items on the AH, M with listings below vendor price, C checked; R requests, S s."). Not while RapidFire or the Recipes scan runs; the On Sale watch waits meanwhile. **Buying and left-click work during the scan** (2026-11-24: a find is gone if you can't react at once): while the buy dialog is open the scan pauses, and it carries on by itself when the dialog closes.
- [ ] **Auto quick scan** (the author's idea, 2026-11-24; after the first quick scan tests): a quick scan every few minutes while the AH is open, like RapidFire. Interval choices to be set from what a quick scan costs in game. Auctionator's own autoscan only scans on opening the AH (off by default, every 15 min at most).
- [x] **Finds expire** (2026-11-24), both lists: one setting, **Finds expire after** 10 min / 30 min (default) / 1 h / 2 h / 4 h. Vendor finds expire that long after their scan; On Sale finds that long after they were last seen (a full scan or search finding one again renews it). Expired finds are no longer listed or counted on the tab; the page says "The last scan expired 5 min ago. Please run a full scan again." (On Sale: "The last finds expired ... (or Start)."). A new full scan resets it.
- Not in 0.4.0: alerts, a live watch between scans, bids, a minimum profit, bag space.
- [x] **On Sale's screen glow stops by itself after 5 seconds** (2026-11-24: it kept pulsing until the On Sale tab was opened). The existing stops (mouse over the AH window, panel or buy dialog; finds gone; AH closed) stay. The author describes it as a red flash; it is meant to be gold (Blizzard's low-health texture tinted gold): to check in game.

## On Sale

Becomes a page of Opportunities in 0.4.0 (section above); what follows stays as it is.

Goal (2026-11-19): a character waits at the AH with the game in the background; ProfitCraft keeps checking broad searches and plays a sound on a find; the author switches to the game and decides. RapidFire needs constant speed and attention, and others (people or bots) take cheap cloth within seconds. Searches by name and suffix are expected to be one of ProfitCraft's best profit features. Works without Auctionator.

- [x] **Modes** (settings; 2026-11-21). Why: judging the whole AH in every full scan produced most of the false finds (price drops, price discovery, thinly traded items); the user's own searches are predictable.

| | **Off** (default) | **Manual List** | **Full Auto** (experimental) |
|---|---|---|---|
| On Sale page (Opportunities panel) | "On Sale is off" line | yes | yes |
| Scanning | none | the watch runs the user's searches; full scans are read | the same |
| Finds and alerts | none | **only items the user's switched-on searches cover** (watch results, and full-scan listings that match a search, judged by that search's rule) | every item on the AH |
| Price history | not recorded | recorded | recorded |

- [x] **Quick check on opening the AH** (Manual List and Full Auto; 2026-11-21): one pass through the switched-on searches, then it stops; **at most once a minute** (open, close, open again: one pass). The continuous watch starts only with the **Start** button (not "starts by itself") and stops when the AH closes.
- [x] **Watched searches, not single items**, like Auctionator's advanced search: text (partial, or exact in quotes), category, level range, item level range, quality (this or better); e.g. Armor > Mail, level 20-30, Uncommon, text "of the Knight". Each search has a name and an on/off box; one list for the account.
  - **Own editor**, plus **paste in** Auctionator searches: one per line, or a whole exported list (`ListName^search^search`). Auctionator's text format, read with ProfitCraft's own code; categories are Blizzard's own.
  - **Per-search rule** (2026-11-19), either/or: a **fixed price** ("at or under 30s"; per item for gear, per unit for stackable goods; needs no history, so it works from the first minute) **or** a **discount** below the usual price (prefilled from the settings) with its own minimum profit. Why: the history needs 3 separate days per item and suffix, so a discount search for suffixed gear finds nothing for the first days.
- [x] **Own price history per item and suffix** (2026-11-19): Auctionator keeps one history per item ID, so "of the Knight" and "of the Monkey" would share one, which both misses deals and raises false alerts. Recorded from what ProfitCraft sees anyway: its searches and full scans.
  - **Usual price** = the lower of the 7-day median and the median of the last 2 days, from at least **3 days with prices in the last 7** (local days). A price that has come down and stays there is the new usual within about two days.
  - Until then: **Auctionator's history for stackable goods only**; single items (gear, recipes, bags, ...) wait for ProfitCraft's own 3 days.
  - The On Sale panel shows "History: N of 7 days"; after a scan with fewer than 3 days, a chat reminder (setting).
- [x] **What counts as on sale** (percent rule):
  - **Single items** (gear, recipes) **70%** below the usual price, **stackable goods 45%** (sliders); profit after the AH cut at least the **minimum profit** (default 50s) and at most the **maximum profit** (default Auto = 1.5x the character's gold; the author: a bigger "profit" is a price still being found).
  - Stackable goods must have a real share of the supply cheap (the crumb limit), so a stack of 100 among 50,000 never alerts.
  - **Market check:** if more than half of what's listed is under the On Sale price, the market moved: no find.
  - **More than 3 listings at or under the On Sale price = not on sale** (single items; the author).
  - Fixed-price searches skip these checks: the user's price is taken as given.
- [x] **Finds list** in the On Sale panel: item (with suffix), price, usual price, possible profit, quantity, age, source (search name or "full scan"); newest first by the minute, then the biggest profit; scroll bar. **Click a find** -> ProfitCraft checks that item's live listings and asks "Buy N for X?"; **Buy** buys inside that click. The list maintains itself (finds that are gone or no longer cheap are removed) and is cleared when the AH closes.
- [x] **Alerts:** a sound on each new find, a **gold screen glow** that pulses until the mouse is over the AH window or the On Sale panel, and the taskbar flash (whether that reaches the desktop under Wine is for the author to test; the author expects not). Settings for sound and glow. Needs Blizzard's "Sound in Background" on (Options > Audio); ProfitCraft says so when the watch starts and it is off.
- Not possible: knowing the price things **sell** at (the AH shows listings, not sales).
- To check in game (the author; not blocking):
  - **Idle logout:** WoW usually logs out after 30 minutes without input (Blizzard forum citing Wowpedia; nothing Forever-specific found). Whether addon searches count as activity is unknown: leave RapidFire running untouched for 35 minutes. Nothing will be built to fake input (ToS).
  - **Suffix text search:** type "of the Knight" in Blizzard's own AH search box; Auctionator passes the text to the server unchanged (`Source_ModernAH/Search/Mixins/DirectSearchProviderMixin.lua`), so whether suffixes match is the server's behaviour. If not, ProfitCraft searches the category without text and matches the names itself.

## Recipes panel at the AH

- [x] The **Recipes** tab scans the AH for recipes of the character's professions and lists them with AH price, profit (**per stack**, default, or per craft; one column with a switch), profit as % of the reagent cost, and **"pays off after"** N crafts. Why (2026-11-20): finding profitable recipes meant hovering hundreds of recipe items one by one.
- [x] Sort by any column; "(known)" marks recipes the character knows, **Hide known** leaves them out; hover for the item's tooltip; **click a row to buy** the cheapest listing.

## Settings and commands

- [x] **Own settings window** (`/pcraft settings`, the panel's Settings button, or the PCraft macro's right-click), also in Blizzard's Options > AddOns, in **three pages**: **General** (currencies bar, free bag slots, AH tab size, crumb limit, summary-scan notice, debug mode), **Crafting profit** (price warning age, disenchant tooltip line), **Opportunities** (finds: expiry, quick scan checks, single items' minimum profit; buying: max per purchase, keep at least; the On Sale section: mode, then what counts as on sale, the watch's pause between searches, alerts). The On Sale options are greyed out while On Sale is Off. **Layout** (2026-11-24): 10 px padding around the settings; a page longer than 16 rows flows into a second column, breaking only at a section heading; the Opportunities page: Finds and Buying on the left, every On Sale section on the right. Compact rows (a slider, dropdown or money box: its label with the control just below); section headings in normal case. The window is sized for the tallest column.
- [x] **`/pcraft`**: show / hide the profit list; `settings`, `bags`, `money`, `tooltip on|off`, `debug on|off`, `errors` (`errors clear`). (Decided 2026-11-13.)

## Planned

### Version 0.4.0 (in beta since 2026-11-24, `0.4.0-beta.7`)

Opportunities (section above) plus these changes to the profit list (2026-11-24):

- [x] **AH or vendor, whichever pays more** ("profit is profit"): each product counts at the higher of its AH price after the 5% cut and its vendor price; one list, no separate vendor mode. Where it shows a sale price (row tooltip, recipe details, recipe tooltips, the Recipes panel) it is marked **(AH)** or **(Vend)**, as reagents are. Consequences: a product with no AH price but a vendor price is no longer "missing"; a bind-on-pickup product counts at its vendor price (still never at an AH price). Example: yellow shirts at 4s 99c on the AH = 4s 74c after the cut; the vendor pays 5s, so 5s counts.
- [x] **Search box** at the top of the profit list: as you type, only recipes whose name contains the text are shown (any case); works together with "Profitable only". (The list shows only the open profession, so no profession filter.)
- [x] **Row tooltip as a breakdown**, per craft: sale value (number made × price, with its source), the AH cut as an amount (none when the vendor price counts), reagent cost, profit. **Hold Shift** to see the same lines for a full stack of the product ("per stack of 20"), or **10** for products that don't stack; the tooltip changes as soon as Shift is pressed or released. The separate "Profit per stack" line goes (Shift replaces it). Like the common "Shift shows the value of all of them" tooltips.
- [x] **Per stack mode: 10 for products that don't stack**, also in the Recipes panel's per-stack column (counting 1 made Per stack the same as Per craft for gear and shirts).

Planned for later in 0.4 (not in 0.4.0):

- [ ] **Item tooltip prices**, with an on/off setting (the author wants it, 2026-11-13). **One line per source, each with its own price and age** (e.g. "Auctionator: 1s 20c, updated today"; "ProfitCraft scan: 1s 15c, 2 h ago"), like CraftProfit's tooltip. Possibly also merchant sell price, and for items you can craft: craft cost and profit (to decide).

### Discovery mode (future, bigger feature; 2026-11-21)

- Like Manual List, fed by Full Auto's finds: the player reviews what Full Auto finds and, per item, **whitelists** it (alert on it from now on, like an entry in the manual list) or **blacklists** it (never alert on it again). Over time this teaches On Sale which items are worth watching.
- Not designed yet. Questions for then: whitelist = a new search per item, or a separate list; blacklist per item, per item + suffix, or per category; where the review happens (the Finds list: right-click a find?); whether blacklisted items still record price history.

### Price sharing (2026-11-14)

- [ ] **Share the latest AH scan prices with other ProfitCraft users** through addon messages (invisible to players).
- [ ] **Settings:** sharing on/off; **outgoing** and **incoming** separately (e.g. share outwards but never accept others' data).
- [ ] **Who to share with**, each on/off: **Friends**, **Party**, **Guild**, **Custom** (a list of character names typed into a box).
- [ ] **On Sale from shared prices** (2026-11-21): a price list received from the party or guild is checked against the On Sale searches (Manual List) or everything (Full Auto) like a full scan, and finds from it show **who shared it and when that scan was made** ("Tester's scan, 5 m ago"). Shared prices can be stale or fake (see Trust): a find from them still gets the usual "check the AH" step before buying.
- Notes from the first look (2026-11-14), to settle before building:
  - Forever has `C_ChatInfo.SendAddonMessage(prefix, message, chatType, target)` (Forever API docs); party and guild are channels, but there is no "friends" channel: each online friend (and each Custom name) gets messages one by one (whisper type). QuestTogether already uses party addon messages on Forever.
  - **Volume:** a full scan is thousands of prices, and addon messages are small (255 bytes each) and rate-limited by the game (the API returns a "throttled" result). Needs compact encoding, sending in the background, and probably only prices newer than what the other side has.
  - **Same AH only:** prices must be tagged with the AH they came from (ruleset/realm and faction, if the AH is per faction: still an open question) and ignored when they don't match the receiver's AH.
  - **Trust:** received prices can be wrong or deliberately fake. Keep them apart from our own scan, use them only when newer than what we have, and never let them overwrite our own scan of the same day; show where a price came from.
  - **Names:** Forever characters have first and last names (`UnitFullName` returns both, knowledge file); how names must be written for whispers and Custom-list matching is not known yet. Retail sends "Name-Realm" as the sender; the format on Forever must be checked in game before any friends/Custom matching.
  - **Protocol version** in every message, so older and newer ProfitCraft versions don't misread each other.
  - **Protocol idea** (from a Claude web chat the author shared, 2026-11-14; matches the notes above): announce "I have a scan from time T" to the party when a scan ends or someone joins; whoever has older data asks for "everything after my time"; the sender sends only items scanned since then; the receiver keeps, per item, whichever price is newer and rejects bad data (non-numeric IDs, prices out of range, timestamps in the future).
  - **Libraries** that would do the chunking, throttling, encoding and compression: AceComm (with ChatThrottleLib), LibSerialize, LibDeflate. Licences not yet checked for use in MIT ProfitCraft; using them is a choice to make (ProfitCraft is written from scratch, but libraries are not other addons).
  - **APIs present in Forever's UI source** (checked 2026-11-14): `C_ChatInfo.InChatMessagingLockdown`, `C_FriendList.GetFriendInfo` / `GetFriendInfoByIndex`, `C_BattleNet.GetFriendGameAccountInfo`, `C_BattleNet.SendGameData` (Battle.net friends; the old `BNSendGameData` is only a deprecated wrapper on Forever, `Blizzard_DeprecatedBattleNet/Deprecated_BattleNet.lua`), `Ambiguate`. Presence in the source is not proof they behave as on Retail.

## Later / maybe

- [ ] Minimap button (to be decided).
- [ ] Profit tags in Blizzard's recipe list: a small profit number next to each recipe name in the list on the left, like CraftProfit's. Separate from the recipe-details profit and the side panel.
- [ ] **Listing deposit risk** (moved here 2026-11-13): show the listing deposit as money at risk if an item doesn't sell, per item and per stack, with the break-even quantity (e.g. "Cured Light Hide: 1 = −40c, stack of 20 = +9s, profitable from 3"). Left out of the main profit because the deposit is refunded on sale. Less relevant since Forever dropped the 1s minimum deposit (2026-11-17): the example assumed it.

## Side project (not planned; 2026-11-19)

- An outside tool (in `tools/`, not part of the addon) that reads Forever's AH snapshots from Blizzard's own Game Data API (per ruleset and faction house, hourly; community reports, not checked) to build price history and **suggest watch lists**, e.g. in Auctionator's shopping-list import format (`ListName^search1^search2`). Undermine Exchange's API covers Retail only (its API page, 2026-11-19). Only mentioned, not planned.

## Future (set aside)

- [ ] Levelling mode (cheapest cost per skill point).
- [ ] **Price history display:** prices over days, a "normal" price and a cheap/normal/high verdict for the current price, like CraftProfit's ("Normal price … learning, x of 7 days"). ProfitCraft already keeps its own history and usual price for On Sale; showing it is what's left. Profit stays based on the **current** price: prices can swing a lot within a day (the author saw Sharpening Wheels go from 74c to 1s 70c on 2026-11-13), so a multi-day average would misstate what a sale earns now.
- [ ] Craft queue / crafting from the side panel (maybe).

## Not doing

- TSM support.
- Manual price override (no need seen, 2026-11-13).
- A "sort by profit" checkbox in Blizzard's recipe list (it can only sort inside each category).
- A "cheapest 20%" average (CraftProfit's "depth value"; dropped 2026-11-17): the author: a share of all supply is the wrong measure for crafting profit; replaced by the reagent-cost and crumb rules.
- **Feeding our scan into Auctionator's data** (the author's idea, 2026-11-14): not possible through Auctionator's public API (checked in Auctionator 346, `Source/API/v1/`: it only reads prices, ages, vendor prices and disenchant values, runs searches and edits shopping lists; nothing writes prices). Writing into Auctionator's internal saved database could corrupt its data whenever Auctionator changes. Not doing unless Auctionator adds a write function.
- Pre-filled vendor price table (see Prices).
- Fully automatic buying (Blizzard requires a key press or click per purchase).
- **Pricing reagents you can craft at their crafting cost** (dropped 2026-11-24, the author: the profit list already covers it). A reagent counts at its AH price, which is what using it instead of selling it gives up; whether crafting the reagent pays shows on its own row.
- **Shopping list** (dropped 2026-11-24, the author: Auctionator does this, no need for two). Auctionator's **[Search]** button in Blizzard's recipe details searches the recipe's product and reagents (`Source_Mainline/CraftingInfo/Professions.lua`).
- **A separate vendor mode or list in the profit list** (2026-11-24: "profit is profit"): each product counts at whichever of AH and vendor pays more (Version 0.4.0).

## Open questions

The deposit questions only matter for "Listing deposit risk".

- [ ] **Does a stack count as one listing?** Does posting 20 or 40 Cured Light Hides at once pay one deposit or one per item? Likely one deposit (Retail's commodity rule), untested in Forever. The author to test in game.
- [ ] **Is the deposit refunded on sale?** Web sources say yes; check in game (list a cheap item, see whether the deposit comes back with the sale money). If yes, the deposit only costs money on unsold auctions.
- [ ] **Unsold auctions: deposit lost or refunded?** Web sources disagree; treat as lost until seen.
- [ ] **How the deposit is calculated** (item value? auction length?). The 1s minimum is gone (2026-11-17).
- [ ] **Can an addon ask Forever's AH what the deposit will be?** Check with an in-game command when building starts.
- [ ] **Is the AH cut 5% in Forever?** Web sources say yes; not yet confirmed in game.
- [ ] **What unit is Auctionator's price age in** (`GetAuctionAgeByItemID`): whole days, or something finer? Decides how often the same-day tie rule applies. It returned 0 for same-day prices (PsiLab, 2026-11-13); check again the day after a scan.
- [x] **Can buyers take part of a listing?** Yes for reagents: the author bought 2 of about 90 Silk Cloth (in game, 2026-11-17).
- [x] **Why Auctionator gave no disenchant values:** its disenchant prices only cover later expansions, not Forever (2026-11-13); see `DESIGN.md` section 12.
- [x] **Which Auctionator functions exist on Forever?** All 21 `Auctionator.API.v1` functions (PsiLab, 2026-11-13).
