-- ProfitCraft: side panel
-- Compact ranked list of the open profession's recipes, next to Blizzard's profession window
-- (DESIGN.md section 7). Only redraws from stored results; never recalculates.

local _, PC = ...

local Panel = {}
PC.Panel = Panel

local WIDTH = 320
local ROW_HEIGHT = 22
local MODES = { "craft", "stack", "disenchant" }
local MODE_LABEL = { craft = "Per craft", stack = "Per stack", disenchant = "Disenchant" }
local MODE_HELP = {
	craft = "Profit of one craft, selling the product on the AH.",
	stack = "Profit of one full stack of the product, selling it on the AH.",
	disenchant = "Profit of one craft if you disenchant the product and sell the materials "
		.. "(Auctionator's disenchant estimate).",
}

local frame, scrollBox, modeButton, statusText

local function ShowRowTooltip(row)
	local result = row.result
	if not result then return end
	local recipe = result.recipe
	GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
	GameTooltip:AddLine(recipe.name, 1, 1, 1)
	if recipe.quantityMin ~= recipe.quantityMax then
		GameTooltip:AddLine(string.format("Makes %d-%d (counted as %s)", recipe.quantityMin, recipe.quantityMax,
			tostring(result.quantity)), 0.8, 0.8, 0.8)
	elseif recipe.quantityMin > 1 then
		GameTooltip:AddLine("Makes " .. recipe.quantityMin, 0.8, 0.8, 0.8)
	end
	if result.complete then
		GameTooltip:AddDoubleLine("Profit per craft", PC:FormatMoney(result.profitCraft))
		if result.stackSize and result.stackSize > 1 then
			GameTooltip:AddDoubleLine("Profit per stack (" .. result.stackSize .. ")", PC:FormatMoney(result.profitStack))
		end
		GameTooltip:AddDoubleLine("AH price per item", PC:FormatMoney(result.salePrice), 0.8, 0.8, 0.8)
	end
	if result.cost then
		GameTooltip:AddDoubleLine("Reagent cost per craft", PC:FormatMoney(result.cost), 0.8, 0.8, 0.8)
	end
	if result.profitDisenchant then
		GameTooltip:AddDoubleLine("Craft and disenchant", PC:FormatMoney(result.profitDisenchant))
		GameTooltip:AddDoubleLine("  Disenchant estimate per item", PC:FormatMoney(result.disenchantValue), 0.8, 0.8, 0.8)
	end
	if #result.missing > 0 then
		GameTooltip:AddLine("No price for:", 1, 0.5, 0.5)
		for _, itemID in ipairs(result.missing) do
			GameTooltip:AddLine("  " .. PC.Items:GetName(itemID), 1, 0.5, 0.5)
		end
	end
	GameTooltip:AddLine("Click to show this recipe.", 0.5, 0.7, 1)
	GameTooltip:Show()
end

local function ProfitText(result, mode)
	if mode == "disenchant" then
		if result.profitDisenchant then return PC:FormatMoney(result.profitDisenchant) end
		if result.cost and not result.disenchantValue then return "|cff888888can't disenchant|r" end
		return "|cff888888no price|r"
	end
	if not result.complete then return "|cff888888no price|r" end
	if mode == "stack" then
		if not result.profitStack then return "|cff888888?|r" end
		local size = result.stackSize or 1
		local prefix = size > 1 and ("|cffaaaaaax" .. size .. "|r  ") or ""
		return prefix .. PC:FormatMoney(result.profitStack)
	end
	return PC:FormatMoney(result.profitCraft)
end

