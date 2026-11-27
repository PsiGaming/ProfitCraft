-- ProfitCraft: the Vendor page of the Opportunities panel (FEATURES.md "Opportunities", DESIGN.md section 16)
-- Listings below vendor price from the last full scan (Vendor.lua), sorted by profit, biggest first. Clicking a find
-- uses On Sale's buy dialog (OnSale:InspectHit): it checks the live listings and offers what is still below vendor
-- price. No sound or glow (2026-11-24). The panel itself is built by UI/OnSale.lua.

local _, PC = ...

local Vendor = PC.Vendor
local VendorUI = {}
PC.VendorUI = VendorUI

local ROW_HEIGHT = 22

local page, header, list, quickButton, quickStatus, detailBox, stackableBox

-- Buy through On Sale's dialog: at or under one copper below the vendor price, so every unit bought earns something
-- (the dialog checks that again before every purchase, VendorSafe). Items that don't stack: after each purchase the
-- dialog offers the next one (buyNext; 2026-11-24: "I can just spam that button").
local function Inspect(key)
  local hit = Vendor:GetHit(key)
  if not hit then return end
  PC.OnSale:InspectHit({
    key = hit.key, itemID = hit.itemID, variant = hit.variant, itemKey = hit.itemKey, stackable = hit.stackable,
    name = hit.name or PC.Items:GetName(hit.itemID), limit = hit.vendorPrice - 1, vendorPrice = hit.vendorPrice,
    buyNext = true,
    dialogTitle = "ProfitCraft Vendor", prefix = "Vendor", goneText = "No longer below vendor price.",
    remove = function(h) Vendor:RemoveHit(h.key) end,
    bought = function(h, offer) Vendor:Bought(h.key, offer.quantity, offer.total) end,
  })
end

-- Left-click (2026-11-24): show the item in Blizzard's own Buy tab, to see its real listings before buying.
-- With an item key: AuctionHouseFrame:SelectBrowseResult, the function Blizzard's browse list calls when a row is
-- clicked (Forever source, Blizzard_AuctionHouseFrame.lua), and the one Auctionator calls for the same purpose
-- (Auctionator 346, Source_ModernAH/Tabs/Buying/Commodity/Mixins/Main.lua). Auctionator then clears
-- AuctionHouseFrame.displayMode, noting it "prevents bag items breaking in some scenarios"; done here too. Gear found
-- by a full scan has no item key: its name goes into Blizzard's search box instead.
local function ShowInAH(key)
  local hit = Vendor:GetHit(key)
  if not (hit and AuctionHouseFrame) then return end
  local itemKey = hit.itemKey
  if itemKey and C_AuctionHouse.GetItemKeyInfo(itemKey) then
    -- Blizzard's listing panel only searches when it becomes visible (its OnShow, Blizzard_AuctionHouseItemList.lua);
    -- SelectBrowseResult on an open one just swaps the item without a search (2026-11-24: only the first
    -- click searched). So back to the browse view first, as Blizzard's Back button does, then select the item.
    if AuctionHouseFrameDisplayMode then AuctionHouseFrame:SetDisplayMode(AuctionHouseFrameDisplayMode.Buy) end
    AuctionHouseFrame:SelectBrowseResult({ itemKey = itemKey, minPrice = hit.cheapest or 0 })
    AuctionHouseFrame.displayMode = nil
    return
  end
  -- A name search is a browse search: it would replace the browse results a running quick scan is still reading.
  if Vendor:IsQuickScanning() then
    PC:Print("Wait for the quick scan to finish, then click again.")
    return
  end
  if AuctionHouseFrameDisplayMode then AuctionHouseFrame:SetDisplayMode(AuctionHouseFrameDisplayMode.Buy) end
  AuctionHouseFrame:SetSearchText(hit.name or PC.Items:GetName(hit.itemID))
  AuctionHouseFrame.SearchBar:StartSearch()
end

