-- ProfitCraft: Core
-- Private namespace, one event frame, a small message system between the parts, the error log,
-- money formatting and the /pcraft slash command. See plan/DESIGN.md.

local ADDON_NAME, PC = ...

PC.version = C_AddOns.GetAddOnMetadata(ADDON_NAME, "Version") or "?"

local MAX_ERRORS = 50

---------------------------------------------------------------------------
-- Chat output
---------------------------------------------------------------------------

function PC:Print(msg)
	print("|cff4fc3f7ProfitCraft:|r " .. tostring(msg))
end

---------------------------------------------------------------------------
-- Error log (DESIGN.md principle 4): errors never pop up while playing; they are
-- always logged, and printed in chat when debug mode is on.
---------------------------------------------------------------------------

function PC:ReportError(where, err)
	local message = tostring(err)
	local db = self.db
	if db then
		local errors = db.errors
		local found
		for i, entry in ipairs(errors) do
			if entry.message == message and entry.where == where then
				found = table.remove(errors, i)
				break
			end
		end
		found = found or { message = message, where = where, count = 0 }
		found.count = found.count + 1
		found.time = time()
		found.version = self.version
		table.insert(errors, 1, found)
		while #errors > MAX_ERRORS do table.remove(errors) end
	end
	if not db or db.settings.debug then
		self:Print("|cffff5555error in " .. tostring(where) .. ":|r " .. message)
	end
end

-- Calls fn(...) and catches any error into the error log. Returns fn's results, or nothing on error.
function PC:Call(where, fn, ...)
	local args, n = { ... }, select("#", ...)
	local results = { xpcall(function() return fn(unpack(args, 1, n)) end, function(err)
		local stack = debugstack and debugstack(2, 6, 0)
		return stack and (tostring(err) .. "\n" .. stack) or err
	end) }
	if not results[1] then
		self:ReportError(where, results[2])
		return
	end
	return unpack(results, 2, table.maxn(results))
end

---------------------------------------------------------------------------
-- Messages between the parts (DESIGN.md principle 2)
---------------------------------------------------------------------------

local listeners = {}

function PC:Listen(message, fn)
	listeners[message] = listeners[message] or {}
	table.insert(listeners[message], fn)
end

function PC:Send(message, ...)
	for _, fn in ipairs(listeners[message] or {}) do
		self:Call("message " .. message, fn, ...)
	end
end

---------------------------------------------------------------------------
-- Game events
---------------------------------------------------------------------------

local eventFrame = CreateFrame("Frame")
local eventHandlers = {}

function PC:RegisterEvent(event, fn)
	if not eventHandlers[event] then
		eventHandlers[event] = {}
		eventFrame:RegisterEvent(event)
	end
	table.insert(eventHandlers[event], fn)
end

eventFrame:SetScript("OnEvent", function(_, event, ...)
	for _, fn in ipairs(eventHandlers[event]) do
		PC:Call("event " .. event, fn, ...)
	end
end)

-- Runs fn once, `delay` seconds after the last request with the same key (several requests in a row
-- become one call).
local debounceTokens = {}
function PC:Debounce(key, delay, fn)
	local token = {}
	debounceTokens[key] = token
	C_Timer.After(delay, function()
		if debounceTokens[key] ~= token then return end
		debounceTokens[key] = nil
		PC:Call("debounced " .. key, fn)
	end)
end

---------------------------------------------------------------------------
-- Formatting
---------------------------------------------------------------------------

-- Copper amount as gold/silver/copper with coin icons; negative amounts in red with a minus sign.
function PC:FormatMoney(copper)
	if copper == nil then return "|cff888888?|r" end
	local rounded = math.floor(math.abs(copper) + 0.5)
	local text = GetMoneyString(rounded, true)
	if copper < 0 and rounded > 0 then return "|cffff5555-|r" .. text end
	return text
end

---------------------------------------------------------------------------
-- Slash command
---------------------------------------------------------------------------

local function PrintErrors(clear)
	local errors = PC.db.errors
	if clear then
		wipe(errors)
		PC:Print("error log emptied.")
		return
	end
	if #errors == 0 then
		PC:Print("no errors logged.")
		return
	end
	PC:Print(#errors .. " logged error(s), newest first:")
	for i, entry in ipairs(errors) do
		print(string.format("  %d. [%s, %dx, v%s] %s: %s", i, date("%Y-%m-%d %H:%M", entry.time), entry.count,
			tostring(entry.version), tostring(entry.where), (tostring(entry.message):match("^[^\n]*"))))
	end
end

SLASH_PROFITCRAFT1 = "/pcraft"
SlashCmdList.PROFITCRAFT = function(msg)
	PC:Call("slash command", function()
		if not PC.db then return end
		local command, rest = strtrim(msg or ""):match("^(%S*)%s*(.-)$")
		command = command:lower()
		rest = rest:lower()
		if command == "" then
			PC:Send("TOGGLE_PANEL")
		elseif command == "debug" and (rest == "on" or rest == "off") then
			PC:SetSetting("debug", rest == "on")
			PC:Print("debug mode " .. rest .. ".")
		elseif command == "settings" then
			PC:Send("TOGGLE_SETTINGS")
		elseif command == "errors" then
			PrintErrors(rest == "clear")
		elseif command == "bags" then
			PC:Send("TOGGLE_BAGS")
		elseif command == "tooltip" and (rest == "on" or rest == "off") then
			PC:SetSetting("tooltipDisenchant", rest == "on")
			PC:Print("disenchant line in item tooltips " .. rest .. ".")
		else
			PC:Print("version " .. PC.version .. ". Commands:")
			print("  /pcraft - show or hide the profit list (with a profession window open)")
			print("  /pcraft settings - open the settings window")
			print("  /pcraft bags - disenchant values of the items in your bags")
			print("  /pcraft tooltip on|off - disenchant estimate in item tooltips")
			print("  /pcraft debug on|off - show errors in chat as they happen")
			print("  /pcraft errors - list logged errors; /pcraft errors clear - empty the log")
		end
	end)
end
