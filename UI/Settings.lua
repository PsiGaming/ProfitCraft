-- ProfitCraft: settings
-- One list of options in three pages (General, Crafting profit, Opportunities), shown in two places built from it:
--   * ProfitCraft's own movable window (/pcraft settings, the side panel's "Settings" button). Closing it just
--     closes it; it never goes through Blizzard's settings panel, whose close always reopens the game menu
--     (Forever source: SettingsPanelMixin:TransitionBackOpeningPanel -> ToggleGameMenu).
--   * The same page under Blizzard's Options > AddOns > ProfitCraft, for people who look there (closing that
--     returns to the game menu, which is where they came from).
-- Each page re-reads the settings when shown and after any change, so the two never disagree.
-- Forever source for the Blizzard side: Blizzard_Settings_Shared/Blizzard_Settings.lua
-- (Settings.RegisterCanvasLayoutCategory, Settings.RegisterAddOnCategory).

local _, PC = ...

local CRUMB_VALUES = { 0.5, 1, 2, 3 }  -- % of all units listed
local TAB_SIZES = {}  -- 24 to 44 px in steps of 4; 44 is about Forever's own side tabs (2026-11-20)
for size = 24, 44, 4 do TAB_SIZES[#TAB_SIZES + 1] = size end
local GEAR_DISCOUNTS = { 50, 55, 60, 65, 70, 75, 80, 85, 90 }
local REAGENT_DISCOUNTS = { 40, 45, 50, 55, 60, 65, 70, 75 }
local MIN_PROFITS = { 0, 1000, 2500, 5000, 10000, 25000, 50000, 100000 }  -- copper
local MAX_PROFITS = { -1, 50000, 100000, 200000, 500000, 1000000, 0 }  -- copper; -1 = Auto, 0 = unlimited
local ONSALE_INTERVALS = { 5, 10, 15, 30, 60, 120 }  -- seconds
local EXPIRY_MINUTES = { 10, 30, 60, 120, 240 }  -- Vendor and On Sale finds (2026-11-24)
local QUICK_CHECKS = { 5, 10, 20 }  -- items a Vendor quick scan checks in detail
local SINGLE_MIN_PROFITS = { 0, 100, 500, 1000, 2500, 5000, 10000 }  -- copper; Vendor finds of items that don't stack
local COLUMN_WIDTH = 320

-- In display order. { page = "..." } starts a page (one page button each at the top), { title = "..." } a section
-- heading (newColumn = true: it starts the next column), { divider = true } a line. requires = function: greyed out
-- while it returns false. money = true: gold and silver boxes (any amount; 2026-11-24: sliders were too
-- restrictive for amounts of money); get / set: a value kept outside PC.db.settings.
-- Pages (2026-11-21): General / Crafting profit / Opportunities (named On Sale until 0.4.0), one column wide
-- (small screens).
local function OnSaleOn() return PC.db.settings.onSaleMode ~= "off" end

local OPTIONS = {
  { page = "General" },
  { title = "Interface" },
  { key = "moneyWindow", label = "Currencies bar",
    help = "A small movable bar with your money and up to 5 currencies of your choice. Right-click it to add "
      .. "or remove currencies, lock its position, change its background or hide it. Also: /pcraft money." },
  -- One choice for both counts: Blizzard's own (game setting displayFreeBagSlots, the switch behind Blizzard's
  -- "Show Free Bag Space" in Options > Interface) and ProfitCraft's split (setting freeSlots, UI/BagSpace.lua).
  { key = "freeSlots", cvar = "displayFreeBagSlots", label = "Free bag slots",
    help = "Free slot counts on the bag bar. Blizzard's count is one total that includes the reagent bag; "
      .. "ProfitCraft's splits it as (reagent bag|normal bags), in the order the bags sit on the bar.",
    choices = {
      { label = "Off", cvarOn = false, mode = "none", help = "No free slot counts." },
      { label = "Blizzard only", cvarOn = true, mode = "none",
        help = "Blizzard's total on the backpack button (the same switch as Blizzard's \"Show Free Bag "
          .. "Space\", Options > Interface)." },
      { label = "ProfitCraft + Blizzard", cvarOn = true, mode = "reagent",
        help = "Blizzard's total on the backpack button, and ProfitCraft's (reagent|normal) split on the "
          .. "reagent bag button." },
      { label = "ProfitCraft only", cvarOn = true, mode = "backpack",
        help = "ProfitCraft's (reagent|normal) split on the backpack button, in place of Blizzard's total. "
          .. "Blizzard's own option stays on underneath, so its count comes back if ProfitCraft is "
          .. "disabled or removed." },
    } },
  { title = "Auction House" },
  { key = "ahTabSize", slider = { values = TAB_SIZES, format = function(v) return v .. " px" end },
    label = "Size of the tabs at the Auction House",
    help = "The RapidFire, Opportunities and Recipes tabs on the Auction House window's right edge. They stay stacked without "
      .. "overlapping, and the panels open to their right." },
  { key = "crumbPercent", slider = { values = CRUMB_VALUES, format = function(v) return v .. "% of units listed" end },
    label = "Ignore cheap amounts below (stackable items)",
    help = "Price levels holding less than this share of all units listed are ignored for reagent costs and sale "
      .. "prices: on a busy Auction House they're gone before you can buy them. Uses ProfitCraft's scan data "
      .. "(Auctionator's detailed scan, or ProfitCraft's own full scan)." },
  { key = "summaryScanWarning", label = "Warn when Auctionator runs a summary scan",
    help = "When Auctionator runs its quick SUMMARY scan, a raid-warning style message and an orange chat line say "
      .. "how to switch it to its detailed scan, which ProfitCraft needs for exact reagent costs and On Sale. Never "
      .. "shown on just opening the Auction House." },
  { title = "Troubleshooting" },
  { key = "debug", label = "Debug mode: show errors in chat",
    help = "Errors are always logged (/pcraft errors). With debug mode on they are also printed in chat as "
      .. "they happen." },
  { page = "Crafting profit" },
  { title = "Prices" },
  { key = "staleDays", slider = { min = 0, max = 4 }, label = "Warn when AH prices are older than",
    help = "The side panel shows a banner asking you to scan the Auction House with Auctionator once prices "
      .. "are this old. Off hides that warning (the \"Auctionator is required\" and \"No AH prices yet\" "
      .. "warnings still show)." },
  { title = "Tooltips" },
  { key = "tooltipDisenchant", label = "Disenchant estimate in item tooltips",
    help = "Adds the estimated disenchant value (average over many disenchants, priced at AH prices) and "
      .. "what the item can disenchant into to item tooltips. Not yet confirmed for Forever." },
  { page = "Opportunities" },
  { title = "Finds" },
  { key = "opportunityExpiry", slider = { values = EXPIRY_MINUTES,
    format = function(v) return v < 60 and (v .. " min") or (v / 60 .. " h") end },
    label = "Finds expire after",
    help = "Vendor and On Sale finds older than this are no longer listed, since the listings may have been bought "
      .. "or cancelled meanwhile. A new full scan brings fresh ones (On Sale: also a search that finds them again)." },
  { key = "quickScanChecks", slider = { values = QUICK_CHECKS, format = function(v) return v .. " items" end },
    label = "Quick scan checks",
    help = "After reading the whole Auction House, the Vendor page's Quick scan checks this many of the most promising "
      .. "items for how many are below vendor price and what they cost (when \"Check top items\" next to the Quick "
      .. "scan button is ticked); only those stay listed. More checks: a fuller list, but each one is another request "
      .. "to the Auction House." },
  { key = "vendorMinSingleProfit", slider = { values = SINGLE_MIN_PROFITS,
    format = function(v) return v == 0 and "off" or PC:FormatMoney(v) end },
    label = "Single items: min profit each",
    help = "Vendor finds of items that don't stack (gear, bags, recipes) are only listed when EACH one earns at least "
      .. "this: every one has to be bought, carried and sold on its own. Stackable goods are always listed. "
      .. "\"Stackable only\" on the Vendor page hides items that don't stack altogether." },
  { title = "Buying" },
  { key = "buyMaxPerPurchase", money = true,
    label = "Max per purchase (Vendor and On Sale)",
    help = "One Buy in the Vendor or On Sale buy dialog never costs more than this: a bigger find is offered in parts, "
      .. "one press each. Limits what a wrong price can cost. Empty or 0: no limit. The Recipes panel and RapidFire "
      .. "aren't limited by it." },
  { key = "keepAtLeast", money = true,
    get = function() return PC.db.rapidFire.minBalance end,
    set = function(v)
      PC.db.rapidFire.minBalance = v
      PC:Send("SETTINGS_CHANGED", "keepAtLeast")
    end,
    label = "Keep at least",
    help = "No purchase by ProfitCraft (Vendor, On Sale, Recipes, RapidFire) takes your money below this. The same "
      .. "amount as \"Keep at least\" in the RapidFire panel." },
  { title = "On Sale", newColumn = true },
  { key = "onSaleMode", label = "On Sale Finder",
    help = "Finds listings far below their usual price. Opening the Auction House checks your searches once (at most "
      .. "once a minute); Start on the On Sale page keeps watching them. The Vendor page works either way.",
    choices = {
      { label = "Off", value = "off", help = "No On Sale finds, alerts or price history. The Vendor page still works." },
      { label = "Manual List", value = "manual",
        help = "Alerts only for items your own searches cover: from the searches themselves, and from full scans." },
      { label = "Full Auto (Experimental)", value = "auto",
        help = "Every item on the Auction House in every full scan, plus your searches. Still being refined: expect "
          .. "finds that aren't real sales." },
    } },
  { title = "What counts as on sale" },
  { key = "onSaleGear", slider = { values = GEAR_DISCOUNTS, format = function(v) return v .. "% below usual" end },
    requires = OnSaleOn,
    label = "Single items (gear, recipes) on sale at",
    help = "A find needs a price at least this far below the item's usual price (the median of its last 7 daily "
      .. "prices). Example: 70% = at 30% of the usual price or less. Single items (gear, recipes, bags) need 3 days "
      .. "of ProfitCraft's own price history, and more than 3 listings that cheap means the price fell: no find." },
  { key = "onSaleReagent", slider = { values = REAGENT_DISCOUNTS, format = function(v) return v .. "% below usual" end },
    requires = OnSaleOn,
    label = "Stackable goods on sale at",
    help = "The same for reagents, cloth, herbs and other stackable goods. Tiny amounts (under the \"ignore cheap "
      .. "amounts\" share above) never count." },
  { key = "onSaleMinProfit", slider = { values = MIN_PROFITS,
    format = function(v) return v == 0 and "any" or PC:FormatMoney(v) end },
    requires = OnSaleOn,
    label = "Minimum profit per find",
    help = "Finds earning less than this (usual price after the AH cut, minus what you'd pay) are not shown, so "
      .. "cheap items don't keep alerting you." },
  { key = "onSaleMaxProfit", slider = { values = MAX_PROFITS,
    format = function(v) return v == -1 and "Auto" or v == 0 and "Unlimited" or PC:FormatMoney(v) end },
    requires = OnSaleOn,
    label = "Maximum profit per find",
    help = "Finds that would earn more than this are not shown: a price that far below usual is mostly a seller "
      .. "still finding the price (listed far too high before), not a sale. Auto: up to 1.5 times the gold you "
      .. "have. Fixed-price searches ignore it." },
  { title = "Watch" },
  { key = "onSaleInterval", slider = { values = ONSALE_INTERVALS,
    format = function(v) return v >= 60 and (v / 60 .. " min") or (v .. " s") end },
    requires = OnSaleOn,
    label = "Pause between two searches",
    help = "On Sale runs your searches one after another with this pause between them. Each search comes round "
      .. "every (number of searches x pause)." },
  { title = "Alerts" },
  { key = "onSaleSound", requires = OnSaleOn, label = "Sound on each new find",
    help = "Plays a sound when On Sale finds something new. To hear it while the game is in the background, turn "
      .. "on Blizzard's \"Sound in Background\" (Options > Audio)." },
  { key = "onSaleGlow", requires = OnSaleOn, label = "Screen glow on each new find",
    help = "A pulsing gold glow around the screen edges (Blizzard's low-health glow, in gold) after a new find, for 5 "
      .. "seconds or until you move the mouse over the Auction House or the Opportunities panel." },
  { key = "historyReminder", requires = OnSaleOn, label = "Remind me when price history is thin",
    help = "After a full scan, an orange chat line says when ProfitCraft has scanned on fewer than 3 of the last 7 "
      .. "days: gear, recipes and other single items need its own prices on 3 days before they can be finds." },
}

