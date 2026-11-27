-- ProfitCraft: item data
-- Names, icons and stack sizes from Blizzard's item data (C_Item.GetItemInfo). Item data can arrive
-- later than asked for; then it is requested and ITEM_DATA_CHANGED is sent once it has arrived.

local _, PC = ...

local Items = {}
PC.Items = Items

local requested = {}
local failed = {}  -- item IDs the game could not load; not requested again this session

local function Info(itemID)
  if not itemID then return nil end
  local name, _, _, _, _, _, _, stackCount, _, icon, sellPrice = C_Item.GetItemInfo(itemID)
  if name then return name, stackCount, icon, sellPrice end
  if not requested[itemID] and not failed[itemID] then
    requested[itemID] = true
    C_Item.RequestLoadItemDataByID(itemID)
  end
  return nil
end

-- Stack size (1 for items that don't stack), or nil while the item data isn't loaded yet.
function Items:GetStackSize(itemID)
  local name, stackCount = Info(itemID)
  if not name then return nil end
  return (stackCount and stackCount > 0) and stackCount or 1
end

function Items:GetName(itemID)
  return Info(itemID) or ("item " .. tostring(itemID))
end

-- Price a merchant pays for one item (0 = can't be sold to a merchant), or nil while not loaded. Items learned to be
-- unsellable count 0 whatever the item data says (2026-11-24: Blinding Powder had a sell price of 1s 25c in
-- the item data, but the merchant refused it).
function Items:GetSellPrice(itemID)
  local name, _, _, sellPrice = Info(itemID)
  if not name then return nil end
  if self:IsUnsellable(itemID) then return 0 end
  return sellPrice or 0
end

-- Unsellable: learned in game (PC.db.unsellable), or on the list shipped from Forever's game data
-- (Sources/NoVendorValue.lua; seen 2026-11-24: Blinding Powder and Strange Dust both carry its flag). The bags
-- overrule the shipped list: an item seen there without the game's no-value flag (PC.db.sellable) counts as sellable.
function Items:IsUnsellable(itemID)
  if not PC.db then return false end
  if PC.db.unsellable[itemID] ~= nil then return true end
  return PC.NO_VENDOR_VALUE[itemID] == true and not PC.db.sellable[itemID]
end

-- Verified: not unsellable, and either covered by the shipped game data (an item ID up to the highest in the data
-- the list was made from: an item missing from the list carries no "no vendor value" flag) or seen in the bags with
-- the game saying a merchant takes it (hasNoValue false). Unverified items get warnings, nothing is blocked; that
-- leaves items newer than the list (2026-11-24: warn only where the data hasn't checked; new items get higher
-- IDs, so far as the Forever-added 2879xx copies show).
function Items:IsVerifiedSellable(itemID)
  if not PC.db or self:IsUnsellable(itemID) then return false end
  return itemID <= PC.NO_VENDOR_VALUE_MAX_ID or PC.db.sellable[itemID] == true
end

-- Learning which items no merchant takes. Neither the item data's sell price nor Blizzard's tooltips (which show no
-- sell price outside a merchant on Forever, seen 2026-11-24) tell; two signals do:
-- * Bags: C_Container.GetContainerItemInfo(...).hasNoValue (Forever API docs, ContainerDocumentation.lua; Blizzard's
--   own bag code reads it, ContainerFrame.lua). Confirmed in game: true for every Blinding Powder stack
--   (2026-11-24).
-- * Merchants: selling a bag item (C_Container.UseContainerItem while a merchant is open) that the merchant refuses
--   shows Blizzard's error ERR_VENDOR_DOESNT_BUY ("The merchant doesn't want that item") in UI_ERROR_MESSAGE.
local function Learn(itemID, how)
  if not (PC.db and itemID) or Items:IsUnsellable(itemID) then return end  -- known already (learned or shipped list)
  PC.db.unsellable[itemID] = how
  PC:Print(string.format("%s: no merchant takes it, so it no longer counts as sellable to vendors.", Items:GetName(itemID)))
  PC:Send("ITEM_UNSELLABLE", itemID)
  PC:Send("PRICES_CHANGED")  -- profits that counted its vendor price are worked out again
end

-- The containers to look at: the bags, and while the bank is open its tabs (Forever's bank: character and account
-- tabs, Enum.BagIndex.CharacterBankTab_1 and up, Forever API docs BagIndexConstantsDocumentation.lua; Camelot
-- BankFrame.lua reads them the same way). Bank contents can only be read at the bank.
local bankOpen = false

local function Containers()
  local list = {}
  for bag = 0, NUM_TOTAL_EQUIPPED_BAG_SLOTS or 4 do list[#list + 1] = bag end
  local first = bankOpen and Enum.BagIndex and Enum.BagIndex.CharacterBankTab_1
  if first then
    for _, id in pairs(Enum.BagIndex) do
      if id >= first then list[#list + 1] = id end
    end
  end
  return list
end

-- Every bag (and bank) item with a sell price in the item data is either learned to be unsellable (the game's
-- no-value flag) or verified sellable (no flag). The list is account-wide, so every character's bags and bank add to
-- it (2026-11-24).
local function ScanBags()
  if not (PC.db and C_Container and C_Container.GetContainerItemInfo) then return end
  local verified = false
  for _, bag in ipairs(Containers()) do
    for slot = 1, C_Container.GetContainerNumSlots(bag) or 0 do
      local info = C_Container.GetContainerItemInfo(bag, slot)
      local itemID = info and info.itemID
      local _, _, _, sellPrice = Info(itemID)
      if sellPrice and sellPrice > 0 then
        if info.hasNoValue then
          Learn(itemID, "bags")  -- the item data gets it wrong
        elseif not PC.db.sellable[itemID] then
          PC.db.sellable[itemID] = true
          verified = true
        end
      end
    end
  end
  if verified then PC:Send("ITEM_SELLABLE") end
end
PC:RegisterEvent("BAG_UPDATE_DELAYED", function() PC:Call("unsellable bags", ScanBags) end)
PC:RegisterEvent("PLAYER_ENTERING_WORLD", function() PC:Call("unsellable bags", ScanBags) end)
PC:RegisterEvent("BANKFRAME_OPENED", function()
  bankOpen = true
  PC:Call("unsellable bags", ScanBags)
end)
PC:RegisterEvent("BANKFRAME_CLOSED", function() bankOpen = false end)
PC:RegisterEvent("PLAYERBANKSLOTS_CHANGED", function() PC:Call("unsellable bags", ScanBags) end)
PC:Listen("ITEM_DATA_CHANGED", function() PC:Call("unsellable bags", ScanBags) end)  -- bag items loaded late

local lastSold  -- { itemID, time }: the bag item last sold to a merchant
if C_Container and C_Container.UseContainerItem then
  hooksecurefunc(C_Container, "UseContainerItem", function(bag, slot)
    PC:Call("unsellable sell", function()
      if not (MerchantFrame and MerchantFrame:IsShown()) then return end
      local info = C_Container.GetContainerItemInfo(bag, slot)
      if info and info.itemID then lastSold = { info.itemID, GetTime() } end
    end)
  end)
end

PC:RegisterEvent("UI_ERROR_MESSAGE", function(_, message)
  if not (lastSold and GetTime() - lastSold[2] < 2 and type(message) == "string") then return end
  local refused = (ERR_VENDOR_DOESNT_BUY and message == ERR_VENDOR_DOESNT_BUY)
    or message:lower():find("doesn't want", 1, true) ~= nil
  if refused then Learn(lastSold[1], "merchant") end
  lastSold = nil
end)

-- Enum.ItemBind (Forever API docs): 1 = bind on pickup, 4 = quest item. Neither can be sold on the AH.
local BIND_ON_PICKUP, BIND_QUEST = 1, 4

-- True when the item binds on pickup (or is a quest item): it can't be sold on the AH, only disenchanted.
-- False while the item data isn't loaded yet.
function Items:IsBindOnPickup(itemID)
  if not Info(itemID) then return false end
  local bindType = select(14, C_Item.GetItemInfo(itemID))
  return bindType == BIND_ON_PICKUP or bindType == BIND_QUEST
end

function Items:GetIcon(itemID)
  local name, _, icon = Info(itemID)
  return name and icon or nil
end

PC:RegisterEvent("GET_ITEM_INFO_RECEIVED", function(itemID, success)
  if not requested[itemID] then return end
  requested[itemID] = nil
  if success == false then
    failed[itemID] = true
    return
  end
  PC:Debounce("item data", 0.3, function() PC:Send("ITEM_DATA_CHANGED") end)
end)