-- Shift + left-click (2026-11-24): watch a stackable find with RapidFire, at a max of one copper below the
-- vendor price (RapidFire never pays as much as a vendor gives for it, whatever its price tolerance).
local function WatchWithRapidFire(key)
  local hit = Vendor:GetHit(key)
  if not hit then return end
  local name = hit.name or PC.Items:GetName(hit.itemID)
  if not hit.stackable then
    PC:Print(name .. ": RapidFire only watches stackable goods.")
    return
  end
  if PC.Rapid:AddItem(hit.itemID, hit.vendorPrice) then
    PC:Print(string.format("%s watched by RapidFire: max %s (a vendor pays %s). Start it on the RapidFire tab.", name,
      PC:FormatMoney(hit.vendorPrice - 1), PC:FormatMoney(hit.vendorPrice)))
    if not PC.Items:IsVerifiedSellable(hit.itemID) then
      PC:Print("|cffff8000" .. name .. ": its vendor price isn't verified (an item newer than ProfitCraft's game data, "
        .. "never seen in your bags or bank). Check that a merchant takes it before letting RapidFire buy much.|r")
    end
  end
end

local function Column(row, x, width)
  local text = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  text:SetSize(width, ROW_HEIGHT)
  text:SetPoint("LEFT", x, 0)
  text:SetJustifyH("RIGHT")
  return text
end

-- One row; the scroll list reuses rows, so the parts are made once per row.
local function InitRow(row, hit)
  if not row.created then
    row.created = true
    local highlight = row:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetAllPoints()
    highlight:SetColorTexture(1, 1, 1, 0.08)
    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetSize(16, 16)
    row.icon:SetPoint("LEFT", 2, 0)
    row.name = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.name:SetSize(170, ROW_HEIGHT)
    row.name:SetPoint("LEFT", 22, 0)
    row.name:SetJustifyH("LEFT")
    row.name:SetWordWrap(false)
    row.units = Column(row, 194, 40)
    row.cost = Column(row, 236, 80)
    row.profit = Column(row, 318, 76)
    row:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    row:SetScript("OnClick", function(self, button)
      if not self.key then return end
      if button == "RightButton" then
        PC:Call("vendor buy", Inspect, self.key)
      elseif IsShiftKeyDown() then
        PC:Call("vendor rapidfire", WatchWithRapidFire, self.key)
      else
        PC:Call("vendor show", ShowInAH, self.key)
      end
    end)
    row:SetScript("OnEnter", function(self)
      local found = self.key and Vendor:GetHit(self.key)
      if not found then return end
      GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
      GameTooltip:AddLine(found.name or PC.Items:GetName(found.itemID), 1, 1, 1)
      -- Stacks or not, and how far (2026-11-24: "I don't have a clue if it's stackable"): items that don't
      -- stack are each bought, carried and sold on their own.
      local stack = PC.Items:GetStackSize(found.itemID)
      if not stack then
        GameTooltip:AddLine("Stack size not known yet", 0.7, 0.7, 0.7)
      elseif stack > 1 then
        GameTooltip:AddLine("Stacks up to " .. stack, 0.5, 1, 0.5)
      elseif found.units and found.units > 1 then
        GameTooltip:AddLine(string.format("Doesn't stack: %d separate items to buy, carry and sell", found.units), 1, 0.5,
          0.25, true)
      else
        GameTooltip:AddLine("Doesn't stack", 1, 0.5, 0.25)
      end
      if found.unchecked then
        GameTooltip:AddDoubleLine("Cheapest", PC:FormatMoney(found.cheapest))
        GameTooltip:AddDoubleLine("Vendor pays", PC:FormatMoney(found.vendorPrice))
        GameTooltip:AddDoubleLine("Profit per unit", PC:FormatProfit(found.profit))
        GameTooltip:AddLine("Not checked: how many are this cheap shows when you buy.", 0.7, 0.7, 0.7, true)
      else
        GameTooltip:AddDoubleLine(string.format("%d in %d listing%s", found.units, found.listings,
          found.listings == 1 and "" or "s"), PC:FormatMoney(found.cost))
        GameTooltip:AddDoubleLine(string.format("Vendor pays (%s each)", PC:FormatMoney(found.vendorPrice)),
          PC:FormatMoney(found.value))
        GameTooltip:AddDoubleLine("Profit", PC:FormatProfit(found.profit))
      end
      GameTooltip:AddLine("Left-click: show in the Auction House", 0.5, 0.7, 1)
      if not PC.Items:IsVerifiedSellable(found.itemID) then
        GameTooltip:AddLine("Vendor price not verified: an item newer than ProfitCraft's game data, never seen in your "
          .. "bags or bank. Its sell price may be wrong (some items no merchant takes).", 1, 0.5, 0.25, true)
      end
      GameTooltip:AddLine("Right-click: buy", 0.3, 1, 0.3)
      if found.stackable then GameTooltip:AddLine("Shift + left-click: watch with RapidFire", 1, 0.82, 0) end
      GameTooltip:Show()
    end)
    row:SetScript("OnLeave", function() GameTooltip:Hide() end)
  end
  row.key = hit.key
  row.icon:SetTexture(PC.Items:GetIcon(hit.itemID) or 134400)
  -- Orange "!": vendor price not verified (Items:IsVerifiedSellable): a warning, buying works as usual (decided
  -- 2026-11-24: no test buys); max per purchase and "keep at least" limit what a wrong price can cost.
  row.name:SetText((PC.Items:IsVerifiedSellable(hit.itemID) and "" or "|cffff8000!|r ")
    .. (hit.name or PC.Items:GetName(hit.itemID)))
  if hit.unchecked then  -- quick scan, not checked (yet): cheapest price and profit per unit
    row.units:SetText("|cff888888?|r")
    row.cost:SetText("|cff888888@|r " .. PC:FormatMoney(hit.cheapest))
    row.profit:SetText(PC:FormatProfit(hit.profit) .. "|cff888888/u|r")
  else
    row.units:SetText(tostring(hit.units))
    row.cost:SetText(PC:FormatMoney(hit.cost))
    row.profit:SetText(PC:FormatProfit(hit.profit))
  end
