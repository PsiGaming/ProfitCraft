-- ProfitCraft: item tooltip
-- Adds ProfitCraft's disenchant estimate and the possible materials (chance, amount) to item tooltips
-- (off by default; /pcraft tooltip on|off).
-- Uses Blizzard's TooltipDataProcessor post-call for item tooltips, as Blizzard's own code does; the item ID
-- is tooltipData.id (Forever source: Blizzard_SharedXMLGame/Tooltip/TooltipUtil.lua).

local _, PC = ...

local function AddDisenchantLine(tooltip, tooltipData)
  if not (PC.db and PC.db.settings.tooltipDisenchant) then return end
  if tooltip ~= GameTooltip and tooltip ~= ItemRefTooltip then return end
  local itemID = tooltipData and tooltipData.id
  if type(itemID) ~= "number" then return end
  local link = tooltip.GetItem and select(2, tooltip:GetItem()) or nil
  local outcomes = PC.Disenchant:GetOutcomes(itemID, link)
  if not outcomes then return end
  -- "?" when a material has no AH price yet; the possible materials are listed either way.
  tooltip:AddDoubleLine("|cff4fc3f7Disenchant|r (est.)", PC:FormatMoney(PC.Disenchant:GetValue(itemID, link)))
  for _, outcome in ipairs(outcomes) do
    local material, chance, low, high = unpack(outcome)
    local amount = low == high and tostring(low) or (low .. "-" .. high)
    tooltip:AddLine(string.format("   |cffffffff%s%%|r  %s  %s", chance, amount, PC.Items:GetName(material)),
      0.8, 0.8, 0.8)
  end
end

if TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall and Enum.TooltipDataType then
  TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, function(tooltip, tooltipData)
    PC:Call("item tooltip", AddDisenchantLine, tooltip, tooltipData)
  end)
end
