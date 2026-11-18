-- ProfitCraft: RapidFire (watch list & quick buy; FEATURES.md "RapidFire: watch list & quick buy")
-- While the AH is open and RapidFire runs, the watched reagents are searched in turn (C_AuctionHouse.SendSearchQuery;
-- Blizzard allows 100 searches a minute, Forever API docs). Each item is searched every `interval` seconds, but at
-- least as many seconds as items are active (Sylice, 2026-11-17), so at most one search a second. The AH also pushes
-- changes to open searches (COMMODITY_SEARCH_RESULTS_UPDATED).
-- When units at or under an item's max price are listed, a popup offers them; while it shows, only that item is
-- searched (every second), so the AH's current search is the item being bought, as when buying through Blizzard's
-- own window. The buy key (default Space) clicks Buy only while the popup shows (SetOverrideBindingClick).
-- Buying: StartCommoditiesPurchase(itemID, quantity) straight from the click, as Auctionator calls it; then
-- COMMODITY_PRICE_UPDATED and ConfirmCommoditiesPurchase (Blizzard's buy dialog does the same, Forever source:
-- Blizzard_AuctionHouseUI/Shared/Blizzard_AuctionHouseBuyDialog.lua). Starting needs the player's key press or click (HasRestrictions, Forever docs).
-- The quantity is taken from the live listings at that moment, capped by the money to keep; the quote must not
-- exceed the expected cost of exactly those units, else it is cancelled. No quote within QUOTE_TIMEOUT or no result
-- within RESULT_TIMEOUT: cancelled, scanning goes on. A Blizzard block (ADDON_ACTION_BLOCKED/FORBIDDEN) is reported.
-- Short-term history: the cheapest price at each check, last HISTORY_SECONDS, in memory only.
-- Stackable goods only (bought by quantity); the player's own units are left out (numOwnerItems).

local ADDON_NAME, PC = ...

local Rapid = {}
PC.Rapid = Rapid

local MAX_ITEMS = 10
local FLASH_SECONDS = 1.5
local FOCUS_SPACING = 1         -- seconds between searches of the item the popup offers
local QUOTE_TIMEOUT = 5
local RESULT_TIMEOUT = 10
local HISTORY_SECONDS = 15 * 60
local HISTORY_BARS = 60
local INTERVALS = { 1, 3, 5, 10, 30, 60, 300 }
local ROW_HEIGHT = 24
local BUY_BUTTON_NAME = "ProfitCraftRapidFireBuy"
local SORT_BY_PRICE = { { sortOrder = Enum.AuctionHouseSortOrder and Enum.AuctionHouseSortOrder.Price or 0, reverseSort = false } }

local panel, historyPanel, toggleButton, popup, buyButton, statusText, startButton, idBox, keyButton, keepInput
local intervalSlider
local rows = {}
local running, generation, queueIndex, lastCheck = false, 0, 0, nil
local listings = {}  -- itemID -> { {unit price, units of other sellers}, ... } cheapest first, from the live search
local history = {}   -- itemID -> { {time, cheapest unit price}, ... } oldest first
local pending        -- the purchase in progress: { itemID, quantity, expected, confirmed, token }
local popupItemID    -- the item the popup offers
local selectedItemID -- the item the history panel shows

local function Data() return PC.db.rapidFire end

local function Debug(message)
	if PC.db.settings.debug then PC:Print("RapidFire: " .. message) end
end

local function Entry(itemID)
	for _, entry in ipairs(Data().items) do
		if entry.itemID == itemID then return entry end
	end
end

