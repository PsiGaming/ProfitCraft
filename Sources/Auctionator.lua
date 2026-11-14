-- ProfitCraft: Auctionator source
-- Reads prices through Auctionator's public API (Auctionator.API.v1) only. Auctionator is optional:
-- without it these functions return nil. Confirmed on Forever with Auctionator 346 (PsiLab, 2026-11-13):
-- all functions used here exist, and RegisterForDBUpdate fires after each AH scan.

local _, PC = ...

local CALLER_ID = "ProfitCraft"

local Source = {}
PC.Auctionator = Source

local function API()
	return type(Auctionator) == "table" and type(Auctionator.API) == "table" and Auctionator.API.v1 or nil
end

function Source:IsAvailable()
	return API() ~= nil
end

-- Calls one Auctionator API function; a failure goes to the error log and counts as "no answer".
local function Ask(functionName, item)
	local api = API()
	local fn = api and api[functionName]
	if type(fn) ~= "function" then return nil end
	local ok, result = pcall(fn, CALLER_ID, item)
	if not ok then
		PC:ReportError("Auctionator " .. functionName, result)
		return nil
	end
	return type(result) == "number" and result or nil
end

-- Last scanned AH price in copper per item, or nil.
function Source:GetAuctionPrice(itemID)
	return Ask("GetAuctionPriceByItemID", itemID)
end

-- Age of that price (0 on the day of the scan; unit to be confirmed), or nil.
function Source:GetAuctionAge(itemID)
	return Ask("GetAuctionAgeByItemID", itemID)
end

-- Auctionator's estimate of what disenchanting the item yields, in copper, or nil (not disenchantable or
-- unknown). Auctionator's disenchant rules are not verified for Forever; shown as Auctionator's estimate.
-- Tries the item ID first, then the item link (an estimate can depend on item details such as item level),
-- passing the exact link when the caller has one (e.g. a bag slot or tooltip).
function Source:GetDisenchantPrice(itemID, itemLink)
	local value = Ask("GetDisenchantPriceByItemID", itemID)
	if value then return value end
	itemLink = itemLink or select(2, C_Item.GetItemInfo(itemID))
	if itemLink then return Ask("GetDisenchantPriceByItemLink", itemLink) end
	return nil
end

-- Merchant buy price per item recorded by Auctionator at merchants, or nil. Can be fractional.
function Source:GetVendorPrice(itemID)
	return Ask("GetVendorPriceByItemID", itemID)
end

PC:RegisterEvent("PLAYER_LOGIN", function()
	local api = API()
	if not api then
		PC:Print("Auctionator not found. Version " .. PC.version .. " gets all its prices from Auctionator, "
			.. "so profits can't be calculated without it.")
		return
	end
	if type(api.RegisterForDBUpdate) == "function" then
		local ok, err = pcall(api.RegisterForDBUpdate, CALLER_ID, function()
			PC:Send("PRICES_CHANGED")
		end)
		if not ok then PC:ReportError("Auctionator RegisterForDBUpdate", err) end
	end
end)
