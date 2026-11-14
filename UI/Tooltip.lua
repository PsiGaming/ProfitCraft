-- ProfitCraft: item tooltip
-- Adds ProfitCraft's disenchant estimate to item tooltips (off by default; /pcraft tooltip on|off).
-- Uses Blizzard's TooltipDataProcessor post-call for item tooltips, as Blizzard's own code does; the item ID
-- is tooltipData.id (Forever source: Blizzard_SharedXMLGame/Tooltip/TooltipUtil.lua).

local _, PC = ...

local function AddDisenchantLine(tooltip, tooltipData)
	if not (PC.db and PC.db.settings.tooltipDisenchant) then return end
	if tooltip ~= GameTooltip and tooltip ~= ItemRefTooltip then return end
	local itemID = tooltipData and tooltipData.id
	if type(itemID) ~= "number" then return end
	local link = tooltip.GetItem and select(2, tooltip:GetItem()) or nil
	local value = PC.Disenchant:GetValue(itemID, link)
	if not value then return end
	tooltip:AddDoubleLine("|cff4fc3f7Disenchant|r (est.)", PC:FormatMoney(value))
end

if TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall and Enum.TooltipDataType then
	TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, function(tooltip, tooltipData)
		PC:Call("item tooltip", AddDisenchantLine, tooltip, tooltipData)
	end)
end
