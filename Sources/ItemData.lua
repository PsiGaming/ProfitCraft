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

-- Price a merchant pays for one item (0 = can't be sold to a merchant), or nil while not loaded.
function Items:GetSellPrice(itemID)
	local name, _, _, sellPrice = Info(itemID)
	if not name then return nil end
	return sellPrice or 0
end

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
