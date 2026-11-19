-- ProfitCraft: window helper
-- Creates ProfitCraft's windows in Blizzard's current frame style (ButtonFrameTemplate: portrait, title bar,
-- inset; the same template family as the profession window). Forever source: Blizzard_SharedXML/Mainline/
-- SharedUIPanelTemplates.xml and PortraitFrame.lua (SetTitle, SetPortraitToAsset).

local _, PC = ...

PC.ICON = "Interface\\Icons\\INV_Misc_Coin_02"

-- Returns a hidden window. options.movable: draggable, clamped to the screen and closed by Escape
-- (UISpecialFrames needs a global name, so movable windows must be named).
function PC:CreateWindow(name, parent, width, height, title, options)
  local frame = CreateFrame("Frame", name, parent or UIParent, "ButtonFrameTemplate")
  frame:SetSize(width, height)
  frame:SetTitle(title)
  frame:SetPortraitToAsset(PC.ICON)
  if options and options.movable then
    frame:SetPoint("CENTER")
    frame:SetFrameStrata("HIGH")
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    table.insert(UISpecialFrames, name)
  end
  frame:Hide()
  return frame
end

-- A scrolling list (Blizzard's ScrollBox) filling the window's inset. initializer(row, data) draws one row.
function PC:CreateScrollList(frame, rowHeight, where, initializer)
  local scrollBox = CreateFrame("Frame", nil, frame, "WowScrollBoxList")
  scrollBox:SetPoint("TOPLEFT", frame.Inset, "TOPLEFT", 4, -4)
  scrollBox:SetPoint("BOTTOMRIGHT", frame.Inset, "BOTTOMRIGHT", -18, 4)
  local scrollBar = CreateFrame("EventFrame", nil, frame, "MinimalScrollBar")
  scrollBar:SetPoint("TOPLEFT", scrollBox, "TOPRIGHT", 4, 0)
  scrollBar:SetPoint("BOTTOMLEFT", scrollBox, "BOTTOMRIGHT", 4, 0)
  local view = CreateScrollBoxListLinearView()
  view:SetElementExtent(rowHeight)
  view:SetElementInitializer("Button", function(row, data)
    PC:Call(where, initializer, row, data)
  end)
  ScrollUtil.InitScrollBoxListWithScrollBar(scrollBox, scrollBar, view)
  return scrollBox
end

-- Footer text in the strip below the inset.
function PC:CreateFooter(frame)
  local text = frame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  text:SetPoint("BOTTOMLEFT", 10, 8)
  text:SetPoint("BOTTOMRIGHT", -10, 8)
  text:SetJustifyH("LEFT")
  text:SetWordWrap(false)
  return text
end
