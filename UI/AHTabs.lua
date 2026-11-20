-- ProfitCraft: tabs for the panels at the Auction House (RapidFire, On Sale)
-- A column of side tabs on the AH window's right edge, outside it, so no AH tab's buttons (Blizzard's Auctions tab,
-- Auctionator's Shopping and Cancelling tabs) can cover them (Sylice, 2026-11-20). Shown only while none of the
-- panels is open; an open panel has the same choices as page buttons in its header, so the tabs add no width then.
-- Same Blizzard template as the ProfitCraft tab on the profession window (UI/Panel.lua).

local _, PC = ...

local AHTabs = {}
PC.AHTabs = AHTabs

local entries = {}  -- { key, title, icon, help, open(), panel(), count() }, in order of registration
local column
local headers = {}  -- panel -> { [key] = button }

-- Title with the count, e.g. "On Sale (3)".
local function Title(entry)
  local count = entry.count and entry.count() or 0
  return count > 0 and string.format("%s (%d)", entry.title, count) or entry.title
end

local function AnyPanelShown()
  for _, entry in ipairs(entries) do
    local panel = entry.panel()
    if panel and panel:IsShown() then return true end
  end
  return false
end

function AHTabs:Register(entry)
  entries[#entries + 1] = entry
end

function AHTabs:Update()
  if column then
    column:SetShown(not AnyPanelShown())
    for _, tab in ipairs(column.tabs) do
      local count = tab.entry.count and tab.entry.count() or 0
      tab.badge:SetText(count > 0 and tostring(count) or "")
    end
  end
  for _, buttons in pairs(headers) do
    for _, entry in ipairs(entries) do
      if buttons[entry.key] then buttons[entry.key]:SetText(Title(entry)) end
    end
  end
end

local function CreateTab(entry, index)
  local tab = CreateFrame("Frame", nil, column, "LargeSideTabButtonTemplate")
  tab.entry = entry
  tab:SetPoint("TOPLEFT", 0, -(index - 1) * (tab:GetHeight() + 2))
  tab.Icon:SetTexture(entry.icon)
  tab:SetFillToInterior(true)
  tab.SelectedTexture:Hide()
  tab.badge = tab:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
  tab.badge:SetPoint("BOTTOMRIGHT", tab.Icon, "BOTTOMRIGHT", 0, 2)
  tab:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT", -4, -4)
    GameTooltip:AddLine("ProfitCraft " .. Title(entry), 1, 1, 1)
    GameTooltip:AddLine(entry.help, nil, nil, nil, true)
    GameTooltip:Show()
  end)
  tab:SetScript("OnLeave", function() GameTooltip:Hide() end)
  tab:SetCustomOnMouseUpHandler(function(_, button, upInside)
    if button == "LeftButton" and upInside ~= false then
      GameTooltip:Hide()
      PC:Call(entry.key .. " panel", entry.open)
    end
  end)
  return tab
end

local function CreateColumn()
  column = CreateFrame("Frame", nil, AuctionHouseFrame)
  column:SetPoint("TOPLEFT", AuctionHouseFrame, "TOPRIGHT", 0, -60)  -- as Forever's profession window tabs
  column:SetSize(1, 1)
  column.tabs = {}
  for index, entry in ipairs(entries) do column.tabs[index] = CreateTab(entry, index) end
end

-- Page buttons in an open panel's header (the strip between title bar and inset, right of the portrait):
-- the panel's own button stays lit, the others switch to their panel. The panel is closed with its X.
function AHTabs:AddHeader(panel, key)
  local buttons = {}
  local previous
  for _, entry in ipairs(entries) do
    local button = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    button:SetSize(110, 22)
    if previous then
      button:SetPoint("LEFT", previous, "RIGHT", 4, 0)
    else
      button:SetPoint("TOPLEFT", panel, "TOPLEFT", 62, -31)
    end
    button:SetText(Title(entry))
    if entry.key == key then
      button:LockHighlight()
    else
      button:SetScript("OnClick", function() PC:Call(entry.key .. " panel", entry.open) end)
    end
    buttons[entry.key] = button
    previous = button
  end
  headers[panel] = buttons
  panel:HookScript("OnShow", function() AHTabs:Update() end)
  panel:HookScript("OnHide", function() AHTabs:Update() end)
end

PC:RegisterEvent("AUCTION_HOUSE_SHOW", function()
  if AuctionHouseFrame and not column then CreateColumn() end
  AHTabs:Update()
end)
