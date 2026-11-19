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

-- Time (seconds, as time()) of the last Auctionator AH scan ProfitCraft saw on this realm, or nil if none yet.
-- Recorded from RegisterForDBUpdate, which fires after each scan (PsiLab, 2026-11-13).
function Source:GetLastScanTime()
  return PC.db.lastScan[GetRealmName()]
end

-- Merchant buy price per item recorded by Auctionator at merchants, or nil. Can be fractional.
function Source:GetVendorPrice(itemID)
  return Ask("GetVendorPriceByItemID", itemID)
end

PC:RegisterEvent("PLAYER_LOGIN", function()
  local api = API()
  if not api then
    PC:Print("Auctionator not found. Use ProfitCraft's Full scan button at the Auction House for prices; "
      .. "Auctionator adds price history.")
    return
  end
  if type(api.RegisterForDBUpdate) == "function" then
    local ok, err = pcall(api.RegisterForDBUpdate, CALLER_ID, function()
      PC.db.lastScan[GetRealmName()] = time()
      PC:Send("PRICES_CHANGED")
    end)
    if not ok then PC:ReportError("Auctionator RegisterForDBUpdate", err) end
  end
end)
