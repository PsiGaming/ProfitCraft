-- ProfitCraft: Sniper (watch list & quick buy; FEATURES.md "Watch list & quick buy")
-- While the AH is open and sniping runs, each watched reagent is searched in turn (C_AuctionHouse.SendSearchQuery,
-- at most SEARCHES_PER_MINUTE; Blizzard's limit is 100 a minute, Forever API docs). The AH also pushes changes to
-- open searches (COMMODITY_SEARCH_RESULTS_UPDATED). When units at or under an item's max price are listed, a popup
-- offers them with a Buy button; the buy key (default Space) clicks it only while the popup shows
-- (SetOverrideBindingClick). Buying needs the player's key press or click: StartCommoditiesPurchase is restricted
-- (HasRestrictions, Forever docs). The quantity is taken from the live listings at that moment (so units already
-- sold are left out), capped by the money to keep; the AH's quote (COMMODITY_PRICE_UPDATED) must not exceed the
-- expected cost of exactly those units, else the purchase is cancelled. Scanning goes on while the popup shows;
-- when the deal is gone the popup flashes "Opportunity gone" and closes.
-- Stackable goods only (bought by quantity); the player's own units are left out (numOwnerItems).

local _, PC = ...

local Sniper = {}
PC.Sniper = Sniper

local MAX_ITEMS = 10
local SEARCHES_PER_MINUTE = 90
local FLASH_SECONDS = 1.5
local INTERVALS = { 3, 5, 10 }
local ROW_HEIGHT = 28
local BUY_BUTTON_NAME = "ProfitCraftSniperBuy"
local SORT_BY_PRICE = { { sortOrder = Enum.AuctionHouseSortOrder and Enum.AuctionHouseSortOrder.Price or 0, reverseSort = false } }

local panel, toggleButton, popup, buyButton, statusText, startButton, idBox, keyButton, keepInput
local rows = {}
local running, generation, queueIndex, lastCheck = false, 0, 0, nil
local listings = {}  -- itemID -> { {unit price, units of other sellers}, ... } cheapest first, from the live search
local pending        -- the purchase waiting for the AH's quote: { itemID, quantity, expected }
local popupItemID    -- the item the popup offers

local function Data() return PC.db.sniper end

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

-- What buying now gets: units at or under the max, cheapest first, as many as the money above the amount to keep
-- pays for. Returns quantity and total cost (0, 0 when nothing).
function Sniper:GetDeal(itemID)
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

local function Search(itemID)
	C_AuctionHouse.SendSearchQuery(C_AuctionHouse.MakeItemKey(itemID), SORT_BY_PRICE, true)
end

---------------------------------------------------------------------------
-- Popup
---------------------------------------------------------------------------

local Refresh  -- the panel's refresh, defined below

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
	local quantity, total = Sniper:GetDeal(popupItemID)
	local name = PC.Items:GetName(popupItemID) or ("item " .. popupItemID)
	popup.icon:SetTexture(PC.Items:GetIcon(popupItemID) or 134400)
	popup.title:SetText(name)
	popup.text:SetText(string.format("%d at <= %s  -  total %s", quantity,
		PC:FormatMoney(Entry(popupItemID).max), PC:FormatMoney(total)))
	popup.note:SetText("You keep " .. PC:FormatMoney(GetMoney() - total) .. " (at least "
		.. PC:FormatMoney(Data().minBalance) .. ").")
	buyButton:SetText("BUY  (" .. GetBindingText(Data().key) .. ")")
	buyButton:SetEnabled(pending == nil)
end

local function ShowPopup(itemID)
	popupItemID = itemID
	popup.flashing = false
	UpdatePopup()
	popup:Show()
	if Data().sound then PlaySound(SOUNDKIT.RAID_WARNING) end
	if not InCombatLockdown() then SetOverrideBindingClick(popup, true, Data().key, BUY_BUTTON_NAME) end
end

-- The next watched item with a deal, if any, gets the popup.
local function OfferNext()
	if popupItemID then return end
	for _, entry in ipairs(ActiveItems()) do
		if Sniper:GetDeal(entry.itemID) > 0 then
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
			OfferNext()
		end
	end)
end

-- New listings for an item: update the panel and the popup.
local function Evaluate(itemID)
	if Refresh then Refresh() end
	if pending then return end
	if popupItemID == itemID and not popup.flashing then
		if Sniper:GetDeal(itemID) > 0 then UpdatePopup() else Flash("Opportunity gone") end
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
	Evaluate(itemID)
end

