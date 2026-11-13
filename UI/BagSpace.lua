-- ProfitCraft: reagent bag free slots
-- Shows the reagent bag's free slots on its bag bar button, styled like Blizzard's own free-slot count on the
-- backpack (NumberFontNormal, "(%d)", 10 px below centre; Forever source: Blizzard_MainMenuBarBagButtons).
-- Blizzard's "Show Free Bag Space" option covers the normal bags; this adds the reagent bag. Off by default.
-- Draws on its own overlay frame; Blizzard's button is not changed.

local _, PC = ...

local REAGENT_BAG = Enum.BagIndex and Enum.BagIndex.ReagentBag or 5

local overlay

local function Update()
	if not overlay then return end
	local slots = C_Container.GetContainerNumSlots(REAGENT_BAG) or 0
	if not PC.db.settings.reagentBagFreeSlots or slots == 0 then
		overlay:Hide()
		return
	end
	overlay.text:SetText(string.format("(%d)", C_Container.GetContainerNumFreeSlots(REAGENT_BAG) or 0))
	overlay:Show()
end

PC:RegisterEvent("PLAYER_LOGIN", function()
	local button = _G.CharacterReagentBag0Slot
	if not button then return end
	overlay = CreateFrame("Frame", nil, button)
	overlay:SetAllPoints()
	overlay:SetFrameLevel(button:GetFrameLevel() + 2)
	overlay.text = overlay:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
	overlay.text:SetPoint("CENTER", 0, -10)
	Update()
end)

-- Blizzard updates its own count one frame after bag changes (to avoid races when moving bags); same here.
PC:RegisterEvent("BAG_UPDATE_DELAYED", function() C_Timer.After(0, function() PC:Call("reagent bag", Update) end) end)
PC:RegisterEvent("PLAYER_ENTERING_WORLD", Update)
PC:Listen("SETTINGS_CHANGED", function(key)
	if key == "reagentBagFreeSlots" then Update() end
end)
