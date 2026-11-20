-- ProfitCraft: tabs for the panels at the Auction House (RapidFire, On Sale)
-- A thin column of icon tabs at the bottom of the AH window's right edge (Sylice: more visible there than at the
-- top), outside it, so no AH tab's buttons (Blizzard's Auctions
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

local GAP = 4  -- between two tabs' frames, and between the column and the AH window / a panel

-- Sizes for the icon size set in the settings (ahTabSize, 24-44): the slot frame drawn around the icon keeps the
-- proportions of Forever's character-window slots (47 px frame around a 37 px button, PaperDollFrame.xml).
local function Sizes()
  local icon = PC.db.settings.ahTabSize or 24
  local frame = math.floor(icon * 47 / 37 + 0.5)
  return icon, frame
end

-- Panels' x offset from the AH window's right edge: right of the tab column.
function AHTabs:PanelOffset()
  local _, frame = Sizes()
  return frame + 2 * GAP
end

-- Anchors a panel right of the tab column (again after the tab size changes).
function AHTabs:Place(panel)
  panel:ClearAllPoints()
  panel:SetPoint("TOPLEFT", AuctionHouseFrame, "TOPRIGHT", self:PanelOffset(), 0)
end

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

local function CreateTab(entry)
  local tab = CreateFrame("CheckButton", nil, column)
  tab.entry = entry
  local icon = tab:CreateTexture(nil, "BACKGROUND")
  icon:SetAllPoints()
  icon:SetTexture(entry.icon)
  tab.border = tab:CreateTexture(nil, "BORDER")
  tab.border:SetTexture("Interface\\Buttons\\UI-Quickslot2")
  tab.border:SetPoint("CENTER", 0, -1)
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

-- Sizes and stacks the tabs for the current size setting: each tab one frame plus a gap below the previous one, so
-- they never overlap at any size; the column grows upwards from the bottom of the AH window's right edge.
local function Layout()
  if not column then return end
  local icon, frame = Sizes()
  local pitch = frame + GAP
  column:SetSize(frame + 2 * GAP, #column.tabs * pitch)
  for index, tab in ipairs(column.tabs) do
    tab:SetSize(icon, icon)
    tab:ClearAllPoints()
    tab:SetPoint("TOP", column, "TOP", 0, -(index - 1) * pitch - (frame - icon) / 2)
    tab.border:SetSize(frame, frame)
    tab.badge:SetFontObject(icon >= 36 and "NumberFontNormal" or "NumberFontNormalSmall")
  end
  for _, entry in ipairs(entries) do
    local panel = entry.panel()
    if panel then AHTabs:Place(panel) end
  end
end

local function CreateColumn()
  column = CreateFrame("Frame", nil, AuctionHouseFrame)
  column:SetPoint("BOTTOMLEFT", AuctionHouseFrame, "BOTTOMRIGHT", 0, 8)
  column.tabs = {}
  for index, entry in ipairs(entries) do column.tabs[index] = CreateTab(entry) end
  Layout()
end

PC:Listen("SETTINGS_CHANGED", function(key)
  if key == "ahTabSize" then PC:Call("tab size", Layout) end
end)

PC:RegisterEvent("AUCTION_HOUSE_SHOW", function()
  if AuctionHouseFrame and not column then CreateColumn() end
  AHTabs:Update()
end)