for _, event in ipairs({ "COMMODITY_SEARCH_RESULTS_UPDATED", "COMMODITY_SEARCH_RESULTS_ADDED" }) do
	PC:RegisterEvent(event, function(itemID)
		if running then ReadListings(itemID) end
	end)
end

---------------------------------------------------------------------------
-- Buying
---------------------------------------------------------------------------

local function Buy()
	if pending or not popupItemID or popup.flashing then return end
	local quantity, total = Sniper:GetDeal(popupItemID)
	if quantity == 0 then return end
	pending = { itemID = popupItemID, quantity = quantity, expected = total }
	buyButton:SetEnabled(false)
	C_AuctionHouse.StartCommoditiesPurchase(popupItemID, quantity)
end

local function Abandon(message)
	local itemID = pending and pending.itemID
	pending = nil
	PC:Print(message)
	if itemID then
		Search(itemID)
		Evaluate(itemID)
	end
end

PC:RegisterEvent("COMMODITY_PRICE_UPDATED", function(_, totalPrice)
	local p = pending
	if not p or p.confirmed then return end
	if totalPrice <= p.expected and GetMoney() - totalPrice >= Data().minBalance then
		p.confirmed = true
		C_AuctionHouse.ConfirmCommoditiesPurchase(p.itemID, p.quantity)
	else
		C_AuctionHouse.CancelCommoditiesPurchase()
		Abandon(string.format("not bought: %d would now cost %s instead of %s (someone bought first).", p.quantity,
			PC:FormatMoney(totalPrice), PC:FormatMoney(p.expected)))
	end
end)

PC:RegisterEvent("COMMODITY_PRICE_UNAVAILABLE", function()
	if pending then Abandon("not bought: no longer available.") end
end)

PC:RegisterEvent("COMMODITY_PURCHASE_FAILED", function()
	if pending then Abandon("the purchase failed.") end
end)

PC:RegisterEvent("COMMODITY_PURCHASE_SUCCEEDED", function()
	local p = pending
	if not p then return end
	pending = nil
	local name = PC.Items:GetName(p.itemID) or ("item " .. p.itemID)
	PC:Print(string.format("bought %d %s for %s.", p.quantity, name, PC:FormatMoney(p.expected)))
	if popupItemID == p.itemID then Flash(string.format("Bought %d for %s", p.quantity, PC:FormatMoney(p.expected))) end
	Search(p.itemID)
end)

---------------------------------------------------------------------------
-- Scanning
---------------------------------------------------------------------------

local function UpdateStatus()
	if not statusText then return end
	local active = #ActiveItems()
	if running then
		statusText:SetText(string.format("Sniping %d %s, last check %s", active, active == 1 and "item" or "items",
			lastCheck and (math.floor(GetTime() - lastCheck) .. " s ago") or "-"))
		startButton:SetText("Stop sniping")
	else
		statusText:SetText("Stopped.")
		startButton:SetText("Start sniping")
	end
end

-- Seconds between two searches: each item is searched every `interval` seconds, but never more than
-- SEARCHES_PER_MINUTE searches in total, so long lists are checked less often.
function Sniper:GetSpacing(count)
	return math.max(Data().interval / math.max(count, 1), 60 / SEARCHES_PER_MINUTE)
end

local Stop

