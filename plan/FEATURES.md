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

## Version 0.2 (standalone: works without Auctionator)

From 0.2 on there are no alphas: each beta adds features, rc = done, fixes only (Sylice, 2026-11-17).

- [x] **Money window** (0.2-beta.0; Sylice, 2026-11-17): a small movable window with your money and up to **5** tracked currencies (ProfitCraft's own limit; Blizzard's backpack tracking has no fixed limit on Forever, it fits as many as the backpack is wide), growing to the left as currencies are added. Off by default (settings checkbox, `/pcraft money`). Right-click anywhere: Add currency (pop-out list of the character's currencies), Remove currency, Lock/Unlock position, Background colour (any colour, fully transparent to solid), Hide. One list for all characters. Design: DESIGN.md "Money window".
- [x] **Create Profit Macro** (0.2-beta.0; Sylice, 2026-11-17): a small button in the bottom-right corner of ProfitCraft's settings window creates a general (account-wide) macro **"PCraft"** with a money bag icon (not coins): left-click opens the profit list (`/pcraft`), right-click the settings. Greyed out with the tooltip "Macro already exists" when a macro named PCraft exists (general or character), and "No free general macro slot" when all general slots are used. Design: DESIGN.md "Settings".
- [x] **Our own AH scan**, so ProfitCraft works without Auctionator (decided 2026-11-13). Also gives the listing detail Auctionator's API doesn't expose.
- [x] **Our own merchant recording** of vendor buy prices, taken whenever a merchant window is open (the game only reveals buy prices there: item data has only the sell price, Forever API docs); used when Auctionator has no vendor price. Fills itself as you visit vendors. **No pre-filled vendor price table** (Sylice, 2026-11-14): no Forever source for buy prices found, and reagents from vendors you never visit fall back to the AH price or show as missing.
- [ ] **Feed our scan into Auctionator's data** (Sylice's idea, 2026-11-14: our scan may be more thorough). **Not possible through Auctionator's public API** (checked in Auctionator 346, `Source/API/v1/`): it only reads prices, ages, vendor prices and disenchant values, runs searches and edits shopping lists; nothing writes prices. The only way would be writing into Auctionator's internal saved price database, which is undocumented and could corrupt its data whenever Auctionator changes. Not doing unless Auctionator adds a write function. ProfitCraft itself still uses its own newer scan prices (next item).
- [x] **AH prices: whichever is most recent, per item.** For each item, compare Auctionator's price (if Auctionator is installed and has one) with ProfitCraft's own scan data and use the newer one. If both are from the same day and can't be told apart (Auctionator's age may only be in whole days), use our own. (Decided 2026-11-13.)

## Requirements (apply to every version)

- **Works fully without Auctionator** (from 0.2 on; disenchant estimates use ProfitCraft's own table from alpha.4 but still need Auctionator's AH prices until 0.2; 0.1 only loads cleanly without it and says it has no price source). ProfitCraft is a standalone addon; Auctionator is an optional, recommended source (`## OptionalDeps: Auctionator` in the `.toc`, so it loads first when installed, never `## Dependencies`). Auctionator's data is used when available. (Decided 2026-11-13.)
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

- [ ] **Spot listings far below their usual price** during ProfitCraft's own AH scan, e.g. level 20-30 mail "of the Knight" that usually sells for 1g+ listed at 10-20s, and list them in a separate **"On Sale" window** with the possible profit (usual price after the AH cut, minus the listing price).
- Notes from the first look (2026-11-14):
  - **Addons can't download anything while the game runs**, so "known data sources" can only come in two ways: (1) a snapshot of outside averages shipped inside the addon (stale between releases; needs a Forever source and permission to use its data; foreverdb.net shows per-realm price history from player scans, terms not checked), or (2) **ProfitCraft's own price history** from its scans (the "Price history" item under Future), helped by price sharing. (2) is the realistic base; (1) only to fill gaps, if at all.
  - Needs the **own AH scan with individual listings** (0.2): Auctionator's API gives one price per item, not the listings.
  - **Random suffixes** ("of the Knight", "of the Bear", ...) share one item ID but sell for different prices, so the history must be kept per item **and suffix**. Auctionator handles suffixes for Vanilla-type games (`Data_Vanilla/Suffixes.lua`); how suffixes appear in Forever's item links and AH results is not checked yet.
  - "Usual price" should be robust against bait listings and sparse data: e.g. the median of recent days, only when there are enough days/listings, and a minimum discount (e.g. 50% below) before an item counts as "on sale".

