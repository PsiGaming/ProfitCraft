-- ProfitCraft: disenchant estimate
-- What disenchanting one item is worth on average, from ProfitCraft's own table priced with AH prices
-- (DESIGN.md section 12). The table is keyed by quality, armor/weapon and item level.
-- Sources (2026-11-13): the Classic disenchanting tables (Warcraft Wiki "Disenchanting tables", matching
-- foreverdb.net's "Classic data"), checked row by row against two addons' Classic tables; where they differ,
-- the majority is used. Item level, not required level: the Forever client's own table is ordered by item
-- level (forevermastery.com). The odds are not yet confirmed for Forever, so the value is shown as an estimate.

local _, PC = ...

local Disenchant = {}
PC.Disenchant = Disenchant

-- Materials (item IDs; spot-checked on foreverdb.net for Forever).
local STRANGE_DUST, SOUL_DUST, VISION_DUST, DREAM_DUST, ILLUSION_DUST = 10940, 11083, 11137, 11176, 16204
local LESSER_MAGIC, GREATER_MAGIC = 10938, 10939
local LESSER_ASTRAL, GREATER_ASTRAL = 10998, 11082
local LESSER_MYSTIC, GREATER_MYSTIC = 11134, 11135
local LESSER_NETHER, GREATER_NETHER = 11174, 11175
local LESSER_ETERNAL, GREATER_ETERNAL = 16202, 16203
local SMALL_GLIMMERING, LARGE_GLIMMERING = 10978, 11084
local SMALL_GLOWING, LARGE_GLOWING = 11138, 11139
local SMALL_RADIANT, LARGE_RADIANT = 11177, 11178
local SMALL_BRILLIANT, LARGE_BRILLIANT = 14343, 14344
local NEXUS_CRYSTAL = 20725

-- 3 lesser essences combine into 1 greater, and 1 greater splits into 3 lesser (both confirmed in the
-- Forever client's item data on foreverdb.net, 2026-11-13). lesser -> greater.
local ESSENCE_PAIRS = {
	[LESSER_MAGIC] = GREATER_MAGIC, [LESSER_ASTRAL] = GREATER_ASTRAL, [LESSER_MYSTIC] = GREATER_MYSTIC,
	[LESSER_NETHER] = GREATER_NETHER, [LESSER_ETERNAL] = GREATER_ETERNAL,
}
local GREATER_TO_LESSER = {}
for lesser, greater in pairs(ESSENCE_PAIRS) do GREATER_TO_LESSER[greater] = lesser end

-- Rows: { lowest item level, highest item level, { material, chance %, min amount, max amount }, ... }
-- Each amount from min to max is equally likely.
local GREEN_ARMOR = {
	{ 1, 15, { STRANGE_DUST, 80, 1, 2 }, { LESSER_MAGIC, 20, 1, 2 } },
	{ 16, 20, { STRANGE_DUST, 75, 2, 3 }, { GREATER_MAGIC, 20, 1, 2 }, { SMALL_GLIMMERING, 5, 1, 1 } },
	{ 21, 25, { STRANGE_DUST, 75, 4, 6 }, { LESSER_ASTRAL, 15, 1, 2 }, { SMALL_GLIMMERING, 10, 1, 1 } },
	{ 26, 30, { SOUL_DUST, 75, 1, 2 }, { GREATER_ASTRAL, 20, 1, 2 }, { LARGE_GLIMMERING, 5, 1, 1 } },
	{ 31, 35, { SOUL_DUST, 75, 2, 5 }, { LESSER_MYSTIC, 20, 1, 2 }, { SMALL_GLOWING, 5, 1, 1 } },
	{ 36, 40, { VISION_DUST, 75, 1, 2 }, { GREATER_MYSTIC, 20, 1, 2 }, { LARGE_GLOWING, 5, 1, 1 } },
	{ 41, 45, { VISION_DUST, 75, 2, 5 }, { LESSER_NETHER, 20, 1, 2 }, { SMALL_RADIANT, 5, 1, 1 } },
	{ 46, 50, { DREAM_DUST, 75, 1, 2 }, { GREATER_NETHER, 20, 1, 2 }, { LARGE_RADIANT, 5, 1, 1 } },
	{ 51, 55, { DREAM_DUST, 75, 2, 5 }, { LESSER_ETERNAL, 20, 1, 2 }, { SMALL_BRILLIANT, 5, 1, 1 } },
	{ 56, 60, { ILLUSION_DUST, 75, 1, 2 }, { GREATER_ETERNAL, 20, 1, 2 }, { LARGE_BRILLIANT, 5, 1, 1 } },
	{ 61, 65, { ILLUSION_DUST, 75, 2, 5 }, { GREATER_ETERNAL, 20, 2, 3 }, { LARGE_BRILLIANT, 5, 1, 1 } },
}

-- Item level 21-30 gives Greater Magic Essence (both addons' Classic tables; the wiki says Astral).
local GREEN_WEAPON = {
	{ 1, 15, { LESSER_MAGIC, 80, 1, 2 }, { STRANGE_DUST, 20, 1, 2 } },
	{ 16, 20, { GREATER_MAGIC, 75, 1, 2 }, { STRANGE_DUST, 20, 2, 3 }, { SMALL_GLIMMERING, 5, 1, 1 } },
	{ 21, 25, { GREATER_MAGIC, 75, 1, 2 }, { STRANGE_DUST, 15, 4, 6 }, { SMALL_GLIMMERING, 10, 1, 1 } },
	{ 26, 30, { GREATER_MAGIC, 75, 1, 2 }, { SOUL_DUST, 20, 1, 2 }, { LARGE_GLIMMERING, 5, 1, 1 } },
	{ 31, 35, { LESSER_MYSTIC, 75, 1, 2 }, { SOUL_DUST, 20, 2, 5 }, { SMALL_GLOWING, 5, 1, 1 } },
	{ 36, 40, { GREATER_MYSTIC, 75, 1, 2 }, { VISION_DUST, 20, 1, 2 }, { LARGE_GLOWING, 5, 1, 1 } },
	{ 41, 45, { LESSER_NETHER, 75, 1, 2 }, { VISION_DUST, 20, 2, 5 }, { SMALL_RADIANT, 5, 1, 1 } },
	{ 46, 50, { GREATER_NETHER, 75, 1, 2 }, { DREAM_DUST, 20, 1, 2 }, { LARGE_RADIANT, 5, 1, 1 } },
	{ 51, 55, { LESSER_ETERNAL, 75, 1, 2 }, { DREAM_DUST, 20, 2, 5 }, { SMALL_BRILLIANT, 5, 1, 1 } },
	{ 56, 60, { GREATER_ETERNAL, 75, 1, 2 }, { ILLUSION_DUST, 20, 1, 2 }, { LARGE_BRILLIANT, 5, 1, 1 } },
	{ 61, 65, { GREATER_ETERNAL, 75, 2, 3 }, { ILLUSION_DUST, 20, 2, 5 }, { LARGE_BRILLIANT, 5, 1, 1 } },
}

-- Armor and weapons alike. Above 55 the TBC-era rows of the wiki don't apply (their materials don't exist
-- at level 60); these are the Classic rows.
local BLUE = {
	{ 1, 25, { SMALL_GLIMMERING, 100, 1, 1 } },
	{ 26, 30, { LARGE_GLIMMERING, 100, 1, 1 } },
	{ 31, 35, { SMALL_GLOWING, 100, 1, 1 } },
	{ 36, 40, { LARGE_GLOWING, 100, 1, 1 } },
	{ 41, 45, { SMALL_RADIANT, 100, 1, 1 } },
	{ 46, 50, { LARGE_RADIANT, 100, 1, 1 } },
	{ 51, 55, { SMALL_BRILLIANT, 100, 1, 1 } },
	{ 56, 86, { LARGE_BRILLIANT, 99.5, 1, 1 }, { NEXUS_CRYSTAL, 0.5, 1, 1 } },
}

local PURPLE_ARMOR = {
	{ 40, 45, { SMALL_RADIANT, 100, 2, 4 } },
	{ 46, 50, { LARGE_RADIANT, 100, 2, 4 } },
	{ 51, 55, { SMALL_BRILLIANT, 100, 2, 4 } },
	{ 56, 60, { NEXUS_CRYSTAL, 100, 1, 1 } },
	{ 61, 92, { NEXUS_CRYSTAL, 100, 1, 2 } },
}

local PURPLE_WEAPON = {
	{ 40, 45, { SMALL_RADIANT, 100, 2, 4 } },
	{ 46, 50, { LARGE_RADIANT, 100, 2, 4 } },
	{ 51, 55, { SMALL_BRILLIANT, 100, 2, 4 } },
	{ 56, 60, { NEXUS_CRYSTAL, 100, 1, 1 } },
	{ 61, 92, { NEXUS_CRYSTAL, 33, 1, 1 }, { NEXUS_CRYSTAL, 67, 2, 2 } },
}

-- Item quality 2/3/4 = green/blue/purple; item class 2 = weapon, 4 = armor (Enum.ItemQuality, Enum.ItemClass).
local TABLES = {
	[2] = { [4] = GREEN_ARMOR, [2] = GREEN_WEAPON },
	[3] = { [4] = BLUE, [2] = BLUE },
	[4] = { [4] = PURPLE_ARMOR, [2] = PURPLE_WEAPON },
}

local function FindRow(quality, classID, itemLevel)
	local byClass = TABLES[quality]
	local rows = byClass and byClass[classID]
	if not (rows and itemLevel) then return nil end
	for _, row in ipairs(rows) do
		if itemLevel >= row[1] and itemLevel <= row[2] then return row end
	end
	return nil
end

-- What one unit of a material sells for: essences count as whichever form (lesser or greater) sells for more,
-- since they convert both ways. nil if no price is known.
local function MaterialPrice(itemID)
	local own = PC.Prices:GetAuctionPrice(itemID)
	local other
	if ESSENCE_PAIRS[itemID] then
		other = PC.Prices:GetAuctionPrice(ESSENCE_PAIRS[itemID])
		other = other and other / 3
	elseif GREATER_TO_LESSER[itemID] then
		other = PC.Prices:GetAuctionPrice(GREATER_TO_LESSER[itemID])
		other = other and other * 3
	end
	if own and other then return math.max(own, other) end
	return own or other
end

-- Average AH value in copper of disenchanting one item (before the AH cut), or nil: not disenchantable, item
-- data not loaded yet, outside the table, or a material without a known price.
-- Pass the exact link when there is one (bag slot, tooltip).
function Disenchant:GetValue(itemID, itemLink)
	local _, _, quality, itemLevel, _, _, _, _, _, _, _, classID = C_Item.GetItemInfo(itemLink or itemID)
	local row = FindRow(quality, classID, itemLevel)
	if not row then return nil end
	local value = 0
	for i = 3, #row do
		local material, chance, low, high = unpack(row[i])
		local price = MaterialPrice(material)
		if not price then return nil end
		value = value + price * chance / 100 * (low + high) / 2
	end
	return math.floor(value + 0.5)
end
