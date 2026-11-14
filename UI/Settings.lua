-- ProfitCraft: settings window
-- ProfitCraft's own small window, never Blizzard's settings panel: closing Blizzard's panel always reopens the
-- game menu (Forever source: SettingsPanelMixin:TransitionBackOpeningPanel -> ToggleGameMenu), which is the bug
-- this avoids (FEATURES.md, Requirements). Closes with Escape (UISpecialFrames). Opened with /pcraft settings or
-- the side panel's "Settings" button.

local _, PC = ...

local Settings = {}
PC.SettingsWindow = Settings

local OPTIONS = {
	{ key = "tooltipDisenchant", label = "Disenchant estimate in item tooltips",
		help = "Adds Auctionator's disenchant estimate to item tooltips." },
	{ key = "reagentBagFreeSlots", label = "Free slots on the reagent bag button",
		help = "Shows the reagent bag's free slots on its bag bar button. For the normal bags, turn on Blizzard's "
			.. "own \"Show Free Bag Space\" option (Options > Interface)." },
	{ key = "debug", label = "Debug mode: show errors in chat",
		help = "Errors are always logged (/pcraft errors). With debug mode on they are also printed in chat as "
			.. "they happen." },
}

local frame
local checkboxes = {}

local function Sync()
	for key, box in pairs(checkboxes) do box:SetChecked(PC.db.settings[key] and true or false) end
end

local function Create()
	frame = PC:CreateWindow("ProfitCraftSettings", UIParent, 360, 96 + #OPTIONS * 30, "ProfitCraft Settings",
		{ movable = true })

	for i, option in ipairs(OPTIONS) do
		local box = CreateFrame("CheckButton", nil, frame, "UICheckButtonTemplate")
		box:SetPoint("TOPLEFT", frame.Inset, "TOPLEFT", 8, -6 - (i - 1) * 30)
		box.Text:SetText(option.label)
		box.Text:SetFontObject("GameFontHighlight")
		box:SetScript("OnClick", function(self)
			PC:Call("settings " .. option.key, PC.SetSetting, PC, option.key, self:GetChecked() and true or false)
		end)
		box:SetScript("OnEnter", function(self)
			GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
			GameTooltip:AddLine(option.label, 1, 1, 1)
			GameTooltip:AddLine(option.help, nil, nil, nil, true)
			GameTooltip:Show()
		end)
		box:SetScript("OnLeave", function() GameTooltip:Hide() end)
		checkboxes[option.key] = box
	end

	local version = frame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
	version:SetPoint("BOTTOMRIGHT", -12, 8)
	version:SetText("ProfitCraft " .. PC.version)

	frame:SetScript("OnShow", Sync)
end

PC:Listen("TOGGLE_SETTINGS", function()
	if not frame then Create() end
	frame:SetShown(not frame:IsShown())
end)

-- Keep the checkboxes right when a setting changes elsewhere (e.g. /pcraft debug on).
PC:Listen("SETTINGS_CHANGED", function()
	if frame and frame:IsShown() then Sync() end
end)