## Later / maybe

- [x] Price-age warnings ("this price is 9 days old"). From Auctionator's age function when its price is used; from our own scan time otherwise.
- [ ] A "cheapest 20%" average so one bait listing can't fake a price. Only possible with our own scan data (Auctionator's API gives one price per item, not the listings), so it would not apply to items priced from Auctionator.
- [ ] Minimap button (not in 0.1; to be decided later).
- [ ] Profit tags in Blizzard's recipe list: a small profit number next to each recipe name in the list on the left, like CraftProfit's. Separate from the recipe-details profit (0.1) and the side panel.

- [ ] **Listing deposit risk** (moved here 2026-11-13): show the listing deposit as money at risk if an item doesn't sell, per item and per stack, with the break-even quantity (e.g. "Cured Light Hide: 1 = −40c, stack of 20 = +9s, profitable from 3"). Left out of the main profit because the deposit is refunded on sale. Less relevant since Forever dropped the 1s minimum deposit (Sylice, 2026-11-17): the example above assumed it.

## Future (set aside)

- [ ] Levelling mode (cheapest cost per skill point).
- [ ] **Price history** from our own scans (needs 0.2): prices over days, a "normal" price (e.g. median of recent days) and a cheap/normal/high verdict for the current price. Profit stays based on the **current** price: prices can swing a lot within a day (Sylice saw Sharpening Wheels go from 74c to 1s 70c on 2026-11-13), so a multi-day average would misstate what a sale earns now. CraftProfit does this ("Normal price … learning, x of 7 days").- [ ] Craft queue / crafting from the side panel (maybe).

## Not doing

- TSM support.
- Manual price override (no need seen, 2026-11-13).
- A "sort by profit" checkbox in Blizzard's recipe list (it can only sort inside each category).

## Open questions

The deposit questions only matter for the "Listing deposit risk" item in "Later / maybe".

- [ ] **Does a stack count as one listing?** Does posting 20 or 40 Cured Light Hides at once pay one deposit or one per item? Likely one deposit (Retail's commodity rule), untested in Forever. Sylice to test in game.
- [ ] **Is the deposit refunded on sale?** Web sources say yes; check in game (list a cheap item, see whether the deposit comes back with the sale money). If yes, the deposit only costs money on unsold auctions.
- [ ] **Unsold auctions: deposit lost or refunded?** Web sources disagree; treat as lost until seen.
- [ ] **Can buyers take part of a listing?** CraftProfit's 0.5.2 changelog mentions buying "1 of 860 Copper Rods" from a grouped row, which suggests partial buys.
- [ ] **How the deposit is calculated** (item value? auction length?). The 1s minimum is gone (Sylice, 2026-11-17).
- [ ] **Is the AH cut 5% in Forever?** Web sources say yes; not yet confirmed in game.
- [ ] **Can an addon ask Forever's AH what the deposit will be?** Check with an in-game command when building starts.
- [x] **Why Auctionator gave no disenchant values:** its disenchant prices only cover later expansions, not Forever (Sylice, 2026-11-13). ProfitCraft builds its own estimate next; see `DESIGN.md` section 12.
- [ ] **Which Auctionator functions exist on Forever** (especially the price-age one)? Check in game when building starts.
- [ ] **What unit is Auctionator's price age in** (`GetAuctionAgeByItemID`): whole days, or something finer? Decides how often the same-day tie rule applies. Check with `/dump` in game.
