-- ProfitCraft: tabs for the panels at the Auction House (RapidFire, On Sale)
-- A thin column of icon tabs on the AH window's right edge, outside it, so no AH tab's buttons (Blizzard's Auctions
-- tab, Auctionator's Shopping and Cancelling tabs) can cover them (Sylice, 2026-11-20). Always visible: the panels
-- open to the right of the column (as ProfitCraft's profit list sits right of Forever's profession tabs), and the
-- open panel's tab is lit; clicking it again closes the panel.
-- The tabs are small CheckButtons drawn like Forever's character-window buttons (Camelot PaperDollFrame.xml:
-- UI-Quickslot2 frame, ButtonHilight-Square on hover, CheckButtonHilight when checked). 0.3.4 used Blizzard's
-- LargeSideTabButtonTemplate, which is much wider on Forever ("Camelot tabs are wider"), and hid the column while a
-- panel was open; Sylice found both awkward.

local _, PC = ...

local AHTabs = {}
PC.AHTabs = AHTabs

local ICON_SIZE = 22
local FRAME_SIZE = math.floor(ICON_SIZE * 47 / 37 + 0.5)  -- the slot frame's proportions in PaperDollFrame.xml
local SPACING = 30
AHTabs.PANEL_OFFSET = 32  -- panels' x offset from the AH window's right edge: right of the tab column

local entries = {}  -- { key, title, icon, help, open(), panel(), count() }, in order of registration
local column

function AHTabs:Register(entry)
  entries[#entries + 1] = entry
end

function AHTabs:Update()
  if not column then return end
  for _, tab in ipairs(column.tabs) do
    local entry = tab.entry
    local panel = entry.panel()
    tab:SetChecked(panel ~= nil and panel:IsShown())
    local count = entry.count and entry.count() or 0
    tab.badge:SetText(count > 0 and tostring(count) or "")
  end
end

local function Toggle(entry)
  local panel = entry.panel()
  if panel and panel:IsShown() then
    panel:Hide()
  else
    entry.open()
    panel = entry.panel()
    if panel and not panel.pcTabsHooked then
      panel.pcTabsHooked = true
      panel:HookScript("OnShow", function() AHTabs:Update() end)
      panel:HookScript("OnHide", function() AHTabs:Update() end)
    end
  end
  AHTabs:Update()
end

local function CreateTab(entry, index)
  local tab = CreateFrame("CheckButton", nil, column)
  tab.entry = entry
  tab:SetSize(ICON_SIZE, ICON_SIZE)
  tab:SetPoint("TOP", 0, -(index - 1) * SPACING)
  local icon = tab:CreateTexture(nil, "BACKGROUND")
  icon:SetAllPoints()
  icon:SetTexture(entry.icon)
  local border = tab:CreateTexture(nil, "BORDER")
  border:SetTexture("Interface\\Buttons\\UI-Quickslot2")
  border:SetSize(FRAME_SIZE, FRAME_SIZE)
  border:SetPoint("CENTER", 0, -1)
  tab:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
  tab:SetCheckedTexture("Interface\\Buttons\\CheckButtonHilight", "ADD")
  tab.badge = tab:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
  tab.badge:SetPoint("BOTTOMRIGHT", 2, -1)
  tab:SetScript("OnClick", function()
    GameTooltip:Hide()
    PC:Call(entry.key .. " panel", Toggle, entry)
  end)
  tab:SetScript("OnEnter", function(self)
    local count = entry.count and entry.count() or 0
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:AddLine("ProfitCraft " .. entry.title .. (count > 0 and string.format(" (%d)", count) or ""), 1, 1, 1)
    GameTooltip:AddLine(entry.help, nil, nil, nil, true)
    GameTooltip:Show()
  end)
  tab:SetScript("OnLeave", function() GameTooltip:Hide() end)
  return tab
end

local function CreateColumn()
  column = CreateFrame("Frame", nil, AuctionHouseFrame)
  column:SetPoint("TOPLEFT", AuctionHouseFrame, "TOPRIGHT", 0, -60)
  column:SetSize(AHTabs.PANEL_OFFSET, 1)
  column.tabs = {}
  for index, entry in ipairs(entries) do column.tabs[index] = CreateTab(entry, index) end
end

PC:RegisterEvent("AUCTION_HOUSE_SHOW", function()
  if AuctionHouseFrame and not column then CreateColumn() end
  AHTabs:Update()
end)
