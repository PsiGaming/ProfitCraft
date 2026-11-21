-- ProfitCraft: On Sale (FEATURES.md "Version 0.3", DESIGN.md section 13)
-- Watched searches run in turn while the AH is open and the watch is started; every result is compared with its
-- usual price (History.lua) and finds go to one list, which keeps itself up to date. Full scans (Scan.lua) add
-- their finds to the same list. Buying: UI/OnSale.lua.
-- * Searches are stored in Auctionator's text format, read with ProfitCraft's own code (Auctionator 346
--   Source/Search/Advanced.lua, SplitAdvancedSearch: text;category;minItemLevel;maxItemLevel;minLevel;maxLevel;
--   minCraftedLevel;maxCraftedLevel;minPrice;maxPrice;quality;tier;expansion;quantity; text in quotes = exact).
--   ProfitCraft uses text, exact, category, item level, level and quality; quality means "this or better". The
--   other fields are kept unchanged.
-- * Categories are Blizzard's own AuctionCategories (Forever: Blizzard_AuctionHouseUI/Camelot/
--   Blizzard_AuctionData.lua), named by their path ("Armor/Mail"), as Auctionator names them.
-- * One search = C_AuctionHouse.SendBrowseQuery, more pages with RequestMoreBrowseResults until
--   HasFullBrowseResults (at most MAX_PAGES). Results: itemKey (itemID, itemLevel, itemSuffix), minPrice,
--   totalQuantity, containsOwnerItem (Forever API docs). At most one AH request a second (Blizzard: 100 searches a
--   minute); RapidFire and On Sale never run at the same time.
-- * Stackable goods: a result under the On Sale price is checked with one item search (units at or under the price;
--   the crumb limit applies) before it counts.
-- * Anyone else's AH search (Blizzard's window, Auctionator) pauses the watch for MANUAL_PAUSE seconds.

local _, PC = ...

local OnSale = {}
PC.OnSale = OnSale

local FIELDS = 14
local MAX_PAGES = 5
local TASK_TIMEOUT = 10
local MIN_SPACING = 1        -- seconds between two AH requests
local MANUAL_PAUSE = 30
local MAX_RECHECK = 50       -- item keys per re-check of full-scan finds
local MAX_SEARCHES = 30
local GEAR_CLASSES = { [2] = true, [4] = true }  -- Enum.ItemClass Weapon, Armor
-- Single items while their data isn't loaded: weapons, armour, bags and recipes (Enum.ItemClass Container 1, Recipe 9;
-- Forever API docs). 0.3.0-0.3.7 counted unloaded recipes as stackable goods (Sylice, 2026-11-21: recipe "finds").
local SINGLE_CLASSES = { [1] = true, [2] = true, [4] = true, [9] = true }
-- A single item with more listings than this at or under its On Sale price is not on sale: the market price fell
-- (Sylice, 2026-11-21: "20x recipes at 8g that used to sell for 40g"). Not for fixed-price searches.
local MAX_CHEAP_LISTINGS = 3
local QUALITY_FILTER_NAMES = { [0] = "PoorQuality", "CommonQuality", "UncommonQuality", "RareQuality", "EpicQuality",
  "LegendaryQuality", "ArtifactQuality" }

local function Settings() return PC.db.settings end
local function Data() return PC.db.onSale end

local function Debug(message)
  if Settings().debug then PC:Print("On Sale: " .. message) end
end

local function Sorts()
  local order = Enum.AuctionHouseSortOrder
  return { { sortOrder = order and order.Price or 0, reverseSort = false } }
end

