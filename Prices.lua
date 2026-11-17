-- ProfitCraft: Prices
-- The one place that answers "what does item X cost / sell for?" (DESIGN.md sections 5 and 9).
-- AH prices come from ProfitCraft's scan snapshot (Scan.lua) when it is at least as recent as Auctionator's price,
-- else from Auctionator. From the snapshot:
-- * stackable items: price levels holding less than the crumb limit (setting crumbPercent, % of all units listed)
--   are ignored; on a busy AH they're gone before anyone can buy them (Sylice, 2026-11-17);
-- * reagent cost = what buying the needed quantity costs, cheapest levels first (reagents can be bought by
--   quantity on Forever: Sylice, 2026-11-17);
-- * sale price = the cheapest remaining level.

local _, PC = ...

local Prices = {}
PC.Prices = Prices

local SCAN_DAY_0 = time({ year = 2020, month = 1, day = 1, hour = 0 })  -- Auctionator's day numbering

local function DayNumber(t)
	return math.floor((t - SCAN_DAY_0) / 86400)
end

-- The snapshot's price levels for an item ({ {price per unit, quantity}, ... }, cheapest first) and the total units
-- listed; nil when the snapshot has no listings for it or Auctionator's price is from a later day (same day: ours).
local function ScanLevels(itemID)
	local snapshot = PC.Scan:GetSnapshot()
	local levels = snapshot and snapshot.levels[itemID]
	if not levels or #levels == 0 then return nil end
	local age = PC.Auctionator:GetAuctionAge(itemID)
	if age and age < DayNumber(time()) - DayNumber(snapshot.time) then return nil end
	local total = snapshot.totals[itemID] or 0
	if PC.Items:GetStackSize(itemID) == 1 then return levels, total end  -- gear: every listing counts
	local minimum = total * PC.db.settings.crumbPercent / 100
	local kept = {}
	for _, level in ipairs(levels) do
		if level[2] >= minimum then kept[#kept + 1] = level end
	end
	if #kept == 0 then return levels, total end  -- every level is tiny: a scattered market, use it as it is
	return kept, total
end

-- AH price per item in copper (what a sale fetches) and its source; or nil.
function Prices:GetAuctionPrice(itemID)
	local levels = ScanLevels(itemID)
	if levels then return levels[1][1], "scan" end
	local price = PC.Auctionator:GetAuctionPrice(itemID)
	if price then return price, "Auctionator" end
	return nil
end

-- How each price source is named on screen, in front of a reagent's price: "(Vend)" / "(AH)".
Prices.SOURCE_LABEL = { vendor = "Vend", ah = "AH", ["ah-cheaper"] = "AH" }

-- A reagent's price with its source in front, e.g. "(Vend) 10c", so the amounts stay right-aligned; "only N listed"
-- after it when the AH has fewer than needed; or a grey "no price".
function Prices:FormatReagent(total, how, listed)
	if not total then return "|cff888888no price|r" end
	local text = "|cff888888(" .. (self.SOURCE_LABEL[how] or "?") .. ")|r " .. PC:FormatMoney(total)
	if listed then text = text .. " |cffff8888(only " .. listed .. " listed)|r" end
	return text
end

-- Cost of `quantity` (default 1) of one reagent: the lower of the merchant price and the AH cost for that quantity.
-- Returns the total cost, how it was priced ("vendor", "ah" when no merchant price is known, "ah-cheaper"), and,
-- when the AH lists fewer units than needed, how many it lists (the rest is counted at its dearest kept price).
-- Returns nil if neither price is known.
function Prices:GetReagentCost(itemID, quantity)
	quantity = quantity or 1
	local vendor = PC.Auctionator:GetVendorPrice(itemID)
	local auction, listed
	local levels, total = ScanLevels(itemID)
	if levels then
		local need, cost = quantity, 0
		for _, level in ipairs(levels) do
			local take = math.min(need, level[2])
			cost = cost + take * level[1]
			need = need - take
			if need == 0 then break end
		end
		if need > 0 then cost = cost + need * levels[#levels][1] end
		if total < quantity then listed = total end
		auction = cost
	else
		local price = PC.Auctionator:GetAuctionPrice(itemID)
		auction = price and price * quantity
	end
	if vendor and (not auction or vendor * quantity <= auction) then return vendor * quantity, "vendor" end
	if auction then return auction, vendor and "ah-cheaper" or "ah", listed end
	return nil
end
