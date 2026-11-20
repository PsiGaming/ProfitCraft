-- ProfitCraft: AH scan data (DESIGN.md section 9)
-- Reads full AH scans (C_AuctionHouse.ReplicateItems) and keeps a small snapshot: for the reagents and products
-- of every recipe seen on the account, the cheapest price levels {price per unit, quantity} plus the total units
-- listed, without the player's own listings. Replaced by every scan. Every listing of other sellers also goes to On
-- Sale (OnSale.lua: price history per item and suffix, finds), 0.3.
-- * With Auctionator: ProfitCraft never scans. It hooks Auctionator's two scan routines (internal, Auctionator
--   346/347: AuctionatorFullScanFrameMixin / AuctionatorIncrementalScanFrameMixin :InitiateScan). A full
--   ("replicate") scan is read along when the game delivers it; a summary scan only gets a chat notice.
-- * Without Auctionator: a "Full scan" button on the AH window, at most one scan per 15 minutes (Auctionator's
--   rule, FullScan/Mixins/Frame.lua CanInitiate).
-- Forever API: REPLICATE_ITEM_LIST_UPDATE goes to every addon listening; GetReplicateItemInfo(index), index 0 ..
-- GetNumReplicateItems() - 1 (as Auctionator reads it), returns name, texture, count, qualityID, usable, level,
-- levelType, minBid, minIncrement, buyoutPrice, bidAmount, highBidder, bidderFullName, owner, ownerFullName,
-- saleStatus, itemID, hasAllInfo (AuctionHouseDocumentation.lua).

local _, PC = ...

local Scan = {}
PC.Scan = Scan

local MAX_LEVELS = 40         -- cheapest price levels kept per item
local BATCH = 1000            -- listings read per frame, so the game doesn't stall
local FULL_SCAN_GAP = 15 * 60 -- seconds between full scans of our own
local LOAD_TIMEOUT = 10        -- seconds to wait for incomplete listings' item data

local reading  -- state while a scan is awaited or read

-- "CAMWOW US2 Realm 7 PvE" + Alliance -> "CAMWOW US2 PvE|Alliance": characters on any instance of a ruleset share
-- one AH (DESIGN.md section 6); the faction is kept apart until a shared AH is confirmed.
function Scan:RulesetKey()
  local realm = (GetRealmName() or "?"):gsub("%s*Realm %d+", "")
  return realm .. "|" .. (UnitFactionGroup("player") or "?")
end

function Scan:GetSnapshot()
  return PC.db.snapshot[self:RulesetKey()]
end

function Scan:IsReading()
  return reading ~= nil
end

-- Remember the reagents and products of every recipe seen, so a scan knows what to keep.
PC:Listen("RECIPES_CHANGED", function()
  local wanted = PC.db.recipeItems
  for _, recipe in ipairs(PC.Recipes.list) do
    if recipe.outputItemID then wanted[recipe.outputItemID] = true end
    for _, reagent in ipairs(recipe.reagents) do
      for _, itemID in ipairs(reagent.items) do wanted[itemID] = true end
    end
  end
end)

-- The forms the player's name may take as a seller: Forever names are "First Last" (knowledge file); how the AH
-- writes them isn't known yet, so all likely forms count.
local function OwnNames()
  local names = {}
  local short = UnitName("player")
  if short then names[short] = true end
  local first, last = UnitFullName("player")
  if first then
    names[first] = true
    if last and last ~= "" then
      names[first .. " " .. last] = true
      names[first .. "-" .. last] = true
    end
  end
  return names, first or short
end

