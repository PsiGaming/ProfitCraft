-- ProfitCraft: side panel
-- Compact ranked list of the open profession's recipes, next to Blizzard's profession window
-- (DESIGN.md section 7). Only redraws from stored results; never recalculates.

local _, PC = ...

local Panel = {}
PC.Panel = Panel

local WIDTH = 320
local ROW_HEIGHT = 22
local MODES = { "craft", "stack", "disenchant" }
local MODE_LABEL = { craft = "Per craft", stack = "Per stack", disenchant = "Disenchant" }
local MODE_HELP = {
  craft = "Profit of one craft, selling the product on the AH.",
  stack = "Profit of one full stack of the product, selling it on the AH.",
  disenchant = "Profit of one craft if you disenchant the product and sell the materials "
    .. "(estimated disenchant value).",
}

local BANNER_HEIGHT = 44

local frame, scrollBox, modeDropdown, statusText, toggleTab, banner
local UpdateToggleTab  -- defined below; used by the overview hooks in Create

local function ShowRowTooltip(row)
  local result = row.result
  if not result then return end
  local recipe = result.recipe
  GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
  GameTooltip:AddLine(recipe.name, 1, 1, 1)
  if recipe.quantityMin ~= recipe.quantityMax then
    GameTooltip:AddLine(string.format("Makes %d-%d (counted as %s)", recipe.quantityMin, recipe.quantityMax,
      tostring(result.quantity)), 0.8, 0.8, 0.8)
  elseif recipe.quantityMin > 1 then
    GameTooltip:AddLine("Makes " .. recipe.quantityMin, 0.8, 0.8, 0.8)
  end
  if result.complete then
    GameTooltip:AddDoubleLine("Profit per craft", PC:FormatProfit(result.profitCraft))
    if result.stackSize and result.stackSize > 1 then
      GameTooltip:AddDoubleLine("Profit per stack (" .. result.stackSize .. ")", PC:FormatProfit(result.profitStack))
    end
    GameTooltip:AddDoubleLine("Auction price per item", PC:FormatMoney(result.salePrice), 0.8, 0.8, 0.8)
  elseif result.bound then
    GameTooltip:AddLine("Bind on pickup: can't be sold", 0.8, 0.8, 0.8)
  end
  if result.cost then
    GameTooltip:AddDoubleLine("Reagent cost per craft", PC:FormatMoney(result.cost), 0.8, 0.8, 0.8)
  end
  if result.profitDisenchant then
    GameTooltip:AddDoubleLine("Craft and disenchant", PC:FormatProfit(result.profitDisenchant))
    GameTooltip:AddDoubleLine("  Disenchant estimate per item", PC:FormatMoney(result.disenchantValue), 0.8, 0.8, 0.8)
  end
  if #result.missing > 0 then
    GameTooltip:AddLine("No price for:", 1, 0.5, 0.5)
    for _, itemID in ipairs(result.missing) do
      GameTooltip:AddLine("  " .. PC.Items:GetName(itemID), 1, 0.5, 0.5)
    end
  end
  GameTooltip:AddLine("Click to show this recipe.", 0.5, 0.7, 1)
  GameTooltip:Show()
end

local function ProfitText(result, mode)
  if mode == "disenchant" then
    if result.profitDisenchant then return PC:FormatProfit(result.profitDisenchant) end
    if result.cost and not result.disenchantValue then return "|cff888888no D/E price|r" end
    return "|cff888888no price|r"
  end
  if result.bound then return "|cff888888BoP|r" end
  if not result.complete then return "|cff888888no price|r" end
  if mode == "stack" then
    if not result.profitStack then return "|cff888888?|r" end
    local size = result.stackSize or 1
    local prefix = size > 1 and ("|cffaaaaaax" .. size .. "|r  ") or ""
    return prefix .. PC:FormatProfit(result.profitStack)
  end
  return PC:FormatProfit(result.profitCraft)
end

local function InitRow(row, result)
  if not row.created then
    row.created = true
    row:SetHeight(ROW_HEIGHT)
    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetSize(ROW_HEIGHT - 4, ROW_HEIGHT - 4)
    row.icon:SetPoint("LEFT", 2, 0)
    row.profit = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.profit:SetPoint("RIGHT", -4, 0)
    row.profit:SetJustifyH("RIGHT")
    row.name = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    row.name:SetPoint("LEFT", row.icon, "RIGHT", 4, 0)
    row.name:SetPoint("RIGHT", row.profit, "LEFT", -6, 0)
    row.name:SetJustifyH("LEFT")
    row.name:SetWordWrap(false)
    local highlight = row:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetAllPoints()
    highlight:SetColorTexture(1, 1, 1, 0.08)
    row:SetScript("OnEnter", function(self) PC:Call("row tooltip", ShowRowTooltip, self) end)
    row:SetScript("OnLeave", function() GameTooltip:Hide() end)
    row:SetScript("OnClick", function(self)
      if self.result then PC:Call("open recipe", C_TradeSkillUI.OpenRecipe, self.result.recipe.recipeID) end
    end)
  end
  row.result = result
  row.icon:SetTexture(result.recipe.icon)
  row.name:SetText(result.recipe.name)
  row.profit:SetText(ProfitText(result, PC.db.settings.profitMode))