local function InitRow(row, result)
	if not row.created then
		row.created = true
		row:SetHeight(ROW_HEIGHT)
		row.icon = row:CreateTexture(nil, "ARTWORK")
		row.icon:SetSize(ROW_HEIGHT - 4, ROW_HEIGHT - 4)
		row.icon:SetPoint("LEFT", 2, 0)
		row.profit = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
		row.profit:SetPoint("RIGHT", -4, 0)
		row.profit:SetJustifyH("RIGHT")
		row.name = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
		row.name:SetPoint("LEFT", row.icon, "RIGHT", 4, 0)
		row.name:SetPoint("RIGHT", row.profit, "LEFT", -6, 0)
		row.name:SetJustifyH("LEFT")
		row.name:SetWordWrap(false)
		local highlight = row:CreateTexture(nil, "HIGHLIGHT")
		highlight:SetAllPoints()
		highlight:SetColorTexture(1, 1, 1, 0.08)
		row:SetScript("OnEnter", function(self) PC:Call("row tooltip", ShowRowTooltip, self) end)
		row:SetScript("OnLeave", function() GameTooltip:Hide() end)
		row:SetScript("OnClick", function(self)
			if self.result then PC:Call("open recipe", C_TradeSkillUI.OpenRecipe, self.result.recipe.recipeID) end
		end)
	end
	row.result = result
	row.icon:SetTexture(result.recipe.icon)
	row.name:SetText(result.recipe.name)
	row.profit:SetText(ProfitText(result, PC.db.settings.profitMode))
end