---------------------------------------------------------------------------
-- Search terms (Auctionator's text format)
---------------------------------------------------------------------------

local function Split(text)
  local parts = {}
  for field in ((text or "") .. ";"):gmatch("(.-);") do parts[#parts + 1] = field end
  for i = #parts + 1, FIELDS do parts[i] = "" end
  return parts
end

local function Number(value)
  value = tonumber(value)
  if value == 0 then return nil end
  return value
end

-- A search term as a table: text, exact, category, minItemLevel, maxItemLevel, minLevel, maxLevel, quality (minimum),
-- and parts (all fields, so the ones ProfitCraft doesn't use survive an edit).
function OnSale:Parse(term)
  local parts = Split(term)
  local text = strtrim(parts[1] or "")
  local exact = text:match('^"(.*)"$')
  local quality = tonumber(parts[11])
  return {
    text = exact or text,
    exact = exact ~= nil,
    category = strtrim(parts[2] or ""),
    minItemLevel = Number(parts[3]),
    maxItemLevel = Number(parts[4]),
    minLevel = Number(parts[5]),
    maxLevel = Number(parts[6]),
    quality = quality,
    parts = parts,
  }
end

local function NumberText(value) return value and tostring(value) or "" end

-- Back to the text format (the inverse of Parse).
function OnSale:Compose(search)
  local parts = {}
  for i = 1, FIELDS do parts[i] = (search.parts and search.parts[i]) or "" end
  local text = strtrim(search.text or "")
  parts[1] = (search.exact and text ~= "") and ('"' .. text .. '"') or text
  parts[2] = search.category or ""
  parts[3], parts[4] = NumberText(search.minItemLevel), NumberText(search.maxItemLevel)
  parts[5], parts[6] = NumberText(search.minLevel), NumberText(search.maxLevel)
  parts[11] = search.quality and tostring(search.quality) or ""
  return table.concat(parts, ";")
end

local function Range(label, min, max)
  if min and max then return label .. " " .. (min == max and min or (min .. "-" .. max)) end
  if min then return label .. " " .. min .. "+" end
  if max then return label .. " up to " .. max end
end

function OnSale:QualityName(quality)
  if quality == nil then return nil end
  return _G["ITEM_QUALITY" .. quality .. "_DESC"] or ("quality " .. quality)
end

-- "\"of the Knight\", Armor/Mail, level 20-30, Uncommon+"
function OnSale:Describe(term)
  local s = type(term) == "table" and term or self:Parse(term)
  local pieces = {}
  if s.text ~= "" then pieces[#pieces + 1] = s.exact and ('"' .. s.text .. '" (exact)') or ('"' .. s.text .. '"') end
  if s.category ~= "" then pieces[#pieces + 1] = s.category end
  pieces[#pieces + 1] = Range("level", s.minLevel, s.maxLevel)
  pieces[#pieces + 1] = Range("item level", s.minItemLevel, s.maxItemLevel)
  if s.quality then pieces[#pieces + 1] = self:QualityName(s.quality) .. "+" end
  if #pieces == 0 then return "(empty)" end
  return table.concat(pieces, ", ")
end

-- A search must narrow the AH down: by text or category (Blizzard: browse searches "should not be used to query the
-- entire auction house", Forever API docs).
function OnSale:IsUsable(term)
  local s = type(term) == "table" and term or self:Parse(term)
  return s.text ~= "" or s.category ~= ""
end

function OnSale:GetSearches() return Data().searches end

function OnSale:AddSearch(name, term, group)
  local searches = Data().searches
  if #searches >= MAX_SEARCHES then return nil, "up to " .. MAX_SEARCHES .. " searches" end
  if not self:IsUsable(term) then return nil, "a search needs a text or a category" end
  local search = { id = Data().nextID, name = (name and strtrim(name) ~= "") and strtrim(name) or self:Describe(term),
    term = term, on = true, group = group }
  Data().nextID = Data().nextID + 1
  searches[#searches + 1] = search
  PC:Send("ONSALE_SEARCHES_CHANGED")
  return search
end

function OnSale:RemoveSearch(id)
  local searches = Data().searches
  for i, search in ipairs(searches) do
    if search.id == id then
      table.remove(searches, i)
      break
    end
  end
  PC:Send("ONSALE_SEARCHES_CHANGED")
end

-- Pasted text: one search per line, or Auctionator's list export "ListName^search1^search2" (Auctionator 346
-- Source/Shopping/ImportExport.lua). Returns the number added and the number skipped.
function OnSale:Import(text)
  local added, skipped = 0, 0
  local function Add(term, group)
    term = strtrim(term)
    if term == "" then return end
    if self:AddSearch(nil, term, group) then added = added + 1 else skipped = skipped + 1 end
  end
  for line in (text or ""):gmatch("[^\r\n]+") do
    line = strtrim(line)
    if line:find("^", 1, true) then
      local group, rest = line:match("^([^%^]*)%^(.*)$")
      for term in rest:gmatch("[^%^]+") do Add(term, strtrim(group)) end
    elseif line ~= "" and not line:match("^%*%*") then  -- "**List name" lines of Auctionator's other format
      Add(line)
    end
  end
  return added, skipped
end

---------------------------------------------------------------------------
-- Categories (Blizzard's AuctionCategories; exists once the AH window has loaded)
---------------------------------------------------------------------------

local categoryTree, categoryByPath

function OnSale:GetCategories()
  if categoryTree then return categoryTree, categoryByPath end
  if type(AuctionCategories) ~= "table" or #AuctionCategories == 0 then return {}, {} end
  categoryTree, categoryByPath = {}, {}
  local function Walk(list, prefix, into)
    for _, category in ipairs(list) do
      if type(category) == "table" and category.name then
        local path = prefix .. category.name
        local entry = { path = path, name = category.name, filters = category.filters or {}, children = {} }
        categoryByPath[path] = entry
        into[#into + 1] = entry
        if category.subCategories then Walk(category.subCategories, path .. "/", entry.children) end
      end
    end
  end
  Walk(AuctionCategories, "", categoryTree)
  return categoryTree, categoryByPath
end

local function QualityFilters(quality)
  local filters = {}
  local enum = Enum.AuctionHouseFilter
  if quality == nil or not enum then return filters end
  for q = quality, #QUALITY_FILTER_NAMES do
    local value = enum[QUALITY_FILTER_NAMES[q]]
    if value then filters[#filters + 1] = value end
  end
  return filters
end

-- The browse query for a search, or nil and why not.
function OnSale:BuildQuery(term)
  local s = type(term) == "table" and term or self:Parse(term)
  if not self:IsUsable(s) then return nil, "needs a text or a category" end
  local classFilters = {}
  if s.category ~= "" then
    local _, byPath = self:GetCategories()
    local category = byPath[s.category]
    if not category then return nil, "unknown category \"" .. s.category .. "\"" end
    classFilters = category.filters
  end
  return { searchString = s.text, sorts = Sorts(), minLevel = s.minLevel, maxLevel = s.maxLevel,
    filters = QualityFilters(s.quality), itemClassFilters = classFilters }
end

---------------------------------------------------------------------------
-- Is it on sale?
---------------------------------------------------------------------------

-- Stackable goods are judged by their stack size; while the item data isn't loaded, weapons and armor count as gear
-- and everything else as stackable (no item data is requested for the thousands of items in a scan).
function OnSale:IsStackable(itemID)
  local cached = not C_Item.IsItemDataCachedByID or C_Item.IsItemDataCachedByID(itemID)
  local stack = cached and select(8, C_Item.GetItemInfo(itemID))
  if stack then return stack > 1 end
  local classID = select(6, C_Item.GetItemInfoInstant(itemID))
  return not SINGLE_CLASSES[classID]
end

function OnSale:IsGear(itemID)
  return GEAR_CLASSES[select(6, C_Item.GetItemInfoInstant(itemID))] == true
end

-- The history key's variant: 0, except for weapons and armour, whose random suffix ("of the Knight") changes the price.
-- Those are told apart by their full name in lower case ("engraved cape of the beast"): Forever's item links don't
-- carry the suffix in the suffixID field (0.3-beta.0 read "Engraved Cape of the Beast" as having none, Sylice's scan
-- 2026-11-19). A browse result whose name is unknown or lacks the suffix uses "#<itemSuffix>". nil = can't tell yet.
function OnSale:Variant(itemID, name, itemSuffix)
  if not self:IsGear(itemID) then return 0 end
  if itemSuffix and itemSuffix ~= 0 and (not name or name == C_Item.GetItemInfo(itemID)) then
    return "#" .. itemSuffix
  end
  return name and name:lower() or nil
end

-- How a price is judged: by the search's own rule, else by the settings (full scans, and searches without their own
-- percent or minimum profit). Returns { limit, fixed, minProfit, usual, source, days, net, stackable }, or nil when it
-- can't be judged (a percent rule without a usual price). limit = highest price that counts (per item, or per unit
-- of stackable goods); net = one sold at the usual price after the AH cut.
-- Auctionator's history counts for stackable goods only: for single items (recipes, gear) its daily lows are mostly
-- one seller's asking price (Sylice, 2026-11-21: "a pattern listed for 600g yesterday"); they need 3 days of
-- ProfitCraft's own history.
function OnSale:GetLimit(itemID, variant, search)
  local stackable = self:IsStackable(itemID)
  local usual, source, days = PC.History:GetUsual(itemID, variant, stackable)
  local info = { usual = usual, source = source, days = days, stackable = stackable,
    net = usual and usual * (1 - Settings().ahCut) }
  if search and search.rule == "fixed" then
    if not (search.maxPrice and search.maxPrice > 0) then return nil end
    info.fixed, info.limit = true, search.maxPrice
    return info
  end
  if not usual then return nil end
  local percent = (search and search.percent) or (info.stackable and Settings().onSaleReagent or Settings().onSaleGear)
  info.limit = math.floor(usual * (100 - percent) / 100)  -- whole numbers: usual * (1 - 0.8) is 1999.99.. for 10000
  info.minProfit = (search and search.minProfit) or Settings().onSaleMinProfit
  -- Maximum profit (nil = no limit). Auto: 1.5x the character's gold (Sylice, 2026-11-21: "up to 50% above what the
  -- user's gold balance is").
  local maxProfit = Settings().onSaleMaxProfit
  if maxProfit == -1 then
    info.maxProfit = math.floor(GetMoney() * 1.5)
  elseif maxProfit and maxProfit > 0 then
    info.maxProfit = maxProfit
  end
  return info
end

-- Buying `quantity` for `cost` and selling at the usual price after the AH cut; nil without a usual price.
local function Profit(limit, quantity, cost)
  return limit.net and (limit.net * quantity - cost) or nil
end

-- A fixed price counts as chosen; a percent rule also needs its minimum profit, and no more than the maximum: a
-- bigger "profit" is a price still being found, not a sale (Sylice, 2026-11-21).
local function Worth(limit, profit)
  if limit.fixed then return true end
  if profit == nil or profit < limit.minProfit then return false end
  return limit.maxProfit == nil or profit <= limit.maxProfit
end

-- "at or under 30s" / "65% below usual (setting), min profit 50s"
function OnSale:DescribeRule(search)
  if search and search.rule == "fixed" then
    return "at or under " .. ((search.maxPrice or 0) > 0 and PC:FormatMoney(search.maxPrice) or "(no price set)")
  end
  local percent = search and search.percent and (search.percent .. "%")
    or (Settings().onSaleGear .. "% (gear) / " .. Settings().onSaleReagent .. "% (stackable)")
  local minProfit = search and search.minProfit or Settings().onSaleMinProfit
  return percent .. " below usual, min profit " .. PC:FormatMoney(minProfit)
end

function OnSale:GetSearch(id)
  for _, search in ipairs(Data().searches) do
    if search.id == id then return search end
  end
end

---------------------------------------------------------------------------
-- Finds
---------------------------------------------------------------------------

local hits = {}       -- key -> find
local newCount = 0    -- finds since the watch started

local function Alert()
  if Settings().onSaleSound then PlaySound(SOUNDKIT.RAID_WARNING) end
  if FlashClientIcon then FlashClientIcon() end
end

-- Adds or updates a find. hit: key, itemID, variant, itemKey (nil for gear found by a full scan: looked up by name
-- when clicked), name, price (cheapest, per unit), quantity, cost (of that quantity), profit (nil without a usual
-- price), usual, source, limit (highest price that counts), fixed (a fixed-price search), from (search id or "scan").
function OnSale:AddHit(hit)
  local old = hits[hit.key]
  hit.seen = time()
  if old then
    hit.found = old.found
    hits[hit.key] = hit
  else
    hit.found = time()
    hits[hit.key] = hit
    newCount = newCount + 1
    Alert()
    PC:Send("ONSALE_NEW_FIND", hit)
    Debug(string.format("found %s: %d for %s (usual %s)", hit.name or "?", hit.quantity, PC:FormatMoney(hit.cost),
      PC:FormatMoney(hit.usual)))
  end
  PC:Send("ONSALE_CHANGED")
end

function OnSale:RemoveHit(key)
  if not hits[key] then return end
  hits[key] = nil
  PC:Send("ONSALE_CHANGED")
end

function OnSale:GetHit(key) return hits[key] end

-- Finds: newest first by the minute (a scan's finds all arrive at once), then the biggest profit first, unknown
-- profit (fixed-price finds without history) last (Sylice, 2026-11-19).
function OnSale:GetHits()
  local list = {}
  for _, hit in pairs(hits) do list[#list + 1] = hit end
  table.sort(list, function(a, b)
    local am, bm = math.floor(a.found / 60), math.floor(b.found / 60)
    if am ~= bm then return am > bm end
    if (a.profit ~= nil) ~= (b.profit ~= nil) then return a.profit ~= nil end
    if a.profit and a.profit ~= b.profit then return a.profit > b.profit end
    return a.key < b.key
  end)
  return list
end

local function ClearHits()
  wipe(hits)
  PC:Send("ONSALE_CHANGED")
end

-- The cheapest price of stackable goods that isn't a crumb (a level holding at least the crumb limit's share of all
-- units listed; Prices.lua's rule). levels: { {price, units}, ... } in any order. nil when nothing is listed.
function OnSale:Floor(levels, total)
  table.sort(levels, function(a, b) return a[1] < b[1] end)
  for _, level in ipairs(levels) do
    if level[2] * 100 >= Settings().crumbPercent * total then return level[1] end
  end
  return levels[1] and levels[1][1]
end

-- More than this share of what's listed under the On Sale price = the market moved, not a sale (Sylice's first scan,
-- 2026-11-19: prices fell since launch, so half the AH looked "on sale" against older daily prices).
local MARKET_SHARE = 0.5

-- Finishes the check of a stackable item from its listings (levels: { {unit price, units of other sellers}, ... }).
-- base: the check task (search, name, from).
function OnSale:CheckStackable(itemID, levels, base)
  local search = base and base.search
  local limit = self:GetLimit(itemID, 0, search)
  local key = PC.History:Key(itemID, 0)
  if not limit then
    self:RemoveHit(key)
    return
  end
  local total, cheap, cost, cheapest = 0, 0, 0, nil
  for _, level in ipairs(levels) do
    total = total + level[2]
    if level[1] <= limit.limit then
      cheap, cost = cheap + level[2], cost + level[1] * level[2]
      cheapest = cheapest and math.min(cheapest, level[1]) or level[1]
    end
  end
  PC.History:Record(itemID, 0, OnSale:Floor(levels, total))
  local profit = Profit(limit, cheap, cost)
  -- A fixed price is taken as given; a percent rule ignores crumbs and a market that moved as a whole.
  local real = cheap > 0 and (limit.fixed
    or (cheap * 100 >= Settings().crumbPercent * total and cheap <= total * MARKET_SHARE))
  if real and Worth(limit, profit) then
    self:AddHit({ key = key, itemID = itemID, variant = 0, itemKey = C_AuctionHouse.MakeItemKey(itemID),
      name = (base and base.name) or PC.Items:GetName(itemID), price = cheapest, quantity = cheap, cost = cost,
      profit = profit, usual = limit.usual, source = limit.source, limit = limit.limit, fixed = limit.fixed,
      from = base and base.from or "scan" })
  else
    self:RemoveHit(key)
  end
end

---------------------------------------------------------------------------
-- The watch: searches in turn
---------------------------------------------------------------------------

local running, generation = false, 0
local queue = {}          -- checks of stackable finds, done before the next search
local current             -- the AH request being answered
local searchIndex = 0
local pausedUntil = 0
local busy = false        -- the buy dialog is open
local ownCall = false     -- set while ProfitCraft itself sends an AH request

local function Active()
  local list = {}
  for _, search in ipairs(Data().searches) do
    if search.on then list[#list + 1] = search end
  end
  return list
end

function OnSale:IsRunning() return running end
function OnSale:GetNewCount() return newCount end
function OnSale:IsPaused() return running and (GetTime() < pausedUntil or busy) end

-- AH requests made by ProfitCraft are marked, so the hooks below can tell them from anyone else's.
local function Send(fn, ...)
  ownCall = true
  local ok, err = pcall(fn, ...)
  ownCall = false
  if not ok then error(err, 0) end
end
OnSale.Send = Send

local Tick

local function ScheduleNext(delay)
  local myGeneration = generation
  C_Timer.After(delay, function() PC:Call("on sale", Tick, myGeneration) end)
end

local function EndTask(task)
  if current ~= task then return end
  current = nil
  ScheduleNext(#queue > 0 and MIN_SPACING or Settings().onSaleInterval)
end

local function QueueCheck(itemID, name, from, search)
  for _, task in ipairs(queue) do
    if task.itemID == itemID then return end
  end
  queue[#queue + 1] = { kind = "verify", itemID = itemID, name = name, from = from, search = search }
end

-- A single item listed more than MAX_CHEAP_LISTINGS times: its listings are counted (one item search) before it counts.
local function QueueItemCheck(itemKey, variant, name, from, search)
  for _, task in ipairs(queue) do
    if task.itemID == itemKey.itemID and task.variant == variant then return end
  end
  queue[#queue + 1] = { kind = "verifyItem", itemID = itemKey.itemID, itemKey = itemKey, variant = variant, name = name,
    from = from, search = search }
end

-- Reads the results of a finished browse request (a search, or a re-check of earlier finds).
local function ReadBrowse(task)
  local search = task.search
  local parsed = search and OnSale:Parse(search.term)
  local seen, unsure = {}, false
  for _, row in ipairs(task.results) do
    local itemKey = row.itemKey
    local itemID = itemKey and itemKey.itemID
    if itemID and (itemKey.battlePetSpeciesID or 0) == 0 then
      local info = C_AuctionHouse.GetItemKeyInfo(itemKey)
      local name = info and info.itemName
      local itemLevel = (itemKey.itemLevel or 0) > 0 and itemKey.itemLevel or select(4, C_Item.GetItemInfo(itemID))
      local matches = true
      if parsed then
        if parsed.text ~= "" then
          if not name then
            matches, unsure = false, true  -- name not loaded yet: decided next time
          elseif parsed.exact then
            matches = name:lower() == parsed.text:lower()
          else
            matches = name:lower():find(parsed.text:lower(), 1, true) ~= nil
          end
        end
        if itemLevel and ((parsed.minItemLevel and itemLevel < parsed.minItemLevel)
          or (parsed.maxItemLevel and itemLevel > parsed.maxItemLevel)) then
          matches = false
        end
      end
      local variant = matches and OnSale:Variant(itemID, name, itemKey.itemSuffix)
      if matches and variant == nil then unsure = true end
      if matches and variant ~= nil then
        local key = PC.History:Key(itemID, variant)
        seen[key] = true
        local hit = hits[key]
        local rule = search or (hit and OnSale:GetSearch(hit.from))
        local limit = OnSale:GetLimit(itemID, variant, rule)
        local candidate = limit and row.minPrice <= limit.limit and not row.containsOwnerItem
        -- A stackable candidate's price is recorded after its unit check, without crumbs.
        if not row.containsOwnerItem and not (candidate and limit.stackable) then
          PC.History:Record(itemID, variant, row.minPrice)
        end
        local from = search and search.id or (hit and hit.from) or "scan"
        if limit and row.minPrice <= limit.limit and not row.containsOwnerItem then
          if limit.stackable then
            -- unchanged price: keep the find; else count the units first
            if not (hit and hit.price == row.minPrice) then QueueCheck(itemID, name, from, rule) end
          elseif not limit.fixed and (row.totalQuantity or 0) > MAX_CHEAP_LISTINGS then
            -- more listed than may be cheap: count those at or under the price first
            if not (hit and hit.price == row.minPrice) then QueueItemCheck(itemKey, variant, name, from, rule) end
          else
            local profit = Profit(limit, 1, row.minPrice)
            if Worth(limit, profit) then
              OnSale:AddHit({ key = key, itemID = itemID, variant = variant, itemKey = itemKey,
                name = name or PC.Items:GetName(itemID), price = row.minPrice, quantity = 1,
                cost = row.minPrice, profit = profit, usual = limit.usual, source = limit.source,
                limit = limit.limit, fixed = limit.fixed, from = from })
            else
              OnSale:RemoveHit(key)
            end
          end
        elseif hit then
          OnSale:RemoveHit(key)
        end
      end
    end
  end
  -- Finds of this search (or these re-checked keys) missing from complete results are gone.
  if task.complete and not unsure then
    for key, hit in pairs(hits) do
      local covered = (search and hit.from == search.id) or (task.keys and task.keys[key])
      if covered and not seen[key] then OnSale:RemoveHit(key) end
    end
  end
  Debug(string.format("%s: %d results%s", search and search.name or "re-check", #task.results,
    task.complete and "" or " (incomplete)"))
end

local function FinishBrowse(task, complete)
  if current ~= task then return end
  task.complete = complete
  PC:Call("on sale results", ReadBrowse, task)
  EndTask(task)
end

-- Asks for the next page, or finishes.
local function ContinueBrowse(task)
  if C_AuctionHouse.HasFullBrowseResults() then
    FinishBrowse(task, true)
  elseif task.pages >= MAX_PAGES then
    FinishBrowse(task, false)
  else
    task.pages = task.pages + 1
    C_Timer.After(MIN_SPACING, function()
      if current ~= task then return end
      task.waiting = true
      Send(C_AuctionHouse.RequestMoreBrowseResults)
    end)
  end
end

local function StartTask(task)
  current = task
  task.started = GetTime()
  C_Timer.After(TASK_TIMEOUT, function()
    if current ~= task then return end
    Debug("no answer from the Auction House in " .. TASK_TIMEOUT .. " s, moving on")
    if task.kind == "browse" then FinishBrowse(task, false) else EndTask(task) end
  end)
  if task.kind == "verify" then
    Send(C_AuctionHouse.SendSearchQuery, C_AuctionHouse.MakeItemKey(task.itemID), Sorts(), true)
  elseif task.kind == "verifyItem" then
    Send(C_AuctionHouse.SendSearchQuery, task.itemKey, Sorts(), true)
  elseif task.keys then
    local list = {}
    for _, hit in pairs(hits) do
      if task.keys[hit.key] then list[#list + 1] = hit.itemKey end
    end
    task.waiting = true
    Send(C_AuctionHouse.SearchForItemKeys, list, Sorts())
  else
    task.waiting = true
    Send(C_AuctionHouse.SendBrowseQuery, task.query)
  end
end

-- Finds no running search covers (full-scan finds of stackable goods, finds of switched-off searches) are re-checked
-- once per round. Gear found by a full scan has no item key (its suffix isn't known), so it isn't re-checked.
local function RecheckTask()
  local keys, count = {}, 0
  local active = {}
  for _, search in ipairs(Active()) do active[search.id] = true end
  for key, hit in pairs(hits) do
    if hit.itemKey and not active[hit.from] and count < MAX_RECHECK then
      keys[key] = true
      count = count + 1
    end
  end
  if count == 0 then return nil end
  return { kind = "browse", keys = keys, results = {}, pages = 1 }
end

function Tick(myGeneration)
  if myGeneration ~= generation or not running or current then return end
  if OnSale:IsPaused() then
    ScheduleNext(MIN_SPACING)
    return
  end
  local task = table.remove(queue, 1)
  if not task then
    local active = Active()
    if #active == 0 then
      OnSale:Stop("no search switched on.")
      return
    end
    searchIndex = searchIndex + 1
    if searchIndex > #active then
      searchIndex = 0
      task = RecheckTask()
      if not task then searchIndex = 1 end
    end
    if not task then
      local search = active[searchIndex]
      local query, why = OnSale:BuildQuery(search.term)
      if not query then
        Debug(search.name .. " skipped: " .. why)
        ScheduleNext(MIN_SPACING)
        return
      end
      task = { kind = "browse", search = search, query = query, results = {}, pages = 1 }
    end
  end
  PC:Send("ONSALE_STATUS")
  StartTask(task)
end

PC:RegisterEvent("AUCTION_HOUSE_BROWSE_RESULTS_UPDATED", function()
  local task = current
  if not (task and task.kind == "browse" and task.waiting) then return end
  task.waiting = false
  task.results = C_AuctionHouse.GetBrowseResults() or {}
  ContinueBrowse(task)
end)

PC:RegisterEvent("AUCTION_HOUSE_BROWSE_RESULTS_ADDED", function(added)
  local task = current
  if not (task and task.kind == "browse" and task.waiting) then return end
  task.waiting = false
  for _, row in ipairs(added or {}) do task.results[#task.results + 1] = row end
  ContinueBrowse(task)
end)

PC:RegisterEvent("AUCTION_HOUSE_BROWSE_FAILURE", function()
  local task = current
  if task and task.kind == "browse" then
    Debug("the Auction House refused the search")
    FinishBrowse(task, false)
  end
end)

local function ReadCommodity(itemID)
  local task = current
  if not (task and task.kind == "verify" and task.itemID == itemID) then return end
  local levels = {}
  for i = 1, C_AuctionHouse.GetNumCommoditySearchResults(itemID) or 0 do
    local result = C_AuctionHouse.GetCommoditySearchResultInfo(itemID, i)
    if result then
      local units = result.quantity - (result.numOwnerItems or 0)
      if units > 0 then levels[#levels + 1] = { result.unitPrice, units } end
    end
  end
  PC:Call("on sale check", OnSale.CheckStackable, OnSale, itemID, levels, task)
  EndTask(task)
end

for _, event in ipairs({ "COMMODITY_SEARCH_RESULTS_UPDATED", "COMMODITY_SEARCH_RESULTS_ADDED" }) do
  PC:RegisterEvent(event, ReadCommodity)
end

-- Finishes the check of a single item from its listings: { buyout, ... } of other sellers.
function OnSale:CheckItem(task, prices)
  local key = PC.History:Key(task.itemID, task.variant)
  local limit = self:GetLimit(task.itemID, task.variant, task.search)
  local cheap, cheapest = 0, nil
  for _, price in ipairs(prices) do
    if limit and price <= limit.limit then
      cheap = cheap + 1
      cheapest = cheapest and math.min(cheapest, price) or price
    end
  end
  local profit = cheapest and Profit(limit, 1, cheapest)
  local real = cheap > 0 and cheap <= MAX_CHEAP_LISTINGS and cheap <= #prices * MARKET_SHARE
  if real and Worth(limit, profit) then
    self:AddHit({ key = key, itemID = task.itemID, variant = task.variant, itemKey = task.itemKey,
      name = task.name or PC.Items:GetName(task.itemID), price = cheapest, quantity = 1, cost = cheapest,
      profit = profit, usual = limit.usual, source = limit.source, limit = limit.limit, fixed = limit.fixed,
      from = task.from })
  else
    self:RemoveHit(key)
  end
end

local function ReadItemListings(itemKey)
  local task = current
  if not (task and task.kind == "verifyItem" and itemKey and itemKey.itemID == task.itemID) then return end
  local prices = {}
  for i = 1, C_AuctionHouse.GetNumItemSearchResults(task.itemKey) or 0 do
    local result = C_AuctionHouse.GetItemSearchResultInfo(task.itemKey, i)
    if result and result.buyoutAmount and not result.containsOwnerItem then prices[#prices + 1] = result.buyoutAmount end
  end
  PC:Call("on sale check", OnSale.CheckItem, OnSale, task, prices)
  EndTask(task)
end

for _, event in ipairs({ "ITEM_SEARCH_RESULTS_UPDATED", "ITEM_SEARCH_RESULTS_ADDED" }) do
  PC:RegisterEvent(event, ReadItemListings)
end

function OnSale:Start()
  if running then return end
  if not Settings().onSaleEnabled then
    PC:Print("On Sale: the On Sale Finder is off (Settings > On Sale).")
    return
  end
  if #Active() == 0 then
    PC:Print("On Sale: switch on at least one search first.")
    return
  end
  if PC.Rapid and PC.Rapid:IsRunning() then PC.Rapid:Stop("On Sale started (only one can search at a time).") end
  running = true
  newCount = 0
  searchIndex = 0
  generation = generation + 1
  if C_CVar.GetCVar("Sound_EnableSoundWhenGameIsInBG") == "0" and Settings().onSaleSound then
    PC:Print("On Sale: Blizzard's \"Sound in Background\" is off (Options > Audio), so you won't hear finds "
      .. "while the game is in the background.")
  end
  PC:Send("ONSALE_STATUS")
  Tick(generation)
end

function OnSale:Stop(reason)
  if not running then return end
  running = false
  generation = generation + 1
  current = nil
  wipe(queue)
  PC:Send("ONSALE_STATUS")
  if reason then PC:Print("On Sale stopped: " .. reason) end
end

-- The buy dialog pauses the searches (its own search must stay the AH's current one); a request of the watch still
-- waiting for its answer is dropped, so the two answers can't mix.
function OnSale:SetBusy(value)
  busy = value and true or false
  if busy and current then
    current = nil
    ScheduleNext(MIN_SPACING)
  end
  if not busy then pausedUntil = math.max(pausedUntil, GetTime() + MIN_SPACING) end
end

function OnSale:GetStatus()
  local active = #Active()
  if not running then return "Stopped." end
  local cycle = active * Settings().onSaleInterval
  local state = OnSale:IsPaused() and (busy and "paused while buying" or "paused: someone else searched")
    or string.format("%d searches, each every %s", active, cycle >= 60 and (math.floor(cycle / 60) .. " m "
      .. (cycle % 60 > 0 and (cycle % 60) .. " s" or "")) or (cycle .. " s"))
  return "On Sale: " .. state
end

-- Anyone else's AH search (Blizzard's window, Auctionator, ...) pauses the watch and drops the request in flight,
-- whose answer would be mixed up with theirs.
local hooked = false
local function HookSearches()
  if hooked then return end
  hooked = true
  for _, name in ipairs({ "SendBrowseQuery", "SendSearchQuery", "SearchForItemKeys", "SearchForFavorites",
    "SendSellSearchQuery" }) do
    if type(C_AuctionHouse[name]) == "function" then
      hooksecurefunc(C_AuctionHouse, name, function()
        if ownCall or not running then return end
        pausedUntil = GetTime() + MANUAL_PAUSE
        if current then
          current = nil
          ScheduleNext(MANUAL_PAUSE)
        end
        PC:Send("ONSALE_STATUS")
      end)
    end
  end
end

PC:RegisterEvent("AUCTION_HOUSE_SHOW", HookSearches)

-- Switched off: stop the watch and drop the finds.
PC:Listen("SETTINGS_CHANGED", function(key, value)
  if key == "onSaleEnabled" and not value then
    OnSale:Stop()
    ClearHits()
  end
end)

PC:RegisterEvent("AUCTION_HOUSE_CLOSED", function()
  OnSale:Stop()
  wipe(queue)
  busy, pausedUntil = false, 0
  ClearHits()
end)

---------------------------------------------------------------------------
-- Full scans (called by Scan.lua for every listing of other sellers)
---------------------------------------------------------------------------

local Collector = {}
Collector.__index = Collector

function OnSale:NewScanCollector()
  return setmetatable({ keys = {}, gear = {} }, Collector)
end

function Collector:Add(index, itemID, unitPrice, count, name)
  local gear = self.gear[itemID]
  if gear == nil then
    gear = OnSale:IsGear(itemID)
    self.gear[itemID] = gear
  end
  if name == "" then name = nil end  -- the scan gives "" for items whose data isn't loaded yet
  local variant = 0
  if gear then
    if not name then
      local link = C_AuctionHouse.GetReplicateItemLink(index)
      name = link and link:match("|h%[(.-)%]|h")
    end
    if not name or name == "" then return end  -- suffix unknown: left out
    variant = name:lower()
  end
  local key = itemID .. ":" .. variant
  local entry = self.keys[key]
  if not entry then
    entry = { itemID = itemID, variant = variant, min = unitPrice, units = 0, listings = 0, cheap = 0, levels = {},
      cheapListings = 0, cheapCost = 0, name = name, limit = OnSale:GetLimit(itemID, variant) or false }
    self.keys[key] = entry
  end
  entry.name = entry.name or name
  if unitPrice < entry.min then entry.min = unitPrice end
  if not gear then entry.levels[unitPrice] = (entry.levels[unitPrice] or 0) + count end
  entry.units = entry.units + count
  entry.listings = entry.listings + 1
  if entry.limit and unitPrice <= entry.limit.limit then
    entry.cheap = entry.cheap + count
    entry.cheapListings = entry.cheapListings + 1
    entry.cheapCost = entry.cheapCost + unitPrice * count
    if not entry.cheapest or unitPrice < entry.cheapest then entry.cheapest = unitPrice end
  end
end

-- After the scan: history for every item seen, finds into the list.
function Collector:Finish()
  local found = 0
  for key, entry in pairs(self.keys) do
    local price = entry.min
    if next(entry.levels) then
      local levels = {}
      for levelPrice, units in pairs(entry.levels) do levels[#levels + 1] = { levelPrice, units } end
      price = OnSale:Floor(levels, entry.units)
    end
    PC.History:Record(entry.itemID, entry.variant, price)
    local limit = entry.limit
    if limit and entry.cheap > 0 then
      local quantity, cost, real
      if limit.stackable then
        quantity, cost = entry.cheap, entry.cheapCost
        real = entry.cheap * 100 >= Settings().crumbPercent * entry.units and entry.cheap <= entry.units * MARKET_SHARE
      else
        quantity, cost = 1, entry.cheapest
        real = entry.cheapListings <= MAX_CHEAP_LISTINGS
          and (entry.listings < 3 or entry.cheapListings <= entry.listings * MARKET_SHARE)
      end
      local profit = Profit(limit, quantity, cost)
      if real and Worth(limit, profit) then
        OnSale:AddHit({ key = key, itemID = entry.itemID, variant = entry.variant,
          itemKey = limit.stackable and C_AuctionHouse.MakeItemKey(entry.itemID) or nil, name = entry.name,
          price = entry.cheapest, quantity = quantity, cost = cost, profit = profit, usual = limit.usual,
          source = limit.source, limit = limit.limit, from = "scan" })
        found = found + 1
      end
    end
  end
  if found > 0 then PC:Print(string.format("On Sale: %d find%s in the full scan.", found, found == 1 and "" or "s")) end
end
