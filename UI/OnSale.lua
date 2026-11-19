-- ProfitCraft: On Sale panel (FEATURES.md "Version 0.3", DESIGN.md section 13)
-- An "On Sale" button on the AH window opens a panel at its right edge (in RapidFire's place; one at a time) with two
-- pages: Finds (newest first; click one to buy it) and Searches (on/off, edit, remove, new, paste). Start/Stop and
-- the status line at the bottom.
-- Buying: clicking a find searches that item (C_AuctionHouse.SendSearchQuery) and the dialog offers what is still at
-- or under the On Sale price; its Buy button makes the purchase call FIRST in the click (Forever blocks it otherwise,
-- knowledge file): gear C_AuctionHouse.PlaceBid(auctionID, buyout) (Blizzard's buyout does the same, Forever source
-- Blizzard_StaticPopup BUYOUT_AUCTION), stackable goods StartCommoditiesPurchase + ConfirmCommoditiesPurchase on the
-- quote, as RapidFire. RapidFire's "keep at least" money applies.

local ADDON_NAME, PC = ...

local OnSale = PC.OnSale

local ROW_HEIGHT = 22
local FIND_ROWS = 19
local SEARCH_ROWS = 16
local ANSWER_TIMEOUT = 5
local RESULT_TIMEOUT = 10
local CLOSE_DELAY = 1.5

local panel, toggleButton, statusText, startButton, findsView, searchesView, editView, pasteView, findsHeader
local findRows, searchRows = {}, {}
local findOffset, searchOffset = 0, 0
local editing  -- the search being edited (nil = new)
local editState = {}
local dialog, buyButton
local inspecting  -- { hit, offer, token, buying, confirmed }

local function Settings() return PC.db.settings end

local function Ago(seconds)
	if seconds < 60 then return seconds .. " s" end
	if seconds < 3600 then return math.floor(seconds / 60) .. " m" end
	return math.floor(seconds / 3600) .. " h"
end

local function SearchName(from)
	if from == "scan" then return "full scan" end
	for _, search in ipairs(OnSale:GetSearches()) do
		if search.id == from then return search.name end
	end
	return "a removed search"
end

local function Label(parent, text, x, y, font)
	local label = parent:CreateFontString(nil, "OVERLAY", font or "GameFontHighlightSmall")
	label:SetPoint("TOPLEFT", x, y)
	label:SetText(text)
	return label
end

local function Button(parent, text, width)
	local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
	button:SetSize(width, 22)
	button:SetText(text)
	return button
end

---------------------------------------------------------------------------
-- Buy dialog
---------------------------------------------------------------------------

local function Budget() return GetMoney() - PC.db.rapidFire.minBalance end

local function CloseDialog()
	local state = inspecting
	inspecting = nil
	if state and state.buying and not state.confirmed and state.offer and state.offer.kind == "commodity" then
		C_AuctionHouse.CancelCommoditiesPurchase()
	end
	if dialog then dialog:Hide() end
	OnSale:SetBusy(false)
end

local function ShowMessage(text, close)
	dialog.text:SetText(text)
	dialog.note:SetText("")
	buyButton:SetEnabled(false)
	if close then
		local state = inspecting
		C_Timer.After(CLOSE_DELAY, function()
			if inspecting == state then CloseDialog() end
		end)
	end
end

local function ShowOffer()
	local state = inspecting
	local offer, hit = state.offer, state.hit
	local profit = offer.net * offer.quantity - offer.total
	dialog.text:SetText(string.format("Buy %d for %s?", offer.quantity, PC:FormatMoney(offer.total)))
	dialog.note:SetText(string.format("Usual %s each (%s)  -  profit after the AH cut %s\nYou keep %s (at least %s).",
		PC:FormatMoney(hit.usual), hit.source == "own" and "ProfitCraft's history" or "Auctionator's history",
		PC:FormatProfit(profit), PC:FormatMoney(GetMoney() - offer.total), PC:FormatMoney(PC.db.rapidFire.minBalance)))
	buyButton:SetEnabled(not state.buying)
end

local function Gone(message)
	local hit = inspecting and inspecting.hit
	if hit then OnSale:RemoveHit(hit.key) end
	ShowMessage(message or "No longer on sale.", true)
end

-- Listings of a stackable find: cheapest first, others' units at or under the On Sale price, as many as the budget pays.
local function ReadCommodityOffer(itemID)
	local state = inspecting
	if not (state and not state.offer and state.hit.itemID == itemID and state.stackable) then return end
	local limit = OnSale:GetLimit(itemID, 0)
	if not limit then return Gone() end
	local levels = {}
	for i = 1, C_AuctionHouse.GetNumCommoditySearchResults(itemID) or 0 do
		local result = C_AuctionHouse.GetCommoditySearchResultInfo(itemID, i)
		if result then
			local units = result.quantity - (result.numOwnerItems or 0)
			if units > 0 then levels[#levels + 1] = { result.unitPrice, units } end
		end
	end
	table.sort(levels, function(a, b) return a[1] < b[1] end)
	local quantity, total, budget = 0, 0, Budget()
	for _, level in ipairs(levels) do
		if level[1] > limit.limit then break end
		local take = math.min(level[2], math.floor((budget - total) / level[1]))
		if take <= 0 then break end
		quantity, total = quantity + take, total + take * level[1]
		if take < level[2] then break end
	end
	if quantity == 0 then
		if levels[1] and levels[1][1] <= limit.limit then return ShowMessage("Not enough money above what you keep.") end
		return Gone()
	end
	state.offer = { kind = "commodity", itemID = itemID, quantity = quantity, total = total, net = limit.net }
	ShowOffer()
end

-- Listings of a gear find: the cheapest one of another seller at or under the On Sale price.
local function ReadItemOffer(itemKey)
	local state = inspecting
	if not (state and not state.offer and not state.stackable and itemKey and itemKey.itemID == state.hit.itemID) then
		return
	end
	local hitKey = state.hit.itemKey
	local limit = OnSale:GetLimit(state.hit.itemID, state.hit.suffix)
	if not limit then return Gone() end
	local best
	for i = 1, C_AuctionHouse.GetNumItemSearchResults(hitKey) or 0 do
		local result = C_AuctionHouse.GetItemSearchResultInfo(hitKey, i)
		if result and result.buyoutAmount and result.buyoutAmount <= limit.limit and not result.containsOwnerItem
			and (not best or result.buyoutAmount < best.buyoutAmount) then
			best = result
		end
	end
	if not best then return Gone() end
	if best.buyoutAmount > Budget() then return ShowMessage("Not enough money above what you keep.") end
	state.offer = { kind = "item", auctionID = best.auctionID, quantity = 1, total = best.buyoutAmount, net = limit.net }
	ShowOffer()
end

for _, event in ipairs({ "COMMODITY_SEARCH_RESULTS_UPDATED", "COMMODITY_SEARCH_RESULTS_ADDED" }) do
	PC:RegisterEvent(event, ReadCommodityOffer)
end
for _, event in ipairs({ "ITEM_SEARCH_RESULTS_UPDATED", "ITEM_SEARCH_RESULTS_ADDED" }) do
	PC:RegisterEvent(event, ReadItemOffer)
end

local function Bought()
	local state = inspecting
	state.done = true
	local offer, hit = state.offer, state.hit
	PC:Print(string.format("On Sale: bought %d %s for %s.", offer.quantity, hit.name or "?", PC:FormatMoney(offer.total)))
	OnSale:RemoveHit(hit.key)
	ShowMessage(string.format("Bought %d for %s", offer.quantity, PC:FormatMoney(offer.total)), true)
end

local function Failed(message)
	local state = inspecting
	if not (state and state.buying) or state.done then return end
	if state.offer.kind == "commodity" and not state.confirmed then C_AuctionHouse.CancelCommoditiesPurchase() end
	state.done = true
	PC:Print("On Sale: " .. message)
	ShowMessage(message, true)
end

-- The purchase call comes first in the click; before it only plain checks (see the file header).
local function Buy()
	local state = inspecting
	if not (state and state.offer) or state.buying then return end
	local offer = state.offer
	if GetMoney() - offer.total < PC.db.rapidFire.minBalance then return end
	if offer.kind == "item" then
		C_AuctionHouse.PlaceBid(offer.auctionID, offer.total)
	else
		C_AuctionHouse.StartCommoditiesPurchase(offer.itemID, offer.quantity)
	end
	state.buying = true
	buyButton:SetEnabled(false)
	dialog.note:SetText("Buying...")
	C_Timer.After(RESULT_TIMEOUT, function()
		if inspecting == state and not state.done then
			Failed("no answer from the Auction House; check your bags and mail.")
		end
	end)
end

PC:RegisterEvent("COMMODITY_PRICE_UPDATED", function(_, totalPrice)
	local state = inspecting
	if not (state and state.buying and not state.confirmed and state.offer.kind == "commodity") then return end
	if totalPrice <= state.offer.total and GetMoney() - totalPrice >= PC.db.rapidFire.minBalance then
		state.confirmed = true
		C_AuctionHouse.ConfirmCommoditiesPurchase(state.offer.itemID, state.offer.quantity)
	else
		Failed(string.format("not bought: it would now cost %s, more than offered (%s).", PC:FormatMoney(totalPrice),
			PC:FormatMoney(state.offer.total)))
	end
end)

PC:RegisterEvent("COMMODITY_PRICE_UNAVAILABLE", function() Failed("not bought: no longer available.") end)
PC:RegisterEvent("COMMODITY_PURCHASE_FAILED", function() Failed("the purchase failed.") end)
PC:RegisterEvent("COMMODITY_PURCHASE_SUCCEEDED", function()
	local state = inspecting
	if state and state.buying and not state.done and state.offer.kind == "commodity" then Bought() end
end)
PC:RegisterEvent("AUCTION_HOUSE_PURCHASE_COMPLETED", function(auctionID)
	local state = inspecting
	if state and state.buying and not state.done and state.offer.kind == "item" and state.offer.auctionID == auctionID then
		Bought()
	end
end)
PC:RegisterEvent("AUCTION_HOUSE_SHOW_ERROR", function()
	Failed("not bought: the Auction House refused (someone may have been faster).")
end)
for _, event in ipairs({ "ADDON_ACTION_BLOCKED", "ADDON_ACTION_FORBIDDEN" }) do
	PC:RegisterEvent(event, function(addon)
		if addon == ADDON_NAME then Failed("Blizzard blocked the purchase.") end
	end)
end

local function CreateDialog()
	dialog = CreateFrame("Frame", "ProfitCraftOnSaleBuy", UIParent, "BasicFrameTemplateWithInset")
	dialog:SetSize(380, 170)
	dialog:SetFrameStrata("DIALOG")
	dialog:SetClampedToScreen(true)
	dialog:SetMovable(true)
	dialog:EnableMouse(true)
	dialog:RegisterForDrag("LeftButton")
	dialog:SetScript("OnDragStart", dialog.StartMoving)
	dialog:SetScript("OnDragStop", dialog.StopMovingOrSizing)
	dialog:Hide()
	dialog.TitleText:SetText("ProfitCraft On Sale")
	dialog.icon = dialog:CreateTexture(nil, "ARTWORK")
	dialog.icon:SetSize(32, 32)
	dialog.icon:SetPoint("TOPLEFT", 14, -32)
	dialog.title = dialog:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
	dialog.title:SetPoint("TOPLEFT", dialog.icon, "TOPRIGHT", 8, 0)
	dialog.title:SetPoint("RIGHT", -12, 0)
	dialog.title:SetJustifyH("LEFT")
	dialog.text = dialog:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	dialog.text:SetPoint("TOPLEFT", dialog.title, "BOTTOMLEFT", 0, -4)
	dialog.note = dialog:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
	dialog.note:SetPoint("TOPLEFT", dialog.text, "BOTTOMLEFT", 0, -6)
	dialog.note:SetJustifyH("LEFT")
	buyButton = CreateFrame("Button", nil, dialog, "UIPanelButtonTemplate")
	buyButton:SetSize(160, 30)
	buyButton:SetPoint("BOTTOMLEFT", 20, 12)
	buyButton:SetText("Buy")
	buyButton:SetScript("OnClick", Buy)  -- no error catcher in between: the purchase must start straight from the click
	local cancel = Button(dialog, "Cancel", 120)
	cancel:SetPoint("BOTTOMRIGHT", -20, 16)
	cancel:SetScript("OnClick", function() PC:Call("on sale cancel", CloseDialog) end)
	dialog.CloseButton:SetScript("OnClick", function() PC:Call("on sale cancel", CloseDialog) end)
end

-- Clicking a find: search that item and offer what's still on sale.
function OnSale:Inspect(key)
	local hit = self:GetHit(key)
	if not hit then return end
	if inspecting then CloseDialog() end
	if not dialog then CreateDialog() end
	inspecting = { hit = hit, stackable = self:IsStackable(hit.itemID) }
	local state = inspecting
	OnSale:SetBusy(true)
	dialog:ClearAllPoints()
	dialog:SetPoint("CENTER", panel or UIParent, "CENTER", 0, 60)
	dialog.icon:SetTexture(PC.Items:GetIcon(hit.itemID) or 134400)
	dialog.title:SetText(hit.name or PC.Items:GetName(hit.itemID))
	dialog:Show()
	ShowMessage("Checking the Auction House...")
	OnSale.Send(C_AuctionHouse.SendSearchQuery, hit.itemKey, { { sortOrder = Enum.AuctionHouseSortOrder.Price,
		reverseSort = false } }, true)
	C_Timer.After(ANSWER_TIMEOUT, function()
		if inspecting == state and not state.offer then ShowMessage("No answer from the Auction House. Try again.", true) end
	end)
end

function OnSale:GetDialogState() return inspecting end
function OnSale:GetBuyButton() return buyButton end

---------------------------------------------------------------------------
-- Finds page
---------------------------------------------------------------------------

local Refresh

local function CreateFindRow(index, parent)
	local row = CreateFrame("Button", nil, parent)
	row:SetSize(416, ROW_HEIGHT)
	row:SetPoint("TOPLEFT", 4, -24 - (index - 1) * ROW_HEIGHT)
	local highlight = row:CreateTexture(nil, "HIGHLIGHT")
	highlight:SetAllPoints()
	highlight:SetColorTexture(1, 1, 1, 0.08)
	row.icon = row:CreateTexture(nil, "ARTWORK")
	row.icon:SetSize(16, 16)
	row.icon:SetPoint("LEFT", 2, 0)
	row.name = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	row.name:SetSize(170, ROW_HEIGHT)
	row.name:SetPoint("LEFT", 22, 0)
	row.name:SetJustifyH("LEFT")
	row.price = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	row.price:SetSize(100, ROW_HEIGHT)
	row.price:SetPoint("LEFT", 194, 0)
	row.price:SetJustifyH("RIGHT")
	row.profit = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	row.profit:SetSize(80, ROW_HEIGHT)
	row.profit:SetPoint("LEFT", 298, 0)
	row.profit:SetJustifyH("RIGHT")
	row.age = row:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
	row.age:SetSize(34, ROW_HEIGHT)
	row.age:SetPoint("LEFT", 380, 0)
	row.age:SetJustifyH("RIGHT")
	row:SetScript("OnClick", function(self)
		if self.key then PC:Call("on sale buy", OnSale.Inspect, OnSale, self.key) end
	end)
	row:SetScript("OnEnter", function(self)
		local hit = self.key and OnSale:GetHit(self.key)
		if not hit then return end
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:AddLine(hit.name or "?", 1, 1, 1)
		GameTooltip:AddLine(string.format("%d for %s (cheapest %s)", hit.quantity, PC:FormatMoney(hit.cost),
			PC:FormatMoney(hit.price)))
		GameTooltip:AddLine("Usual price " .. PC:FormatMoney(hit.usual) .. " (" .. (hit.source == "own"
			and "ProfitCraft's history" or "Auctionator's history") .. ")")
		GameTooltip:AddLine("Profit after the AH cut " .. PC:FormatProfit(hit.profit))
		GameTooltip:AddLine("Found by " .. SearchName(hit.from) .. ", " .. Ago(time() - hit.found) .. " ago", 0.7, 0.7, 0.7)
		GameTooltip:AddLine("Click to buy", 0.3, 1, 0.3)
		GameTooltip:Show()
	end)
	row:SetScript("OnLeave", function() GameTooltip:Hide() end)
	return row
end

local function RefreshFinds()
	local list = OnSale:GetHits()
	findOffset = math.max(0, math.min(findOffset, #list - FIND_ROWS))
	findsHeader:SetText(#list == 0 and "No finds yet." or (#list .. (#list == 1 and " find" or " finds")
		.. ", newest first - click one to buy it"))
	for index = 1, FIND_ROWS do
		local row, hit = findRows[index], list[findOffset + index]
		row:SetShown(hit ~= nil)
		if hit then
			row.key = hit.key
			row.icon:SetTexture(PC.Items:GetIcon(hit.itemID) or 134400)
			row.name:SetText(hit.name or PC.Items:GetName(hit.itemID))
			row.price:SetText((hit.quantity > 1 and (hit.quantity .. " x ") or "") .. PC:FormatMoney(hit.price))
			row.profit:SetText(PC:FormatProfit(hit.profit))
			row.age:SetText(Ago(time() - hit.found))
		end
	end
end

---------------------------------------------------------------------------
-- Searches page
---------------------------------------------------------------------------

local ShowView

local function CreateSearchRow(index, parent)
	local row = CreateFrame("Frame", nil, parent)
	row:SetSize(416, ROW_HEIGHT)
	row:SetPoint("TOPLEFT", 4, -24 - (index - 1) * ROW_HEIGHT)
	row.check = CreateFrame("CheckButton", nil, row, "UICheckButtonTemplate")
	row.check:SetSize(20, 20)
	row.check:SetPoint("LEFT")
	row.check:SetScript("OnClick", function(self)
		local search = row.search
		if search then search.on = self:GetChecked() and true or false end
		PC:Send("ONSALE_STATUS")
	end)
	row.name = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	row.name:SetSize(300, ROW_HEIGHT)
	row.name:SetPoint("LEFT", 24, 0)
	row.name:SetJustifyH("LEFT")
	row:EnableMouse(true)
	row:SetScript("OnEnter", function(self)
		if not self.search then return end
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:AddLine(self.search.name, 1, 1, 1)
		GameTooltip:AddLine(OnSale:Describe(self.search.term), nil, nil, nil, true)
		if self.search.group then GameTooltip:AddLine("From list: " .. self.search.group, 0.7, 0.7, 0.7) end
		local _, why = OnSale:BuildQuery(self.search.term)
		if why and next(select(2, OnSale:GetCategories())) then GameTooltip:AddLine("Can't run: " .. why, 1, 0.3, 0.3) end
		GameTooltip:Show()
	end)
	row:SetScript("OnLeave", function() GameTooltip:Hide() end)
	row.edit = Button(row, "Edit", 50)
	row.edit:SetHeight(18)
	row.edit:SetPoint("LEFT", 328, 0)
	row.edit:SetScript("OnClick", function()
		if row.search then
			editing = row.search
			ShowView("edit")
		end
	end)
	row.remove = Button(row, "x", 22)
	row.remove:SetHeight(18)
	row.remove:SetPoint("LEFT", 382, 0)
	row.remove:SetScript("OnClick", function()
		if row.search then PC:Call("on sale remove", OnSale.RemoveSearch, OnSale, row.search.id) end
	end)
	return row
end

local function RefreshSearches()
	local list = OnSale:GetSearches()
	searchOffset = math.max(0, math.min(searchOffset, #list - SEARCH_ROWS))
	for index = 1, SEARCH_ROWS do
		local row, search = searchRows[index], list[searchOffset + index]
		row.search = search
		row:SetShown(search ~= nil)
		if search then
			row.check:SetChecked(search.on)
			row.name:SetText(search.name)
		end
	end
end

---------------------------------------------------------------------------
-- Search editor
---------------------------------------------------------------------------

local editFields = {}

local function EditBox(parent, x, y, width, numeric)
	local box = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
	box:SetSize(width, 20)
	box:SetPoint("TOPLEFT", x, y)
	box:SetAutoFocus(false)
	if numeric then box:SetNumeric(true) end
	box:SetScript("OnTextChanged", function() if editView and editView.preview then editView.UpdatePreview() end end)
	box:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
	return box
end

local function NumberOrNil(box)
	local value = tonumber(box:GetText())
	if value == 0 then return nil end
	return value
end

local function EditedSearch()
	local s = editState.parsed or OnSale:Parse("")
	return { text = strtrim(editFields.text:GetText() or ""), exact = editFields.exact:GetChecked() and true or false,
		category = editState.category or "", minLevel = NumberOrNil(editFields.minLevel),
		maxLevel = NumberOrNil(editFields.maxLevel), minItemLevel = NumberOrNil(editFields.minItemLevel),
		maxItemLevel = NumberOrNil(editFields.maxItemLevel), quality = editState.quality, parts = s.parts }
end

local function AddCategoryChoices(description, list)
	for _, category in ipairs(list) do
		local entry = description:CreateRadio(category.name,
			function() return editState.category == category.path end,
			function()
				editState.category = category.path
				editView.UpdatePreview()
			end)
		if #category.children > 0 then
			-- A submenu's own entry may not be clickable, so it starts with an "All ..." choice.
			entry:CreateRadio("All " .. category.name, function() return editState.category == category.path end,
				function()
					editState.category = category.path
					editView.UpdatePreview()
				end)
			AddCategoryChoices(entry, category.children)
		end
	end
end

local function CreateEditView(parent)
	editView = CreateFrame("Frame", nil, parent)
	editView:SetAllPoints()
	Label(editView, "SEARCH", 8, -6, "GameFontNormal")
	local y = -32
	Label(editView, "Name", 10, y - 4)
	editFields.name = EditBox(editView, 110, y, 290)
	y = y - 30
	Label(editView, "Text", 10, y - 4)
	editFields.text = EditBox(editView, 110, y, 200)
	editFields.exact = CreateFrame("CheckButton", nil, editView, "UICheckButtonTemplate")
	editFields.exact:SetSize(22, 22)
	editFields.exact:SetPoint("TOPLEFT", 318, y + 1)
	editFields.exact.Text:SetText("exact name")
	editFields.exact.Text:SetFontObject("GameFontHighlightSmall")
	editFields.exact:SetScript("OnClick", function() editView.UpdatePreview() end)
	local textHint = editView:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
	textHint:SetPoint("TOPLEFT", 110, y - 22)
	textHint:SetText("Part of the name, e.g. \"of the Knight\". Empty = any name.")
	y = y - 48
	Label(editView, "Category", 10, y - 4)
	local category = CreateFrame("DropdownButton", nil, editView, "WowStyle1DropdownTemplate")
	category:SetWidth(240)
	category:SetPoint("TOPLEFT", 110, y + 2)
	category:SetupMenu(function(_, root)
		root:CreateRadio("Any category", function() return (editState.category or "") == "" end,
			function()
				editState.category = ""
				editView.UpdatePreview()
			end)
		AddCategoryChoices(root, (OnSale:GetCategories()))
	end)
	category:SetDefaultText("Any category")
	editFields.category = category
	y = y - 34
	Label(editView, "Level", 10, y - 4)
	editFields.minLevel = EditBox(editView, 110, y, 40, true)
	Label(editView, "to", 158, y - 4)
	editFields.maxLevel = EditBox(editView, 180, y, 40, true)
	local levelHint = editView:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
	levelHint:SetPoint("TOPLEFT", 230, y - 4)
	levelHint:SetText("required level")
	y = y - 30
	Label(editView, "Item level", 10, y - 4)
	editFields.minItemLevel = EditBox(editView, 110, y, 40, true)
	Label(editView, "to", 158, y - 4)
	editFields.maxItemLevel = EditBox(editView, 180, y, 40, true)
	y = y - 30
	Label(editView, "Quality", 10, y - 4)
	local quality = CreateFrame("DropdownButton", nil, editView, "WowStyle1DropdownTemplate")
	quality:SetWidth(160)
	quality:SetPoint("TOPLEFT", 110, y + 2)
	quality:SetupMenu(function(_, root)
		root:CreateRadio("Any quality", function() return editState.quality == nil end, function()
			editState.quality = nil
			editView.UpdatePreview()
		end)
		for q = 0, 4 do
			root:CreateRadio(OnSale:QualityName(q) .. " or better", function() return editState.quality == q end, function()
				editState.quality = q
				editView.UpdatePreview()
			end)
		end
	end)
	editFields.quality = quality
	y = y - 40
	editView.preview = editView:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	editView.preview:SetPoint("TOPLEFT", 10, y)
	editView.preview:SetPoint("RIGHT", editView, "RIGHT", -10, 0)
	editView.preview:SetJustifyH("LEFT")
	function editView.UpdatePreview()
		local s = EditedSearch()
		editView.preview:SetText("Searches: " .. OnSale:Describe(s) .. (OnSale:IsUsable(s) and ""
			or "\n|cffff5555Needs a text or a category.|r"))
		category:GenerateMenu()
		quality:GenerateMenu()
	end
	local save = Button(editView, "Save", 90)
	save:SetPoint("TOPLEFT", 110, y - 40)
	save:SetScript("OnClick", function()
		PC:Call("on sale save", function()
			local s = EditedSearch()
			if not OnSale:IsUsable(s) then return end
			local term = OnSale:Compose(s)
			local name = strtrim(editFields.name:GetText() or "")
			if editing then
				editing.term = term
				editing.name = name ~= "" and name or OnSale:Describe(s)
				PC:Send("ONSALE_SEARCHES_CHANGED")
			else
				local _, why = OnSale:AddSearch(name, term)
				if why then PC:Print("On Sale: " .. why .. ".") end
			end
			ShowView("searches")
		end)
	end)
	local cancel = Button(editView, "Cancel", 90)
	cancel:SetPoint("LEFT", save, "RIGHT", 10, 0)
	cancel:SetScript("OnClick", function() ShowView("searches") end)
	editView:Hide()
end

local function LoadEditor()
	local parsed = OnSale:Parse(editing and editing.term or "")
	editState = { parsed = parsed, category = parsed.category, quality = parsed.quality }
	editFields.name:SetText(editing and editing.name or "")
	editFields.text:SetText(parsed.text)
	editFields.exact:SetChecked(parsed.exact)
	editFields.minLevel:SetText(parsed.minLevel and tostring(parsed.minLevel) or "")
	editFields.maxLevel:SetText(parsed.maxLevel and tostring(parsed.maxLevel) or "")
	editFields.minItemLevel:SetText(parsed.minItemLevel and tostring(parsed.minItemLevel) or "")
	editFields.maxItemLevel:SetText(parsed.maxItemLevel and tostring(parsed.maxItemLevel) or "")
	editView.UpdatePreview()
end

---------------------------------------------------------------------------
-- Paste page
---------------------------------------------------------------------------

local function CreatePasteView(parent)
	pasteView = CreateFrame("Frame", nil, parent)
	pasteView:SetAllPoints()
	Label(pasteView, "PASTE SEARCHES", 8, -6, "GameFontNormal")
	local help = pasteView:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	help:SetPoint("TOPLEFT", 10, -26)
	help:SetPoint("RIGHT", pasteView, "RIGHT", -10, 0)
	help:SetJustifyH("LEFT")
	help:SetText("One search per line in Auctionator's format (e.g. from an Auctionator shopping list: Export), or a "
		.. "whole exported list \"Name^search^search\". Quality is read as \"this or better\".")
	local scroll = CreateFrame("ScrollFrame", nil, pasteView, "UIPanelScrollFrameTemplate")
	scroll:SetPoint("TOPLEFT", 10, -70)
	scroll:SetPoint("BOTTOMRIGHT", -30, 80)
	local box = CreateFrame("EditBox", nil, scroll)
	box:SetMultiLine(true)
	box:SetAutoFocus(false)
	box:SetFontObject("ChatFontNormal")
	box:SetWidth(380)
	box:SetHeight(300)
	box:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
	scroll:SetScrollChild(box)
	scroll:SetScript("OnMouseDown", function() box:SetFocus() end)
	pasteView.box = box
	local add = Button(pasteView, "Add", 90)
	add:SetPoint("BOTTOMLEFT", 10, 46)
	add:SetScript("OnClick", function()
		PC:Call("on sale paste", function()
			local added, skipped = OnSale:Import(box:GetText())
			PC:Print(string.format("On Sale: %d search%s added%s.", added, added == 1 and "" or "es",
				skipped > 0 and (", " .. skipped .. " skipped (empty, or the list is full)") or ""))
			box:SetText("")
			ShowView("searches")
		end)
	end)
	local cancel = Button(pasteView, "Cancel", 90)
	cancel:SetPoint("LEFT", add, "RIGHT", 10, 0)
	cancel:SetScript("OnClick", function() ShowView("searches") end)
	pasteView:Hide()
end

---------------------------------------------------------------------------
-- Panel
---------------------------------------------------------------------------

local currentView = "finds"

function ShowView(name)
	currentView = name
	findsView:SetShown(name == "finds")
	searchesView:SetShown(name == "searches")
	editView:SetShown(name == "edit")
	pasteView:SetShown(name == "paste")
	if name == "edit" then LoadEditor() end
	Refresh()
end

local function UpdateStatus()
	if not panel then return end
	statusText:SetText(OnSale:GetStatus())
	startButton:SetText(OnSale:IsRunning() and "Stop" or "Start")
end

function Refresh()
	if toggleButton then
		local count = #OnSale:GetHits()
		toggleButton:SetText(count > 0 and ("On Sale (" .. count .. ")") or "On Sale")
	end
	if not (panel and panel:IsShown()) then return end
	if currentView == "finds" then RefreshFinds() elseif currentView == "searches" then RefreshSearches() end
	UpdateStatus()
end

local function Wheel(view, getOffset, setOffset)
	view:EnableMouseWheel(true)
	view:SetScript("OnMouseWheel", function(_, delta)
		setOffset(math.max(0, getOffset() - delta))
		Refresh()
	end)
end

local function CreatePanel()
	panel = PC:CreateWindow("ProfitCraftOnSale", AuctionHouseFrame, 440, 580, "ProfitCraft On Sale")
	panel:SetPoint("TOPLEFT", AuctionHouseFrame, "TOPRIGHT", 2, 0)
	local inset = panel.Inset

	local content = CreateFrame("Frame", nil, inset)
	content:SetPoint("TOPLEFT", 0, -30)
	content:SetPoint("BOTTOMRIGHT", 0, 34)
	local findsTab = Button(inset, "Finds", 90)
	findsTab:SetPoint("TOPLEFT", 6, -4)
	findsTab:SetScript("OnClick", function() ShowView("finds") end)
	local searchesTab = Button(inset, "Searches", 90)
	searchesTab:SetPoint("LEFT", findsTab, "RIGHT", 6, 0)
	searchesTab:SetScript("OnClick", function() ShowView("searches") end)

	findsView = CreateFrame("Frame", nil, content)
	findsView:SetAllPoints()
	findsHeader = Label(findsView, "", 8, -6)
	for index = 1, FIND_ROWS do findRows[index] = CreateFindRow(index, findsView) end
	Wheel(findsView, function() return findOffset end, function(v) findOffset = v end)

	searchesView = CreateFrame("Frame", nil, content)
	searchesView:SetAllPoints()
	Label(searchesView, "On: searched in turn while On Sale runs. Hover for details.", 8, -6)
	for index = 1, SEARCH_ROWS do searchRows[index] = CreateSearchRow(index, searchesView) end
	Wheel(searchesView, function() return searchOffset end, function(v) searchOffset = v end)
	local new = Button(searchesView, "New search", 110)
	new:SetPoint("BOTTOMLEFT", 8, 6)
	new:SetScript("OnClick", function()
		editing = nil
		ShowView("edit")
	end)
	local paste = Button(searchesView, "Paste searches", 120)
	paste:SetPoint("LEFT", new, "RIGHT", 8, 0)
	paste:SetScript("OnClick", function() ShowView("paste") end)

	CreateEditView(content)
	CreatePasteView(content)

	startButton = Button(inset, "Start", 80)
	startButton:SetPoint("BOTTOMRIGHT", -8, 8)
	startButton:SetScript("OnClick", function()
		PC:Call("on sale start", function()
			if OnSale:IsRunning() then OnSale:Stop() else OnSale:Start() end
		end)
	end)
	statusText = inset:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	statusText:SetPoint("LEFT", inset, "BOTTOMLEFT", 10, 19)
	statusText:SetPoint("RIGHT", startButton, "LEFT", -10, 0)
	statusText:SetJustifyH("LEFT")
	panel:HookScript("OnShow", Refresh)
	ShowView(#OnSale:GetSearches() == 0 and "searches" or "finds")
end

local function CreateToggle()
	toggleButton = Button(AuctionHouseFrame, "On Sale", 100)
	toggleButton:SetPoint("BOTTOMRIGHT", AuctionHouseFrame, "BOTTOMRIGHT", -90, 4)  -- left of RapidFire's button
	toggleButton:SetScript("OnClick", function()
		PC:Call("on sale panel", function()
			if not panel then CreatePanel() end
			panel:SetShown(not panel:IsShown())
			if panel:IsShown() then PC:Send("AH_PANEL_SHOWN", "onsale") end
		end)
	end)
end

---------------------------------------------------------------------------
-- Screen glow: Blizzard's low-health glow (Forever source: Blizzard_FrameXML/Mainline/LowHealthFrame.xml,
-- texture Interface\FullScreenTextures\LowHealth, additive), tinted gold so it can't be taken for low health. It
-- pulses after a new find until the mouse is over the AH window, the On Sale panel or the buy dialog.
---------------------------------------------------------------------------

local glow

local function StopGlow()
	if glow then glow:Hide() end
end

local function StartGlow()
	if not Settings().onSaleGlow then return end
	if not glow then
		glow = CreateFrame("Frame", nil, UIParent)
		glow:SetAllPoints(UIParent)
		glow:SetFrameStrata("FULLSCREEN")
		glow:EnableMouse(false)
		local texture = glow:CreateTexture(nil, "BACKGROUND")
		texture:SetAllPoints()
		texture:SetTexture("Interface\\FullScreenTextures\\LowHealth")
		texture:SetBlendMode("ADD")
		texture:SetVertexColor(1, 0.82, 0)
		glow.elapsed = 0
		glow:SetScript("OnUpdate", function(self, elapsed)
			self.elapsed = self.elapsed + elapsed
			self:SetAlpha(0.55 + 0.45 * math.sin(self.elapsed * 4))
			for _, frame in ipairs({ AuctionHouseFrame, panel, dialog }) do
				if frame and frame:IsVisible() and frame:IsMouseOver() then
					StopGlow()
					return
				end
			end
		end)
	end
	glow.elapsed = 0
	glow:Show()
end

function OnSale:IsGlowing() return glow ~= nil and glow:IsShown() end

PC:Listen("ONSALE_NEW_FIND", StartGlow)
PC:Listen("ONSALE_CHANGED", function()
	if #OnSale:GetHits() == 0 then StopGlow() end
end)

PC:RegisterEvent("AUCTION_HOUSE_SHOW", function()
	if AuctionHouseFrame and not toggleButton then CreateToggle() end
	Refresh()
end)

PC:RegisterEvent("AUCTION_HOUSE_CLOSED", function()
	if inspecting then CloseDialog() end
	StopGlow()
end)

PC:Listen("AH_PANEL_SHOWN", function(which)
	if which ~= "onsale" and panel then panel:Hide() end
end)

PC:Listen("ONSALE_CHANGED", Refresh)
PC:Listen("ONSALE_SEARCHES_CHANGED", Refresh)
PC:Listen("ONSALE_STATUS", UpdateStatus)
PC:Listen("ITEM_DATA_CHANGED", Refresh)
