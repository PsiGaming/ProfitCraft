-- ProfitCraft: money window
-- A small one-row window: your money on the right and up to MAX_CURRENCIES tracked currencies to its left. The
-- window is anchored by its right edge, so it grows leftwards as currencies are added. Off by default (setting
-- moneyWindow; settings window or /pcraft money). Right-click anywhere on it: add or remove a currency, lock or
-- unlock its position, background colour with opacity, hide. Saved account-wide in ProfitCraftDB.money (one list
-- for every character, Sylice 2026-11-17); a tracked currency the character doesn't have shows 0.
-- Forever source: currency list C_CurrencyInfo.GetCurrencyListSize / GetCurrencyListInfo (as Blizzard's own
-- Currency tab, Blizzard_TokenUI/Camelot); right-click menu MenuUtil.CreateContextMenu (Blizzard_Menu; used by
-- Forever's character window); colour picker ColorPickerFrame:SetupColorPickerAndShow with hasOpacity
-- (Blizzard_ColorPickerFrame/Mainline: "opacity" is the alpha, read back with GetColorAlpha).

local _, PC = ...

local MAX_CURRENCIES = 5
local HEIGHT, PADDING, GAP, ICON_SIZE = 22, 8, 12, 14
local UNKNOWN_ICON = 134400  -- question mark

local frame, moneyText
local entries = {}  -- one per tracked currency, reused

local function Data() return PC.db.money end

local function ApplyPosition()
	local data = Data()
	frame:ClearAllPoints()
	if data.x and data.y then
		frame:SetPoint("TOPRIGHT", UIParent, "BOTTOMLEFT", data.x, data.y)
	else
		frame:SetPoint("TOPRIGHT", UIParent, "CENTER", 150, 0)
	end
end

local function ApplyBackground()
	local bg = Data().bg
	frame.bg:SetColorTexture(bg.r, bg.g, bg.b, bg.a)
end

local function CurrencyLabel(icon, name, quantity)
	return string.format("|T%s:%d:%d|t %s (%s)", icon or UNKNOWN_ICON, ICON_SIZE, ICON_SIZE, name or "?",
		BreakUpLargeNumbers(quantity or 0))
end

local function CreateEntry()
	local entry = CreateFrame("Frame", nil, frame)
	entry:SetHeight(HEIGHT)
	entry.icon = entry:CreateTexture(nil, "ARTWORK")
	entry.icon:SetSize(ICON_SIZE, ICON_SIZE)
	entry.icon:SetPoint("LEFT")
	entry.text = entry:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	entry.text:SetPoint("LEFT", entry.icon, "RIGHT", 2, 0)
	entry:EnableMouse(true)
	entry:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_TOP")
		GameTooltip:SetCurrencyByID(self.currencyID)
		GameTooltip:Show()
	end)
	entry:SetScript("OnLeave", function() GameTooltip:Hide() end)
	-- Clicks and drags on an entry act on the window.
	entry:RegisterForDrag("LeftButton")
	for _, script in ipairs({ "OnMouseUp", "OnDragStart", "OnDragStop" }) do
		entry:SetScript(script, function(_, ...) frame:GetScript(script)(frame, ...) end)
	end
	return entry
end

-- Money on the right, tracked currencies leftwards from it; the window's width follows.
local function Layout()
	moneyText:SetText(PC:FormatMoney(GetMoney()))
	local x = PADDING + moneyText:GetStringWidth()
	local currencies = Data().currencies
	for i, currencyID in ipairs(currencies) do
		entries[i] = entries[i] or CreateEntry()
		local entry = entries[i]
		local info = C_CurrencyInfo.GetCurrencyInfo(currencyID)
		entry.currencyID = currencyID
		entry.icon:SetTexture(info and info.iconFileID or UNKNOWN_ICON)
		entry.text:SetText(BreakUpLargeNumbers(info and info.quantity or 0))
		local width = ICON_SIZE + 2 + entry.text:GetStringWidth()
		entry:SetWidth(width)
		entry:ClearAllPoints()
		entry:SetPoint("RIGHT", frame, "RIGHT", -(x + GAP), 0)
		entry:Show()
		x = x + GAP + width
	end
	for i = #currencies + 1, #entries do entries[i]:Hide() end
	frame:SetSize(x + PADDING, HEIGHT)
end