local function ActiveItems()
	local list = {}
	for _, entry in ipairs(Data().items) do
		if entry.on then list[#list + 1] = entry end
	end
	return list
end

local function ItemName(itemID)
	return PC.Items:GetName(itemID) or ("item " .. itemID)
end

local function DurationText(seconds)
	if seconds >= 60 then return (seconds / 60) .. " m" end
	return seconds .. " s"
end

-- What buying now gets: units at or under the max, cheapest first, as many as the money above the amount to keep
-- pays for. Returns quantity and total cost (0, 0 when nothing).
function Rapid:GetDeal(itemID)
	local entry, levels = Entry(itemID), listings[itemID]
	if not (entry and entry.on and levels and (entry.max or 0) > 0) then return 0, 0 end
	local budget = GetMoney() - Data().minBalance
	local quantity, total = 0, 0
	for _, level in ipairs(levels) do
		local price, available = level[1], level[2]
		if price > entry.max then break end
		local take = math.min(available, math.floor((budget - total) / price))
		if take <= 0 then break end
		quantity, total = quantity + take, total + take * price
		if take < available then break end
	end
	return quantity, total
end

-- Seconds between each item's checks: the chosen interval, but at least one second per active item.
function Rapid:GetEffectiveInterval(count)
	return math.max(Data().interval, count or #ActiveItems())
end

-- Seconds between two searches.
function Rapid:GetSpacing(count)
	count = math.max(count or #ActiveItems(), 1)
	return self:GetEffectiveInterval(count) / count
end

local function Search(itemID)
	C_AuctionHouse.SendSearchQuery(C_AuctionHouse.MakeItemKey(itemID), SORT_BY_PRICE, true)
	lastCheck = GetTime()
end

---------------------------------------------------------------------------
-- History
---------------------------------------------------------------------------

local function Record(itemID, price)
	local list = history[itemID]
	if not list then
		list = {}
		history[itemID] = list
	end
	local now = GetTime()
	list[#list + 1] = { now, price }
	while list[1] and list[1][1] < now - HISTORY_SECONDS do table.remove(list, 1) end
end

-- now, average, lowest (and when), highest, trend ("up"/"down"/"flat"), number of checks; nil without data.
function Rapid:GetHistoryStats(itemID)
	local list = history[itemID]
	if not list or #list == 0 then return nil end
	local sum, low, lowTime, high = 0, math.huge, nil, 0
	for _, point in ipairs(list) do
		sum = sum + point[2]
		if point[2] < low then low, lowTime = point[2], point[1] end
		if point[2] > high then high = point[2] end
	end
	local quarter = math.max(1, math.floor(#list / 4))
	local first, last = 0, 0
	for i = 1, quarter do
		first = first + list[i][2]
		last = last + list[#list - quarter + i][2]
	end
	local change = (last - first) / first
	local trend = change > 0.02 and "up" or (change < -0.02 and "down" or "flat")
	return { now = list[#list][2], average = sum / #list, low = low, lowAgo = GetTime() - lowTime, high = high,
		trend = trend, checks = #list }
end

-- The chart's bars: bar index (1 = oldest, HISTORY_BARS = now) -> the lowest price checked in that bar's time slot.
-- Slots are fixed to the clock (every check stays in its slot for good); counting them back from "now" made checks
-- slide between neighbouring bars, so bars jumped up and back (Sylice, 2026-11-17). Only the newest bar changes.
function Rapid:GetHistoryBars(itemID)
	local slotLength = HISTORY_SECONDS / HISTORY_BARS
	local current = math.floor(GetTime() / slotLength)
	local bars = {}
	for _, point in ipairs(history[itemID] or {}) do
		local index = HISTORY_BARS - (current - math.floor(point[1] / slotLength))
		if index >= 1 and index <= HISTORY_BARS and (not bars[index] or point[2] < bars[index]) then
			bars[index] = point[2]
		end
	end
	return bars
end

---------------------------------------------------------------------------
-- Popup
---------------------------------------------------------------------------

local Refresh, UpdateHistoryPanel  -- defined below

local function ClearBinding()
	if popup and not InCombatLockdown() then ClearOverrideBindings(popup) end
end

local function HidePopup()
	popupItemID = nil
	if popup then
		popup.flashing = false
		popup:Hide()
	end
	ClearBinding()
end

local function UpdatePopup()
	local quantity, total = Rapid:GetDeal(popupItemID)
	popup.icon:SetTexture(PC.Items:GetIcon(popupItemID) or 134400)
	popup.title:SetText(ItemName(popupItemID))
	popup.text:SetText(string.format("%d at <= %s  -  total %s", quantity,
		PC:FormatMoney(Entry(popupItemID).max), PC:FormatMoney(total)))
	popup.note:SetText("You keep " .. PC:FormatMoney(GetMoney() - total) .. " (at least "
		.. PC:FormatMoney(Data().minBalance) .. ").")
	buyButton:SetText("BUY  (" .. GetBindingText(Data().key) .. ")")
	buyButton:SetEnabled(pending == nil)
end

local function PlacePopup()
	popup:ClearAllPoints()
	local saved = Data().popupPosition
	if saved then
		popup:SetPoint("CENTER", UIParent, "BOTTOMLEFT", saved.x, saved.y)
	elseif panel and panel:IsShown() then
		popup:SetPoint("BOTTOM", panel, "BOTTOM", 0, 70)
	else
		popup:SetPoint("RIGHT", AuctionHouseFrame, "RIGHT", -20, 0)
	end
end

local Reschedule

local function ShowPopup(itemID)
	popupItemID = itemID
	popup.flashing = false
	UpdatePopup()
	PlacePopup()
	popup:Show()
	if Data().sound then PlaySound(SOUNDKIT.RAID_WARNING) end
	if not InCombatLockdown() then SetOverrideBindingClick(popup, true, Data().key, BUY_BUTTON_NAME) end
	Reschedule()  -- focus the searches on this item
end

-- The next watched item with a deal, if any, gets the popup.
local function OfferNext()
	if popupItemID then return end
	for _, entry in ipairs(ActiveItems()) do
		if Rapid:GetDeal(entry.itemID) > 0 then
			ShowPopup(entry.itemID)
			return
		end
	end
end

-- A short message in the popup ("Opportunity gone", "Bought ..."), then it closes and offers the next deal.
local function Flash(message)
	popup.flashing = true
	popup.text:SetText(message)
	popup.note:SetText("")
	buyButton:SetEnabled(false)
	ClearBinding()
	local shown = popupItemID
	C_Timer.After(FLASH_SECONDS, function()
		if popup.flashing and popupItemID == shown then
			HidePopup()
			Reschedule()  -- back to checking every item
			OfferNext()
		end
	end)
end

-- New listings for an item: update the panels and the popup.
local function Evaluate(itemID)
	if Refresh then Refresh() end
	if pending then return end
	if popupItemID == itemID and not popup.flashing then
		if Rapid:GetDeal(itemID) > 0 then UpdatePopup() else Flash("Opportunity gone") end
	elseif not popupItemID then
		OfferNext()
	end
end

local function ReadListings(itemID)
	if not Entry(itemID) then return end
	local levels = {}
	for i = 1, C_AuctionHouse.GetNumCommoditySearchResults(itemID) or 0 do
		local result = C_AuctionHouse.GetCommoditySearchResultInfo(itemID, i)
		if result then
			local units = result.quantity - (result.numOwnerItems or 0)
			if units > 0 then levels[#levels + 1] = { result.unitPrice, units } end
		end
	end
	table.sort(levels, function(a, b) return a[1] < b[1] end)
	listings[itemID] = levels
	if levels[1] then Record(itemID, levels[1][1]) end
	Evaluate(itemID)
	if UpdateHistoryPanel and itemID == selectedItemID then UpdateHistoryPanel() end
end

for _, event in ipairs({ "COMMODITY_SEARCH_RESULTS_UPDATED", "COMMODITY_SEARCH_RESULTS_ADDED" }) do
	PC:RegisterEvent(event, function(itemID)
		if running then ReadListings(itemID) end
	end)
end

---------------------------------------------------------------------------
-- Buying
---------------------------------------------------------------------------

-- Ends the purchase in progress without buying: says why, searches the item again, scanning goes on.
local function Abandon(message, cancel)
	local p = pending
	if not p then return end
	pending = nil
	if cancel then C_AuctionHouse.CancelCommoditiesPurchase() end
	PC:Print(message)
	if running then Search(p.itemID) end
	Evaluate(p.itemID)
end

local function Buy()
	if pending or not popupItemID or popup.flashing then return end
	local quantity, total = Rapid:GetDeal(popupItemID)
	if quantity == 0 then return end
	local token = {}
	pending = { itemID = popupItemID, quantity = quantity, expected = total, token = token }
	buyButton:SetEnabled(false)
	Debug(string.format("asking the AH for a quote: %d x %s, expected %s", quantity, ItemName(popupItemID),
		PC:FormatMoney(total)))
	-- Called exactly as Auctionator does it (Source_ModernAH/Tabs/Buying/Commodity/Mixins/Main.lua): two arguments,
	-- straight from the click. With a third argument (Blizzard's own call) and an error catcher in between, Forever
	-- refused mouse clicks: "tried to call the protected function StartCommoditiesPurchase()" (Sylice, 2026-11-17).
	C_AuctionHouse.StartCommoditiesPurchase(popupItemID, quantity)
	C_Timer.After(QUOTE_TIMEOUT, function()
		if pending and pending.token == token and not pending.confirmed then
			Abandon("not bought: the Auction House didn't answer the purchase request within " .. QUOTE_TIMEOUT
				.. " seconds.", true)
		end
	end)
end

PC:RegisterEvent("COMMODITY_PRICE_UPDATED", function(unitPrice, totalPrice)
	local p = pending
	if not p or p.confirmed then return end
	Debug(string.format("quote: %s each, %s in total", PC:FormatMoney(unitPrice), PC:FormatMoney(totalPrice)))
	if totalPrice <= p.expected and GetMoney() - totalPrice >= Data().minBalance then
		p.confirmed = true
		Debug("confirming")
		C_AuctionHouse.ConfirmCommoditiesPurchase(p.itemID, p.quantity)
		local token = p.token
		C_Timer.After(RESULT_TIMEOUT, function()
			if pending and pending.token == token then
				Abandon("no answer from the Auction House after confirming; check your bags and mail.", false)
			end
		end)
	else
		Abandon(string.format("not bought: %d would now cost %s instead of %s (someone bought first).", p.quantity,
			PC:FormatMoney(totalPrice), PC:FormatMoney(p.expected)), true)
	end
end)

PC:RegisterEvent("COMMODITY_PRICE_UNAVAILABLE", function()
	Abandon("not bought: no longer available.", true)
end)

PC:RegisterEvent("COMMODITY_PURCHASE_FAILED", function()
	Abandon("the purchase failed.", false)
end)

PC:RegisterEvent("COMMODITY_PURCHASE_SUCCEEDED", function()
	local p = pending
	if not p then return end
	pending = nil
	PC:Print(string.format("bought %d %s for %s.", p.quantity, ItemName(p.itemID), PC:FormatMoney(p.expected)))
	if popupItemID == p.itemID then Flash(string.format("Bought %d for %s", p.quantity, PC:FormatMoney(p.expected))) end
	if running then Search(p.itemID) end
end)

-- Blizzard blocking one of ProfitCraft's calls (shown by Blizzard only as a brief "Interface action failed").
for _, event in ipairs({ "ADDON_ACTION_BLOCKED", "ADDON_ACTION_FORBIDDEN" }) do
	PC:RegisterEvent(event, function(addon, functionName)
		if addon ~= ADDON_NAME then return end
		PC:Print("Blizzard blocked ProfitCraft from " .. tostring(functionName) .. ".")
		if pending then Abandon("purchase stopped.", false) end
	end)
end

---------------------------------------------------------------------------
-- Scanning
---------------------------------------------------------------------------

local function UpdateStatus()
	if not statusText then return end
	local active = #ActiveItems()
	if running then
		local effective = Rapid:GetEffectiveInterval(active)
		local limited = effective > Data().interval and (" (min " .. effective .. " s for " .. active .. " items)") or ""
		statusText:SetText(string.format("RapidFire: %d items, each every %s%s", active, DurationText(effective), limited))
		startButton:SetText("Stop")
	else
		statusText:SetText("Stopped.")
		startButton:SetText("Start")
	end
end

local Stop

local function Tick(myGeneration)
	if myGeneration ~= generation or not running then return end
	local spacing
	if popupItemID and not popup.flashing then
		if not pending then Search(popupItemID) end  -- no new search while a purchase is in progress
		spacing = FOCUS_SPACING
	else
		local active = ActiveItems()
		if #active == 0 then
			Stop("nothing to watch: add an item and set its max price.")
			return
		end
		if not pending then
			queueIndex = queueIndex % #active + 1
			Search(active[queueIndex].itemID)
		end
		spacing = Rapid:GetSpacing(#active)
	end
	UpdateStatus()
	C_Timer.After(spacing, function() PC:Call("rapidfire", Tick, myGeneration) end)
end

-- Restarts the search timing now (interval changed, popup shown or closed).
function Reschedule()
	if not running then return end
	generation = generation + 1
	Tick(generation)
end

local function Start()
	if running then return end
	running = true
	queueIndex = 0
	Reschedule()
end

function Stop(reason)
	running = false
	generation = generation + 1
	if pending then Abandon("purchase stopped.", not pending.confirmed) end
	HidePopup()
	UpdateStatus()
	if reason then PC:Print("RapidFire stopped: " .. reason) end
end

function Rapid:IsRunning() return running end
function Rapid:GetPopupItem() return popupItemID end
function Rapid:IsFlashing() return popup and popup.flashing end
function Rapid:IsBuying() return pending ~= nil end

PC:RegisterEvent("AUCTION_HOUSE_CLOSED", function()
	if running then Stop() end
	HidePopup()
end)

---------------------------------------------------------------------------
-- Watch list
---------------------------------------------------------------------------

-- Adds an item by ID. Only stackable goods (the AH sells them by quantity); while the item's data is still loading
-- (stack size unknown) it is added.
function Rapid:AddItem(itemID)
	itemID = tonumber(itemID)
	if not itemID then return end
	local data = Data()
	if Entry(itemID) then
		PC:Print("already on the watch list.")
		return
	end
	if #data.items >= MAX_ITEMS then
		PC:Print("the watch list holds up to " .. MAX_ITEMS .. " items.")
		return
	end
	if C_Item.DoesItemExistByID and not C_Item.DoesItemExistByID(itemID) then
		PC:Print("there is no item with ID " .. itemID .. ".")
		return
	end
	if PC.Items:GetStackSize(itemID) == 1 then
		PC:Print("only stackable goods (reagents, cloth, bars...) can be watched for now.")
		return
	end
	table.insert(data.items, { itemID = itemID, max = 0, on = true })
	selectedItemID = selectedItemID or itemID
	C_Item.RequestLoadItemDataByID(itemID)
	if Refresh then Refresh() end
end

local function AddFromCursor()
	local kind, itemID = GetCursorInfo()
	if kind == "item" and itemID then
		ClearCursor()
		Rapid:AddItem(itemID)
	end
end

-- Shift-clicking an item link while the "Add item ID" box has focus puts the item's ID there (Forever source:
-- shift-clicks go through ChatFrameUtil.InsertLink, Blizzard_ChatFrameBase/Mainline/ChatFrameUtilOverrides.lua).
if type(ChatFrameUtil) == "table" and type(ChatFrameUtil.InsertLink) == "function" then
	hooksecurefunc(ChatFrameUtil, "InsertLink", function(text)
		PC:Call("rapidfire link", function()
			if idBox and idBox:HasFocus() and type(text) == "string" then
				local itemID = text:match("item:(%d+)")
				if itemID then idBox:SetText(itemID) end
			end
		end)
	end)
end

---------------------------------------------------------------------------
-- Panels
---------------------------------------------------------------------------

local function MoneyInput(name, parent, onChange)
	local input = CreateFrame("Frame", name, parent, "MoneyInputFrameTemplate")
	MoneyInputFrame_SetOnValueChangedFunc(input, function()
		if not input.updating then PC:Call("rapidfire money", onChange, MoneyInputFrame_GetCopper(input)) end
	end)
	return input
end

local function SetMoney(input, copper)
	input.updating = true
	MoneyInputFrame_SetCopper(input, copper or 0)
	input.updating = false
end

local function Label(parent, text, x, y, font)
	local label = parent:CreateFontString(nil, "OVERLAY", font or "GameFontHighlightSmall")
	label:SetPoint("TOPLEFT", x, y)
	label:SetText(text)
	return label
end

local function CreateRow(index, parent)
	local row = CreateFrame("Button", nil, parent)
	row:SetSize(420, ROW_HEIGHT)
	row:SetPoint("TOPLEFT", 6, -24 - (index - 1) * ROW_HEIGHT)
	row:SetScript("OnClick", function()  -- clicking a row shows its history
		local entry = Data().items[index]
		if entry then
			selectedItemID = entry.itemID
			Refresh()
		end
	end)
	row.highlight = row:CreateTexture(nil, "BACKGROUND")
	row.highlight:SetAllPoints()
	row.highlight:SetColorTexture(1, 1, 1, 0.08)
	row.check = CreateFrame("CheckButton", nil, row, "UICheckButtonTemplate")
	row.check:SetSize(20, 20)
	row.check:SetPoint("LEFT")
	row.check:SetScript("OnClick", function(self)
		local entry = Data().items[index]
		if entry then entry.on = self:GetChecked() and true or false end
		Refresh()
		Reschedule()
	end)
	row.icon = row:CreateTexture(nil, "ARTWORK")
	row.icon:SetSize(16, 16)
	row.icon:SetPoint("LEFT", 22, 0)
	row.name = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	row.name:SetSize(100, ROW_HEIGHT)
	row.name:SetJustifyH("LEFT")
	row.name:SetPoint("LEFT", 42, 0)
	row.max = MoneyInput("ProfitCraftRapidFireMax" .. index, row, function(copper)
		local entry = Data().items[index]
		if entry then entry.max = copper end
		Refresh()
	end)
	row.max:SetPoint("LEFT", 146, 0)
	row.now = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	row.now:SetSize(70, ROW_HEIGHT)
	row.now:SetJustifyH("RIGHT")
	row.now:SetPoint("LEFT", 322, 0)
	row.remove = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
	row.remove:SetSize(20, 18)
	row.remove:SetPoint("LEFT", 398, 0)
	row.remove:SetText("x")
	row.remove:SetScript("OnClick", function()
		local entry = table.remove(Data().items, index)
		if entry then
			if popupItemID == entry.itemID then HidePopup() end
			if selectedItemID == entry.itemID then selectedItemID = Data().items[1] and Data().items[1].itemID end
		end
		Refresh()
		Reschedule()
	end)
	return row
end

-- The history panel: a bar chart of the cheapest price at each check (last 15 minutes, in time slots), the max price
-- as a line, and the numbers below it.
local function CreateHistoryPanel()
	historyPanel = PC:CreateWindow("ProfitCraftRapidFireHistory", panel, 300, 538, "Price history")
	historyPanel:SetPoint("TOPLEFT", panel, "TOPRIGHT", 2, 0)
	local inset = historyPanel.Inset
	historyPanel.itemName = Label(inset, "", 10, -8, "GameFontNormal")
	local chart = CreateFrame("Frame", nil, inset)
	chart:SetSize(270, 140)
	chart:SetPoint("TOPLEFT", 10, -32)
	local background = chart:CreateTexture(nil, "BACKGROUND")
	background:SetAllPoints()
	background:SetColorTexture(0, 0, 0, 0.35)
	chart.bars = {}
	local width = 270 / HISTORY_BARS
	for i = 1, HISTORY_BARS do
		local bar = chart:CreateTexture(nil, "ARTWORK")
		bar:SetWidth(math.max(width - 1, 1))
		bar:SetPoint("BOTTOMLEFT", (i - 1) * width, 0)
		bar:Hide()
		chart.bars[i] = bar
	end
	chart.maxLine = chart:CreateTexture(nil, "OVERLAY")
	chart.maxLine:SetHeight(1)
	chart.maxLine:SetWidth(270)
	chart.maxLine:SetColorTexture(1, 0.82, 0, 0.9)
	Label(inset, "15 min ago", 10, -176, "GameFontDisableSmall")
	local nowLabel = Label(inset, "now", 0, -176, "GameFontDisableSmall")
	nowLabel:ClearAllPoints()
	nowLabel:SetPoint("TOPRIGHT", chart, "BOTTOMRIGHT", 0, -4)
	historyPanel.chart = chart
	historyPanel.stats = Label(inset, "", 10, -200)
	historyPanel.stats:SetJustifyH("LEFT")
	historyPanel.stats:SetSpacing(4)
end

function UpdateHistoryPanel()
	if not (historyPanel and historyPanel:IsShown()) then return end
	local itemID = selectedItemID
	local chart = historyPanel.chart
	for _, bar in ipairs(chart.bars) do bar:Hide() end
	chart.maxLine:Hide()
	if not itemID then
		historyPanel.itemName:SetText("No item selected")
		historyPanel.stats:SetText("Click an item on the watch list.")
		return
	end
	historyPanel.itemName:SetText(ItemName(itemID))
	local stats = Rapid:GetHistoryStats(itemID)
	if not stats then
		historyPanel.stats:SetText("No checks yet. Press Start to collect prices.")
		return
	end
	local slots = Rapid:GetHistoryBars(itemID)
	local max = Entry(itemID) and Entry(itemID).max or 0
	local low, high = stats.low, math.max(stats.high, max)
	if max > 0 then low = math.min(low, max) end
	local range = math.max(high - low, 1)
	local function Height(price) return 10 + (price - low) / range * 120 end
	for index, price in pairs(slots) do
		local bar = chart.bars[index]
		bar:SetHeight(Height(price))
		if max > 0 and price <= max then bar:SetColorTexture(0.3, 1, 0.3, 0.9) else bar:SetColorTexture(0.6, 0.6, 0.9, 0.9) end
		bar:Show()
	end
	if max > 0 then
		chart.maxLine:ClearAllPoints()
		chart.maxLine:SetPoint("BOTTOMLEFT", 0, Height(max))
		chart.maxLine:Show()
	end
	local arrow = stats.trend == "up" and "|cffff5555rising|r" or (stats.trend == "down" and "|cff55ff55falling|r" or "steady")
	historyPanel.stats:SetText(table.concat({
		"Now:  " .. PC:FormatMoney(stats.now),
		"Average:  " .. PC:FormatMoney(math.floor(stats.average + 0.5)),
		"Lowest dip:  " .. PC:FormatMoney(stats.low) .. "  (" .. math.floor(stats.lowAgo / 60) .. " min ago)",
		"Highest:  " .. PC:FormatMoney(stats.high),
		"Trend:  " .. arrow,
		"Your max:  " .. (max > 0 and PC:FormatMoney(max) or "not set") .. "  (yellow line)",
		stats.checks .. " checks in the last 15 minutes",
	}, "\n"))
end

function Refresh()
	if not panel then return end
	local items = Data().items
	for index = 1, MAX_ITEMS do
		local row, entry = rows[index], items[index]
		row:SetShown(entry ~= nil)
		if entry then
			row.check:SetChecked(entry.on)
			row.icon:SetTexture(PC.Items:GetIcon(entry.itemID) or 134400)
			row.name:SetText(ItemName(entry.itemID))
			row.highlight:SetShown(entry.itemID == selectedItemID)
			if not row.max.gold:HasFocus() and not row.max.silver:HasFocus() and not row.max.copper:HasFocus() then
				SetMoney(row.max, entry.max)
			end
			local levels = listings[entry.itemID]
			if levels and levels[1] then
				local cheap = levels[1][1] <= (entry.max or 0)
				row.now:SetText((cheap and "|cff55ff55" or "") .. PC:FormatMoney(levels[1][1]) .. (cheap and "|r" or ""))
			elseif levels then
				row.now:SetText("|cff888888none listed|r")
			else
				row.now:SetText("|cff888888-|r")
			end
		end
	end
	keyButton:SetText("Buy key: " .. GetBindingText(Data().key))
	UpdateStatus()
	UpdateHistoryPanel()
end

local function IntervalPosition()
	for position, seconds in ipairs(INTERVALS) do
		if seconds >= Data().interval then return position end
	end
	return #INTERVALS
end

local function CreateIntervalSlider(parent, y)
	Label(parent, "Check each item every", 10, y)
	local slider = CreateFrame("Frame", nil, parent, "MinimalSliderWithSteppersTemplate")
	slider:SetWidth(240)
	slider:SetPoint("TOPLEFT", 160, y + 4)
	slider:Init(IntervalPosition(), 1, #INTERVALS, #INTERVALS - 1, { [MinimalSliderWithSteppersMixin.Label.Right] =
		function(position) return DurationText(INTERVALS[math.floor(position + 0.5)]) end })
	slider:RegisterCallback(MinimalSliderWithSteppersMixin.Event.OnValueChanged, function(_, position)
		PC:Call("rapidfire interval", function()
			Data().interval = INTERVALS[math.floor(position + 0.5)]
			UpdateStatus()
			Reschedule()  -- takes effect now
		end)
	end, parent)
	return slider
end

local function CreateKeyButton(parent)
	local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
	button:SetSize(130, 20)
	button:SetScript("OnClick", function(self)
		self.capturing = true
		self:SetText("Press a key...")
		self:EnableKeyboard(true)
	end)
	button:SetScript("OnKeyDown", function(self, key)
		if not self.capturing then
			self:SetPropagateKeyboardInput(true)
			return
		end
		self:SetPropagateKeyboardInput(false)
		if key:find("SHIFT") or key:find("CTRL") or key:find("ALT") then return end  -- wait for a real key
		self.capturing = false
		self:EnableKeyboard(false)
		if key ~= "ESCAPE" then Data().key = key end
		Refresh()
	end)
	return button
end

local function CreatePanel()
	panel = PC:CreateWindow("ProfitCraftRapidFire", AuctionHouseFrame, 440, 538, "ProfitCraft RapidFire")
	panel:SetPoint("TOPLEFT", AuctionHouseFrame, "TOPRIGHT", 2, 0)
	local inset = panel.Inset
	inset:EnableMouse(true)
	inset:SetScript("OnReceiveDrag", function() PC:Call("rapidfire drop", AddFromCursor) end)
	inset:SetScript("OnMouseUp", function() PC:Call("rapidfire drop", AddFromCursor) end)

	Label(inset, "WATCH LIST", 10, -6, "GameFontNormal")
	local hint = inset:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
	hint:SetPoint("TOPRIGHT", -10, -8)
	hint:SetText("max price per unit; click a row for its history")
	for index = 1, MAX_ITEMS do rows[index] = CreateRow(index, inset) end

	local y = -30 - MAX_ITEMS * ROW_HEIGHT  -- below the rows
	local addLabel = Label(inset, "Add item ID:", 10, y - 4)
	idBox = CreateFrame("EditBox", nil, inset, "InputBoxTemplate")
	idBox:SetSize(70, 20)
	idBox:SetPoint("LEFT", addLabel, "RIGHT", 10, 0)
	idBox:SetAutoFocus(false)
	idBox:SetNumeric(true)
	local function AddTyped()
		Rapid:AddItem(idBox:GetText())
		idBox:SetText("")
		idBox:ClearFocus()
	end
	idBox:SetScript("OnEnterPressed", function() PC:Call("rapidfire add", AddTyped) end)
	local addButton = CreateFrame("Button", nil, inset, "UIPanelButtonTemplate")
	addButton:SetSize(50, 20)
	addButton:SetPoint("LEFT", idBox, "RIGHT", 6, 0)
	addButton:SetText("Add")
	addButton:SetScript("OnClick", function() PC:Call("rapidfire add", AddTyped) end)
	local addHint = inset:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
	addHint:SetPoint("LEFT", addButton, "RIGHT", 8, 0)
	addHint:SetText("or drop / shift-click an item")

	y = y - 32
	local keepLabel = Label(inset, "Keep at least", 10, y - 4)
	keepInput = MoneyInput("ProfitCraftRapidFireKeep", inset, function(copper) Data().minBalance = copper end)
	keepInput:SetPoint("LEFT", keepLabel, "RIGHT", 10, 0)
	SetMoney(keepInput, Data().minBalance)

	y = y - 30
	intervalSlider = CreateIntervalSlider(inset, y)

	y = y - 30
	local sound = CreateFrame("CheckButton", nil, inset, "UICheckButtonTemplate")
	sound:SetSize(22, 22)
	sound:SetPoint("TOPLEFT", 6, y + 2)
	sound.Text:SetText("Sound")
	sound.Text:SetFontObject("GameFontHighlightSmall")
	sound:SetChecked(Data().sound)
	sound:SetScript("OnClick", function(self) Data().sound = self:GetChecked() and true or false end)
	keyButton = CreateKeyButton(inset)
	keyButton:SetPoint("TOPLEFT", 160, y)

	-- Bottom line: the status, and Start/Stop at the right (Sylice, 2026-11-17).
	startButton = CreateFrame("Button", nil, inset, "UIPanelButtonTemplate")
	startButton:SetSize(80, 22)
	startButton:SetPoint("BOTTOMRIGHT", -8, 8)
	startButton:SetScript("OnClick", function()
		PC:Call("rapidfire start", function() if running then Stop() else Start() end end)
	end)
	statusText = inset:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	statusText:SetPoint("LEFT", inset, "BOTTOMLEFT", 10, 19)
	statusText:SetPoint("RIGHT", startButton, "LEFT", -10, 0)
	statusText:SetJustifyH("LEFT")

	CreateHistoryPanel()
	historyPanel:Show()  -- PC:CreateWindow creates windows hidden; it shows and hides with the RapidFire panel (its parent)
	panel:HookScript("OnShow", Refresh)
	historyPanel:HookScript("OnShow", UpdateHistoryPanel)
	selectedItemID = selectedItemID or (Data().items[1] and Data().items[1].itemID)
end

local function CreatePopup()
	popup = CreateFrame("Frame", "ProfitCraftRapidFirePopup", UIParent, "BasicFrameTemplateWithInset")
	popup:SetSize(360, 140)
	popup:SetFrameStrata("DIALOG")
	popup:SetClampedToScreen(true)
	popup:SetMovable(true)
	popup:EnableMouse(true)
	popup:RegisterForDrag("LeftButton")
	popup:SetScript("OnDragStart", popup.StartMoving)
	popup:SetScript("OnDragStop", function(self)
		self:StopMovingOrSizing()
		local x, y = self:GetCenter()
		Data().popupPosition = { x = x, y = y }  -- remembered from now on
	end)
	popup:Hide()
	popup.TitleText:SetText("ProfitCraft RapidFire")
	popup.icon = popup:CreateTexture(nil, "ARTWORK")
	popup.icon:SetSize(32, 32)
	popup.icon:SetPoint("TOPLEFT", 14, -32)
	popup.title = popup:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
	popup.title:SetPoint("TOPLEFT", popup.icon, "TOPRIGHT", 8, 0)
	popup.text = popup:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	popup.text:SetPoint("TOPLEFT", popup.title, "BOTTOMLEFT", 0, -4)
	popup.note = popup:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
	popup.note:SetPoint("TOPLEFT", popup.text, "BOTTOMLEFT", 0, -4)
	buyButton = CreateFrame("Button", BUY_BUTTON_NAME, popup, "UIPanelButtonTemplate")
	buyButton:SetSize(220, 32)
	buyButton:SetPoint("BOTTOM", 0, 12)
	buyButton:SetScript("OnClick", Buy)  -- no error catcher in between: the purchase must start straight from the click
	popup:SetScript("OnHide", ClearBinding)
	popup.CloseButton:SetScript("OnClick", function()
		HidePopup()
		Reschedule()
	end)
end

local function CreateToggle()
	toggleButton = CreateFrame("Button", nil, AuctionHouseFrame, "UIPanelButtonTemplate")
	toggleButton:SetSize(80, 22)
	toggleButton:SetPoint("BOTTOMRIGHT", AuctionHouseFrame, "BOTTOMRIGHT", -6, 4)
	toggleButton:SetText("RapidFire")
	toggleButton:SetScript("OnClick", function()
		PC:Call("rapidfire panel", function()
			if not panel then CreatePanel() end
			panel:SetShown(not panel:IsShown())
		end)
	end)
end

PC:RegisterEvent("AUCTION_HOUSE_SHOW", function()
	if not AuctionHouseFrame then return end
	if not toggleButton then
		CreateToggle()
		CreatePopup()
	end
end)

PC:Listen("ITEM_DATA_CHANGED", function()
	if panel and panel:IsShown() then Refresh() end
	if popupItemID and not popup.flashing then UpdatePopup() end
end)