local function Tick(myGeneration)
	if myGeneration ~= generation or not running then return end
	local active = ActiveItems()
	if #active == 0 then
		Stop("nothing to watch: add an item and set its max price.")
		return
	end
	if not pending then  -- no new search while a purchase waits for its quote
		queueIndex = queueIndex % #active + 1
		Search(active[queueIndex].itemID)
		lastCheck = GetTime()
	end
	UpdateStatus()
	C_Timer.After(Sniper:GetSpacing(#active), function() PC:Call("sniper", Tick, myGeneration) end)
end

local function Start()
	if running then return end
	running = true
	generation = generation + 1
	queueIndex = 0
	Tick(generation)
end

function Stop(reason)
	running = false
	generation = generation + 1
	pending = nil
	HidePopup()
	UpdateStatus()
	if reason then PC:Print("sniping stopped: " .. reason) end
end

function Sniper:IsRunning() return running end
function Sniper:GetPopupItem() return popupItemID end
function Sniper:IsFlashing() return popup and popup.flashing end

PC:RegisterEvent("AUCTION_HOUSE_CLOSED", function()
	if running then Stop() end
	HidePopup()
end)

---------------------------------------------------------------------------
-- Watch list
---------------------------------------------------------------------------

-- Adds an item by ID. Only stackable goods (the AH sells them by quantity); while the item's data is still loading
-- (stack size unknown) it is added and checked once known.
function Sniper:AddItem(itemID)
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
		PC:Print("only stackable goods (reagents, cloth, bars...) can be sniped for now.")
		return
	end
	table.insert(data.items, { itemID = itemID, max = 0, on = true })
	C_Item.RequestLoadItemDataByID(itemID)
	if Refresh then Refresh() end
end

local function AddFromCursor()
	local kind, itemID = GetCursorInfo()
	if kind == "item" and itemID then
		ClearCursor()
		Sniper:AddItem(itemID)
	end
end

-- Shift-clicking an item link while the "Add item ID" box has focus puts the item's ID there (Forever source:
-- shift-clicks go through ChatFrameUtil.InsertLink, Blizzard_ChatFrameBase/Mainline/ChatFrameUtilOverrides.lua).
if type(ChatFrameUtil) == "table" and type(ChatFrameUtil.InsertLink) == "function" then
	hooksecurefunc(ChatFrameUtil, "InsertLink", function(text)
		PC:Call("sniper link", function()
			if idBox and idBox:HasFocus() and type(text) == "string" then
				local itemID = text:match("item:(%d+)")
				if itemID then idBox:SetText(itemID) end
			end
		end)
	end)
end

---------------------------------------------------------------------------
-- Panel
---------------------------------------------------------------------------

local function MoneyInput(name, parent, onChange)
	local input = CreateFrame("Frame", name, parent, "MoneyInputFrameTemplate")
	MoneyInputFrame_SetOnValueChangedFunc(input, function()
		if not input.updating then PC:Call("sniper money", onChange, MoneyInputFrame_GetCopper(input)) end
	end)
	return input
end

local function SetMoney(input, copper)
	input.updating = true
	MoneyInputFrame_SetCopper(input, copper or 0)
	input.updating = false
end

local function CreateRow(index, parent)
	local row = CreateFrame("Frame", nil, parent)
	row:SetSize(420, ROW_HEIGHT)
	row:SetPoint("TOPLEFT", 6, -26 - (index - 1) * ROW_HEIGHT)
	row.check = CreateFrame("CheckButton", nil, row, "UICheckButtonTemplate")
	row.check:SetSize(22, 22)
	row.check:SetPoint("LEFT")
	row.check:SetScript("OnClick", function(self)
		local entry = Data().items[index]
		if entry then entry.on = self:GetChecked() and true or false end
		Refresh()
	end)
	row.icon = row:CreateTexture(nil, "ARTWORK")
	row.icon:SetSize(18, 18)
	row.icon:SetPoint("LEFT", 24, 0)
	row.name = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	row.name:SetSize(96, ROW_HEIGHT)
	row.name:SetJustifyH("LEFT")
	row.name:SetPoint("LEFT", 46, 0)
	row.max = MoneyInput("ProfitCraftSniperMax" .. index, row, function(copper)
		local entry = Data().items[index]
		if entry then entry.max = copper end
		if Refresh then Refresh() end
	end)
	row.max:SetPoint("LEFT", 146, 0)
	row.now = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	row.now:SetSize(70, ROW_HEIGHT)
	row.now:SetJustifyH("RIGHT")
	row.now:SetPoint("LEFT", 322, 0)
	row.remove = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
	row.remove:SetSize(20, 20)
	row.remove:SetPoint("LEFT", 398, 0)
	row.remove:SetText("x")
	row.remove:SetScript("OnClick", function()
		local entry = table.remove(Data().items, index)
		if entry and popupItemID == entry.itemID then HidePopup() end
		Refresh()
	end)
	return row
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
			row.name:SetText(PC.Items:GetName(entry.itemID) or ("item " .. entry.itemID))
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
end

local function IntervalDropdown(parent)
	local dropdown = CreateFrame("DropdownButton", nil, parent, "WowStyle1DropdownTemplate")
	dropdown:SetWidth(80)
	dropdown:SetupMenu(function(_, rootDescription)
		for _, seconds in ipairs(INTERVALS) do
			rootDescription:CreateRadio(seconds .. " s", function() return Data().interval == seconds end,
				function() Data().interval = seconds end)
		end
	end)
	return dropdown
end

local function KeyButton(parent)
	local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
	button:SetSize(150, 22)
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
	panel = PC:CreateWindow("ProfitCraftSniper", AuctionHouseFrame, 440, 538, "ProfitCraft Sniper")
	panel:SetPoint("TOPLEFT", AuctionHouseFrame, "TOPRIGHT", 2, 0)
	local inset = panel.Inset
	inset:EnableMouse(true)
	inset:SetScript("OnReceiveDrag", function() PC:Call("sniper drop", AddFromCursor) end)
	inset:SetScript("OnMouseUp", function() PC:Call("sniper drop", AddFromCursor) end)

	local heading = inset:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	heading:SetPoint("TOPLEFT", 10, -8)
	heading:SetText("WATCH LIST")
	local hint = inset:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
	hint:SetPoint("TOPRIGHT", -10, -10)
	hint:SetText("max price per unit; drop items here")
	for index = 1, MAX_ITEMS do rows[index] = CreateRow(index, inset) end

	local y = -32 - MAX_ITEMS * ROW_HEIGHT
	local addLabel = inset:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	addLabel:SetPoint("TOPLEFT", 10, y - 4)
	addLabel:SetText("Add item ID:")
	idBox = CreateFrame("EditBox", nil, inset, "InputBoxTemplate")
	idBox:SetSize(70, 20)
	idBox:SetPoint("LEFT", addLabel, "RIGHT", 10, 0)
	idBox:SetAutoFocus(false)
	idBox:SetNumeric(true)
	local function AddTyped()
		Sniper:AddItem(idBox:GetText())
		idBox:SetText("")
		idBox:ClearFocus()
	end
	idBox:SetScript("OnEnterPressed", function() PC:Call("sniper add", AddTyped) end)
	local addButton = CreateFrame("Button", nil, inset, "UIPanelButtonTemplate")
	addButton:SetSize(50, 22)
	addButton:SetPoint("LEFT", idBox, "RIGHT", 6, 0)
	addButton:SetText("Add")
	addButton:SetScript("OnClick", function() PC:Call("sniper add", AddTyped) end)
	local addHint = inset:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
	addHint:SetPoint("LEFT", addButton, "RIGHT", 8, 0)
	addHint:SetText("or shift-click an item link")

	y = y - 40
	local keepLabel = inset:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	keepLabel:SetPoint("TOPLEFT", 10, y - 4)
	keepLabel:SetText("Keep at least:")
	keepInput = MoneyInput("ProfitCraftSniperKeep", inset, function(copper) Data().minBalance = copper end)
	keepInput:SetPoint("LEFT", keepLabel, "RIGHT", 10, 0)
	SetMoney(keepInput, Data().minBalance)

	y = y - 32
	local everyLabel = inset:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	everyLabel:SetPoint("TOPLEFT", 10, y - 4)
	everyLabel:SetText("Check each item every:")
	local interval = IntervalDropdown(inset)
	interval:SetPoint("LEFT", everyLabel, "RIGHT", 8, 0)
	local sound = CreateFrame("CheckButton", nil, inset, "UICheckButtonTemplate")
	sound:SetPoint("LEFT", interval, "RIGHT", 12, 0)
	sound.Text:SetText("Sound")
	sound.Text:SetFontObject("GameFontHighlightSmall")
	sound:SetChecked(Data().sound)
	sound:SetScript("OnClick", function(self) Data().sound = self:GetChecked() and true or false end)

	y = y - 32
	keyButton = KeyButton(inset)
	keyButton:SetPoint("TOPLEFT", 10, y)

	startButton = CreateFrame("Button", nil, inset, "UIPanelButtonTemplate")
	startButton:SetSize(180, 26)
	startButton:SetPoint("BOTTOM", 0, 30)
	startButton:SetScript("OnClick", function()
		PC:Call("sniper start", function() if running then Stop() else Start() end end)
	end)
	statusText = inset:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	statusText:SetPoint("BOTTOM", 0, 10)
	panel:HookScript("OnShow", Refresh)
end

local function CreatePopup()
	popup = CreateFrame("Frame", "ProfitCraftSniperPopup", UIParent, "BasicFrameTemplateWithInset")
	popup:SetSize(360, 140)
	popup:SetPoint("BOTTOM", AuctionHouseFrame, "TOP", 0, 8)
	popup:SetFrameStrata("DIALOG")
	popup:Hide()
	popup.TitleText:SetText("ProfitCraft Sniper")
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
	buyButton:SetScript("OnClick", function() PC:Call("sniper buy", Buy) end)
	popup:SetScript("OnHide", ClearBinding)
	popup.CloseButton:SetScript("OnClick", function() HidePopup() end)
end

local function CreateToggle()
	toggleButton = CreateFrame("Button", nil, AuctionHouseFrame, "UIPanelButtonTemplate")
	toggleButton:SetSize(80, 22)
	toggleButton:SetPoint("BOTTOMRIGHT", AuctionHouseFrame, "BOTTOMRIGHT", -6, 4)
	toggleButton:SetText("Sniper")
	toggleButton:SetScript("OnClick", function()
		PC:Call("sniper panel", function()
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
