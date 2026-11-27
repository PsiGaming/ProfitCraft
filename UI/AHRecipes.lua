-- ProfitCraft: Recipes panel at the Auction House (2026-11-20)
-- "Scan recipes" searches the AH for the recipe items of the character's professions and lists them by how much a
-- craft of the recipe earns, so nobody has to hover hundreds of recipes one by one.
-- * Professions: GetProfessions / GetProfessionInfo, as Forever's own profession window (Camelot
--   Blizzard_ProfessionsFrame.lua); each one's AH category is the Recipe subclass with the same name
--   (C_Item.GetItemSubClassInfo(Enum.ItemClass.Recipe, n)), so no IDs are hard-coded.
-- * One browse search per profession (itemClassFilters { classID = Recipe, subClassID }), more pages with
--   RequestMoreBrowseResults until HasFullBrowseResults (at most MAX_PAGES), one AH request a second. The On Sale watch
--   is paused meanwhile (OnSale:SetBusy); not while RapidFire runs.
-- * Which recipe an item teaches: the ItemSpellTriggerLearn line of its tooltip data (PsiLab, 2026-11-14, from bag
--   items; the same line ProfitCraft's recipe tooltips use). Read with C_TooltipInfo.GetItemByID (Forever API docs;
--   not yet confirmed in game for items not in your bags); items whose data isn't loaded yet are requested and
--   read again when it arrives. Cached in ProfitCraftDB.recipeOfItem (it never changes).
-- * Profit: the same calculation as the recipe tooltip (Profit:Evaluate); recipe details are readable for the
--   character's own professions without the profession window (PsiLab, 2026-11-14).
-- * Clicking a row opens On Sale's buy dialog for the cheapest listing at or under the listed price.
-- * Profit per stack (default) or per craft (setting recipesProfitMode, 2026-11-21): per stack is the profit of
--   crafting one full stack of the product, as the profession window's "Per stack". The % and "pays off" (in crafts)
--   don't change with the mode.

local _, PC = ...

local AHRecipes = {}
PC.AHRecipes = AHRecipes

local MAX_PAGES = 20
local MIN_SPACING = 1
local TIMEOUT = 10
local ROW_HEIGHT = 22
local RECIPE_CLASS = Enum.ItemClass and Enum.ItemClass.Recipe or 9
local BOOK_SUBCLASS = Enum.ItemRecipeSubclass and Enum.ItemRecipeSubclass.Book or 0
local LEARN_LINE = Enum.TooltipDataLineType and Enum.TooltipDataLineType.ItemSpellTriggerLearn or 38
local SORTS = { { sortOrder = Enum.AuctionHouseSortOrder and Enum.AuctionHouseSortOrder.Price or 0, reverseSort = false } }

local rows = {}       -- one per recipe item listed: { itemID, itemKey, price, quantity, recipeID, profit, ... }
local byItem = {}
local running, current, queue, generation = false, nil, {}, 0
local status = "Press Scan recipes."
local sortKey, sortDescending = "profit", true

local panel, list, scanButton, statusText, hideKnown, headers, modeDropdown

---------------------------------------------------------------------------
-- Data
---------------------------------------------------------------------------

