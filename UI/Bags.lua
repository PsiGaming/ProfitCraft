-- ProfitCraft: bag list
-- A movable window listing the disenchantable items in your bags with their disenchant estimate (Auctionator),
-- AH price and merchant sell price, best option highlighted. Opened with the side panel's "Bags" button or
-- /pcraft bags; works anywhere, not only at a profession window. Closes with Escape.

local _, PC = ...

local Bags = {}
PC.Bags = Bags

local WIDTH, HEIGHT = 440, 420
local ROW_HEIGHT = 22
local VALUE_WIDTH = 80
local GOOD = "|cff55ff55"

local frame, scrollBox, footer

-- Items in the bags, combined per item ID: { itemID, count, bound (any of them soulbound) }.
local function ReadBags()
	local items, order = {}, {}
	local first = Enum.BagIndex and Enum.BagIndex.Backpack or 0
	local last = NUM_TOTAL_EQUIPPED_BAG_SLOTS or NUM_BAG_SLOTS or 4
	for bag = first, last do
		for slot = 1, C_Container.GetContainerNumSlots(bag) or 0 do
			local info = C_Container.GetContainerItemInfo(bag, slot)
			if info and info.itemID then
				local entry = items[info.itemID]
				if not entry then
					entry = { itemID = info.itemID, count = 0 }
					items[info.itemID] = entry
					order[#order + 1] = entry
				end
				entry.count = entry.count + (info.stackCount or 1)
				entry.bound = entry.bound or info.isBound
				entry.link = entry.link or info.hyperlink
			end
		end
	end
	return order
end

-- Disenchantable items with their values per item and which option pays most after the AH cut.
local function BuildList()
	local cut = PC.db.settings.ahCut
	local list = {}
	for _, entry in ipairs(ReadBags()) do
		local disenchant = PC.Auctionator:GetDisenchantPrice(entry.itemID, entry.link)
		if disenchant then
			entry.disenchant = disenchant
			entry.auction = not entry.bound and PC.Prices:GetAuctionPrice(entry.itemID) or nil
			local sell = PC.Items:GetSellPrice(entry.itemID)
			entry.vendor = (sell and sell > 0) and sell or nil
			local options = {
				disenchant = disenchant * (1 - cut),  -- the materials are sold on the AH
				auction = entry.auction and entry.auction * (1 - cut),
				vendor = entry.vendor,
			}
			local best, bestValue
			for option, value in pairs(options) do
				if value and (not bestValue or value > bestValue) then best, bestValue = option, value end
			end
			entry.best = best
			list[#list + 1] = entry
		end
	end
	table.sort(list, function(a, b)
		if a.disenchant ~= b.disenchant then return a.disenchant > b.disenchant end
		return a.itemID < b.itemID
	end)
	return list
end

local function ValueText(entry, option, value, note)
	if not value then return "|cff888888" .. (note or "-") .. "|r" end
	local text = PC:FormatMoney(value)
	if entry.best == option then return GOOD .. ">|r " .. text end
	return text
end

local function MakeColumn(row, offset)
	local text = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	text:SetPoint("RIGHT", -offset, 0)
	text:SetWidth(VALUE_WIDTH)
	text:SetJustifyH("RIGHT")
	return text
end

local function InitRow(row, entry)
	if not row.created then
		row.created = true
		row:SetHeight(ROW_HEIGHT)
		row.icon = row:CreateTexture(nil, "ARTWORK")
		row.icon:SetSize(ROW_HEIGHT - 4, ROW_HEIGHT - 4)
		row.icon:SetPoint("LEFT", 2, 0)
		row.vendor = MakeColumn(row, 4)
		row.auction = MakeColumn(row, 4 + VALUE_WIDTH)
		row.disenchant = MakeColumn(row, 4 + 2 * VALUE_WIDTH)
		row.name = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
		row.name:SetPoint("LEFT", row.icon, "RIGHT", 4, 0)
		row.name:SetPoint("RIGHT", row.disenchant, "LEFT", -6, 0)
		row.name:SetJustifyH("LEFT")
		row.name:SetWordWrap(false)
		local highlight = row:CreateTexture(nil, "HIGHLIGHT")
		highlight:SetAllPoints()
		highlight:SetColorTexture(1, 1, 1, 0.08)
		row:SetScript("OnEnter", function(self)
			if not self.entry then return end
			GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
			GameTooltip:SetItemByID(self.entry.itemID)
			GameTooltip:Show()
		end)
		row:SetScript("OnLeave", function() GameTooltip:Hide() end)
	end
	row.entry = entry
	row.icon:SetTexture(PC.Items:GetIcon(entry.itemID))
	local name = PC.Items:GetName(entry.itemID)
	row.name:SetText(entry.count > 1 and (name .. " |cffaaaaaax" .. entry.count .. "|r") or name)
	row.disenchant:SetText(ValueText(entry, "disenchant", entry.disenchant))
	row.auction:SetText(ValueText(entry, "auction", entry.auction, entry.bound and "bound" or "-"))
	row.vendor:SetText(ValueText(entry, "vendor", entry.vendor))
end

function Bags:Refresh()
	if not (frame and frame:IsShown()) then return end
	if not PC.Auctionator:IsAvailable() then
		scrollBox:SetDataProvider(CreateDataProvider({}))
		footer:SetText("|cffff8888Auctionator not found: no disenchant estimates.|r")
		return
	end
	local list = BuildList()
	scrollBox:SetDataProvider(CreateDataProvider(list), ScrollBoxConstants.RetainScrollPosition)
	footer:SetText(string.format("%d item(s). Per item; %s>|r pays most after the %d%% AH cut. D/E: Auctionator est.",
		#list, GOOD, math.floor(PC.db.settings.ahCut * 100 + 0.5)))
end

local function Header(text, offset)
	local label = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	label:SetPoint("BOTTOMRIGHT", frame.Inset, "TOPRIGHT", -(18 + offset), 4)
	label:SetWidth(VALUE_WIDTH)
	label:SetJustifyH("RIGHT")
	label:SetText(text)
end

local function Create()
	frame = PC:CreateWindow("ProfitCraftBags", UIParent, WIDTH, HEIGHT, "ProfitCraft: Bags", { movable = true })

	local itemHeader = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	itemHeader:SetPoint("BOTTOMLEFT", frame.Inset, "TOPLEFT", 8, 4)
	itemHeader:SetText("Item")
	Header("Disenchant", 4 + 2 * VALUE_WIDTH)
	Header("AH", 4 + VALUE_WIDTH)
	Header("Vendor", 4)

	footer = PC:CreateFooter(frame)
	scrollBox = PC:CreateScrollList(frame, ROW_HEIGHT, "bags row", InitRow)
	frame:SetScript("OnShow", function() PC:Call("bags show", Bags.Refresh, Bags) end)
end

PC:Listen("TOGGLE_BAGS", function()
	if not frame then Create() end
	frame:SetShown(not frame:IsShown())
end)

local function RefreshSoon()
	if frame and frame:IsShown() then
		PC:Debounce("bags", 0.3, function() Bags:Refresh() end)
	end
end

PC:RegisterEvent("BAG_UPDATE_DELAYED", RefreshSoon)
PC:Listen("PRICES_CHANGED", RefreshSoon)
PC:Listen("ITEM_DATA_CHANGED", RefreshSoon)
PC:Listen("SETTINGS_CHANGED", function(key)
	if key == "ahCut" then RefreshSoon() end
end)
