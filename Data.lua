-- ProfitCraft: Data
-- Loads ProfitCraftDB, fills in default settings and upgrades older layouts step by step (DESIGN.md section 6).

local ADDON_NAME, PC = ...

local DB_VERSION = 1

local DEFAULT_SETTINGS = {
	debug = false,        -- show errors in chat as they happen
	profitMode = "craft", -- side panel: "craft", "stack" (per full stack) or "disenchant" (craft, then disenchant)
	ahCut = 0.05,         -- share of the sale price the AH keeps (web sources: 5%; to confirm in game)
	panelShown = true,    -- side panel open next to the profession window
	tooltipDisenchant = false, -- disenchant estimate line in item tooltips (off by default, as in Auctionator)
	reagentBagFreeSlots = false, -- free slots on the reagent bag button (off by default)
}

-- upgrades[n] turns a version n-1 database into version n.
local upgrades = {}

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