local ROW_SPACING = 30
local SLIDER_ROWS = 1.5   -- a slider, dropdown or money input: its label, then the control just below it
local DIVIDER_ROWS = 0.5  -- a divider line takes half a row
local TITLE_ROWS = 1      -- a section heading, with a gap above it (2026-11-24: too close to the row above)
local PAGE_BUTTONS = 32   -- height of the page buttons' row
local CONTROL_WIDTH = 200 -- sliders and dropdowns

-- Layout (2026-11-24: the Opportunities page ran off the window; padding around it): a page flows into a
-- further column at a heading marked newColumn, or once a column would hold more than MAX_COLUMN_ROWS rows, breaking
-- only at a section heading so a section stays together. The window is sized for the tallest column and the most
-- columns.
local PADDING = 10         -- around the settings, inside the window's frame
local COLUMN_GAP = 20
local MAX_COLUMN_ROWS = 16

local function RowsUsed(option)
  if option.divider then return DIVIDER_ROWS end
  if option.title then return TITLE_ROWS end
  return (option.slider or option.choices or option.money) and SLIDER_ROWS or 1
end

-- Rows of the section that starts with OPTIONS[i] (up to the next heading or page).
local function SectionRows(i)
  local rows = RowsUsed(OPTIONS[i])
  for j = i + 1, #OPTIONS do
    if OPTIONS[j].title or OPTIONS[j].page then break end
    rows = rows + RowsUsed(OPTIONS[j])
  end
  return rows
