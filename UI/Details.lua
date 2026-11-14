-- ProfitCraft: recipe details block
-- Shows the selected recipe's net profit and the cost of each reagent below the reagents in Blizzard's recipe
-- details (ProfessionsFrame.CraftingPage.SchematicForm). Follows the selection by hooking the form's Init
-- (hooksecurefunc: runs after Blizzard's code, changes nothing of it). Placed relative to Blizzard's
-- frames, not at fixed pixel offsets, and cut to fit the form (DESIGN.md section 7).

local _, PC = ...

local Details = {}
PC.Details = Details

local LINE_HEIGHT = 13
local MAX_LINES = 10

local block, lines, form
local currentRecipeID

local function GetLine(i)
	local line = lines[i]
	if not line then
		line = {}
		line.left = block:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
		line.left:SetPoint("TOPLEFT", 0, -(i - 1) * LINE_HEIGHT)
		line.left:SetJustifyH("LEFT")
		line.left:SetWordWrap(false)
		line.right = block:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
		line.right:SetPoint("TOPRIGHT", 0, -(i - 1) * LINE_HEIGHT)
		line.right:SetJustifyH("RIGHT")
		line.left:SetPoint("RIGHT", line.right, "LEFT", -6, 0)
		lines[i] = line
	end
	return line
end

local function SetLines(rows)
	for i = 1, math.max(#rows, #lines) do
		local row = rows[i]
		if row then
			local line = GetLine(i)
			line.left:SetText(row[1])
			line.right:SetText(row[2] or "")
			line.left:Show()
			line.right:Show()
		elseif lines[i] then
			lines[i].left:Hide()
			lines[i].right:Hide()
		end
	end
	block:SetHeight(math.max(1, #rows) * LINE_HEIGHT)
end

-- The block sits at the bottom of the recipe details (above the Track Recipe line) and grows upward, so it
-- never covers what Blizzard or other addons stack under the reagents (Auctionator adds "To Craft" and
-- "Profit" lines there). Lines that don't fit between the reagents and the bottom are left out.
local BOTTOM_OFFSET = 44     -- clears Blizzard's Track Recipe checkbox
local RESERVED_BELOW = 36    -- room kept under the reagents for other addons' lines (Auctionator: 2 lines)

-- Returns how many lines fit.
local function Place()
	local anchor = form.Reagents
	if form.OptionalReagents and form.OptionalReagents:IsShown() then anchor = form.OptionalReagents end
	local formLeft, formBottom = form:GetLeft(), form:GetBottom()
	local left, anchorBottom = form.Reagents:GetLeft(), anchor:GetBottom()
	block:ClearAllPoints()
	block:SetPoint("BOTTOMLEFT", form, "BOTTOMLEFT", (left and formLeft) and (left - formLeft) or 20, BOTTOM_OFFSET)
	if anchorBottom and formBottom then
		local space = (anchorBottom - RESERVED_BELOW) - (formBottom + BOTTOM_OFFSET)
		return math.max(0, math.floor(space / LINE_HEIGHT))
	end
	return MAX_LINES
end

function Details:Update()
	if not block then return end
	local result = currentRecipeID and PC.Profit.results[currentRecipeID]
	if not result or result.noProduct or not form.Reagents:IsShown() then
		block:Hide()
		return
	end
	local maxLines = math.min(MAX_LINES, Place())
	if maxLines < 1 then
		block:Hide()
		return
	end
	local rows = {}
	if result.complete then
		rows[#rows + 1] = { "|cffffd100Net profit per craft|r", PC:FormatProfit(result.profitCraft) }
	elseif result.bound then
		rows[#rows + 1] = { "|cffffd100Net profit per craft|r", "|cff888888BoP: can't be sold|r" }
	else
		rows[#rows + 1] = { "|cffffd100Net profit per craft|r", "|cff888888missing prices|r" }
	end
	if result.profitDisenchant then
		rows[#rows + 1] = { "|cffffd100Craft and disenchant|r", PC:FormatProfit(result.profitDisenchant) }
	end
	for _, reagent in ipairs(result.reagents) do
		local label = reagent.quantity .. " x " .. PC.Items:GetName(reagent.itemID)
		local value = reagent.total and PC.Prices:FormatReagent(reagent.total, reagent.how) or "|cffff8888no price|r"
		rows[#rows + 1] = { label, value }
	end
	if not result.salePrice and not result.bound and result.recipe.outputItemID then
		rows[#rows + 1] = { "|cffff8888No auction price for the product|r" }
	end
	while #rows > maxLines do table.remove(rows) end
	SetLines(rows)
	block:Show()
end

local function Create()
	form = ProfessionsFrame and ProfessionsFrame.CraftingPage and ProfessionsFrame.CraftingPage.SchematicForm
	if not (form and form.Reagents) then return end
	block = CreateFrame("Frame", nil, form)
	block:SetWidth(300)
	block:SetHeight(LINE_HEIGHT)
	lines = {}
	hooksecurefunc(form, "Init", function(_, recipeInfo)
		PC:Call("details hook", function()
			currentRecipeID = recipeInfo and recipeInfo.recipeID
			Details:Update()
		end)
	end)
	local recipeInfo = form.GetRecipeInfo and form:GetRecipeInfo()
	currentRecipeID = recipeInfo and recipeInfo.recipeID
end

PC:Listen("PROFESSION_OPENED", function()
	if not block then Create() end
	Details:Update()
end)
PC:Listen("RESULTS_CHANGED", function() Details:Update() end)
PC:Listen("ITEM_DATA_CHANGED", function() Details:Update() end)