end

local function HeaderText(count, hidden)
  local t = Vendor:GetScanTime()
  if not t then return "No scan read yet: press Quick scan below, or run a full scan." end
  local expired = Vendor:ExpiredFor()
  if expired then
    return string.format("The last scan expired %s ago. Please run a full scan or Quick scan again.",
      PC:FormatAge(expired))
  end
  local when = string.format("%s, %s ago", date("%H:%M", t), PC:FormatAge(time() - t))
  local filtered = hidden > 0 and string.format(" |cff888888(%d hidden by filters)|r", hidden) or ""
  if count == 0 then return "No finds in the scan of " .. when .. "." .. filtered end
  return string.format("%d find%s in the scan of %s%s", count, count == 1 and "" or "s", when, filtered)
end

local QUICK_HINT = "Reads the whole AH; no 15-minute wait."

function VendorUI:Refresh()
  if not (page and page:IsShown()) then return end
  local hits, hidden = Vendor:GetHits()
  header:SetText(HeaderText(#hits, hidden))
  list:SetDataProvider(CreateDataProvider(hits), ScrollBoxConstants.RetainScrollPosition)
  quickButton:SetEnabled(not Vendor:IsQuickScanning())
  detailBox:SetChecked(PC.db.settings.quickScanDetail)
  stackableBox:SetChecked(PC.db.settings.vendorStackableOnly)
  quickStatus:SetText(Vendor:GetQuickScanStatus() or QUICK_HINT)
end

PC:Listen("SETTINGS_CHANGED", function(key)
  if key == "quickScanDetail" or key == "vendorStackableOnly" then PC:Call("vendor page", VendorUI.Refresh, VendorUI) end
end)

-- A small checkbox bound to a boolean setting, with a tooltip.
local function SettingBox(key, label, help)
  local box = CreateFrame("CheckButton", nil, page, "UICheckButtonTemplate")
  box:SetSize(22, 22)
  box.Text:SetText(label)
  box.Text:SetFontObject("GameFontHighlightSmall")
  box:SetScript("OnClick", function(self) PC:SetSetting(key, self:GetChecked() and true or false) end)
  box:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:AddLine(label, 1, 1, 1)
    GameTooltip:AddLine(help, nil, nil, nil, true)
    GameTooltip:Show()
  end)
  box:SetScript("OnLeave", function() GameTooltip:Hide() end)
  return box
end

-- Builds the page inside `parent` (the Opportunities panel's content area) and returns it.
function VendorUI:CreatePage(parent)
  page = CreateFrame("Frame", nil, parent)
  page:SetAllPoints()
  -- "Stackable only" (2026-11-24): hides items that don't stack (setting vendorStackableOnly; Vendor.lua).
  stackableBox = SettingBox("vendorStackableOnly", "Stackable only", "Hide finds of items that don't stack (gear, "
    .. "bags, recipes): each one has to be bought, carried and sold on its own. When unticked, they still only show "
    .. "if each earns at least \"Single items: min profit each\" (Settings > Opportunities).")
  stackableBox:SetPoint("TOPRIGHT", -96, -1)
  header = page:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  header:SetPoint("TOPLEFT", 8, -6)
  header:SetPoint("RIGHT", stackableBox, "LEFT", -6, 0)
  header:SetJustifyH("LEFT")
  header:SetWordWrap(false)
  local columns = CreateFrame("Frame", nil, page)
  columns:SetPoint("TOPLEFT", 4, -22)
  columns:SetSize(400, 16)
  for _, c in ipairs({ { "Item", 26, 170, "LEFT" }, { "Units", 194, 40 }, { "Cost", 236, 80 }, { "Profit", 318, 76 } }) do
    local label = columns:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    label:SetSize(c[3], 16)
    label:SetPoint("LEFT", c[2], 0)
    label:SetJustifyH(c[4] or "RIGHT")
    label:SetText(c[1])
  end
  local area = CreateFrame("Frame", nil, page)
  area:SetPoint("TOPLEFT", 0, -38)
  area:SetPoint("BOTTOMRIGHT", 0, 34)
  list = PC:CreateScrollList(page, ROW_HEIGHT, "vendor row", InitRow, area)
  -- Quick scan (Vendor.lua): a summary-style scan of the whole AH, then a check of the items found below vendor price.
  quickButton = CreateFrame("Button", nil, page, "UIPanelButtonTemplate")
  quickButton:SetSize(100, 22)
  quickButton:SetPoint("BOTTOMLEFT", 8, 8)
  quickButton:SetText("Quick scan")
  quickButton:SetScript("OnClick", function() PC:Call("vendor quick scan", Vendor.QuickScan, Vendor) end)
  -- "Check top items" (2026-11-24): the quick scan's detailed checks on or off (setting quickScanDetail).
  detailBox = SettingBox("quickScanDetail", "Check top items", "After reading the whole Auction House, check the most "
    .. "promising items (Settings > Opportunities: 5, 10 or 20) for how many are below vendor price and what they cost; "
    .. "only those stay listed. Off: the scan ends after reading the AH, and every item found stays listed with its "
    .. "cheapest price and profit per unit.")
  detailBox:SetPoint("LEFT", quickButton, "RIGHT", 6, 0)
  quickStatus = page:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  quickStatus:SetPoint("LEFT", detailBox.Text, "RIGHT", 10, 0)
  quickStatus:SetPoint("RIGHT", -8, 0)
  quickStatus:SetJustifyH("LEFT")
  page:SetScript("OnShow", function() PC:Call("vendor page", VendorUI.Refresh, VendorUI) end)
  return page
end

PC:Listen("VENDOR_QUICKSCAN", function() PC:Call("vendor page", VendorUI.Refresh, VendorUI) end)
PC:Listen("ITEM_SELLABLE", function() PC:Call("vendor page", VendorUI.Refresh, VendorUI) end)  -- "!" marks go
