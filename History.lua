-- ProfitCraft: own price history per item and variant (DESIGN.md section 13, "History")
-- Auctionator keeps one history per item ID on Forever (all its keys are plain item IDs; suffix keys exist only for
-- Classic's old AH, Auctionator 346 Source/Utilities/DBKeyFromLink.lua), so "of the Knight" and "of the Monkey"
-- would share one price. ProfitCraft records what it sees anyway (On Sale searches, full scans) per item + variant
-- (OnSale:Variant: 0, or for weapons and armour the full item name, which includes a random suffix):
-- * the first price seen in each hour of the day (the cheapest listing of other sellers at that moment);
-- * at the end of a day, the median of that day's hourly prices becomes the day's price;
-- * usual price = median of the last 7 daily prices (today's so far included), once there are at least 3 days.
-- Daily lows are not used: a search every minute sees every short-lived cheap listing, which would pull the usual
-- price down. Kept 14 days, per ruleset key (Scan:RulesetKey).
-- Until an item has 3 days: Auctionator's history (internal Auctionator.Database:GetPriceHistory, Auctionator 346
-- Source/Database/Mixin.lua), but only when the caller allows it (not for weapons and armour, whose random suffixes
-- Auctionator mixes); those wait.

local _, PC = ...

local History = {}
PC.History = History

local KEEP_DAYS = 14
local USUAL_DAYS = 7
local MIN_DAYS = 3
local FALLBACK_CACHE_SECONDS = 600

local function Today() return math.floor(time() / 86400) end
local function Hour() return math.floor(time() / 3600) % 24 end

local function Median(values)
  if #values == 0 then return nil end
  table.sort(values)
  local middle = math.floor((#values + 1) / 2)
  if #values % 2 == 1 then return values[middle] end
  return math.floor((values[middle] + values[middle + 1]) / 2 + 0.5)
end
History.Median = Median

function History:Key(itemID, variant)
  return itemID .. ":" .. (variant or 0)
end

local function Store(create)
  local all = PC.db.history
  local key = PC.Scan:RulesetKey()
  if not all[key] and create then all[key] = {} end
  return all[key]
end

-- Turns the samples of an earlier day into that day's price and drops days older than KEEP_DAYS.
local function Roll(entry, today)
  if entry.t ~= today then
    local samples = {}
    for _, price in pairs(entry.s or {}) do samples[#samples + 1] = price end
    if #samples > 0 and entry.t then entry.d[entry.t] = Median(samples) end
    entry.s, entry.t = {}, today
  end
  for day in pairs(entry.d) do
    if day <= today - KEEP_DAYS then entry.d[day] = nil end
  end
end

-- Notes the cheapest price of other sellers seen now for an item (+ variant). Only the first price of each hour counts.
function History:Record(itemID, variant, price)
  if not (itemID and price and price > 0) then return end
  local store = Store(true)
  local key = self:Key(itemID, variant)
  local entry = store[key]
  local today = Today()
  if not entry then
    entry = { t = today, s = {}, d = {} }
    store[key] = entry
  end
  Roll(entry, today)
  local hour = Hour()
  if entry.s[hour] == nil then entry.s[hour] = price end
end

-- Daily prices, newest first: today's median so far (if any), then the stored days.
function History:GetDays(itemID, variant)
  local store = Store(false)
  local entry = store and store[self:Key(itemID, variant)]
  if not entry then return {} end
  local today = Today()
  Roll(entry, today)
  local days = {}
  for day, price in pairs(entry.d) do days[#days + 1] = { day, price } end
  local samples = {}
  for _, price in pairs(entry.s) do samples[#samples + 1] = price end
  if #samples > 0 then days[#days + 1] = { today, Median(samples) } end
  table.sort(days, function(a, b) return a[1] > b[1] end)
  return days
end

-- Auctionator's daily lows for an item ID (no suffixes), newest first; nil when Auctionator or its data is missing.
-- Internal Auctionator code: wrapped so a change in Auctionator only switches this fallback off.
local fallbackCache = {}
local function AuctionatorDays(itemID)
  local cached = fallbackCache[itemID]
  if cached and cached.time > GetTime() - FALLBACK_CACHE_SECONDS then return cached.prices end
  local prices
  local database = type(Auctionator) == "table" and Auctionator.Database
  if type(database) == "table" and type(database.GetPriceHistory) == "function" then
    local ok, result = pcall(database.GetPriceHistory, database, tostring(itemID))
    if ok and type(result) == "table" then
      prices = {}
      for _, day in ipairs(result) do
        if type(day) == "table" and type(day.minSeen) == "number" and day.minSeen > 0 then
          prices[#prices + 1] = day.minSeen
        end
      end
    end
  end
  fallbackCache[itemID] = { time = GetTime(), prices = prices }
  return prices
end

-- The usual price of an item (+ variant): copper, source ("own" or "Auctionator") and number of days used; nil when
-- there's not enough history. allowFallback: Auctionator's history may fill in while ours has < 3 days.
function History:GetUsual(itemID, variant, allowFallback)
  local days = self:GetDays(itemID, variant)
  if #days >= MIN_DAYS then
    local prices = {}
    for i = 1, math.min(USUAL_DAYS, #days) do prices[i] = days[i][2] end
    return Median(prices), "own", #prices
  end
  if not allowFallback then return nil end
  local lows = AuctionatorDays(itemID)
  if lows and #lows >= MIN_DAYS then
    local prices = {}
    for i = 1, math.min(USUAL_DAYS, #lows) do prices[i] = lows[i] end
    return Median(prices), "Auctionator", #prices
  end
  return nil
end

-- Number of items (+ suffixes) with history on this ruleset.
function History:Count()
  local store = Store(false)
  local count = 0
  for _ in pairs(store or {}) do count = count + 1 end
  return count
end

-- Drops items not seen for KEEP_DAYS, at login.
PC:Listen("DATA_READY", function()
  local cutoff = Today() - KEEP_DAYS
  for _, store in pairs(PC.db.history) do
    for key, entry in pairs(store) do
      local newest = entry.t or 0
      for day in pairs(entry.d or {}) do newest = math.max(newest, day) end
      if newest <= cutoff then store[key] = nil end
    end
  end
end)
