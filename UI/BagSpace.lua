-- ProfitCraft: free bag slots, split into reagent bag | normal bags
-- Blizzard's own count on the backpack button ("Show Free Bag Space", game setting displayFreeBagSlots) is one
-- total that includes the reagent bag (seen in game by Sylice, 2026-11-17). ProfitCraft shows the same total
-- split as "(reagent|normal)", in the order the bag bar shows the bags (reagent bag on the left).
-- Setting freeSlots (what ProfitCraft draws; Blizzard's own count is the game setting, see UI/Settings.lua):
--   "none"     nothing
--   "reagent"  the split on the reagent bag button, next to Blizzard's count ("ProfitCraft + Blizzard")
--   "backpack" the split on the backpack button in place of Blizzard's count ("ProfitCraft only")
-- "ProfitCraft only" hides Blizzard's count by making its text transparent (SetAlpha 0) and leaves Blizzard's
-- setting on, so Blizzard's count comes back by itself when ProfitCraft is disabled or removed. Blizzard only
-- ever shows/hides that text (Forever source: Blizzard_MainMenuBarBagButtons/Shared/MainMenuBarBagButtons.lua,
-- MainMenuBarBackpackMixin:SetCountShown), never changes its alpha, so the alpha stays as set here.
-- Styled like Blizzard's count (NumberFontNormal, "(%d)", 10 px below centre). Draws on its own overlay frames.

local _, PC = ...

local REAGENT_BAG = Enum.BagIndex and Enum.BagIndex.ReagentBag or 5

local overlays = {}  -- "reagent" / "backpack" -> overlay frame on that bag button
local blizzardHidden = false

local function CreateOverlay(button)
	local overlay = CreateFrame("Frame", nil, button)
	overlay:SetAllPoints()
	overlay:SetFrameLevel(button:GetFrameLevel() + 2)
	overlay.text = overlay:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
	overlay.text:SetPoint("CENTER", 0, -10)
	overlay:Hide()
	return overlay
end

-- "(reagent|normal)", or "(normal)" without a reagent bag; nil when the reagent bag button should stay empty.
local function SplitText(where)
	local total = C_Container.CalculateTotalNumberOfFreeBagSlots() or 0
	if (C_Container.GetContainerNumSlots(REAGENT_BAG) or 0) == 0 then
		if where == "reagent" then return nil end
		return string.format("(%d)", total)
	end
	local reagentFree = C_Container.GetContainerNumFreeSlots(REAGENT_BAG) or 0
	return string.format("(%d|%d)", reagentFree, total - reagentFree)
end

local function Update()
	local mode = PC.db.settings.freeSlots
	for where, overlay in pairs(overlays) do
		local text = where == mode and SplitText(where)
		if text then overlay.text:SetText(text) end
		overlay:SetShown(text and true or false)
	end
	local blizzardCount = MainMenuBarBackpackButton and MainMenuBarBackpackButton.FreeSlots
	if blizzardCount and (mode == "backpack") ~= blizzardHidden then
		blizzardHidden = mode == "backpack"
		blizzardCount:SetAlpha(blizzardHidden and 0 or 1)
	end
end

PC:RegisterEvent("PLAYER_LOGIN", function()
	if CharacterReagentBag0Slot then overlays.reagent = CreateOverlay(CharacterReagentBag0Slot) end
	if MainMenuBarBackpackButton then overlays.backpack = CreateOverlay(MainMenuBarBackpackButton) end
	Update()
end)

-- Blizzard updates its own count one frame after bag changes (to avoid races when moving bags); same here.
PC:RegisterEvent("BAG_UPDATE_DELAYED", function() C_Timer.After(0, function() PC:Call("free bag slots", Update) end) end)
PC:RegisterEvent("PLAYER_ENTERING_WORLD", Update)
PC:Listen("SETTINGS_CHANGED", function(key)
	if key == "freeSlots" then Update() end
end)
