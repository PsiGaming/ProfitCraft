-- ProfitCraft: Data
-- Loads ProfitCraftDB, fills in default settings and upgrades older layouts step by step (DESIGN.md section 6).

local ADDON_NAME, PC = ...

local DB_VERSION = 2

local DEFAULT_SETTINGS = {
  debug = false,        -- show errors in chat as they happen
  profitMode = "craft", -- side panel: "craft", "stack" (per full stack) or "disenchant" (craft, then disenchant)
  ahCut = 0.05,         -- share of the sale price the AH keeps (web sources: 5%; to confirm in game)
  panelShown = true,    -- side panel open next to the profession window
  tooltipDisenchant = false, -- disenchant estimate line in item tooltips (off by default, as in Auctionator)
  freeSlots = "none",   -- ProfitCraft's free bag slot count: "none", "reagent" or "backpack" (UI/BagSpace.lua)
  staleDays = 2,        -- side panel warns when AH prices are this many days old; 0 = off
  moneyWindow = false,  -- currencies bar shown (UI/MoneyWindow.lua)
  crumbPercent = 1,     -- stackable items: price levels under this % of all units listed are ignored (Prices.lua)
  onSaleGear = 65,      -- On Sale: gear is on sale this many % below its usual price (OnSale.lua)
  onSaleReagent = 40,   -- On Sale: stackable goods, % below the usual price
  onSaleMinProfit = 5000, -- On Sale: a find must earn at least this much (copper) after the AH cut
  onSaleInterval = 10,  -- On Sale: seconds between two searches
  onSaleSound = true,   -- On Sale: sound on each new find
  onSaleGlow = true,    -- On Sale: screen glow on a new find until the mouse is over the AH or the On Sale panel
  scanWarning = true,   -- raid-warning style notice when Auctionator runs a summary scan; history notice after scans
}

-- upgrades[n] turns a version n-1 database into version n.
local upgrades = {}

-- 0.1-rc.0: the reagent bag checkbox became the free bag slots choice; "on" keeps the count on the reagent bag.
upgrades[2] = function(db)
  if type(db.settings) ~= "table" then return end
  if db.settings.reagentBagFreeSlots then db.settings.freeSlots = "reagent" end
  db.settings.reagentBagFreeSlots = nil
end

local function FillDefaults(target, defaults)
  for key, value in pairs(defaults) do
    if target[key] == nil then target[key] = value end
  end
end

PC:RegisterEvent("ADDON_LOADED", function(name)
  if name ~= ADDON_NAME then return end
  local db = type(ProfitCraftDB) == "table" and ProfitCraftDB or {}
  db.version = db.version or DB_VERSION
  for v = db.version + 1, DB_VERSION do
    upgrades[v](db)
    db.version = v
  end
  db.settings = type(db.settings) == "table" and db.settings or {}
  FillDefaults(db.settings, DEFAULT_SETTINGS)
  db.errors = type(db.errors) == "table" and db.errors or {}
  db.lastScan = type(db.lastScan) == "table" and db.lastScan or {}  -- realm -> time of the last AH scan seen
  -- Money window (UI/MoneyWindow.lua), account-wide: position (x, y of its top-right corner), locked, background
  -- colour and opacity, tracked currency IDs.
  local money = type(db.money) == "table" and db.money or {}
  money.currencies = type(money.currencies) == "table" and money.currencies or {}
  money.bg = type(money.bg) == "table" and money.bg or { r = 0, g = 0, b = 0, a = 0.5 }
  money.locked = money.locked == true
  db.money = money
  -- AH scan data (Scan.lua, DESIGN.md section 9): the latest detailed scan per ruleset key, the reagents and
  -- products of every recipe seen on the account, and the time of ProfitCraft's own last full scan.
  db.snapshot = type(db.snapshot) == "table" and db.snapshot or {}
  db.recipeItems = type(db.recipeItems) == "table" and db.recipeItems or {}
  -- RapidFire (UI/Rapid.lua), account-wide: watch list { itemID, max (copper per unit), on }, the money to keep,
  -- seconds between checks of each item, sound, buy key.
  local rapidFire = type(db.rapidFire) == "table" and db.rapidFire or {}
  rapidFire.items = type(rapidFire.items) == "table" and rapidFire.items or {}
  rapidFire.minBalance = rapidFire.minBalance or 2500
  rapidFire.interval = rapidFire.interval or 5
  if rapidFire.sound == nil then rapidFire.sound = true end
  rapidFire.key = rapidFire.key or "SPACE"
  rapidFire.tolerance = rapidFire.tolerance or 0  -- % above the max a purchase may cost on average if the price moved
  db.rapidFire = rapidFire
  -- On Sale (OnSale.lua, DESIGN.md section 13), account-wide: the searches { id, name, term, on } (term in Auctionator's
  -- text format) and the next search id. Price history per ruleset key (History.lua).
  local onSale = type(db.onSale) == "table" and db.onSale or {}
  onSale.searches = type(onSale.searches) == "table" and onSale.searches or {}
  onSale.nextID = onSale.nextID or 1
  db.onSale = onSale
  db.history = type(db.history) == "table" and db.history or {}
  db.scanDays = type(db.scanDays) == "table" and db.scanDays or {}  -- ruleset key -> { [local day] = true } (History.lua)
  ProfitCraftDB = db
  PC.db = db
  PC:Send("DATA_READY")
end)

-- Changes a setting and tells the other parts. Settings that don't affect anything else are just stored.
function PC:SetSetting(key, value)
  if self.db.settings[key] == value then return end
  self.db.settings[key] = value
  self:Send("SETTINGS_CHANGED", key, value)
end