end

-- Newest Auctionator price age (whole days, 0 = today) among the listed recipes' products and reagents, or nil
-- when none of them has a price.
local function NewestPriceAge(list)
  local newest
  local function Check(itemID)
    local age = itemID and PC.Auctionator:GetAuctionAge(itemID)
    if age and (not newest or age < newest) then newest = age end
  end
  for _, result in ipairs(list) do
    Check(result.recipe.outputItemID)
    for _, reagent in ipairs(result.reagents) do Check(reagent.itemID) end
  end
  return newest
end

-- "12 min ago", "3 h ago", "2 days ago".
local function ScanAge(t)
  local minutes = math.floor((time() - t) / 60)
  if minutes < 60 then return minutes .. " min ago" end
  if minutes < 48 * 60 then return math.floor(minutes / 60) .. " h ago" end
  return math.floor(minutes / 1440) .. " days ago"
end

local function ScanWith()
  return PC.Auctionator:IsAvailable() and "with Auctionator" or "with ProfitCraft's Full scan button"
end

local function OldPricesText(days)
  return string.format("AH prices are %d %s old. Scan the Auction House %s to update them.", days,
    days == 1 and "day" or "days", ScanWith())
end

-- Time of the newest scan seen: Auctionator's (recorded by ProfitCraft) or ProfitCraft's snapshot; or nil.
local function LastScanTime()
  local auctionator = PC.Auctionator:GetLastScanTime()
  local snapshot = PC.Scan:GetSnapshot()
  local own = snapshot and snapshot.time
  if auctionator and own then return math.max(auctionator, own) end
  return auctionator or own
end

-- The banner's text: no AH prices yet, or prices older than the staleDays setting (0 = that warning off); nil when
-- all is well. Without Auctionator, prices come only from ProfitCraft's own full scans.
local function PriceWarning(list)
  if not PC.Auctionator:IsAvailable() and not PC.Scan:GetSnapshot() then
    return "No AH prices yet. Without Auctionator, scan the Auction House with ProfitCraft's Full scan button "
      .. "(on the AH window)."
  end
  if #list == 0 then return nil end
  local staleDays = PC.db.settings.staleDays
  local lastScan = LastScanTime()
  if lastScan then
    local hours = (time() - lastScan) / 3600
    if staleDays == 0 or hours < staleDays * 24 then return nil end
    return OldPricesText(math.floor(hours / 24))
  end
  -- No scan seen by ProfitCraft yet (e.g. just updated): fall back to Auctionator's price age in days.
  local age = NewestPriceAge(list)
  if not age then return "No AH prices yet. Scan the Auction House " .. ScanWith() .. "." end
  if staleDays == 0 or age < staleDays then return nil end
  return OldPricesText(age)
end

-- Shows the banner above the list (moving the list down) or hides it.
local function UpdateBanner(text)
  banner.text:SetText(text or "")
  banner:SetShown(text ~= nil)
  scrollBox:SetPoint("TOPLEFT", frame.Inset, "TOPLEFT", 4, text and -(BANNER_HEIGHT + 8) or -4)
end

function Panel:Refresh()
  if not (frame and frame:IsShown()) then return end
  local mode = PC.db.settings.profitMode
  modeDropdown:GenerateMenu()
  local list = PC.Profit:GetRanked(mode)
  UpdateBanner(PriceWarning(list))
  scrollBox:SetDataProvider(CreateDataProvider(list), ScrollBoxConstants.RetainScrollPosition)
  if not PC.Auctionator:IsAvailable() and not PC.Scan:GetSnapshot() then
    statusText:SetText("|cffff8888No AH prices yet: use the Full scan button at the AH.|r")
  elseif #list == 0 then
    statusText:SetText("Reading recipes...")
  else
    local field = PC.Profit.PROFIT_FIELD[mode]
    local priced = 0
    for _, result in ipairs(list) do
      if result[field] then priced = priced + 1 end
    end
    local text = string.format("%s: %d recipes, %d priced", PC.Recipes.professionName or "?", #list, priced)
    local snapshot = PC.Scan:GetSnapshot()
    if snapshot then text = text .. ", scan " .. ScanAge(snapshot.time) end
    statusText:SetText(text)
  end
end

-- Forever (only) has a column of profession tabs on the window's right edge (Camelot ProfessionsFrame.xml:
-- ProfessionsOverviewTab and Professions1Tab..7Tab, anchored to its TOPRIGHT); the panel goes right of them.
local function TabColumnWidth()
  local tab = ProfessionsFrame.ProfessionsOverviewTab
  return tab and tab.GetWidth and tab:GetWidth() or 0
