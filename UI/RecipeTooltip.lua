-- ProfitCraft: trainer and recipe item tooltips
-- Adds what a recipe costs to craft and what its product earns, so you can decide whether a recipe is worth
-- training, learning or selling. Shown when hovering a recipe at a trainer and on recipe items (bags, AH, links).
-- Forever facts (PsiLab, 2026-11-14): a trainer service's tooltip data is of type Spell with the recipe ID as
-- its id; a recipe item's tooltip data has an ItemSpellTriggerLearn line whose spellID is the recipe ID; recipe
-- details can be read with no profession window open (for the character's own professions).

local _, PC = ...

local LEARN_LINE = Enum.TooltipDataLineType and Enum.TooltipDataLineType.ItemSpellTriggerLearn or 38
local RECIPE_ITEM_CLASS = Enum.ItemClass and Enum.ItemClass.Recipe or 9
-- Profit as a percentage of the reagent cost, e.g. "(+48%) ", to compare recipes' efficiency (Sylice, 2026-11-20).
-- Goes left of the amount, so the right-aligned money values stay lined up. Nothing when the cost is unknown or zero.
local function Percent(profit, cost)
  if not (profit and cost and cost > 0) then return "" end
  return string.format("|cffaaaaaa(%+d%%)|r ", math.floor(profit / cost * 100 + 0.5))
end

local function AddRecipeLines(tooltip, recipeID)
  local recipe = PC.Recipes:Load(recipeID)
  if not (recipe and recipe.outputItemID) then return end  -- e.g. enchants: no product to sell
  local result = PC.Profit:Evaluate(recipe)
  local amount = result.quantity ~= 1 and string.format(" (x%s)", result.quantity) or ""

  tooltip:AddLine(" ")
  tooltip:AddLine("|cff4fc3f7ProfitCraft|r")
  tooltip:AddDoubleLine("Reagent cost", PC:FormatMoney(result.cost), 1, 1, 1)
  for _, reagent in ipairs(result.reagents) do
    tooltip:AddDoubleLine("  " .. reagent.quantity .. " x " .. PC.Items:GetName(reagent.itemID),
      PC.Prices:FormatReagent(reagent.total, reagent.how, reagent.listed), 0.8, 0.8, 0.8)
  end
  if result.bound then
    tooltip:AddDoubleLine("Sale", "|cff888888bind on pickup: can't be sold|r", 1, 1, 1)
  else
    tooltip:AddDoubleLine("Auction price" .. amount, PC:FormatMoney(result.salePrice and result.salePrice * result.quantity),
      1, 1, 1)
    tooltip:AddDoubleLine("Profit per craft", result.profitCraft
      and (Percent(result.profitCraft, result.cost) .. PC:FormatProfit(result.profitCraft)) or "|cff888888?|r", 1, 1, 1)
  end
  if result.profitDisenchant then
    tooltip:AddDoubleLine("Craft and disenchant",
      Percent(result.profitDisenchant, result.cost) .. PC:FormatProfit(result.profitDisenchant), 1, 1, 1)
  end
end

local function OnTrainerTooltip(tooltip, tooltipData)
  if tooltip ~= GameTooltip or not (ClassTrainerFrame and ClassTrainerFrame:IsShown()) then return end
  if type(tooltipData and tooltipData.id) ~= "number" then return end
  AddRecipeLines(tooltip, tooltipData.id)
end

local function OnItemTooltip(tooltip, tooltipData)
  if tooltip ~= GameTooltip and tooltip ~= ItemRefTooltip then return end
  local itemID = tooltipData and tooltipData.id
  if type(itemID) ~= "number" or select(12, C_Item.GetItemInfo(itemID)) ~= RECIPE_ITEM_CLASS then return end
  for _, line in ipairs(tooltipData.lines or {}) do
    if line.type == LEARN_LINE and type(line.spellID) == "number" then
      AddRecipeLines(tooltip, line.spellID)
      return
    end
  end
end

if TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall and Enum.TooltipDataType then
  TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Spell, function(tooltip, tooltipData)
    PC:Call("trainer tooltip", OnTrainerTooltip, tooltip, tooltipData)
  end)
  TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, function(tooltip, tooltipData)
    PC:Call("recipe tooltip", OnItemTooltip, tooltip, tooltipData)
  end)
end