-- The character's professions that have recipe items: { { sub = subclass, name = name } }.
function AHRecipes:GetProfessionCategories()
  local names = {}
  local indexes = { GetProfessions() }
  for i = 1, select("#", GetProfessions()) do
    local index = indexes[i]
    if index then
      local name = GetProfessionInfo(index)
      if name then names[name] = true end
    end
  end
  local categories = {}
  for sub = 0, 20 do
    local name = sub ~= BOOK_SUBCLASS and C_Item.GetItemSubClassInfo(RECIPE_CLASS, sub)
    if name and names[name] then categories[#categories + 1] = { sub = sub, name = name } end
  end
  return categories
end

-- The recipe (spell) an item teaches, or nil while unknown.
function AHRecipes:RecipeOf(itemID)
  local cache = PC.db.recipeOfItem
  if cache[itemID] then return cache[itemID] end
  local data = C_TooltipInfo and C_TooltipInfo.GetItemByID and C_TooltipInfo.GetItemByID(itemID)
  for _, line in ipairs(data and data.lines or {}) do
    if line.type == LEARN_LINE and type(line.spellID) == "number" then
      cache[itemID] = line.spellID
      return line.spellID
    end
  end
  PC.Items:GetName(itemID)  -- requests the item data if it isn't loaded; ITEM_DATA_CHANGED reads it again
  return nil
end

local function Evaluate(row)
  row.name = PC.Items:GetName(row.itemID)
  row.icon = PC.Items:GetIcon(row.itemID)
  row.recipeID = row.recipeID or AHRecipes:RecipeOf(row.itemID)
  row.profit, row.cost, row.percent, row.payoff, row.bound, row.state = nil, nil, nil, nil, nil, nil
  row.profitStack, row.batch = nil, nil
  if not row.recipeID then
    row.state = "unknown"
    return
  end
  local recipe = PC.Recipes:Load(row.recipeID)
  if not recipe then
    row.state = "unreadable"
  elseif not recipe.outputItemID then
    row.state = "noproduct"  -- e.g. enchants
  else
    local result = PC.Profit:Evaluate(recipe)
    row.cost = result.cost
    if result.profitCraft then  -- sold on the AH or to a vendor, whichever pays more (Profit.lua)
      row.profit = result.profitCraft
      row.profitStack, row.batch = result.profitStack, result.batch
      if result.cost and result.cost > 0 then row.percent = row.profit / result.cost * 100 end
      if row.profit > 0 then row.payoff = math.ceil(row.price / row.profit) end
    elseif result.bound and not result.vendorPrice then
      row.bound = true
    else
      row.state = "noprice"
    end
  end
  local info = C_TradeSkillUI.GetRecipeInfo and C_TradeSkillUI.GetRecipeInfo(row.recipeID)
  row.known = info and info.learned or false
end

local function Changed()
  PC:Send("AHRECIPES_CHANGED")
end

function AHRecipes:Evaluate()
  for _, row in ipairs(rows) do Evaluate(row) end
  Changed()
end

-- Rows in display order: the chosen column, unknown values last.
local function StackMode() return PC.db.settings.recipesProfitMode ~= "craft" end

-- The profit shown: per stack or per craft.
function AHRecipes:ShownProfit(row)
  if StackMode() then return row.profitStack or row.profit end
  return row.profit
end

local SORT_VALUE = {
  name = function(row) return row.name end,
  price = function(row) return row.price end,
  profit = function(row) return AHRecipes:ShownProfit(row) end,
  percent = function(row) return row.percent end,
  payoff = function(row) return row.payoff end,
}

function AHRecipes:GetRows()
  local shown = {}
  for _, row in ipairs(rows) do
    if not (PC.db.settings.recipesHideKnown and row.known) then shown[#shown + 1] = row end
  end
  local value, descending = SORT_VALUE[sortKey], sortDescending
  table.sort(shown, function(a, b)
    local va, vb = value(a), value(b)
    if va == nil or vb == nil then
      if va ~= nil then return true end
      if vb ~= nil then return false end
      return a.itemID < b.itemID
    end
    if va == vb then return a.itemID < b.itemID end
    if descending then return va > vb end
    return va < vb
  end)
  return shown
end

function AHRecipes:SetSort(key)
  if sortKey == key then
    sortDescending = not sortDescending
  else
    sortKey = key
    sortDescending = key ~= "name" and key ~= "price" and key ~= "payoff"  -- best first
  end
  Changed()
end

function AHRecipes:GetSort() return sortKey, sortDescending end
function AHRecipes:GetStatus() return status end
function AHRecipes:IsRunning() return running end

---------------------------------------------------------------------------
-- Scan
---------------------------------------------------------------------------

local function Collect(results)
  for _, result in ipairs(results or {}) do
    local key = result.itemKey
    if key and key.itemID and result.minPrice and result.minPrice > 0 then
      local row = byItem[key.itemID]
      if not row then
        row = { itemID = key.itemID, itemKey = key, price = result.minPrice, quantity = result.totalQuantity or 0 }
        byItem[key.itemID] = row
        rows[#rows + 1] = row
      elseif result.minPrice < row.price then
        row.price, row.itemKey = result.minPrice, key
      end
    end
  end
end

local function Finish()
  running, current = false, nil
  PC.OnSale:SetBusy(false)
  AHRecipes:Evaluate()
  local readable, waiting = 0, 0
  for _, row in ipairs(rows) do
    if row.profit then readable = readable + 1 elseif row.state == "unknown" then waiting = waiting + 1 end
  end
  status = string.format("%d recipes listed, %d with a profit%s.", #rows, readable,
    waiting > 0 and string.format(" (%d still loading)", waiting) or "")
  Changed()
end

local NextCategory

local function After(delay, fn)
  local myGeneration = generation
  C_Timer.After(delay, function()
    if myGeneration == generation and running then PC:Call("recipes scan", fn) end
  end)
end

local function Continue(task)
  if C_AuctionHouse.HasFullBrowseResults() or task.pages >= MAX_PAGES then
    After(MIN_SPACING, NextCategory)
    return
  end
  task.pages = task.pages + 1
  status = string.format("Searching %s (page %d)...", task.name, task.pages)
  Changed()
  After(MIN_SPACING, function()
    if current ~= task then return end
    task.waiting = true
    PC.OnSale.Send(C_AuctionHouse.RequestMoreBrowseResults)
  end)
end

function NextCategory()
  local category = table.remove(queue, 1)
  if not category then return Finish() end
  local task = { name = category.name, pages = 1, waiting = true }
  current = task
  status = "Searching " .. category.name .. "..."
  Changed()
  PC.OnSale.Send(C_AuctionHouse.SendBrowseQuery, { searchString = "", sorts = SORTS, filters = {},
    itemClassFilters = { { classID = RECIPE_CLASS, subClassID = category.sub } } })
  After(TIMEOUT, function()
    if current == task and task.waiting then
      task.waiting = false
      PC:Print("Recipes: no answer from the Auction House for " .. task.name .. ", moving on.")
      NextCategory()
    end
  end)
end

function AHRecipes:Start()
  if running then return end
  if PC.Rapid and PC.Rapid:IsRunning() then
    status = "Stop RapidFire first: both search the Auction House."
    return Changed()
  end
  if PC.Vendor:IsQuickScanning() then
    status = "Wait for the quick scan to finish: both search the Auction House."
    return Changed()
  end
  local categories = self:GetProfessionCategories()
  if #categories == 0 then
    status = "This character has no profession with recipe items."
    return Changed()
  end
  wipe(rows)
  wipe(byItem)
  queue = categories
  running = true
  generation = generation + 1
  PC.OnSale:SetBusy(true)
  NextCategory()
end

function AHRecipes:Stop()
  if not running then return end
  generation = generation + 1
  wipe(queue)
  Finish()
  status = "Stopped. " .. status
  Changed()
end

PC:RegisterEvent("AUCTION_HOUSE_BROWSE_RESULTS_UPDATED", function()
  local task = current
  if not (running and task and task.waiting) then return end
  task.waiting = false
  Collect(C_AuctionHouse.GetBrowseResults())
  Continue(task)
end)

PC:RegisterEvent("AUCTION_HOUSE_BROWSE_RESULTS_ADDED", function(added)
  local task = current
  if not (running and task and task.waiting) then return end
  task.waiting = false
  Collect(added)
  Continue(task)
end)

PC:RegisterEvent("AUCTION_HOUSE_BROWSE_FAILURE", function()
  local task = current
  if not (running and task and task.waiting) then return end
  task.waiting = false
  PC:Print("Recipes: the Auction House refused the search for " .. task.name .. ".")
  After(MIN_SPACING, NextCategory)
end)

PC:RegisterEvent("AUCTION_HOUSE_CLOSED", function()
  if running then
    generation = generation + 1
    running, current = false, nil
    wipe(queue)
  end
end)

-- Item data arriving later: names, icons and the recipe each item teaches.
PC:Listen("ITEM_DATA_CHANGED", function()
  if not running and #rows > 0 then AHRecipes:Evaluate() end
end)

---------------------------------------------------------------------------
-- Panel
---------------------------------------------------------------------------

local COLUMNS = {
  { key = "name", label = "Recipe", x = 4, width = 170 },
  { key = "price", label = "AH price", x = 174, width = 76, right = true },
  { key = "profit", label = "Profit / stack", x = 250, width = 100, right = true },
  { key = "percent", label = "%", x = 350, width = 46, right = true },
  { key = "payoff", label = "Pays off", x = 396, width = 60, right = true },
}
local GREY = "|cff888888"

local function ProfitText(row)
  local shown = AHRecipes:ShownProfit(row)
  if shown then
    local prefix = StackMode() and row.profitStack and (GREY .. "x" .. row.batch .. "|r  ") or ""
    return prefix .. PC:FormatProfit(shown)
  end
  if row.bound then return GREY .. "BoP|r" end
  if row.state == "noproduct" then return GREY .. "no item|r" end
  if row.state == "noprice" then return GREY .. "no price|r" end
  return GREY .. "?|r"
end

local function ShowRowTooltip(frame)
  local row = frame.row
  if not row then return end
  GameTooltip:SetOwner(frame, "ANCHOR_RIGHT")
  GameTooltip:SetItemByID(row.itemID)  -- ProfitCraft's recipe lines are added by UI/RecipeTooltip.lua
  GameTooltip:AddLine(" ")
  GameTooltip:AddLine(string.format("%d listed, cheapest %s", row.quantity, PC:FormatMoney(row.price)), 1, 1, 1)
  if row.payoff then
    GameTooltip:AddLine(string.format("Pays for itself after %d craft%s.", row.payoff, row.payoff == 1 and "" or "s"),
      0.8, 0.8, 0.8)
  end
  if row.known then GameTooltip:AddLine("You already know this recipe.", 0.5, 1, 0.5) end
  if row.state == "unknown" then
    GameTooltip:AddLine("Not read yet: the item's data is still loading.", 1, 0.5, 0.5)
  elseif row.state == "unreadable" then
    GameTooltip:AddLine("ProfitCraft can't read this recipe (not your profession's?).", 1, 0.5, 0.5)
  end
  GameTooltip:AddLine("Click to buy it.", 0.5, 0.7, 1)
  GameTooltip:Show()
end

local function Buy(row)
  local note = row.profit and string.format("Profit per craft %s%s", PC:FormatProfit(row.profit),
    row.payoff and string.format("  -  pays off after %d craft%s", row.payoff, row.payoff == 1 and "" or "s") or "")
    or "Profit per craft not known"
  PC.OnSale:InspectHit({ key = "recipe:" .. row.itemID, itemID = row.itemID, itemKey = row.itemKey, name = row.name,
    limit = row.price, stackable = false, dialogTitle = "ProfitCraft Recipes", note = note,
    goneText = "No longer listed at this price: scan again.", prefix = "Recipes", anchor = panel,
    noSpendCap = true })  -- a recipe is a deliberate buy, not an opportunity: no max per purchase
end

local function InitRow(frame, row)
  if not frame.name then
    frame.icon = frame:CreateTexture(nil, "ARTWORK")
    frame.icon:SetSize(18, 18)
    frame.icon:SetPoint("LEFT", 2, 0)
    frame.name = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    frame.name:SetPoint("LEFT", 24, 0)
    frame.name:SetWidth(COLUMNS[1].width - 24)
    frame.name:SetJustifyH("LEFT")
    frame.name:SetWordWrap(false)
    frame.cells = {}
    for i = 2, #COLUMNS do
      local column = COLUMNS[i]
      local cell = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
      cell:SetPoint("LEFT", column.x - 4, 0)
      cell:SetWidth(column.width - 4)
      cell:SetJustifyH("RIGHT")
      frame.cells[column.key] = cell
    end
    frame:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
    frame:SetScript("OnEnter", ShowRowTooltip)
    frame:SetScript("OnLeave", function() GameTooltip:Hide() end)
    frame:SetScript("OnClick", function(self) if self.row then PC:Call("recipes buy", Buy, self.row) end end)
  end
  frame.row = row
  frame.icon:SetTexture(row.icon or 134400)
  frame.name:SetText(row.known and (GREY .. row.name .. " (known)|r") or row.name)
  frame.cells.price:SetText(PC:FormatMoney(row.price))
  frame.cells.profit:SetText(ProfitText(row))
  frame.cells.percent:SetText(row.percent and string.format("%+d%%", math.floor(row.percent + 0.5)) or "")
  frame.cells.payoff:SetText(row.payoff and (row.payoff .. "x") or "")
end

local function Refresh()
  if not (panel and panel:IsShown()) then return end
  list:SetDataProvider(CreateDataProvider(AHRecipes:GetRows()), ScrollBoxConstants.RetainScrollPosition)
  local key, descending = AHRecipes:GetSort()
  headers[3].column.label = StackMode() and "Profit / stack" or "Profit / craft"
  headers[3]:SetText(headers[3].column.label)
  modeDropdown:GenerateMenu()
  -- The AH's own sort arrow, flipped the way Blizzard's headers flip it (AuctionHouseTableHeaderStringMixin:
  -- SetArrowState: normal order = texture upside down).
  for _, header in ipairs(headers) do
    header.arrow:SetShown(header.column.key == key)
    if descending then header.arrow:SetTexCoord(0, 1, 0, 1) else header.arrow:SetTexCoord(0, 1, 1, 0) end
  end
  statusText:SetText(status)
  scanButton:SetText(running and "Stop" or "Scan recipes")
  hideKnown:SetChecked(PC.db.settings.recipesHideKnown)
end

local function CreatePanel()
  panel = PC:CreateWindow("ProfitCraftRecipes", AuctionHouseFrame, 480, 580, "ProfitCraft Recipes")
  PC.AHTabs:Place(panel)
  local inset = panel.Inset
  headers = {}
  for _, column in ipairs(COLUMNS) do
    local header = CreateFrame("Button", nil, inset)
    header:SetSize(column.width, 18)
    header:SetPoint("TOPLEFT", column.x + 4, -4)
    header:SetNormalFontObject("GameFontNormalSmall")
    header:SetHighlightFontObject("GameFontHighlightSmall")
    header:SetText(column.label)
    local text = header:GetFontString()
    header.arrow = header:CreateTexture(nil, "OVERLAY")
    header.arrow:SetAtlas("auctionhouse-ui-sortarrow", true)
    if text and column.right then
      text:ClearAllPoints()
      text:SetPoint("RIGHT", -4, 0)
      header.arrow:SetPoint("RIGHT", text, "LEFT", -3, 0)
    elseif text then
      header.arrow:SetPoint("LEFT", text, "RIGHT", 3, 0)
    end
    header.column = column
    header:SetScript("OnClick", function() AHRecipes:SetSort(column.key) end)
    header:SetScript("OnEnter", function(self)
      GameTooltip:SetOwner(self, "ANCHOR_TOP")
      GameTooltip:AddLine("Sort by " .. column.label:lower() .. "; click again to reverse.", 1, 1, 1)
      GameTooltip:Show()
    end)
    header:SetScript("OnLeave", function() GameTooltip:Hide() end)
    headers[#headers + 1] = header
  end
  local area = CreateFrame("Frame", nil, inset)
  area:SetPoint("TOPLEFT", 0, -22)
  area:SetPoint("BOTTOMRIGHT", 0, 52)
  list = PC:CreateScrollList(panel, ROW_HEIGHT, "recipes row", InitRow, area)

  scanButton = CreateFrame("Button", nil, inset, "UIPanelButtonTemplate")
  scanButton:SetSize(110, 22)
  scanButton:SetPoint("BOTTOMRIGHT", -8, 8)
  scanButton:SetScript("OnClick", function()
    PC:Call("recipes scan", function()
      if AHRecipes:IsRunning() then AHRecipes:Stop() else AHRecipes:Start() end
    end)
  end)
  -- Per stack / per craft, as the profession window's mode dropdown (WowStyle1DropdownTemplate, UI/Panel.lua).
  modeDropdown = CreateFrame("DropdownButton", nil, inset, "WowStyle1DropdownTemplate")
  modeDropdown:SetWidth(110)
  modeDropdown:SetPoint("BOTTOMLEFT", 8, 8)
  modeDropdown:SetupMenu(function(_, root)
    for _, mode in ipairs({ { "stack", "Per stack" }, { "craft", "Per craft" } }) do
      root:CreateRadio(mode[2], function() return (PC.db.settings.recipesProfitMode or "stack") == mode[1] end,
        function()
          PC:SetSetting("recipesProfitMode", mode[1])
          Changed()
        end)
    end
  end)
  hideKnown = CreateFrame("CheckButton", nil, inset, "UICheckButtonTemplate")
  hideKnown:SetSize(22, 22)
  hideKnown:SetPoint("LEFT", modeDropdown, "RIGHT", 10, 0)
  hideKnown.Text:SetText("Hide known")
  hideKnown.Text:SetFontObject("GameFontHighlightSmall")
  hideKnown:SetScript("OnClick", function(self)
    PC:SetSetting("recipesHideKnown", self:GetChecked() and true or false)
    Refresh()
  end)
  statusText = inset:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  statusText:SetPoint("BOTTOMLEFT", 10, 36)
  statusText:SetPoint("RIGHT", -10, 0)
  statusText:SetJustifyH("LEFT")
  statusText:SetWordWrap(false)
  panel:HookScript("OnShow", Refresh)
end

PC.AHTabs:Register({
  key = "recipes",
  title = "Recipes",
  order = 1,
  icon = "Interface\\Icons\\INV_Scroll_03",
  help = "Scan the Auction House for recipes of your professions, sorted by how much a craft earns.",
  panel = function() return panel end,
  open = function()
    if not panel then CreatePanel() end
    panel:Show()
    PC:Send("AH_PANEL_SHOWN", "recipes")
  end,
})

PC:Listen("AH_PANEL_SHOWN", function(which)
  if which ~= "recipes" and panel then panel:Hide() end
end)

PC:Listen("AHRECIPES_CHANGED", function() PC:Call("recipes panel", Refresh) end)