function Panel:Refresh()
	if not (frame and frame:IsShown()) then return end
	local mode = PC.db.settings.profitMode
	modeButton:SetText(MODE_LABEL[mode] or mode)
	local list = PC.Profit:GetRanked(mode)
	scrollBox:SetDataProvider(CreateDataProvider(list), ScrollBoxConstants.RetainScrollPosition)
	if not PC.Auctionator:IsAvailable() then
		statusText:SetText("|cffff8888Auctionator not found: no prices.|r")
	elseif #list == 0 then
		statusText:SetText("Reading recipes...")
	else
		local field = PC.Profit.PROFIT_FIELD[mode]
		local priced = 0
		for _, result in ipairs(list) do
			if result[field] then priced = priced + 1 end
		end
		statusText:SetText(string.format("%s: %d recipes, %d priced", PC.Recipes.professionName or "?", #list, priced))
	end
end

-- Forever (only) has a column of profession tabs on the window's right edge (Camelot ProfessionsFrame.xml:
-- ProfessionsOverviewTab and Professions1Tab..7Tab, anchored to its TOPRIGHT); the panel goes right of them.
local function TabColumnWidth()
	local tab = ProfessionsFrame.ProfessionsOverviewTab
	return tab and tab.GetWidth and tab:GetWidth() or 0
end

-- The window can also show the professions overview (BookPage); the panel only belongs with a recipe list.
local function BookPageShown()
	local page = ProfessionsFrame and ProfessionsFrame.BookPage
	return page and page:IsShown()
end

local function ShouldShow()
	return PC.db.settings.panelShown and PC.Recipes.isOpen and ProfessionsFrame and ProfessionsFrame:IsShown()
		and not BookPageShown()
end

local function Create()
	frame = CreateFrame("Frame", "ProfitCraftPanel", ProfessionsFrame, "BasicFrameTemplateWithInset")
	frame:SetSize(WIDTH, ProfessionsFrame:GetHeight())
	frame:SetPoint("TOPLEFT", ProfessionsFrame, "TOPRIGHT", TabColumnWidth() + 4, 0)
	frame.TitleText:SetText("ProfitCraft")
	frame.CloseButton:SetScript("OnClick", function()
		PC:SetSetting("panelShown", false)
		frame:Hide()
	end)

	modeButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
	modeButton:SetSize(96, 22)
	modeButton:SetPoint("TOPLEFT", 10, -28)
	modeButton:SetScript("OnClick", function()
		local current = PC.db.settings.profitMode
		local nextMode = MODES[1]
		for i, mode in ipairs(MODES) do
			if mode == current then nextMode = MODES[i % #MODES + 1] end
		end
		PC:SetSetting("profitMode", nextMode)
	end)
	modeButton:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:AddLine(MODE_HELP[PC.db.settings.profitMode] or "", 1, 1, 1, true)
		GameTooltip:AddLine("Click to switch: per craft, per stack, disenchant.", 0.5, 0.7, 1, true)
		GameTooltip:Show()
	end)
	modeButton:SetScript("OnLeave", function() GameTooltip:Hide() end)

	local bagsButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
	bagsButton:SetSize(70, 22)
	bagsButton:SetPoint("TOPRIGHT", -10, -28)
	bagsButton:SetText("Bags")
	bagsButton:SetScript("OnClick", function() PC:Send("TOGGLE_BAGS") end)
	bagsButton:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:AddLine("Disenchant value of the items in your bags.", 1, 1, 1, true)
		GameTooltip:Show()
	end)
	bagsButton:SetScript("OnLeave", function() GameTooltip:Hide() end)

	local settingsButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
	settingsButton:SetSize(70, 22)
	settingsButton:SetPoint("RIGHT", bagsButton, "LEFT", -4, 0)
	settingsButton:SetText("Settings")
	settingsButton:SetScript("OnClick", function() PC:Send("TOGGLE_SETTINGS") end)

	statusText = frame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
	statusText:SetPoint("BOTTOMLEFT", 12, 10)
	statusText:SetPoint("BOTTOMRIGHT", -12, 10)
	statusText:SetJustifyH("LEFT")
	statusText:SetWordWrap(false)

	scrollBox = CreateFrame("Frame", nil, frame, "WowScrollBoxList")
	scrollBox:SetPoint("TOPLEFT", 8, -56)
	scrollBox:SetPoint("BOTTOMRIGHT", -24, 28)
	local scrollBar = CreateFrame("EventFrame", nil, frame, "MinimalScrollBar")
	scrollBar:SetPoint("TOPLEFT", scrollBox, "TOPRIGHT", 6, 0)
	scrollBar:SetPoint("BOTTOMLEFT", scrollBox, "BOTTOMRIGHT", 6, 0)
	local view = CreateScrollBoxListLinearView()
	view:SetElementExtent(ROW_HEIGHT)
	view:SetElementInitializer("Button", function(row, result)
		PC:Call("panel row", InitRow, row, result)
	end)
	ScrollUtil.InitScrollBoxListWithScrollBar(scrollBox, scrollBar, view)

	frame:SetScript("OnShow", function() PC:Call("panel show", Panel.Refresh, Panel) end)

	-- Hide over the overview page, come back when it closes (HookScript adds to Blizzard's handlers).
	if ProfessionsFrame.BookPage then
		ProfessionsFrame.BookPage:HookScript("OnShow", function() frame:Hide() end)
		ProfessionsFrame.BookPage:HookScript("OnHide", function()
			PC:Call("panel after overview", function() Panel:Update() end)
		end)
	end
end

-- Shows or hides the panel to match the current state.
function Panel:Update()
	if not ShouldShow() then
		if frame then frame:Hide() end
		return
	end
	if not frame then Create() end
	if frame:IsShown() then
		self:Refresh()
	else
		frame:Show()  -- OnShow refreshes
	end
end

PC:Listen("PROFESSION_OPENED", function() Panel:Update() end)
PC:Listen("PROFESSION_CLOSED", function() Panel:Update() end)

PC:Listen("TOGGLE_PANEL", function()
	if not (PC.Recipes.isOpen and ProfessionsFrame and ProfessionsFrame:IsShown()) then
		PC:Print("open a profession window first.")
		return
	end
	PC:SetSetting("panelShown", not (frame and frame:IsShown()))
	Panel:Update()
end)

PC:Listen("RESULTS_CHANGED", function() Panel:Refresh() end)
PC:Listen("SETTINGS_CHANGED", function(key)
	if key == "profitMode" then Panel:Refresh() end
end)