end

-- Where each option goes: { column (0-based), row }, plus the most rows in any column and the most columns of a page.
local function Layout()
  local places, tallest, widest = {}, 0, 1
  local column, row = 0, 0
  for i, option in ipairs(OPTIONS) do
    if option.page then
      column, row = 0, 0
    else
      if option.title and row > 0 and (option.newColumn or row + SectionRows(i) > MAX_COLUMN_ROWS) then
        column, row = column + 1, 0
      end
      places[option] = { column, row }
      row = row + RowsUsed(option)
      tallest, widest = math.max(tallest, row), math.max(widest, column + 1)
    end
  end
  return places, tallest, widest
end

local function DaysText(value)
  value = math.floor(value + 0.5)
  if value == 0 then return "Off" end
  return value == 1 and "1 day" or (value .. " days")
end

-- Where a slider's knob sits for the saved value: the value itself, or its place in the `values` list.
local function SliderPosition(option)
  local value = PC.db.settings[option.key]
  local values = option.slider.values
  if not values then return value end
  for position, v in ipairs(values) do
    if v == value then return position end
  end
  return 1
end

local pages = {}  -- every page built, for syncing
local window

local function GetValue(option)
  if option.cvar then return C_CVar.GetCVarBool(option.cvar) and true or false end
  return PC.db.settings[option.key] and true or false
