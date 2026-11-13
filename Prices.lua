-- ProfitCraft: Prices
-- The one place that answers "what does item X cost / sell for?" (DESIGN.md section 5).
-- Version 0.1 has one AH source (Auctionator); version 0.2 adds our own scan and merchant records here.

local _, PC = ...

local Prices = {}
PC.Prices = Prices

-- AH price per item in copper and the source's name; or nil.
function Prices:GetAuctionPrice(itemID)
	local price = PC.Auctionator:GetAuctionPrice(itemID)
	if price then return price, "Auctionator" end
	return nil
end

-- Cost of one reagent: the lower of its merchant buy price and its AH price.
-- Returns unit price and how it was priced: "vendor", "ah" (no merchant price known) or "ah-cheaper".
-- Returns nil if neither price is known.
function Prices:GetReagentCost(itemID)
	local vendor = PC.Auctionator:GetVendorPrice(itemID)
	local auction = self:GetAuctionPrice(itemID)
	if vendor and (not auction or vendor <= auction) then return vendor, "vendor" end
	if auction then return auction, vendor and "ah-cheaper" or "ah" end
	return nil
end