end

-- The window can also show the professions overview (BookPage); the panel only belongs with a recipe list.
local function BookPageShown()
  local page = ProfessionsFrame and ProfessionsFrame.BookPage
  return page and page:IsShown()
end

local function ShouldShow()
  return PC.db.settings.panelShown and PC.Recipes.isOpen and ProfessionsFrame and ProfessionsFrame:IsShown()
    and not BookPageShown()
end

local function SmallButton(parent, width, text, tooltip, onClick)
  local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
  button:SetSize(width, 22)
  button:SetText(text)
  button:SetScript("OnClick", onClick)
  button:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:AddLine(tooltip, 1, 1, 1, true)
    GameTooltip:Show()
  end)
  button:SetScript("OnLeave", function() GameTooltip:Hide() end)
  return button
end

local function Create()
  frame = PC:CreateWindow("ProfitCraftPanel", ProfessionsFrame, WIDTH, ProfessionsFrame:GetHeight(), "ProfitCraft")
  frame:SetPoint("TOPLEFT", ProfessionsFrame, "TOPRIGHT", TabColumnWidth() + 4, 0)
  frame.CloseButton:SetScript("OnClick", function()
    PC:SetSetting("panelShown", false)
    Panel:Update()
  end)

  -- Mode dropdown (Blizzard's current dropdown: WowStyle1DropdownTemplate + SetupMenu/CreateRadio).
  modeDropdown = CreateFrame("DropdownButton", nil, frame, "WowStyle1DropdownTemplate")
  modeDropdown:SetWidth(104)
  modeDropdown:SetPoint("TOPLEFT", 60, -30)
  modeDropdown:SetupMenu(function(_, rootDescription)
    for _, mode in ipairs(MODES) do
      local option = rootDescription:CreateRadio(MODE_LABEL[mode],
        function() return PC.db.settings.profitMode == mode end,
        function() PC:SetSetting("profitMode", mode) end)
      option:SetTooltip(function(tooltip)
        GameTooltip_SetTitle(tooltip, MODE_LABEL[mode])
        GameTooltip_AddNormalLine(tooltip, MODE_HELP[mode])
      end)
    end
  end)

  local settingsButton = SmallButton(frame, 66, "Settings", "ProfitCraft settings.",
    function() PC:Send("TOGGLE_SETTINGS") end)
  settingsButton:SetPoint("TOPRIGHT", -8, -32)
  local bagsButton = SmallButton(frame, 70, "D/E Bags", "Disenchant value of the items in your bags.",
    function() PC:Send("TOGGLE_BAGS") end)
  bagsButton:SetPoint("RIGHT", settingsButton, "LEFT", -4, 0)

  statusText = PC:CreateFooter(frame)
  scrollBox = PC:CreateScrollList(frame, ROW_HEIGHT, "panel row", InitRow)

  -- Warning banner at the top of the list (Auctionator missing, no prices, old prices).
  banner = CreateFrame("Frame", nil, frame)
  banner:SetPoint("TOPLEFT", frame.Inset, "TOPLEFT", 4, -4)
  banner:SetPoint("TOPRIGHT", frame.Inset, "TOPRIGHT", -4, -4)
  banner:SetHeight(BANNER_HEIGHT)
  local background = banner:CreateTexture(nil, "BACKGROUND")
  background:SetAllPoints()
  background:SetColorTexture(0.45, 0.1, 0.05, 0.85)
  banner.text = banner:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  banner.text:SetPoint("TOPLEFT", 8, -6)
  banner.text:SetPoint("BOTTOMRIGHT", -8, 6)
  banner.text:SetJustifyH("LEFT")
  banner.text:SetJustifyV("MIDDLE")
  banner.text:SetWordWrap(true)
  banner:Hide()

  frame:SetScript("OnShow", function() PC:Call("panel show", Panel.Refresh, Panel) end)

  -- Hide over the overview page, come back when it closes (HookScript adds to Blizzard's handlers).
  if ProfessionsFrame.BookPage then
    ProfessionsFrame.BookPage:HookScript("OnShow", function() frame:Hide() UpdateToggleTab() end)
    ProfessionsFrame.BookPage:HookScript("OnHide", function()
      PC:Call("panel after overview", function() Panel:Update() end)
    end)
  end
end

-- A tab that shows or hides the panel, in the next free slot of Forever's right-hand tab column counted from
-- the BOTTOM of the profession window: the lowest slot is 10 px above the bottom edge (where What's Training
-- puts its tab by default, Crafting/Crafting.lua:197 in its 11.4.6); if another addon's frame is already in
-- that spot, the tab moves up above it, 2 px apart like Blizzard's tabs. Same template and art as Blizzard's
-- tabs (LargeSideTabButtonTemplate). Lit while the panel is open. Re-placed when Blizzard refreshes its tabs
-- and whenever the panel updates, since other addons may add or move their tabs at any time.
local BOTTOM_MARGIN, SLOT_GAP = 10, 2

-- Other frames attached to the window's right edge in the tab column (not Blizzard's tabs, not ours).
local function OccupiedSpans()
  local column = ProfessionsFrame:GetRight()
  if not column then return {} end
  local blizzard = { [ProfessionsFrame.ProfessionsOverviewTab or false] = true }
  for _, tab in ipairs(ProfessionsFrame.rightProfessionTabs or {}) do blizzard[tab] = true end
  local spans = {}
  for _, child in ipairs({ ProfessionsFrame:GetChildren() }) do
    if child ~= toggleTab and child ~= frame and not blizzard[child] and child:IsShown() then
      local left, bottom, top = child:GetLeft(), child:GetBottom(), child:GetTop()
      if left and bottom and top and left >= column - 4 and left <= column + 20 then
        spans[#spans + 1] = { bottom = bottom, top = top }
      end
    end
  end
  return spans
end

local function PlaceToggleTab()
  if not toggleTab then return end
  local frameBottom = ProfessionsFrame:GetBottom()
  local height = toggleTab:GetHeight()
  local offset = BOTTOM_MARGIN
  if frameBottom and height and height > 0 then
    local spans = OccupiedSpans()
    local moved = true
    while moved do
      moved = false
      local slotBottom, slotTop = frameBottom + offset, frameBottom + offset + height
      for _, span in ipairs(spans) do
        if span.top > slotBottom and span.bottom < slotTop then
          offset = span.top - frameBottom + SLOT_GAP
          moved = true
        end
      end
    end
  end
  toggleTab:ClearAllPoints()
  toggleTab:SetPoint("BOTTOMLEFT", ProfessionsFrame, "BOTTOMRIGHT", 0, offset)
end

local function CreateToggleTab()
  toggleTab = CreateFrame("Frame", nil, ProfessionsFrame, "LargeSideTabButtonTemplate")
  if type(ProfessionsFrame.RefreshRightTabs) == "function" then
    hooksecurefunc(ProfessionsFrame, "RefreshRightTabs", function() PC:Call("place tab", PlaceToggleTab) end)
  end
  toggleTab.Icon:SetTexture(PC.ICON)
  toggleTab:SetFillToInterior(true)
  toggleTab.tooltipText = "ProfitCraft"
  toggleTab:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT", -4, -4)
    GameTooltip:AddLine("ProfitCraft", 1, 1, 1)
    GameTooltip:AddLine("Show or hide the profit list.", nil, nil, nil, true)
    GameTooltip:Show()
  end)
  toggleTab:SetScript("OnLeave", function() GameTooltip:Hide() end)
  toggleTab:SetCustomOnMouseUpHandler(function(_, button, upInside)
    if button == "LeftButton" and upInside ~= false then PC:Send("TOGGLE_PANEL") end
  end)
end

function UpdateToggleTab()
  if not toggleTab then return end
  PlaceToggleTab()
  -- Other addons may create or move their tab after us; check again once the frame has been laid out.
  C_Timer.After(0, function() PC:Call("place tab", PlaceToggleTab) end)
  local onRecipes = PC.Recipes.isOpen and not BookPageShown()
  toggleTab:SetShown(onRecipes)
  toggleTab.SelectedTexture:SetShown(frame ~= nil and frame:IsShown())
end

-- Shows or hides the panel to match the current state.
function Panel:Update()
  if ProfessionsFrame and not toggleTab then CreateToggleTab() end
  if not ShouldShow() then
    if frame then frame:Hide() end
  else
    if not frame then Create() end
    if frame:IsShown() then
      self:Refresh()
    else
      frame:Show()  -- OnShow refreshes
    end
  end
  UpdateToggleTab()
end

PC:Listen("PROFESSION_OPENED", function() Panel:Update() end)
PC:Listen("PROFESSION_CLOSED", function() Panel:Update() end)

PC:Listen("TOGGLE_PANEL", function()
  if not (PC.Recipes.isOpen and ProfessionsFrame and ProfessionsFrame:IsShown()) then
    PC:Print("open a profession window first.")
    return
  end
  PC:SetSetting("panelShown", not (frame and frame:IsShown()))
  Panel:Update()
end)

PC:Listen("RESULTS_CHANGED", function() Panel:Refresh() end)
PC:Listen("SETTINGS_CHANGED", function(key)
  if key == "staleDays" then Panel:Refresh() end
end)
PC:Listen("SETTINGS_CHANGED", function(key)
  if key == "profitMode" then Panel:Refresh() end
end)
