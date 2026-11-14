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

local OPTIONS = {
	{ key = "tooltipDisenchant", label = "Disenchant estimate in item tooltips",
		help = "Adds the estimated disenchant value to item tooltips (average over many disenchants, "
			.. "priced at AH prices). Not yet confirmed for Forever." },
	-- Mirrors Blizzard's own "Show Free Bag Space" (Options > Interface): reads and writes the game setting
	-- displayFreeBagSlots, which Blizzard's backpack button watches (CVAR_UPDATE). ProfitCraft stores nothing.
	{ cvar = "displayFreeBagSlots", label = "Free slots on the backpack button (Blizzard)",
		help = "The same switch as Blizzard's \"Show Free Bag Space\" (Options > Interface): free slots in your "
			.. "normal bags, shown on the backpack button. Changing it here changes Blizzard's option." },
	{ key = "reagentBagFreeSlots", label = "Free slots on the reagent bag button",
		help = "Shows the reagent bag's free slots on its bag bar button. For the normal bags, turn on Blizzard's "
			.. "own \"Show Free Bag Space\" option (Options > Interface)." },
	{ key = "debug", label = "Debug mode: show errors in chat",
		help = "Errors are always logged (/pcraft errors). With debug mode on they are also printed in chat as "
			.. "they happen." },
}

local ROW_SPACING = 30

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

-- Makes the checkboxes reflect the saved settings (and Blizzard's, for mirrored ones).
local function Sync(page)
	for option, box in pairs(page.checkboxes) do box:SetChecked(GetValue(option)) end
end

-- Builds one settings page (the checkboxes) inside `page`, starting at (x, y) from its top left.
local function BuildPage(page, x, y)
	page.checkboxes = {}
	for i, option in ipairs(OPTIONS) do
		local box = CreateFrame("CheckButton", nil, page, "UICheckButtonTemplate")
		box:SetPoint("TOPLEFT", x, y - (i - 1) * ROW_SPACING)
		box.Text:SetText(option.label)
		box.Text:SetFontObject("GameFontHighlight")
		box:SetScript("OnClick", function(self)
			PC:Call("settings " .. (option.key or option.cvar), SetValue, option, self:GetChecked() and true or false)
		end)
		box:SetScript("OnEnter", function(self)
			GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
			GameTooltip:AddLine(option.label, 1, 1, 1)
			GameTooltip:AddLine(option.help, nil, nil, nil, true)
			GameTooltip:Show()
		end)
		box:SetScript("OnLeave", function() GameTooltip:Hide() end)
		page.checkboxes[option] = box
	end
	page:HookScript("OnShow", Sync)
	pages[#pages + 1] = page
end

local function CreateWindowPage()
	window = PC:CreateWindow("ProfitCraftSettings", UIParent, 360, 96 + #OPTIONS * ROW_SPACING, "ProfitCraft Settings",
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
