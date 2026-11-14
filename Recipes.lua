-- ProfitCraft: Recipes
-- Reads the learned recipes of the open profession. Uses C_TradeSkillUI.GetAllRecipeIDs (every recipe of the
-- open profession, learned or not) and keeps the learned ones: GetFilteredRecipeIDs follows the window's
-- search and filters, so it can't give a complete ranking (PsiLab, 2026-11-13).

local _, PC = ...

local Recipes = {}
PC.Recipes = Recipes

Recipes.list = {}         -- learned recipes of the open profession (see Read for the fields)
Recipes.byID = {}
Recipes.professionName = nil
Recipes.isOpen = false

local lastSignature

local REAGENT_TYPES = Enum and Enum.CraftingReagentType
local BASIC_REAGENT = REAGENT_TYPES and REAGENT_TYPES.Basic or 1
local AUTOMATIC_REAGENT = REAGENT_TYPES and REAGENT_TYPES.Automatic or 3

local function AllRecipeIDs()
	if C_TradeSkillUI.GetAllRecipeIDs then return C_TradeSkillUI.GetAllRecipeIDs() or {} end
	return C_TradeSkillUI.GetFilteredRecipeIDs() or {}
end

-- Reagents a craft always uses: basic and automatic reagent slots (optional/finishing reagents are left out).
-- Each slot can accept several items; all are kept and the cheapest is used.
local function ReadReagents(schematic)
	local reagents = {}
	for _, slot in ipairs(schematic.reagentSlotSchematics or {}) do
		local kind = slot.reagentType
		if (kind == BASIC_REAGENT or kind == AUTOMATIC_REAGENT) and (slot.quantityRequired or 0) > 0 then
			local items = {}
			for _, reagent in ipairs(slot.reagents or {}) do
				if reagent.itemID then items[#items + 1] = reagent.itemID end
			end
			if #items > 0 then
				reagents[#reagents + 1] = { items = items, quantity = slot.quantityRequired }
			end
		end
	end
	return reagents
end

-- One recipe in ProfitCraft's form, or nil. Also works with no profession window open, for learned and unlearned
-- recipes of the character's professions (PsiLab, 2026-11-14); `info` is optional (name and icon).
function Recipes:Load(recipeID, info)
	local schematic = C_TradeSkillUI.GetRecipeSchematic(recipeID, false)
	if not schematic then return nil end
	return {
		recipeID = recipeID,
		name = (info and info.name) or schematic.name or ("recipe " .. recipeID),
		icon = (info and info.icon) or schematic.icon,
		outputItemID = schematic.outputItemID,
		quantityMin = schematic.quantityMin or 1,
		quantityMax = schematic.quantityMax or schematic.quantityMin or 1,
		reagents = ReadReagents(schematic),
	}
end

function Recipes:Read()
	local profession = C_TradeSkillUI.GetBaseProfessionInfo()
	local list, byID, ids = {}, {}, {}
	for _, recipeID in ipairs(AllRecipeIDs()) do
		local info = C_TradeSkillUI.GetRecipeInfo(recipeID)
		if info and info.learned then
			local recipe = self:Load(recipeID, info)
			if recipe then
				list[#list + 1] = recipe
				byID[recipeID] = recipe
				ids[#ids + 1] = recipeID
			end
		end
	end
	table.sort(ids)
	local name = profession and profession.professionName or "?"
	local signature = name .. ":" .. table.concat(ids, ",")
	self.list, self.byID, self.professionName = list, byID, name
	if signature ~= lastSignature then
		lastSignature = signature
		PC:Send("RECIPES_CHANGED")
	end
end

local function RequestRead()
	-- Opening the window fires about 3 TRADE_SKILL_LIST_UPDATE within 0.2 s (PsiLab): read once after them.
	PC:Debounce("recipes", 0.3, function()
		if Recipes.isOpen then Recipes:Read() end
	end)
end

PC:RegisterEvent("TRADE_SKILL_SHOW", function()
	Recipes.isOpen = true
	RequestRead()
	-- Blizzard builds and shows its profession window in response to this same event; wait one frame so
	-- ProfessionsFrame exists before the panel and details block attach to it.
	C_Timer.After(0, function()
		if Recipes.isOpen then PC:Send("PROFESSION_OPENED") end
	end)
end)
PC:RegisterEvent("TRADE_SKILL_LIST_UPDATE", RequestRead)
PC:RegisterEvent("NEW_RECIPE_LEARNED", RequestRead)
PC:RegisterEvent("TRADE_SKILL_CLOSE", function()
	Recipes.isOpen = false
	-- Forget this profession, so the next one opened never shows its recipes, and RECIPES_CHANGED is sent
	-- again when the same profession is reopened.
	Recipes.list, Recipes.byID, Recipes.professionName = {}, {}, nil
	lastSignature = nil
	PC:Send("PROFESSION_CLOSED")
end)
