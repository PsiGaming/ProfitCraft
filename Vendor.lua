-- ProfitCraft: Vendor finds (FEATURES.md "Opportunities", DESIGN.md section 16)
-- Every full scan (and every quick scan, below) is checked for listings of other sellers that cost less than a vendor
-- pays for them (seen
-- 2026-11-24: 10 yellow shirts at 4s 99c that vendor for 5s each). Works whatever the On Sale mode is. The list is
-- replaced by each full scan, kept in memory only (not cleared when the AH closes). No sound or glow; one chat line
-- per scan with finds.
-- Vendor price: what a vendor pays for one item (C_Item.GetItemInfo, 11th value; 0 = vendors don't buy it).

local _, PC = ...

local Vendor = {}
PC.Vendor = Vendor

local LOAD_TIMEOUT = 10  -- seconds to wait for item data after a scan, as Scan.lua waits for recipe items

local hits = {}   -- key -> find
local scanTime    -- when the scan behind the list was read
local pending     -- the last scan's collector while listings of unloaded items wait for their item data

---------------------------------------------------------------------------
-- The list
---------------------------------------------------------------------------

local function Changed() PC:Send("VENDOR_CHANGED") end

-- Finds expire a while after their scan (setting, 10 min to 4 h; 2026-11-24); the next full scan brings fresh
-- ones.
local function ExpirySeconds() return PC.db.settings.opportunityExpiry * 60 end

function Vendor:IsExpired()
  return scanTime ~= nil and time() - scanTime >= ExpirySeconds()
end

-- Seconds since the finds expired, or nil while they haven't.
function Vendor:ExpiredFor()
  if not self:IsExpired() then return nil end
  return time() - scanTime - ExpirySeconds()
end

-- One check just after the finds expire, so the page and the tab's badge empty by themselves.
local function ScheduleExpiry()
  if not scanTime then return end
  local left = scanTime + ExpirySeconds() - time()
  if left > 0 then C_Timer.After(left + 1, Changed) end
end

PC:Listen("SETTINGS_CHANGED", function(key)
  if key ~= "opportunityExpiry" then return end
  Changed()
  ScheduleExpiry()
end)

-- Filters (2026-11-24: "no way I'm buying 188 individual items and vendoring them all"): items that don't
-- stack are each bought, carried and sold on their own, so they only count when each one earns at least the
-- "Single items: min profit each" setting (vendorMinSingleProfit), and not at all with "Stackable only"
-- (vendorStackableOnly, checkbox on the Vendor page). Stackable goods always pass. Stack size from the item data;
-- while it isn't loaded, the game's commodity flag decides.
function Vendor:IsSingle(itemID, commodity)
  local stack = PC.Items:GetStackSize(itemID)
  if stack then return stack == 1 end
  return not commodity
end

function Vendor:PassesFilters(itemID, commodity, perItem)
  if not self:IsSingle(itemID, commodity) then return true end
  local settings = PC.db.settings
  if settings.vendorStackableOnly then return false end
  return perItem >= settings.vendorMinSingleProfit
end

local function Shown(hit)
  local perItem = hit.unchecked and hit.profit or hit.profit / math.max(hit.units, 1)
  return Vendor:PassesFilters(hit.itemID, hit.stackable, perItem)
end

PC:Listen("SETTINGS_CHANGED", function(key)
  if key == "vendorStackableOnly" or key == "vendorMinSingleProfit" then Changed() end
end)

-- An item learned to be unsellable (Sources/ItemData.lua) leaves the list at once.
PC:Listen("ITEM_UNSELLABLE", function(itemID)
  for key, hit in pairs(hits) do
    if hit.itemID == itemID then hits[key] = nil end
  end
  Changed()
end)

-- Finds sorted by profit, biggest first, then by name; none once they have expired; without those the filters hide
-- (the second value: how many are hidden). While a quick scan runs, its unchecked finds (`unchecked`: only the
-- cheapest price is known; `profit` is per unit) come after the checked ones, by profit per unit (2026-11-24:
-- to react to something good while the scan still runs).
function Vendor:GetHits()
  if self:IsExpired() then return {}, 0 end
  local list, hidden = {}, 0
  for _, hit in pairs(hits) do
    if Shown(hit) then list[#list + 1] = hit else hidden = hidden + 1 end
  end
  table.sort(list, function(a, b)
    if (a.unchecked or false) ~= (b.unchecked or false) then return not a.unchecked end
    if a.profit ~= b.profit then return a.profit > b.profit end
    return (a.name or "") < (b.name or "")
  end)
  return list, hidden
end

-- Commodity (one listing type, bought by quantity) or not: the game's own answer when it has the item's key info
-- (C_AuctionHouse.GetItemKeyInfo(...).isCommodity, what Blizzard's Buy tab goes by, Blizzard_AuctionHouseFrame.lua
-- SelectBrowseResult); otherwise judged by the stack size (OnSale:IsStackable). The two kinds of item answer AH
-- searches with different events.
function Vendor:IsCommodity(itemID, itemKey)
  local info = C_AuctionHouse.GetItemKeyInfo(itemKey or C_AuctionHouse.MakeItemKey(itemID))
  if info and info.isCommodity ~= nil then return info.isCommodity end
  return PC.OnSale:IsStackable(itemID)
end

function Vendor:GetHit(key)
  if self:IsExpired() then return nil end
  return hits[key]
end
function Vendor:GetScanTime() return scanTime end

function Vendor:RemoveHit(key)
  if not hits[key] then return end
  hits[key] = nil
  Changed()
end

-- After a purchase: the bought units and their cost come off the find; gone when nothing (or no profit) is left.
function Vendor:Bought(key, quantity, total)
  local hit = hits[key]
  if not hit then return end
  if hit.unchecked then  -- quantity never known: the purchase took what was cheap at that moment
    hits[key] = nil
    return Changed()
  end
  hit.units = hit.units - quantity
  hit.cost = math.max(0, hit.cost - total)
  hit.listings = math.max(1, hit.listings - 1)
  hit.value = hit.vendorPrice * hit.units
  hit.profit = hit.value - hit.cost
  if hit.units <= 0 or hit.profit <= 0 then hits[key] = nil end
  Changed()
end

---------------------------------------------------------------------------
-- Full scans (called by Scan.lua for every listing of other sellers with a buyout)
---------------------------------------------------------------------------

local Collector = {}
Collector.__index = Collector

function Vendor:NewScanCollector()
  return setmetatable({ time = time(), keys = {}, waiting = {}, waitingCount = 0 }, Collector)
end

-- Quick scan: an unchecked entry (shown with its cheapest price) turns into a checked one once its check has
-- answered: by Judge for the first listing below vendor price, else by EndCheck; with 0 units it then leaves the list
-- on the next Publish. Until the answer it stays shown as unchecked.
local function Checked(entry)
  entry.unchecked = nil
  entry.units, entry.cost, entry.listings, entry.cheapest = 0, 0, 0, nil
end

-- One listing whose vendor price is known: a find when the buyout is below what a vendor pays for its items. Uses
-- the buyout and count, not a rounded unit price, since the margin can be a single copper.
function Collector:Judge(itemID, variant, name, buyout, count, sell)
  if sell <= 0 or buyout >= sell * count then return end
  local key = itemID .. ":" .. variant
  local entry = self.keys[key]
  if not entry then
    entry = { itemID = itemID, variant = variant, name = name, units = 0, cost = 0, listings = 0, vendorPrice = sell }
    self.keys[key] = entry
  elseif entry.unchecked then
    Checked(entry)  -- quick scan: the candidate's check has answered
  end
  entry.name = entry.name or name
  entry.units = entry.units + count
  entry.cost = entry.cost + buyout
  entry.listings = entry.listings + 1
  local unit = math.floor(buyout / count)
  if not entry.cheapest or unit < entry.cheapest then entry.cheapest = unit end
end

-- Quick scan, while it reads the AH: an item whose cheapest listing is below vendor price, shown at once with that
-- price and the profit per unit ("?" units). Returns its key. A key that is already a checked find is left alone.
function Collector:AddUnchecked(itemID, variant, name, itemKey, cheapest, sell)
  local key = itemID .. ":" .. variant
  local entry = self.keys[key]
  if entry and not entry.unchecked then return key end
  if not entry or cheapest < entry.cheapest then
    self.keys[key] = { itemID = itemID, variant = variant, name = name, itemKey = itemKey, unchecked = true,
      cheapest = cheapest, vendorPrice = sell }
  end
  return key
end

-- Quick scan, once a candidate's check has answered: an entry still unchecked turns into a checked one (see Checked).
function Collector:EndCheck(key)
  local entry = self.keys[key]
  if entry and entry.unchecked then Checked(entry) end
end

-- Quick scan, at its end: what is still unchecked goes (2026-11-24: a profit per unit without a quantity is
-- no use once the scan is done).
function Collector:DropUnchecked()
  for key, entry in pairs(self.keys) do
    if entry.unchecked then
      self.keys[key] = nil
      if entry.key then hits[entry.key] = nil end
    end
  end
end

-- Gear is told apart by its full name (random suffixes), as On Sale does (OnSale:Variant); a blank scan name is taken
-- from the item link; gear whose name can't be read is left out. Items whose data isn't loaded yet wait for it.
function Collector:Add(index, itemID, buyout, count, name)
  if name == "" then name = nil end
  local variant = 0
  if PC.OnSale:IsGear(itemID) then
    if not name then
      local link = C_AuctionHouse.GetReplicateItemLink(index)
      name = link and link:match("|h%[(.-)%]|h")
    end
    if not name or name == "" then return end
    variant = name:lower()
  end
  local sell = PC.Items:GetSellPrice(itemID)  -- requests the item data when it isn't loaded
  if sell then return self:Judge(itemID, variant, name, buyout, count, sell) end
  local list = self.waiting[itemID]
  if not list then
    list = {}
    self.waiting[itemID] = list
    self.waitingCount = self.waitingCount + 1
  end
  list[#list + 1] = { variant, name, buyout, count }
end

-- Listings waiting for item data that has arrived meanwhile are judged now.
function Collector:JudgeLoaded()
  for itemID, list in pairs(self.waiting) do
    local sell = PC.Items:GetSellPrice(itemID)
    if sell then
      for _, l in ipairs(list) do self:Judge(itemID, l[1], l[2], l[3], l[4], sell) end
      self.waiting[itemID] = nil
      self.waitingCount = self.waitingCount - 1
    end
  end
end

-- The list becomes this scan's finds: the first call replaces the list, later calls (item data that arrived after a
-- full scan; each page and each finished check of a quick scan) add new finds, so a find bought or found gone
-- meanwhile doesn't come back. Values are worked out on every call, since a later listing can add to a find already
-- shown, and a quick scan's checked find can turn out empty.
function Collector:Publish()
  if not self.published then
    wipe(hits)
    self.published = {}
  end
  for key, entry in pairs(self.keys) do
    if not self.published[key] then
      self.published[key] = true
      local stackable = Vendor:IsCommodity(entry.itemID, entry.itemKey)
      entry.key = "vendor:" .. key
      entry.stackable = stackable
      -- A quick scan knows gear's item key (with its suffix) from the browse results; a full scan doesn't.
      entry.itemKey = entry.itemKey or (stackable and C_AuctionHouse.MakeItemKey(entry.itemID) or nil)
      hits[entry.key] = entry
    end
    if entry.unchecked then
      entry.profit = entry.vendorPrice - entry.cheapest  -- per unit
    else
      entry.value = entry.vendorPrice * entry.units
      entry.profit = entry.value - entry.cost
      if entry.units == 0 then hits[entry.key] = nil end  -- checked: nothing below vendor price after all
    end
  end
  scanTime = self.time
  Changed()
  ScheduleExpiry()
end

-- One chat line per scan with finds (2026-11-24: no spam, just how many and the possible profit); nothing
-- when there are none.
local function Summary()
  local count, checked, profit = 0, 0, 0
  for _, hit in ipairs((Vendor:GetHits())) do  -- what the filters let through
    count = count + 1
    if not hit.unchecked then
      checked = checked + 1
      profit = profit + hit.profit
    end
  end
  if count == 0 then return end
  local s = count == 1 and "" or "s"
  if checked == count then
    PC:Print(string.format("Vendor: %d item%s below vendor price, %s if you buy and vendor all of them "
      .. "(Opportunities tab).", count, s, PC:FormatProfit(profit)))
  elseif checked == 0 then  -- quick scan without the detailed checks: no quantities, so no total
    PC:Print(string.format("Vendor: %d item%s below vendor price (Opportunities tab).", count, s))
  else
    PC:Print(string.format("Vendor: %d item%s below vendor price; the %d checked: %s if you buy and vendor all of "
      .. "them (Opportunities tab).", count, s, checked, PC:FormatProfit(profit)))
  end
end

function Collector:Finish()
  self:JudgeLoaded()
  self:Publish()
  Summary()
  if self.waitingCount == 0 then
    pending = nil
    return
  end
  pending = self
  C_Timer.After(LOAD_TIMEOUT, function()
    if pending ~= self then return end
    pending = nil
    if PC.db.settings.debug then
      PC:Print(string.format("debug: Vendor: %d items never loaded their data and were left out.", self.waitingCount))
    end
  end)
end

PC:Listen("ITEM_DATA_CHANGED", function()
  local c = pending
  if not c then return end
  local before = c.waitingCount
  c:JudgeLoaded()
  if c.waitingCount ~= before then c:Publish() end
  if c.waitingCount == 0 then pending = nil end
end)

---------------------------------------------------------------------------
-- Quick scan (2026-11-24): a Vendor check without a full scan, modelled on Auctionator's summary scan
-- (Auctionator 346, Source_ModernAH/IncrementalScan/Mixins/Frame.lua; read for the approach, no code copied): one
-- browse search with no filters, then "more results" until the game has sent them all. Every request waits until
-- the AH's throttle says it may be sent (C_AuctionHouse.IsThrottledMessageSystemReady, resumed on
-- AUCTION_HOUSE_THROTTLED_SYSTEM_READY), as Auctionator's request queue does (Source/AH/Mixins/Queue.lua).
-- A browse result has only an item's cheapest price, so every item whose cheapest price is below its vendor price
-- is a candidate (none is missed). Candidates go into the list page by page as unchecked finds (cheapest price,
-- profit per unit). Then, unless "Check top items" is off (quickScanDetail), the most promising ones (quickScanChecks:
-- 5, 10 or 20) get one item search each, counting the units below vendor price and what they cost (first page of
-- results only: cheapest first); each becomes a full find as its check finishes, and the rest are dropped at the end.
-- The finds replace the Vendor list, as a full scan's do.
---------------------------------------------------------------------------

local ANSWER_TIMEOUT = 10  -- seconds to wait for each answer
local SORTS = { { sortOrder = Enum.AuctionHouseSortOrder and Enum.AuctionHouseSortOrder.Price or 0, reverseSort = false } }

local quick  -- the running quick scan, or nil

function Vendor:IsQuickScanning() return quick ~= nil end

-- Why a quick scan can't start now, or nil.
function Vendor:QuickScanBlocked()
  if quick then return "A quick scan is already running." end
  if not (AuctionHouseFrame and AuctionHouseFrame:IsShown()) then return "Open the Auction House first." end
  if PC.Rapid and PC.Rapid:IsRunning() then return "Stop RapidFire first: both search the Auction House." end
  if PC.AHRecipes and PC.AHRecipes:IsRunning() then return "Wait for the Recipes scan to finish." end
  if PC.OnSale:GetDialogState() then return "Close the buy dialog first." end
  return nil
end

local function Status(text)
  if quick then quick.status = text end
  PC:Send("VENDOR_QUICKSCAN")
end

function Vendor:GetQuickScanStatus() return quick and quick.status end

local function Stop(message)
  if not quick then return end
  quick = nil
  PC.OnSale:SetBusy(PC.OnSale:GetDialogState() ~= nil)  -- an open buy dialog keeps the On Sale watch waiting
  if message then PC:Print(message) end
  PC:Send("VENDOR_QUICKSCAN")
end

-- Sends `fn(...)` as soon as the AH's throttle allows, marked as ProfitCraft's own request (OnSale.Send), and
-- expects an answer within ANSWER_TIMEOUT. While the buy dialog is open (buying during a scan; 2026-11-24)
-- nothing new is sent, so the dialog's own search goes first; the scan carries on about a second after it closes.
local function Request(q, fn, ...)
  local args = { n = select("#", ...), ... }
  q.queued = function() PC.OnSale.Send(fn, unpack(args, 1, args.n)) end
  q.waiting = false
  local function Try()
    if quick ~= q or not q.queued then return end
    if PC.OnSale:GetDialogState() then
      if not q.paused then
        q.paused = q.status or ""
        Status("Quick scan: paused while you buy...")
      end
      C_Timer.After(1, function() if q.try then q.try() end end)
      return
    end
    if q.paused then
      local status = q.paused
      q.paused = nil
      Status(status)
    end
    if C_AuctionHouse.IsThrottledMessageSystemReady and not C_AuctionHouse.IsThrottledMessageSystemReady() then
      C_Timer.After(1, function() if q.try then q.try() end end)  -- also resumed by the "ready" event
      return
    end
    local send = q.queued
    q.queued = nil
    q.requests = q.requests + 1
    q.waiting = true
    local token = {}
    q.token = token
    send()
    C_Timer.After(ANSWER_TIMEOUT, function()
      if quick == q and q.waiting and q.token == token then q.onTimeout() end
    end)
  end
  q.try = Try
  Try()
end

PC:RegisterEvent("AUCTION_HOUSE_THROTTLED_SYSTEM_READY", function()
  if quick and quick.try then quick.try() end
end)

local NextCandidate  -- defined below

-- A candidate: an item listed cheaper than a vendor pays. It goes straight into the list, unchecked (decided
-- 2026-11-24: to react to something good while the scan still runs). Gear whose name isn't known yet can't be told
-- apart by suffix and is left out, as elsewhere.
local function AddCandidate(q, row, sell)
  local key = row.itemKey
  local info = C_AuctionHouse.GetItemKeyInfo(key)
  local name = info and info.itemName
  local variant = PC.OnSale:Variant(key.itemID, name, key.itemSuffix)
  if variant == nil then return end
  local itemKey = not Vendor:IsCommodity(key.itemID, key) and key or nil
  local entryKey = q.collector:AddUnchecked(key.itemID, variant, name, itemKey, row.minPrice, sell)
  q.candidates[#q.candidates + 1] = { row = row, sell = sell, entryKey = entryKey }
end

-- Browse results (battle pets are left out). Each item key counts once, should the game send the whole list again.
local function CollectBrowse(q, results)
  for _, row in ipairs(results or {}) do
    local key = row.itemKey
    local id = key and (key.itemID .. ":" .. (key.itemLevel or 0) .. ":" .. (key.itemSuffix or 0))
    if key and not q.seen[id] and (key.battlePetSpeciesID or 0) == 0 and row.minPrice and (row.totalQuantity or 0) > 0 then
      q.seen[id] = true
      q.items = q.items + 1
      local sell = PC.Items:GetSellPrice(key.itemID)
      if sell == nil then
        q.unloaded[#q.unloaded + 1] = row
      elseif sell > 0 and row.minPrice < sell then
        AddCandidate(q, row, sell)
      end
    end
  end
  q.collector:Publish()  -- the first page replaces the old list
end

local function ContinueBrowse(q)
  if not C_AuctionHouse.HasFullBrowseResults() then
    q.pages = q.pages + 1
    Status(string.format("Quick scan: reading the AH (page %d, %d items, %d below vendor price)...", q.pages, q.items,
      #q.candidates))
    return Request(q, C_AuctionHouse.RequestMoreBrowseResults)
  end
  -- Items whose data has arrived meanwhile get their vendor price now; the rest are left out.
  for _, row in ipairs(q.unloaded) do
    local sell = PC.Items:GetSellPrice(row.itemKey.itemID)
    if sell and sell > 0 and row.minPrice < sell then AddCandidate(q, row, sell) end
  end
  q.collector:Publish()
  q.found = #q.candidates
  -- "Check top items" off (checkbox on the Vendor page): done; the unchecked finds stay.
  if not PC.db.settings.quickScanDetail then
    q.candidates = {}
    q.phase, q.next = "check", 0
    return NextCandidate(q)
  end
  -- Only the most promising candidates are checked (2026-11-24: checking all 171 took about as long as a full
  -- scan): ranked by what they could earn at most, profit per unit x units listed; how many: the "Quick scan checks"
  -- setting.
  -- Candidates the filters would hide aren't worth a check.
  local kept = {}
  for _, candidate in ipairs(q.candidates) do
    local key = candidate.row.itemKey
    if Vendor:PassesFilters(key.itemID, Vendor:IsCommodity(key.itemID, key), candidate.sell - candidate.row.minPrice) then
      candidate.possible = (candidate.sell - candidate.row.minPrice) * candidate.row.totalQuantity
      kept[#kept + 1] = candidate
    end
  end
  q.candidates = kept
  table.sort(q.candidates, function(a, b) return a.possible > b.possible end)
  for i = PC.db.settings.quickScanChecks + 1, #q.candidates do q.candidates[i] = nil end
  q.phase, q.next = "check", 0
  NextCandidate(q)
end

PC:RegisterEvent("AUCTION_HOUSE_BROWSE_RESULTS_UPDATED", function()
  local q = quick
  if not (q and q.phase == "browse" and q.waiting) then return end
  q.waiting = false
  CollectBrowse(q, C_AuctionHouse.GetBrowseResults())
  ContinueBrowse(q)
end)

PC:RegisterEvent("AUCTION_HOUSE_BROWSE_RESULTS_ADDED", function(added)
  local q = quick
  if not (q and q.phase == "browse" and q.waiting) then return end
  q.waiting = false
  CollectBrowse(q, added)
  ContinueBrowse(q)
end)

PC:RegisterEvent("AUCTION_HOUSE_BROWSE_FAILURE", function()
  if quick and quick.phase == "browse" and quick.waiting then
    Stop("Quick scan: the Auction House refused the search. Try again in a moment.")
  end
end)

-- One chat line with the finds (as after a full scan) and one with what the scan did and cost. With the detailed
-- checks on, the finds left unchecked go; with them off, the unchecked finds are all there is and stay.
local function FinishQuick(q)
  if PC.db.settings.quickScanDetail then q.collector:DropUnchecked() end
  q.collector:Publish()
  Summary()
  Stop(string.format("Quick scan done: %d items on the AH, %d with listings below vendor price, %d checked%s; "
    .. "%d requests, %d s.", q.items, q.found, #q.candidates,
    q.skipped > 0 and string.format(" (%d gave no answer)", q.skipped) or "", q.requests,
    math.floor(GetTime() - q.started + 0.5)))
end

-- One item search per candidate, cheapest listings first; each finished check's finds show at once.
function NextCandidate(q)
  if q.next > 0 then q.collector:Publish() end
  q.next = q.next + 1
  local candidate = q.candidates[q.next]
  if not candidate then return FinishQuick(q) end
  local key = candidate.row.itemKey
  candidate.stackable = Vendor:IsCommodity(key.itemID, key)
  candidate.searchKey = candidate.stackable and C_AuctionHouse.MakeItemKey(key.itemID) or key
  q.current = candidate
  Status(string.format("Quick scan: checking %d of %d...", q.next, #q.candidates))
  Request(q, C_AuctionHouse.SendSearchQuery, candidate.searchKey, SORTS, true)
end

-- Listings of other sellers below vendor price go into the scan's finds.
local function ReadCommodity(q, candidate, itemID)
  local sell = candidate.sell
  for i = 1, C_AuctionHouse.GetNumCommoditySearchResults(itemID) or 0 do
    local result = C_AuctionHouse.GetCommoditySearchResultInfo(itemID, i)
    if result then
      local units = result.quantity - (result.numOwnerItems or 0)
      if units > 0 and result.unitPrice < sell then
        q.collector:Judge(itemID, 0, nil, result.unitPrice * units, units, sell)
      end
    end
  end
end

local function ReadItems(q, candidate, itemKey)
  local sell = candidate.sell
  local info = C_AuctionHouse.GetItemKeyInfo(itemKey)
  local name = info and info.itemName
  local variant = PC.OnSale:Variant(itemKey.itemID, name, itemKey.itemSuffix)
  if variant == nil then return end
  -- A row's buyoutAmount is the price of ONE item, and the row stands for `quantity` such items (a screenshot,
  -- 2026-11-24: Blizzard's list showed Small Blue Pouch, which doesn't stack, as "2s 49c, 22"; Blizzard's Buy button
  -- pays one row's buyoutAmount, Blizzard_AuctionHouseFrame.lua). Counted as the row's total, almost every row would
  -- look like a find.
  for i = 1, C_AuctionHouse.GetNumItemSearchResults(itemKey) or 0 do
    local result = C_AuctionHouse.GetItemSearchResultInfo(itemKey, i)
    if result and result.buyoutAmount and not result.containsOwnerItem then
      local quantity = result.quantity or 1
      q.collector:Judge(itemKey.itemID, variant, name, result.buyoutAmount * quantity, quantity, sell)
    end
  end
  local entry = q.collector.keys[itemKey.itemID .. ":" .. variant]
  if entry then entry.itemKey = entry.itemKey or itemKey end
end

-- Either kind of answer is taken for the current candidate, whatever it was expected to be: an answer of the other
-- kind would otherwise only end after ANSWER_TIMEOUT (2026-11-24: the checks took far too long).
for _, event in ipairs({ "COMMODITY_SEARCH_RESULTS_UPDATED", "COMMODITY_SEARCH_RESULTS_ADDED" }) do
  PC:RegisterEvent(event, function(itemID)
    local q = quick
    local candidate = q and q.current
    if not (q and q.phase == "check" and q.waiting and itemID == candidate.row.itemKey.itemID) then return end
    q.waiting = false
    ReadCommodity(q, candidate, itemID)
    q.collector:EndCheck(candidate.entryKey)
    NextCandidate(q)
  end)
end

for _, event in ipairs({ "ITEM_SEARCH_RESULTS_UPDATED", "ITEM_SEARCH_RESULTS_ADDED" }) do
  PC:RegisterEvent(event, function(itemKey)
    local q = quick
    local candidate = q and q.current
    if not (q and q.phase == "check" and q.waiting and itemKey and itemKey.itemID == candidate.row.itemKey.itemID) then
      return
    end
    q.waiting = false
    ReadItems(q, candidate, candidate.stackable and itemKey or candidate.searchKey)
    q.collector:EndCheck(candidate.entryKey)
    NextCandidate(q)
  end)
end

function Vendor:QuickScan()
  local blocked = self:QuickScanBlocked()
  if blocked then
    PC:Print("Quick scan: " .. blocked)
    return
  end
  local q = { started = GetTime(), requests = 0, pages = 1, items = 0, skipped = 0, phase = "browse",
    candidates = {}, unloaded = {}, seen = {}, collector = self:NewScanCollector() }
  q.onTimeout = function()
    if q.phase == "browse" then
      Stop("Quick scan: no answer from the Auction House. Try again.")
    else
      q.waiting = false
      q.skipped = q.skipped + 1
      NextCandidate(q)
    end
  end
  quick = q
  PC.OnSale:SetBusy(true)  -- the On Sale watch waits meanwhile, as for the Recipes scan
  Status("Quick scan: reading the AH...")
  Request(q, C_AuctionHouse.SendBrowseQuery, { searchString = "", sorts = {}, filters = {}, itemClassFilters = {} })
end

PC:RegisterEvent("AUCTION_HOUSE_CLOSED", function()
  if quick then Stop("Quick scan stopped: the Auction House closed.") end
end)
