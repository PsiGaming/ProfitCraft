-- ProfitCraft: settings
-- One list of options, shown in two places built from it:
--   * ProfitCraft's own movable window (/pcraft settings, the side panel's "Settings" button). Closing it just
--     closes it; it never goes through Blizzard's settings panel, whose close always reopens the game menu
--     (Forever source: SettingsPanelMixin:TransitionBackOpeningPanel -> ToggleGameMenu).
--   * The same page under Blizzard's Options > AddOns > ProfitCraft, for people who look there (closing that
--     returns to the game menu, which is where they came from).
-- Each page re-reads the settings when shown and after any change, so the two never disagree.
-- Forever source for the Blizzard side: Blizzard_Settings_Shared/Blizzard_Settings.lua
-- (Settings.RegisterCanvasLayoutCategory, Settings.RegisterAddOnCategory).

local _, PC = ...

-- In display order; { divider = true } draws a line between sections.
local OPTIONS = {
	{ key = "staleDays", slider = { min = 0, max = 4 }, label = "Warn when AH prices are older than",
		help = "The side panel shows a banner asking you to scan the Auction House with Auctionator once prices "
			.. "are this old. Off hides that warning (the \"Auctionator is required\" and \"No AH prices yet\" "
			.. "warnings still show)." },
	{ key = "tooltipDisenchant", label = "Disenchant estimate in item tooltips",
		help = "Adds the estimated disenchant value (average over many disenchants, priced at AH prices) and "
			.. "what the item can disenchant into to item tooltips. Not yet confirmed for Forever." },
	{ divider = true },
	-- One choice for both counts: Blizzard's own (game setting displayFreeBagSlots, the switch behind Blizzard's
	-- "Show Free Bag Space" in Options > Interface) and ProfitCraft's split (setting freeSlots, UI/BagSpace.lua).
	{ key = "freeSlots", cvar = "displayFreeBagSlots", label = "Free bag slots",
		help = "Free slot counts on the bag bar. Blizzard's count is one total that includes the reagent bag; "
			.. "ProfitCraft's splits it as (reagent bag|normal bags), in the order the bags sit on the bar.",
		choices = {
			{ label = "Off", cvarOn = false, mode = "none", help = "No free slot counts." },
			{ label = "Blizzard only", cvarOn = true, mode = "none",
				help = "Blizzard's total on the backpack button (the same switch as Blizzard's \"Show Free Bag "
					.. "Space\", Options > Interface)." },
			{ label = "ProfitCraft + Blizzard", cvarOn = true, mode = "reagent",
				help = "Blizzard's total on the backpack button, and ProfitCraft's (reagent|normal) split on the "
					.. "reagent bag button." },
			{ label = "ProfitCraft only", cvarOn = true, mode = "backpack",
				help = "ProfitCraft's (reagent|normal) split on the backpack button, in place of Blizzard's total. "
					.. "Blizzard's own option stays on underneath, so its count comes back if ProfitCraft is "
					.. "disabled or removed." },
		} },
	{ divider = true },
	{ key = "debug", label = "Debug mode: show errors in chat",
		help = "Errors are always logged (/pcraft errors). With debug mode on they are also printed in chat as "
			.. "they happen." },
}

local ROW_SPACING = 30
local SLIDER_ROWS = 2     -- a slider or dropdown takes two rows: its label, then the control
local DIVIDER_ROWS = 0.5  -- a divider line takes half a row

local function RowsUsed(option)
	if option.divider then return DIVIDER_ROWS end
	return (option.slider or option.choices) and SLIDER_ROWS or 1
end

local function TotalRows()
	local rows = 0
	for _, option in ipairs(OPTIONS) do rows = rows + RowsUsed(option) end
	return rows
end

local function DaysText(value)
	value = math.floor(value + 0.5)
	if value == 0 then return "Off" end
	return value == 1 and "1 day" or (value .. " days")
end

local pages = {}  -- every page built, for syncing
local window

