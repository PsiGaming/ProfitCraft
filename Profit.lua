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
--   bound (the product binds on pickup: never sold, so no sale profit; craft-and-disenchant still counts),
--   quantity (items per craft; the average for a random range), salePrice (AH price per item), vendorPrice (what a
--   vendor pays per item), saleNet (per item: the higher of the AH price after the cut and the vendor price; a tie
--   counts as vendor), saleHow ("ah" or "vendor"),
--   cost (reagent cost per craft), reagents ({ itemID, quantity, unit, total, how, listed }; listed = units on the AH
--   when fewer than needed),
--   profitCraft, profitItem, stackSize, batch (the stack size, or NON_STACK_BATCH for products that don't stack),
--   profitStack, batchCost (profit and reagent cost for one batch; nil when not computable),
--   disenchantValue (ProfitCraft's disenchant estimate per item), profitDisenchant (craft, then disenchant and sell the
--   materials: estimate x quantity x (1 - AH cut) - cost; nil when not disenchantable or not computable)

-- Per stack mode counts this many of a product that doesn't stack (2026-11-24: "10x yellow shirts").
local NON_STACK_BATCH = 10
Profit.NON_STACK_BATCH = NON_STACK_BATCH

-- Profit for one batch of the product (a full stack, or NON_STACK_BATCH): the reagents for enough crafts to make it
-- are priced together, because buying more can cost more per unit (Prices:GetReagentCost). The reagent cost is
-- counted per item made, times the batch. Returns profit and reagent cost, or nil.
local function BatchProfit(result)
  if not result.batch then return nil end
  local crafts = math.ceil(result.batch / result.quantity)
  local made = crafts * result.quantity
  local cost = 0
  for _, line in ipairs(result.reagents) do
    local total = PC.Prices:GetReagentCost(line.itemID, line.quantity * crafts)
    if not total then return nil end
    cost = cost + total
  end
  local batchCost = cost * result.batch / made
  return result.saleNet * result.batch - batchCost, batchCost
end

local function Evaluate(recipe, cut)
  local result = { recipe = recipe, missing = {}, reagents = {} }
  result.quantity = (recipe.quantityMin + recipe.quantityMax) / 2

  local cost, complete = 0, true
  for _, reagent in ipairs(recipe.reagents) do
    local bestItem, bestTotal, bestHow, bestListed
    for _, itemID in ipairs(reagent.items) do
      local total, how, listed = PC.Prices:GetReagentCost(itemID, reagent.quantity)
      if total and (not bestTotal or total < bestTotal) then
        bestItem, bestTotal, bestHow, bestListed = itemID, total, how, listed
      end
    end
    local itemID = bestItem or reagent.items[1]
    local line = { itemID = itemID, quantity = reagent.quantity, how = bestHow, listed = bestListed }
    if bestTotal then
      line.total = bestTotal
      line.unit = bestTotal / reagent.quantity
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
    result.bound = PC.Items:IsBindOnPickup(outputItemID)
    result.salePrice = not result.bound and PC.Prices:GetAuctionPrice(outputItemID) or nil
    -- Sold where it pays more: the AH after its cut, or a vendor (2026-11-24: "profit is profit").
    -- Bind-on-pickup products can only go to a vendor.
    local vendor = PC.Items:GetSellPrice(outputItemID)
    result.vendorPrice = vendor and vendor > 0 and vendor or nil
    local auctionNet = result.salePrice and result.salePrice * (1 - cut)
    if auctionNet and not (result.vendorPrice and result.vendorPrice >= auctionNet) then
      result.saleNet, result.saleHow = auctionNet, "ah"
    elseif result.vendorPrice then
      result.saleNet, result.saleHow = result.vendorPrice, "vendor"
    end
    if not result.saleNet then
      complete = false  -- bound and no vendor price: no sale profit, only craft-and-disenchant
      if not result.bound then table.insert(result.missing, 1, outputItemID) end
    end
    result.stackSize = PC.Items:GetStackSize(outputItemID)
    if result.stackSize then result.batch = result.stackSize > 1 and result.stackSize or NON_STACK_BATCH end
    result.disenchantValue = PC.Disenchant:GetValue(outputItemID)
  else
    complete = false
    result.noProduct = true
  end

  result.complete = complete
  if complete then
    result.profitCraft = result.saleNet * result.quantity - result.cost
    result.profitItem = result.profitCraft / result.quantity
    result.profitStack, result.batchCost = BatchProfit(result)
  end
  if result.cost and result.disenchantValue then
    result.profitDisenchant = result.disenchantValue * result.quantity * (1 - cut) - result.cost
  end
  return result
end

-- One recipe's result with the current AH cut (for tooltips, outside the stored results).
function Profit:Evaluate(recipe)
  return Evaluate(recipe, PC.db.settings.ahCut)
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
