-- ProfitCraft: Profit
-- Calculates one stored result per recipe; recalculates once after recipes, prices, item data or the AH cut
-- change, and only while a profession window is open (DESIGN.md sections 4 and 5). Results are dropped when
-- the window closes; reopening reads the recipes again, which triggers a fresh calculation.
-- Sorting by "per craft" or "per stack" only re-sorts the stored results.

local _, PC = ...

local Profit = {}
PC.Profit = Profit

Profit.results = {}   -- recipeID -> result (see Evaluate)
local ranked = {}     -- mode -> sorted list of results

-- A result:
--   recipe, complete (all prices known), missing (item IDs without a price),
--   quantity (items per craft; the average for a random range), salePrice (AH price per item),
--   cost (reagent cost per craft), reagents ({ itemID, quantity, unit, total, how }),
--   profitCraft, profitItem, stackSize, profitStack (nil when not computable),
--   disenchantValue (Auctionator's estimate per item), profitDisenchant (craft, then disenchant and sell the
--   materials: estimate x quantity x (1 - AH cut) - cost; nil when not disenchantable or not computable)
local function Evaluate(recipe, cut)
	local result = { recipe = recipe, missing = {}, reagents = {} }
	result.quantity = (recipe.quantityMin + recipe.quantityMax) / 2

	local cost, complete = 0, true
	for _, reagent in ipairs(recipe.reagents) do
		local bestItem, bestUnit, bestHow
		for _, itemID in ipairs(reagent.items) do
			local unit, how = PC.Prices:GetReagentCost(itemID)
			if unit and (not bestUnit or unit < bestUnit) then
				bestItem, bestUnit, bestHow = itemID, unit, how
			end
		end
		local itemID = bestItem or reagent.items[1]
		local line = { itemID = itemID, quantity = reagent.quantity, unit = bestUnit, how = bestHow }
		if bestUnit then
			line.total = bestUnit * reagent.quantity
			cost = cost + line.total
		else
			complete = false
			result.missing[#result.missing + 1] = itemID
		end
		result.reagents[#result.reagents + 1] = line
	end
	result.cost = complete and cost or nil

	local outputItemID = recipe.outputItemID
	if outputItemID then
		result.salePrice = PC.Prices:GetAuctionPrice(outputItemID)
		if not result.salePrice then
			complete = false
			table.insert(result.missing, 1, outputItemID)
		end
		result.stackSize = PC.Items:GetStackSize(outputItemID)
		result.disenchantValue = PC.Auctionator:GetDisenchantPrice(outputItemID)
	else
		complete = false
		result.noProduct = true
	end

	result.complete = complete
	if complete then
		result.profitCraft = result.salePrice * result.quantity * (1 - cut) - result.cost
		result.profitItem = result.profitCraft / result.quantity
		if result.stackSize then result.profitStack = result.profitItem * result.stackSize end
	end
	if result.cost and result.disenchantValue then
		result.profitDisenchant = result.disenchantValue * result.quantity * (1 - cut) - result.cost
	end
	return result
end

local PROFIT_FIELD = { craft = "profitCraft", stack = "profitStack", disenchant = "profitDisenchant" }
Profit.PROFIT_FIELD = PROFIT_FIELD

-- Results sorted for a mode: complete results by profit (highest first), then incomplete ones by name.
function Profit:GetRanked(mode)
	if ranked[mode] then return ranked[mode] end
	local field = PROFIT_FIELD[mode] or "profitCraft"
	local list = {}
	for _, result in pairs(self.results) do
		if not result.noProduct then list[#list + 1] = result end
	end
	table.sort(list, function(a, b)
		local pa, pb = a[field], b[field]
		if (pa ~= nil) ~= (pb ~= nil) then return pa ~= nil end
		if pa and pb and pa ~= pb then return pa > pb end
		return a.recipe.name < b.recipe.name
	end)
	ranked[mode] = list
	return list
end

function Profit:Recalculate()
	if not PC.Recipes.isOpen then return end  -- reopening reads the recipes again, which recalculates
	local cut = PC.db.settings.ahCut
	local results = {}
	for _, recipe in ipairs(PC.Recipes.list) do
		results[recipe.recipeID] = Evaluate(recipe, cut)
	end
	self.results = results
	ranked = {}
	PC:Send("RESULTS_CHANGED")
end

local function Schedule()
	PC:Debounce("profit", 0.2, function() Profit:Recalculate() end)
end

PC:Listen("RECIPES_CHANGED", Schedule)
PC:Listen("PRICES_CHANGED", Schedule)
PC:Listen("ITEM_DATA_CHANGED", Schedule)
PC:Listen("PROFESSION_CLOSED", function()
	Profit.results = {}
	ranked = {}
end)
PC:Listen("SETTINGS_CHANGED", function(key)
	if key == "ahCut" then Schedule() end
end)