local function Finish()
  local r = reading
  reading = nil
  local levels, totals, kept = {}, {}, 0
  for itemID, byPrice in pairs(r.items) do
    local list, total = {}, 0
    for price, quantity in pairs(byPrice) do
      list[#list + 1] = { price, quantity }
      total = total + quantity
    end
    table.sort(list, function(a, b) return a[1] < b[1] end)
    for i = MAX_LEVELS + 1, #list do list[i] = nil end
    levels[itemID], totals[itemID] = list, total
    kept = kept + 1
  end
  PC.db.snapshot[Scan:RulesetKey()] = { time = r.time, levels = levels, totals = totals }
  local incomplete = r.pendingCount > 0
    and string.format(" %d listings stayed incomplete and were left out.", r.pendingCount) or ""
  PC:Print(string.format("scan read: %s listings, prices for %d of your recipe items (%d of your own listings "
    .. "left out).%s", BreakUpLargeNumbers(r.count), kept, r.ownSkipped, incomplete))
  if next(r.wanted) == nil then
    PC:Print("open each of your professions once, so ProfitCraft knows which items to keep from the next scan.")
  end
  if PC.db.settings.debug then
    local forms = {}
    for name in pairs(r.ownForms) do forms[#forms + 1] = "\"" .. name .. "\"" end
    table.sort(forms)
    PC:Print("debug: sellers named like you: " .. (#forms > 0 and table.concat(forms, ", ") or "none"))
  end
  PC:Send("PRICES_CHANGED")
  PC:Send("SCAN_CHANGED")
  if r.collector and not r.collector.failed then PC:Call("On Sale scan", r.collector.Finish, r.collector) end
  PC:Call("scan days", function()
    PC.History:NoteScanDay()
    local days = PC.History:ScanDaysInWeek()
    if days < PC.History.MIN_DAYS and PC.db.settings.scanWarning then
      PC:Print(string.format("%sPrice history: full scans on %d of the last 7 days. On Sale's usual prices (and gear "
        .. "finds) need scans on %d different days.|r", NOTICE_COLOR, days, PC.History.MIN_DAYS))
    end
    PC:Send("ONSALE_STATUS")
  end)
end

-- Adds one listing (index into the game's scan list) to the snapshot being built. A listing of a recipe item that
-- the game delivers incomplete (hasAllInfo false) is read again once its item data has loaded, as Auctionator
-- does (Source_ModernAH/FullScan/Mixins/Frame.lua, ProcessBatch); everything else is used right away.
local function ReadListing(r, index, retry)
  local name, _, count, _, _, _, _, _, _, buyout, _, _, _, owner, ownerFull, _, itemID, hasAllInfo =
    C_AuctionHouse.GetReplicateItemInfo(index)
  if r.first and ((owner and owner:find(r.first, 1, true)) or (ownerFull and ownerFull:find(r.first, 1, true))) then
    r.ownForms[ownerFull or owner] = true
  end
  if not itemID then return end
  local wanted = r.wanted[itemID]
  if wanted and not hasAllInfo and not retry then
    r.pending[index] = itemID
    r.pendingCount = r.pendingCount + 1
    C_Item.RequestLoadItemDataByID(itemID)
    return
  end
  if not (buyout and buyout > 0 and count and count > 0) then return end
  if (owner and r.own[owner]) or (ownerFull and r.own[ownerFull]) then
    if wanted then r.ownSkipped = r.ownSkipped + 1 end
    return
  end
  local price = math.floor(buyout / count + 0.5)
  -- On Sale must never break the scan: its first error switches it off for this scan (and is logged).
  if r.collector and not r.collector.failed then
    local ok, err = pcall(r.collector.Add, r.collector, index, itemID, price, count, name)
    if not ok then
      r.collector.failed = true
      PC:ReportError("On Sale scan", err)
    end
  end
  if not wanted then return end
  local byPrice = r.items[itemID]
  if not byPrice then
    byPrice = {}
    r.items[itemID] = byPrice
  end
  byPrice[price] = (byPrice[price] or 0) + count
end

-- Done once every listing is read and no incomplete one is still waiting (or the wait timed out).
local function FinishWhenComplete(r)
  if reading == r and r.next >= r.count and r.pendingCount == 0 then Finish() end
end

local function ReadBatch()
  local r = reading
  if not r then return end  -- AH closed meanwhile
  local last = math.min(r.next + BATCH, r.count) - 1
  for i = r.next, last do ReadListing(r, i) end
  r.next = last + 1
  if r.next < r.count then
    C_Timer.After(0, function() PC:Call("read scan", ReadBatch) end)
  elseif r.pendingCount > 0 then
    C_Timer.After(LOAD_TIMEOUT, function()
      if reading == r then Finish() end  -- give up on what never loaded
    end)
  else
    Finish()
  end
end

PC:RegisterEvent("ITEM_DATA_LOAD_RESULT", function(itemID)
  local r = reading
  if not (r and r.pending and r.pendingCount > 0) then return end
  for index, pendingItemID in pairs(r.pending) do
    if pendingItemID == itemID then
      r.pending[index] = nil
      r.pendingCount = r.pendingCount - 1
      ReadListing(r, index, true)
    end
  end
  FinishWhenComplete(r)
end)

-- A full scan has been requested (by Auctionator or by us): wait for the game's data.
local function Await(message)
  if reading then return end
  reading = { time = time(), waiting = true }
  PC:Print(message)
  PC:Send("SCAN_CHANGED")
end

PC:RegisterEvent("REPLICATE_ITEM_LIST_UPDATE", function()
  if not (reading and reading.waiting) then return end
  local own, first = OwnNames()
  reading.waiting = false
  reading.count = C_AuctionHouse.GetNumReplicateItems() or 0
  reading.next = 0
  reading.wanted = PC.db.recipeItems
  reading.own, reading.first = own, first
  reading.items, reading.ownForms, reading.ownSkipped = {}, {}, 0
  reading.pending, reading.pendingCount = {}, 0
  reading.collector = PC.OnSale and PC.OnSale:NewScanCollector()
  ReadBatch()
end)

PC:RegisterEvent("AUCTION_HOUSE_CLOSED", function()
  if not reading then return end
  reading = nil
  PC:Print("the Auction House closed before the scan was read; prices unchanged.")
  PC:Send("SCAN_CHANGED")
end)

---------------------------------------------------------------------------
-- With Auctionator: follow its scans
---------------------------------------------------------------------------

local SUMMARY_NOTICE = "Auctionator summary scan detected. For exact reagent costs and On Sale, switch "
  .. "Auctionator to its detailed scan: Auctionator settings > Advanced > \"Use alternate slower scan mode by default\"."
local SUMMARY_WARNING = "ProfitCraft: Auctionator ran a SUMMARY scan - On Sale needs its detailed scan"
local NOTICE_COLOR = "|cffff8000"  -- orange, as Blizzard's raid warnings

-- Only when Auctionator really runs a summary scan, never on opening the AH (Sylice, 2026-11-20). A raid-warning style
-- message in the middle of the screen (Forever: Blizzard_RaidWarning, RaidWarningFrame:AddMessage) and an orange chat
-- line with the setting's path. Off with the "scanWarning" setting.
local function SummaryNotice()
  if not PC.db.settings.scanWarning then return end
  if RaidWarningFrame and RaidWarningFrame.AddMessage then
    RaidWarningFrame:AddMessage(SUMMARY_WARNING, ChatTypeInfo and ChatTypeInfo["RAID_WARNING"])
  end
  PC:Print(NOTICE_COLOR .. SUMMARY_NOTICE .. "|r")
end

-- Each hook checks that a scan really started now (Auctionator sets its scan time when it starts one and refuses
-- otherwise, e.g. within 15 minutes of the last full scan).
local function HookAuctionator()
  local full = AuctionatorFullScanFrameMixin
  if type(full) == "table" and type(full.InitiateScan) == "function" then
    hooksecurefunc(full, "InitiateScan", function(frame)
      PC:Call("Auctionator full scan", function()
        if frame.inProgress and frame.state and frame.state.TimeOfLastReplicateScan == time() then
          Await("reading Auctionator's full scan...")
        end
      end)
    end)
  end
  local summary = AuctionatorIncrementalScanFrameMixin
  if type(summary) == "table" and type(summary.InitiateScan) == "function" then
    hooksecurefunc(summary, "InitiateScan", function(frame)
      PC:Call("Auctionator summary scan", function()
        if frame.doingFullScan and frame.state and frame.state.TimeOfLastBrowseScan == time() then
          SummaryNotice()
        end
      end)
    end)
  end
end

---------------------------------------------------------------------------
-- Without Auctionator: our own "Full scan" button
---------------------------------------------------------------------------

local button, ticking

local function SecondsToWait()
  return (PC.db.lastFullScan or 0) + FULL_SCAN_GAP - time()
end

local function UpdateButton()
  local wait = SecondsToWait()
  if reading then
    button:SetText("Scanning...")
    button:SetEnabled(false)
  elseif wait > 0 then
    button:SetText(string.format("Scan in %d:%02d", math.floor(wait / 60), wait % 60))
    button:SetEnabled(false)
  else
    button:SetText("Full scan")
    button:SetEnabled(true)
  end
end

local function Tick()
  if not (button and button:IsVisible()) then
    ticking = false
    return
  end
  UpdateButton()
  C_Timer.After(1, Tick)
end

local function CreateButton()
  local parent = AuctionHouseFrame
  button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
  button:SetSize(110, 22)
  -- Next to the money display at the bottom left (Forever source: Blizzard_AuctionHouseUI/Shared/
  -- Blizzard_AuctionHouseFrame.xml, MoneyFrameInset).
  button:SetPoint("LEFT", parent.MoneyFrameInset or parent, parent.MoneyFrameInset and "RIGHT" or "BOTTOMLEFT", 4, 0)
  button:SetMotionScriptsWhileDisabled(true)
  button:SetScript("OnClick", function()
    PC:Call("full scan", function()
      if reading or SecondsToWait() > 0 then return end
      PC.db.lastFullScan = time()
      Await("full scan started, waiting for the Auction House...")
      C_AuctionHouse.ReplicateItems()
      UpdateButton()
    end)
  end)
  button:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    GameTooltip:AddLine("ProfitCraft full scan", 1, 1, 1)
    GameTooltip:AddLine("Reads every auction once and keeps the prices of your recipes' reagents and products. "
      .. "One full scan every 15 minutes. With Auctionator installed, scan with Auctionator instead.", nil, nil,
      nil, true)
    GameTooltip:Show()
  end)
  button:SetScript("OnLeave", function() GameTooltip:Hide() end)
end

PC:RegisterEvent("AUCTION_HOUSE_SHOW", function()
  if PC.Auctionator:IsAvailable() or not AuctionHouseFrame then return end
  if not button then CreateButton() end
  button:Show()
  if not ticking then
    ticking = true
    Tick()
  end
end)

PC:Listen("SCAN_CHANGED", function()
  if button and button:IsVisible() then UpdateButton() end
end)

PC:RegisterEvent("PLAYER_LOGIN", function()
  if PC.Auctionator:IsAvailable() then HookAuctionator() end
end)