local function GetValue(option)
	if option.cvar then return C_CVar.GetCVarBool(option.cvar) and true or false end
	return PC.db.settings[option.key] and true or false
end

local function SetValue(option, value)
	if option.cvar then
		C_CVar.SetCVar(option.cvar, value and "1" or "0")
	else
		PC:SetSetting(option.key, value)
	end
end

-- A dropdown choice is selected when ProfitCraft's setting matches and, where ProfitCraft draws nothing, when
-- Blizzard's game setting matches too (that tells "Off" and "Blizzard only" apart).
local function IsChoiceSelected(option, choice)
	if PC.db.settings[option.key] ~= choice.mode then return false end
	return choice.mode ~= "none" or C_CVar.GetCVarBool(option.cvar) == choice.cvarOn
end

local function SelectChoice(option, choice)
	C_CVar.SetCVar(option.cvar, choice.cvarOn and "1" or "0")
	PC:SetSetting(option.key, choice.mode)
end

-- Makes the checkboxes, sliders and dropdowns reflect the saved settings (and Blizzard's, for mirrored ones).
local function Sync(page)
	for option, box in pairs(page.checkboxes) do box:SetChecked(GetValue(option)) end
	for option, slider in pairs(page.sliders) do slider:SetValue(PC.db.settings[option.key]) end
	for _, dropdown in pairs(page.dropdowns) do dropdown:GenerateMenu() end
end

local function ShowHelp(owner, option)
	GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
	GameTooltip:AddLine(option.label, 1, 1, 1)
	GameTooltip:AddLine(option.help, nil, nil, nil, true)
	GameTooltip:Show()
end

-- A slider with arrow buttons (Blizzard's MinimalSliderWithSteppersTemplate, as in its own options; Forever
-- source: Blizzard_SharedXML/Shared/Slider/MinimalSlider.lua), with its label on the row above and the value
-- on its right.
local function BuildSlider(page, option, x, y)
	local label = page:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	label:SetPoint("TOPLEFT", x + 4, y - 6)
	label:SetText(option.label)
	local slider = CreateFrame("Frame", nil, page, "MinimalSliderWithSteppersTemplate")
	slider:SetWidth(220)
	slider:SetPoint("TOPLEFT", x + 8, y - ROW_SPACING + 4)
	local range = option.slider
	slider:Init(PC.db.settings[option.key], range.min, range.max, range.max - range.min,
		{ [MinimalSliderWithSteppersMixin.Label.Right] = DaysText })
	slider:RegisterCallback(MinimalSliderWithSteppersMixin.Event.OnValueChanged, function(_, value)
		PC:Call("settings " .. option.key, PC.SetSetting, PC, option.key, math.floor(value + 0.5))
	end, page)
	slider.Slider:HookScript("OnEnter", function(self) ShowHelp(self, option) end)
	slider.Slider:HookScript("OnLeave", function() GameTooltip:Hide() end)
	return slider
end

-- A dropdown (Blizzard's WowStyle1DropdownTemplate, as in the side panel) with its label on the row above.
local function BuildDropdown(page, option, x, y)
	local label = page:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	label:SetPoint("TOPLEFT", x + 4, y - 6)
	label:SetText(option.label)
	local dropdown = CreateFrame("DropdownButton", nil, page, "WowStyle1DropdownTemplate")
	dropdown:SetWidth(200)
	dropdown:SetPoint("TOPLEFT", x + 8, y - ROW_SPACING + 2)
	dropdown:SetupMenu(function(_, rootDescription)
		for _, choice in ipairs(option.choices) do
			local entry = rootDescription:CreateRadio(choice.label,
				function() return IsChoiceSelected(option, choice) end,
				function() PC:Call("settings " .. option.key, SelectChoice, option, choice) end)
			entry:SetTooltip(function(tooltip)
				GameTooltip_SetTitle(tooltip, choice.label)
				GameTooltip_AddNormalLine(tooltip, choice.help)
			end)
		end
	end)
	dropdown:HookScript("OnEnter", function(self) ShowHelp(self, option) end)
	dropdown:HookScript("OnLeave", function() GameTooltip:Hide() end)
	return dropdown
end

local function BuildCheckbox(page, option, x, y)
	local box = CreateFrame("CheckButton", nil, page, "UICheckButtonTemplate")
	box:SetPoint("TOPLEFT", x, y)
	box.Text:SetText(option.label)
	box.Text:SetFontObject("GameFontHighlight")
	box:SetScript("OnClick", function(self)
		PC:Call("settings " .. (option.key or option.cvar), SetValue, option, self:GetChecked() and true or false)
	end)
	box:SetScript("OnEnter", function(self) ShowHelp(self, option) end)
	box:SetScript("OnLeave", function() GameTooltip:Hide() end)
	return box
end

-- Builds one settings page (checkboxes, sliders and dropdowns) inside `page`, starting at (x, y) from its top left.
local function BuildPage(page, x, y)
	page.checkboxes, page.sliders, page.dropdowns = {}, {}, {}
	local row = 0
	for _, option in ipairs(OPTIONS) do
		local rowY = y - row * ROW_SPACING
		row = row + RowsUsed(option)
		if option.divider then
			local line = page:CreateTexture(nil, "ARTWORK")
			line:SetColorTexture(1, 1, 1, 0.15)
			line:SetHeight(1)
			line:SetWidth(300)
			line:SetPoint("TOPLEFT", x + 4, rowY - ROW_SPACING * DIVIDER_ROWS / 2)
		elseif option.slider then
			page.sliders[option] = BuildSlider(page, option, x, rowY)
		elseif option.choices then
			page.dropdowns[option] = BuildDropdown(page, option, x, rowY)
		else
			page.checkboxes[option] = BuildCheckbox(page, option, x, rowY)
		end
	end
	page:HookScript("OnShow", Sync)
	pages[#pages + 1] = page
end

local function CreateWindowPage()
	window = PC:CreateWindow("ProfitCraftSettings", UIParent, 360, 96 + TotalRows() * ROW_SPACING, "ProfitCraft Settings",
		{ movable = true })
	local page = CreateFrame("Frame", nil, window.Inset)
	page:SetAllPoints()
	BuildPage(page, 8, -6)

	local version = window:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
	version:SetPoint("BOTTOMRIGHT", -12, 8)
	version:SetText("ProfitCraft " .. PC.version)
end

-- The page in Blizzard's Options > AddOns. Blizzard sizes and shows the canvas frame itself.
local function RegisterBlizzardPage()
	if not (Settings and Settings.RegisterCanvasLayoutCategory and Settings.RegisterAddOnCategory) then return end
	local canvas = CreateFrame("Frame", nil, UIParent)
	canvas:Hide()
	local title = canvas:CreateFontString(nil, "OVERLAY", "GameFontHighlightHuge")
	title:SetPoint("TOPLEFT", 16, -16)
	title:SetText("ProfitCraft")
	local version = canvas:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
	version:SetPoint("LEFT", title, "RIGHT", 8, -2)
	version:SetText(PC.version)
	BuildPage(canvas, 12, -52)
	local category = Settings.RegisterCanvasLayoutCategory(canvas, "ProfitCraft")
	Settings.RegisterAddOnCategory(category)
end

PC:Listen("DATA_READY", function() PC:Call("register settings", RegisterBlizzardPage) end)

PC:Listen("TOGGLE_SETTINGS", function()
	if not window then CreateWindowPage() end
	window:SetShown(not window:IsShown())
end)

-- Keep every visible page right when a setting changes anywhere (the other page, /pcraft debug on, or
-- Blizzard's own Interface option for the mirrored game setting).
local function SyncVisible()
	for _, page in ipairs(pages) do
		if page:IsVisible() then Sync(page) end
	end
end
PC:Listen("SETTINGS_CHANGED", SyncVisible)
PC:RegisterEvent("CVAR_UPDATE", function(name)
	for _, option in ipairs(OPTIONS) do
		if option.cvar and option.cvar == name then SyncVisible() end
	end
end)