end

local function SetValue(option, value)
  if option.cvar then
    C_CVar.SetCVar(option.cvar, value and "1" or "0")
  else
    PC:SetSetting(option.key, value)
  end
end

-- A dropdown choice is selected when ProfitCraft's setting matches and, where ProfitCraft draws nothing, when
-- Blizzard's game setting matches too (that tells "Off" and "Blizzard only" apart).
-- A plain dropdown (no game setting) selects by `value`.
local function IsChoiceSelected(option, choice)
  if not option.cvar then return PC.db.settings[option.key] == choice.value end
  if PC.db.settings[option.key] ~= choice.mode then return false end
  return choice.mode ~= "none" or C_CVar.GetCVarBool(option.cvar) == choice.cvarOn
end

local function SelectChoice(option, choice)
  if not option.cvar then return PC:SetSetting(option.key, choice.value) end
  C_CVar.SetCVar(option.cvar, choice.cvarOn and "1" or "0")
  PC:SetSetting(option.key, choice.mode)
end

local function Available(option)
  return not option.requires or option.requires()
end

-- Makes the checkboxes, sliders and dropdowns reflect the saved settings (and Blizzard's, for mirrored ones); options
-- whose switch is off are greyed out.
local function Sync(page)
  for option, box in pairs(page.checkboxes) do
    box:SetChecked(GetValue(option))
    box:SetEnabled(Available(option))
    box.Text:SetFontObject(Available(option) and "GameFontHighlight" or "GameFontDisable")
  end
  for option, slider in pairs(page.sliders) do
    slider:SetValue(SliderPosition(option))
    slider:SetEnabled(Available(option))
    slider.label:SetFontObject(Available(option) and "GameFontHighlight" or "GameFontDisable")
  end
  for _, dropdown in pairs(page.dropdowns) do dropdown:GenerateMenu() end
  for option, input in pairs(page.moneyInputs) do
    -- Not while it's being typed in: rewriting the boxes would move the cursor.
    if not (input.gold:HasFocus() or input.silver:HasFocus()) then
      input.updating = true
      MoneyInputFrame_SetCopper(input, (option.get and option.get() or PC.db.settings[option.key]) or 0)
      input.updating = false
    end
  end
end

local function ShowHelp(owner, option)
  GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
  GameTooltip:AddLine(option.label, 1, 1, 1)
  GameTooltip:AddLine(option.help, nil, nil, nil, true)
  GameTooltip:Show()
end

-- A slider with arrow buttons (Blizzard's MinimalSliderWithSteppersTemplate, as in its own options; Forever
-- source: Blizzard_SharedXML/Shared/Slider/MinimalSlider.lua), with its label on the row above and the value
-- on its right.
local function BuildSlider(page, option, x, y)
  local label = page:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  label:SetPoint("TOPLEFT", x + 4, y - 4)
  label:SetText(option.label)
  local slider = CreateFrame("Frame", nil, page, "MinimalSliderWithSteppersTemplate")
  slider:SetWidth(CONTROL_WIDTH)
  slider:SetPoint("TOPLEFT", x + 8, y - 12)  -- the template is 40 px tall with the bar in its middle
  local range = option.slider
  local min, max = range.min, range.max
  local format = DaysText
  if range.values then
    min, max = 1, #range.values
    format = function(position) return range.format(range.values[math.floor(position + 0.5)]) end
  end
  slider:Init(SliderPosition(option), min, max, max - min, { [MinimalSliderWithSteppersMixin.Label.Right] = format })
  slider:RegisterCallback(MinimalSliderWithSteppersMixin.Event.OnValueChanged, function(_, position)
    position = math.floor(position + 0.5)
    local value = range.values and range.values[position] or position
    PC:Call("settings " .. option.key, PC.SetSetting, PC, option.key, value)
  end, page)
  slider.Slider:HookScript("OnEnter", function(self) ShowHelp(self, option) end)
  slider.Slider:HookScript("OnLeave", function() GameTooltip:Hide() end)
  slider.label = label
  return slider
end

-- A dropdown (Blizzard's WowStyle1DropdownTemplate, as in the side panel) with its label on the row above.
local function BuildDropdown(page, option, x, y)
  local label = page:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  label:SetPoint("TOPLEFT", x + 4, y - 4)
  label:SetText(option.label)
  local dropdown = CreateFrame("DropdownButton", nil, page, "WowStyle1DropdownTemplate")
  dropdown:SetWidth(CONTROL_WIDTH)
  dropdown:SetPoint("TOPLEFT", x + 8, y - 19)
  dropdown:SetupMenu(function(_, rootDescription)
    for _, choice in ipairs(option.choices) do
      local entry = rootDescription:CreateRadio(choice.label,
        function() return IsChoiceSelected(option, choice) end,
        function() PC:Call("settings " .. option.key, SelectChoice, option, choice) end)
      entry:SetTooltip(function(tooltip)
        GameTooltip_SetTitle(tooltip, choice.label)
        GameTooltip_AddNormalLine(tooltip, choice.help)
      end)
    end
  end)
  dropdown:HookScript("OnEnter", function(self) ShowHelp(self, option) end)
  dropdown:HookScript("OnLeave", function() GameTooltip:Hide() end)
  return dropdown
end

-- Gold and silver boxes (Blizzard's MoneyInputFrameTemplate with its copper box hidden; Forever source:
-- Blizzard_MoneyFrame/Shared/MoneyInputFrame.lua, MoneyInputFrame_SetCopperShown) with the label on the row above.
-- Every change is saved as it's typed. The template needs a frame name (its edit boxes are named after it).
local moneyInputCount = 0
local function BuildMoney(page, option, x, y)
  local label = page:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  label:SetPoint("TOPLEFT", x + 4, y - 4)
  label:SetText(option.label)
  moneyInputCount = moneyInputCount + 1
  local input = CreateFrame("Frame", "ProfitCraftSettingsMoney" .. moneyInputCount, page, "MoneyInputFrameTemplate")
  MoneyInputFrame_SetCopperShown(input, false)
  input:SetPoint("TOPLEFT", x + 12, y - 21)
  MoneyInputFrame_SetOnValueChangedFunc(input, function()
    if input.updating then return end
    local copper = MoneyInputFrame_GetCopper(input)
    if option.set then
      PC:Call("settings " .. option.key, option.set, copper)
    else
      PC:Call("settings " .. option.key, PC.SetSetting, PC, option.key, copper)
    end
  end)
  for _, box in ipairs({ input.gold, input.silver }) do
    box:HookScript("OnEnter", function(self) ShowHelp(self, option) end)
    box:HookScript("OnLeave", function() GameTooltip:Hide() end)
  end
  return input
end

local function BuildCheckbox(page, option, x, y)
  local box = CreateFrame("CheckButton", nil, page, "UICheckButtonTemplate")
  box:SetPoint("TOPLEFT", x, y)
  box.Text:SetText(option.label)
  box.Text:SetFontObject("GameFontHighlight")
  box:SetScript("OnClick", function(self)
    PC:Call("settings " .. (option.key or option.cvar), SetValue, option, self:GetChecked() and true or false)
  end)
  box:SetScript("OnEnter", function(self) ShowHelp(self, option) end)
  box:SetScript("OnLeave", function() GameTooltip:Hide() end)
  box:SetMotionScriptsWhileDisabled(true)  -- help still shows while greyed out
  return box
end

-- Shows one page of a settings frame; its page button stays lit.
local function ShowPage(container, index)
  container.current = index
  for i, frame in ipairs(container.pageFrames) do
    frame:SetShown(i == index)
    if i == index then container.pageButtons[i]:LockHighlight() else container.pageButtons[i]:UnlockHighlight() end
  end
end

-- Builds the settings (page buttons, then each page's checkboxes, sliders and dropdowns) inside `container`, starting
-- at (x, y) from its top left.
local function BuildPage(container, left, top)
  container.checkboxes, container.sliders, container.dropdowns, container.moneyInputs = {}, {}, {}, {}
  container.pageFrames, container.pageButtons = {}, {}
  local places = Layout()
  local page = container
  for _, option in ipairs(OPTIONS) do
    local place = places[option]
    local x = place and left + place[1] * (COLUMN_WIDTH + COLUMN_GAP) or left
    local rowY = place and top - PAGE_BUTTONS - place[2] * ROW_SPACING
    local y = top
    if option.page then
      local index = #container.pageFrames + 1
      page = CreateFrame("Frame", nil, container)
      page:SetAllPoints()
      container.pageFrames[index] = page
      local button = CreateFrame("Button", nil, container, "UIPanelButtonTemplate")
      button:SetSize(110, 22)
      button:SetPoint("TOPLEFT", left + (index - 1) * 114, y)
      button:SetText(option.page)
      button:SetScript("OnClick", function() ShowPage(container, index) end)
      container.pageButtons[index] = button
    elseif option.title then
      local heading = page:CreateFontString(nil, "OVERLAY", "GameFontNormal")
      heading:SetPoint("TOPLEFT", x + 4, rowY - 10)
      heading:SetText(option.title)
    elseif option.divider then
      local line = page:CreateTexture(nil, "ARTWORK")
      line:SetColorTexture(1, 1, 1, 0.15)
      line:SetHeight(1)
      line:SetWidth(300)
      line:SetPoint("TOPLEFT", x + 4, rowY - ROW_SPACING * DIVIDER_ROWS / 2)
    elseif option.slider then
      container.sliders[option] = BuildSlider(page, option, x, rowY)
    elseif option.choices then
      container.dropdowns[option] = BuildDropdown(page, option, x, rowY)
    elseif option.money then
      container.moneyInputs[option] = BuildMoney(page, option, x, rowY)
    else
      container.checkboxes[option] = BuildCheckbox(page, option, x, rowY)
    end
  end
  ShowPage(container, 1)
  container:HookScript("OnShow", Sync)
  pages[#pages + 1] = container
end

-- "Create Profit Macro": a general (account-wide) macro "PCraft": left-click /pcraft, right-click the settings.
-- /pcraft reads the [btn:2] condition itself (SecureCmdOptionParse, Core.lua). Blizzard's own macro window creates
-- macros the same way (Forever source: Blizzard_MacroUI/Blizzard_MacroIconSelector.lua, CreateMacro); the icon is
-- the money bag of Forever's bank window (Blizzard_UIPanels_Game/Camelot/BankFrame.xml).
local MACRO_NAME = "PCraft"
local MACRO_ICON = "Interface\\Icons\\Achievement_GuildPerk_MobileBanking"
local MACRO_BODY = "/pcraft [btn:2] settings; [btn:1]"

-- nil when the macro can be created, else why not.
local function MacroBlocked()
  local numAccount, numCharacter = GetNumMacros()
  local maxAccount = Constants.MacroConsts.MAX_ACCOUNT_MACROS
  for i = 1, numAccount do
    if GetMacroInfo(i) == MACRO_NAME then return "Macro already exists" end
  end
  for i = maxAccount + 1, maxAccount + numCharacter do
    if GetMacroInfo(i) == MACRO_NAME then return "Macro already exists" end
  end
  if numAccount >= maxAccount then return "No free general macro slot" end
end

-- Hovering the PCraft macro on an action bar adds what its clicks do. A macro has no tooltip of its own, so the
-- lines are added after Blizzard builds the action button's tooltip (GameTooltip:SetAction, called when the mouse
-- enters the button and on Blizzard's own 0.2 s tooltip refresh; Forever source: Blizzard_ActionBar/Shared/
-- ActionButton.lua). No polling: nothing runs unless an action button's tooltip is being shown.
hooksecurefunc(GameTooltip, "SetAction", function(tooltip, slot)
  PC:Call("macro tooltip", function()
    if C_ActionBar.GetActionText(slot) ~= MACRO_NAME then return end
    tooltip:AddLine("Left-click: profit list", 0.7, 0.7, 0.7)
    tooltip:AddLine("Right-click: ProfitCraft settings", 0.7, 0.7, 0.7)
    tooltip:Show()
  end)
end)

local macroButton
local function UpdateMacroButton()
  if macroButton then macroButton:SetEnabled(MacroBlocked() == nil) end
end

local function CreateMacroButton(parent)
  macroButton = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
  macroButton:SetSize(140, 22)
  macroButton:SetPoint("BOTTOMRIGHT", -6, 4)
  macroButton:SetText("Create Profit Macro")
  macroButton:SetMotionScriptsWhileDisabled(true)  -- the tooltip also shows while greyed out
  macroButton:SetScript("OnClick", function()
    PC:Call("create macro", function()
      if MacroBlocked() then return end
      CreateMacro(MACRO_NAME, GetFileIDFromPath(MACRO_ICON) or MACRO_ICON, MACRO_BODY, false)
      PC:Print("macro \"" .. MACRO_NAME .. "\" created (Escape > Macros, General tab). Left-click: profit list; "
        .. "right-click: settings.")
      UpdateMacroButton()
    end)
  end)
  macroButton:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    local blocked = MacroBlocked()
    if blocked then
      GameTooltip:AddLine(blocked, 1, 1, 1)
    else
      GameTooltip:AddLine("Create Profit Macro", 1, 1, 1)
      GameTooltip:AddLine("Adds a general macro \"" .. MACRO_NAME .. "\" for your action bar: left-click opens "
        .. "the profit list (/pcraft), right-click opens these settings.", nil, nil, nil, true)
    end
    GameTooltip:Show()
  end)
  macroButton:SetScript("OnLeave", function() GameTooltip:Hide() end)
  parent:HookScript("OnShow", UpdateMacroButton)
  PC:RegisterEvent("UPDATE_MACROS", UpdateMacroButton)
end

local function CreateWindowPage()
  local _, rows, columns = Layout()
  window = PC:CreateWindow("ProfitCraftSettings", UIParent,
    20 + 2 * PADDING + columns * COLUMN_WIDTH + (columns - 1) * COLUMN_GAP,
    96 + 2 * PADDING + PAGE_BUTTONS + rows * ROW_SPACING, "ProfitCraft Settings", { movable = true })
  local page = CreateFrame("Frame", nil, window.Inset)
  page:SetAllPoints()
  BuildPage(page, PADDING, -PADDING)

  local version = window:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  version:SetPoint("BOTTOMLEFT", 12, 8)
  version:SetText("ProfitCraft " .. PC.version)

  CreateMacroButton(window)
  UpdateMacroButton()
end

-- The page in Blizzard's Options > AddOns. Blizzard sizes and shows the canvas frame itself.
local function RegisterBlizzardPage()
  if not (Settings and Settings.RegisterCanvasLayoutCategory and Settings.RegisterAddOnCategory) then return end
  local canvas = CreateFrame("Frame", nil, UIParent)
  canvas:Hide()
  local title = canvas:CreateFontString(nil, "OVERLAY", "GameFontHighlightHuge")
  title:SetPoint("TOPLEFT", 16, -16)
  title:SetText("ProfitCraft")
  local version = canvas:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  version:SetPoint("LEFT", title, "RIGHT", 8, -2)
  version:SetText(PC.version)
  BuildPage(canvas, 12, -52)
  local category = Settings.RegisterCanvasLayoutCategory(canvas, "ProfitCraft")
  Settings.RegisterAddOnCategory(category)
end

PC:Listen("DATA_READY", function() PC:Call("register settings", RegisterBlizzardPage) end)

PC:Listen("TOGGLE_SETTINGS", function()
  if not window then CreateWindowPage() end
  window:SetShown(not window:IsShown())
end)

-- Keep every visible page right when a setting changes anywhere (the other page, /pcraft debug on, or
-- Blizzard's own Interface option for the mirrored game setting).
local function SyncVisible()
  for _, page in ipairs(pages) do
    if page:IsVisible() then Sync(page) end
  end
end
PC:Listen("SETTINGS_CHANGED", SyncVisible)
PC:RegisterEvent("CVAR_UPDATE", function(name)
  for _, option in ipairs(OPTIONS) do
    if option.cvar and option.cvar == name then SyncVisible() end
  end
end)