-- Currencies in the character's Currency tab that aren't tracked yet. Sections collapsed in that tab don't list
-- their currencies (the game leaves them out of the list); ProfitCraft doesn't open them, to leave the tab as it is.
local function AvailableCurrencies()
	local tracked = {}
	for _, currencyID in ipairs(Data().currencies) do tracked[currencyID] = true end
	local list, collapsed = {}, false
	for i = 1, C_CurrencyInfo.GetCurrencyListSize() do
		local info = C_CurrencyInfo.GetCurrencyListInfo(i)
		if info and info.isHeader then
			if not info.isHeaderExpanded then collapsed = true end
		elseif info and info.currencyID and not tracked[info.currencyID] then
			list[#list + 1] = info
		end
	end
	return list, collapsed
end

local function SetCurrencies(change)
	PC:Call("money window", function()
		change(Data().currencies)
		Layout()
	end)
end

local function OpenColorPicker()
	local bg = Data().bg
	local function SetBackground(r, g, b, a)
		bg.r, bg.g, bg.b, bg.a = r, g, b, a
		ApplyBackground()
	end
	local function Changed()
		PC:Call("money background", function()
			local r, g, b = ColorPickerFrame:GetColorRGB()
			SetBackground(r, g, b, ColorPickerFrame:GetColorAlpha())
		end)
	end
	ColorPickerFrame:SetupColorPickerAndShow({
		r = bg.r, g = bg.g, b = bg.b, opacity = bg.a, hasOpacity = true,
		swatchFunc = Changed, opacityFunc = Changed,
		cancelFunc = function(previous)
			PC:Call("money background", SetBackground, previous.r, previous.g, previous.b, previous.a)
		end,
	})
end

local function OpenMenu()
	MenuUtil.CreateContextMenu(frame, function(_, root)
		local data = Data()
		root:CreateTitle("ProfitCraft money")

		local full = #data.currencies >= MAX_CURRENCIES
		local add = root:CreateButton(full and ("Add currency (limit of " .. MAX_CURRENCIES .. ")") or "Add currency")
		if full then
			add:SetEnabled(false)
		else
			local list, collapsed = AvailableCurrencies()
			for _, info in ipairs(list) do
				add:CreateButton(CurrencyLabel(info.iconFileID, info.name, info.quantity), function()
					SetCurrencies(function(currencies) table.insert(currencies, info.currencyID) end)
				end)
			end
			if #list == 0 then add:CreateTitle("No other currencies") end
			if collapsed then add:CreateTitle("Collapsed sections of your Currency tab are not listed") end
			if #list > 20 then add:SetScrollMode(400) end
		end

		local remove = root:CreateButton("Remove currency")
		remove:SetEnabled(#data.currencies > 0)
		for i, currencyID in ipairs(data.currencies) do
			local info = C_CurrencyInfo.GetCurrencyInfo(currencyID)
			remove:CreateButton(CurrencyLabel(info and info.iconFileID, info and info.name, info and info.quantity),
				function() SetCurrencies(function(currencies) table.remove(currencies, i) end) end)
		end

		root:CreateDivider()
		root:CreateButton(data.locked and "Unlock position" or "Lock position", function()
			data.locked = not data.locked
		end)
		root:CreateButton("Background colour...", function() PC:Call("money background", OpenColorPicker) end)
		root:CreateButton("Hide (/pcraft money shows it again)", function()
			PC:SetSetting("moneyWindow", false)
		end)
	end)
end

local function Create()
	frame = CreateFrame("Frame", nil, UIParent)
	frame:SetFrameStrata("MEDIUM")
	frame:SetClampedToScreen(true)
	frame:SetMovable(true)
	frame:EnableMouse(true)
	frame:RegisterForDrag("LeftButton")
	frame.bg = frame:CreateTexture(nil, "BACKGROUND")
	frame.bg:SetAllPoints()
	moneyText = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	moneyText:SetPoint("RIGHT", -PADDING, 0)

	frame:SetScript("OnDragStart", function(self)
		if not Data().locked then self:StartMoving() end
	end)
	frame:SetScript("OnDragStop", function(self)
		self:StopMovingOrSizing()
		local data = Data()
		data.x, data.y = self:GetRight(), self:GetTop()
		ApplyPosition()  -- back to a right-edge anchor, so the window keeps growing leftwards
	end)
	frame:SetScript("OnMouseUp", function(_, button)
		if button == "RightButton" then PC:Call("money window menu", OpenMenu) end
	end)

	ApplyPosition()
	ApplyBackground()
end

local function Refresh()
	local shown = PC.db.settings.moneyWindow
	if shown and not frame then Create() end
	if not frame then return end
	frame:SetShown(shown)
	if shown then Layout() end
end

local function Update()
	if frame and frame:IsShown() then Layout() end
end

PC:RegisterEvent("PLAYER_LOGIN", Refresh)
PC:RegisterEvent("PLAYER_MONEY", Update)
PC:RegisterEvent("CURRENCY_DISPLAY_UPDATE", Update)
PC:Listen("SETTINGS_CHANGED", function(key)
	if key == "moneyWindow" then Refresh() end
end)
