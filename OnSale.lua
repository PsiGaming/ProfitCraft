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
	return not GEAR_CLASSES[classID]
end

function OnSale:IsGear(itemID)
	return GEAR_CLASSES[select(6, C_Item.GetItemInfoInstant(itemID))] == true
end

-- The On Sale price for an item (+ suffix): { usual, source, days, limit, net, stackable }, or nil without a usual
-- price. limit = highest price that is on sale; net = what one sells for at the usual price after the AH cut.
function OnSale:GetLimit(itemID, suffix)
	local usual, source, days = PC.History:GetUsual(itemID, suffix)
	if not usual then return nil end
	local stackable = self:IsStackable(itemID)
	local discount = stackable and Settings().onSaleReagent or Settings().onSaleGear
	return { usual = usual, source = source, days = days, stackable = stackable,
		limit = math.floor(usual * (1 - discount / 100)), net = usual * (1 - Settings().ahCut) }
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

-- Adds or updates a find. hit: key, itemID, suffix, itemKey, name, price (cheapest, per unit), quantity, cost (of
-- that quantity), profit, usual, source, from (search id, or "scan").
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

-- Finds, newest first.
function OnSale:GetHits()
	local list = {}
	for _, hit in pairs(hits) do list[#list + 1] = hit end
	table.sort(list, function(a, b)
		if a.found ~= b.found then return a.found > b.found end
		return a.key < b.key
	end)
	return list
end

local function ClearHits()
	wipe(hits)
	PC:Send("ONSALE_CHANGED")
end

-- Finishes the check of a stackable item from its listings (levels: { {unit price, units of other sellers}, ... }).
function OnSale:CheckStackable(itemID, levels, base)
	local limit = self:GetLimit(itemID, 0)
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
	local profit = limit.net * cheap - cost
	if cheap > 0 and cheap * 100 >= Settings().crumbPercent * total and profit >= Settings().onSaleMinProfit then
		self:AddHit({ key = key, itemID = itemID, suffix = 0, itemKey = C_AuctionHouse.MakeItemKey(itemID),
			name = (base and base.name) or PC.Items:GetName(itemID), price = cheapest, quantity = cheap, cost = cost,
			profit = profit, usual = limit.usual, source = limit.source, from = base and base.from or "scan" })
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

local function QueueCheck(itemID, name, from)
	for _, task in ipairs(queue) do
		if task.itemID == itemID then return end
	end
	queue[#queue + 1] = { kind = "verify", itemID = itemID, name = name, from = from }
end

-- Reads the results of a finished browse request (a search, or a re-check of full-scan finds).
local function ReadBrowse(task)
	local search = task.search
	local parsed = search and OnSale:Parse(search.term)
	local seen, unsure = {}, false
	for _, row in ipairs(task.results) do
		local itemKey = row.itemKey
		local itemID = itemKey and itemKey.itemID
		if itemID and (itemKey.battlePetSpeciesID or 0) == 0 then
			local suffix = itemKey.itemSuffix or 0
			local key = PC.History:Key(itemID, suffix)
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
			if matches then
				seen[key] = true
				local limit = OnSale:GetLimit(itemID, suffix)
				if not row.containsOwnerItem then PC.History:Record(itemID, suffix, row.minPrice) end
				local hit = hits[key]
				if limit and row.minPrice <= limit.limit and not row.containsOwnerItem then
					if limit.stackable then
						-- unchanged price: keep the find; else count the units first
						if not (hit and hit.price == row.minPrice) then
							QueueCheck(itemID, name, search and search.id or (hit and hit.from) or "scan")
						end
					else
						local profit = limit.net - row.minPrice
						if profit >= Settings().onSaleMinProfit then
							OnSale:AddHit({ key = key, itemID = itemID, suffix = suffix, itemKey = itemKey,
								name = name or PC.Items:GetName(itemID), price = row.minPrice, quantity = 1,
								cost = row.minPrice, profit = profit, usual = limit.usual, source = limit.source,
								from = search and search.id or (hit and hit.from) or "scan" })
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

-- Full-scan finds no search covers are re-checked once per round.
local function RecheckTask()
	local keys, count = {}, 0
	local active = {}
	for _, search in ipairs(Active()) do active[search.id] = true end
	for key, hit in pairs(hits) do
		if not active[hit.from] and count < MAX_RECHECK then
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

function OnSale:Start()
	if running then return end
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

-- The buy dialog pauses the searches (its own search must stay the AH's current one).
function OnSale:SetBusy(value)
	busy = value and true or false
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

-- Classic-style item string: item:itemID:enchant:gem1:gem2:gem3:gem4:suffixID:... (the field Auctionator reads for
-- suffixes on the old AH, Source/Utilities/DBKeyFromLink.lua). How Forever's links carry the suffix: to check.
local function SuffixFromLink(link)
	local suffix = link and link:match("item:%-?%d+:[^:]*:[^:]*:[^:]*:[^:]*:[^:]*:(%-?%d+)")
	return tonumber(suffix) or 0
end
OnSale.SuffixFromLink = SuffixFromLink

function Collector:Add(index, itemID, unitPrice, count, name)
	local gear = self.gear[itemID]
	if gear == nil then
		gear = OnSale:IsGear(itemID)
		self.gear[itemID] = gear
	end
	local suffix, link = 0, nil
	if gear then
		link = C_AuctionHouse.GetReplicateItemLink(index)
		if not link then return end  -- suffix unknown: left out
		suffix = SuffixFromLink(link)
	end
	local key = itemID .. ":" .. suffix
	local entry = self.keys[key]
	if not entry then
		entry = { itemID = itemID, suffix = suffix, min = unitPrice, units = 0, cheap = 0, cheapCost = 0, name = name,
			link = link, limit = OnSale:GetLimit(itemID, suffix) or false }
		self.keys[key] = entry
	end
	if unitPrice < entry.min then entry.min = unitPrice end
	entry.units = entry.units + count
	if entry.limit and unitPrice <= entry.limit.limit then
		entry.cheap = entry.cheap + count
		entry.cheapCost = entry.cheapCost + unitPrice * count
		if not entry.cheapest or unitPrice < entry.cheapest then
			entry.cheapest = unitPrice
			entry.link = link or entry.link
		end
	end
end

-- After the scan: history for every item seen, finds into the list.
function Collector:Finish()
	local found = 0
	for key, entry in pairs(self.keys) do
		PC.History:Record(entry.itemID, entry.suffix, entry.min)
		local limit = entry.limit
		if limit and entry.cheap > 0 then
			local quantity, cost, profit
			if limit.stackable then
				quantity, cost = entry.cheap, entry.cheapCost
				profit = limit.net * quantity - cost
				if entry.cheap * 100 < Settings().crumbPercent * entry.units then profit = -1 end
			else
				quantity, cost = 1, entry.cheapest
				profit = limit.net - cost
			end
			if profit >= Settings().onSaleMinProfit then
				local itemLevel = 0
				if not limit.stackable and entry.link and C_Item.GetDetailedItemLevelInfo then
					itemLevel = C_Item.GetDetailedItemLevelInfo(entry.link) or 0
				end
				OnSale:AddHit({ key = key, itemID = entry.itemID, suffix = entry.suffix,
					itemKey = C_AuctionHouse.MakeItemKey(entry.itemID, itemLevel, entry.suffix), name = entry.name,
					price = entry.cheapest, quantity = quantity, cost = cost, profit = profit, usual = limit.usual,
					source = limit.source, from = "scan" })
				found = found + 1
			end
		end
	end
	if found > 0 then PC:Print(string.format("On Sale: %d find%s in the full scan.", found, found == 1 and "" or "s")) end
end
