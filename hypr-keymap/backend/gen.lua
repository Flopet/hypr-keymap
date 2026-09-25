-- Reads Hyprland binds for the keymap panel by loading your Lua config against
-- a stand-in `hl`, so nothing touches the running compositor.
--
--   lua gen.lua [path/to/hyprland.lua]      (default ~/.config/hypr/hyprland.lua)
--
-- Prints JSON: { mode, config, hook, overrides_path, rows, overrides, warnings, stale }.
-- mode is "lua", or "none" when there's no Lua config at that path (the panel then
-- falls back to hyprctl). hook is true when the config loads hyprland/keymap.lua
-- and calls apply(), which is what editing needs.

local HOME = os.getenv("HOME") or ""
local config = (string.gsub(arg[1] or (HOME .. "/.config/hypr/hyprland.lua"), "^~", HOME))

-- ---- JSON ----

local ARRAY = {}
local function list() return setmetatable({}, ARRAY) end

local ESC = { ['"'] = '\\"', ["\\"] = "\\\\", ["\n"] = "\\n", ["\t"] = "\\t", ["\r"] = "\\r" }
local function escape(c) return ESC[c] or string.format("\\u%04x", c:byte()) end

local function json(v)
	local t = type(v)
	if v == nil then return "null" end
	if t == "boolean" then return tostring(v) end
	if t == "number" then return string.format("%.14g", v) end
	if t == "string" then return '"' .. v:gsub('[%c"\\]', escape) .. '"' end
	if #v > 0 or getmetatable(v) == ARRAY then
		local parts = {}
		for _, x in ipairs(v) do parts[#parts + 1] = json(x) end
		return "[" .. table.concat(parts, ",") .. "]"
	end
	local keys = {}
	for k in pairs(v) do keys[#keys + 1] = k end
	table.sort(keys)
	local parts = {}
	for _, k in ipairs(keys) do parts[#parts + 1] = json(tostring(k)) .. ":" .. json(v[k]) end
	return "{" .. table.concat(parts, ",") .. "}"
end

local f = io.open(config, "r")
if not f or not config:match("%.lua$") then
	if f then f:close() end
	io.write(json({ mode = "none", config = config, rows = list(), overrides = list(), warnings = list(), stale = list() }))
	return
end
f:close()

-- ---- Source files, for sections and function names ----

local sources = {}
local function linesOf(path)
	if not sources[path] then
		local lines = {}
		local file = io.open(path, "r")
		if file then
			for l in file:lines() do lines[#lines + 1] = l end
			file:close()
		end
		sources[path] = lines
	end
	return sources[path]
end

-- The line that declared a bind: the nearest file-level chunk on the stack, so a
-- bind helper or the keymap hook in between doesn't count
local function callSite()
	for level = 3, 60 do
		local info = debug.getinfo(level, "Sl")
		if not info then break end
		if info.what == "main" and info.source:sub(1, 1) == "@" then
			return info.source:sub(2), info.currentline
		end
	end
end

local function normalize(keys)
	local mods, key = {}, ""
	for raw in keys:gmatch("[^+]+") do
		local part = raw:match("^%s*(.-)%s*$")
		local mod = part:upper():gsub("^CONTROL$", "CTRL")
		if mod == "SUPER" or mod == "CTRL" or mod == "ALT" or mod == "SHIFT" then
			mods[mod] = true
		else
			key = part:lower()
		end
	end
	local out = {}
	for _, mod in ipairs({ "SUPER", "CTRL", "ALT", "SHIFT" }) do
		if mods[mod] then out[#out + 1] = mod end
	end
	out[#out + 1] = key
	return table.concat(out, " + ")
end

-- ---- Stand-in hl ----
-- Dispatchers become { name, args } so they can be shown; every other hl.* call
-- is a no-op, so autostart commands, rules and settings don't run here.

local records = {}

local function dispatchers(path)
	return setmetatable({}, {
		__index = function(t, k)
			local v = dispatchers(path == "" and k or path .. "." .. k)
			rawset(t, k, v)
			return v
		end,
		__call = function(_, a) return { name = path, args = a } end,
	})
end

local function noop()
	return setmetatable({}, { __index = function() return noop() end, __call = function() return nil end })
end

hl = setmetatable({
	dsp = dispatchers(""),
	bind = function(keys, action, opts)
		local file, line = callSite()
		local record = { keys = keys, action = action, opts = opts or {}, file = file, line = line }
		records[#records + 1] = record
		local handle = { record = record }
		function handle.unbind(self) self.record.removed = true end
		handle.remove = handle.unbind
		function handle.set_enabled() end
		function handle.is_enabled() return true end
		return handle
	end,
	unbind = function(keys)
		local want = normalize(keys)
		for _, r in ipairs(records) do
			if not r.removed and normalize(r.keys) == want then r.removed = true end
		end
	end,
	version = function() return "0.56.0" end,
}, {
	__index = function(t, k)
		local v = noop()
		rawset(t, k, v)
		return v
	end,
})

local warnings, stale = list(), list()

local dir = config:match("^(.*)/[^/]*$") or "."
package.path = dir .. "/?.lua;" .. dir .. "/?/init.lua;" .. package.path
local loaded, err = pcall(dofile, config)
if not loaded then
	warnings[#warnings + 1] = "Your config stopped loading here, so binds after this point are missing: " .. tostring(err)
end

-- ---- Describing actions ----

local ARG_ORDER = { "workspace", "monitor", "direction", "mode", "action", "x", "y", "relative", "index",
	"into_group", "out_of_group", "follow", "internal", "client", "prop", "value", "next" }

local function ser(v)
	if type(v) == "string" then return '"' .. v .. '"' end
	if type(v) ~= "table" then return tostring(v) end
	local parts, seen = {}, {}
	for _, x in ipairs(v) do parts[#parts + 1] = ser(x) end
	for _, k in ipairs(ARG_ORDER) do
		if v[k] ~= nil then parts[#parts + 1] = k .. " = " .. ser(v[k]); seen[k] = true end
	end
	for k, x in pairs(v) do
		if type(k) ~= "number" and not seen[k] then parts[#parts + 1] = tostring(k) .. " = " .. ser(x) end
	end
	return "{ " .. table.concat(parts, ", ") .. " }"
end

local function upvalues(fn)
	local t, i = {}, 1
	while true do
		local name, value = debug.getupvalue(fn, i)
		if not name then break end
		t[name] = value
		i = i + 1
	end
	return t
end

local function describe(action)
	if type(action) == "table" then
		if action.name == "exec_cmd" then return tostring(action.args) end
		if action.args == nil then return tostring(action.name) .. "()" end
		if type(action.args) == "string" then return action.name .. '("' .. action.args .. '")' end
		return tostring(action.name) .. "(" .. ser(action.args) .. ")"
	end
	if type(action) ~= "function" then return tostring(action) end
	local info = debug.getinfo(action, "S")
	local lines = info.source:sub(1, 1) == "@" and linesOf(info.source:sub(2)) or {}
	local text = lines[info.linedefined] or ""
	local named = text:match("^%s*local function ([%w_]+)") or text:match("^%s*function ([%w_.:]+)")
	if named then return named .. "()" end
	local inline = text:match("function%(%)%s*(.-)%s*end")
	if inline and inline ~= "" then return inline end
	for i = info.linedefined + 1, info.lastlinedefined - 1 do
		local call = (lines[i] or ""):match("^%s*(hl%.config%(.*%))%s*$")
		if call then return call end
	end
	-- A closure returned by a factory: name the factory and its settings
	local factory
	for i = info.linedefined, 1, -1 do
		factory = (lines[i] or ""):match("^%s*local function ([%w_]+)") or (lines[i] or ""):match("^%s*function ([%w_.:]+)")
		if factory then break end
	end
	local up = upvalues(action)
	if factory == "universal_clipboard_shortcut" and up.default_key then
		return string.format("send %s+%s (terminals: %s+%s)", up.default_mods, up.default_key, up.terminal_mods, up.terminal_key)
	end
	if factory == "send_shortcut_once" and up.key then return "send " .. tostring(up.mods) .. "+" .. up.key end
	local args = {}
	for name, value in pairs(up) do
		if type(value) == "string" or type(value) == "number" then args[#args + 1] = name .. " = " .. ser(value) end
	end
	table.sort(args)
	if factory then return factory .. "(" .. table.concat(args, ", ") .. ")" end
	return "Lua function"
end

-- ---- Sections ----
-- A header comment such as "---- TILING ----" above the bind names its section;
-- otherwise the file name does ("tiling.lua" becomes "Tiling").

local function titleCase(s)
	s = s:gsub(":.*$", ""):gsub("^%s+", ""):gsub("%s+$", "")
	if s == s:upper() then s = s:sub(1, 1) .. s:sub(2):lower() end
	return s
end

local function sectionFor(file, line)
	if not file then return "Binds" end
	local lines = linesOf(file)
	for i = math.min(line or #lines, #lines), 1, -1 do
		local header = lines[i]:match("^%s*%-%-%-+%s+(.-)%s+%-%-%-+%s*$")
		if header and header:match("%a") then return titleCase(header) end
	end
	local base = file:match("([^/]+)%.lua$") or file
	return titleCase((base:gsub("[_%-]", " "):gsub("^%l", string.upper)))
end

-- Short keycap labels. The table covers Omarchy's default descriptions and a few
-- common ones; anything else is shortened by short_for below.
local SHORT_PATTERNS = {
	{ "^Switch to workspace (%d+)$", "WS %1" },
	{ "^Move window to workspace (%d+)$", "To WS %1" },
	{ "^Move window silently to workspace (%d+)$", "Send %1" },
	{ "^Switch to group window (%d+)$", "Tab %1" },
	{ "^Go to workspace (%d+) of this monitor$", "Local %1" },
	{ "^Move window to workspace (%d+) of this monitor$", "To local %1" },
	{ "^Focus on %a+ window$", "Focus" },
	{ "^Swap window", "Swap" },
	{ "^Move workspace to", "WS to mon" },
	{ "^Move window to group", "Join" },
}
local RESIZE = { ["Expand window left"] = "Wider", ["Shrink window left"] = "Narrow",
	["Shrink window up"] = "Shorter", ["Expand window down"] = "Taller" }
local SHORT = {
	["Terminal"] = "Terminal", ["Browser"] = "Browser", ["File manager"] = "Files",
	["File manager (cwd)"] = "Files here", ["Browser (private)"] = "Private", ["Editor"] = "Editor",
	["Obsidian"] = "Obsidian", ["Close window"] = "Close", ["Close all windows"] = "Close all",
	["Toggle window split"] = "Split", ["Pseudo window"] = "Pseudo",
	["Toggle window floating/tiling"] = "Float", ["Full screen"] = "Full screen",
	["Tiled full screen"] = "Tiled full", ["Full width"] = "Full width",
	["Pop window out (float & pin)"] = "Pop out", ["Save window width"] = "Save width",
	["Restore window width"] = "Width", ["Toggle workspace layout"] = "Layout",
	["Toggle scratchpad"] = "Scratch", ["Move window to scratchpad"] = "To scratch",
	["Next workspace"] = "Next ws", ["Previous workspace"] = "Prev ws", ["Former workspace"] = "Last ws",
	["Focus on next window"] = "Next win", ["Focus on previous window"] = "Prev win",
	["Reveal active window on top"] = "Raise", ["Focus on next monitor"] = "Next mon",
	["Focus on previous monitor"] = "Prev mon",
	["Scroll active workspace forward"] = "Next ws", ["Scroll active workspace backward"] = "Prev ws",
	["Move window"] = "Move", ["Resize window"] = "Resize",
	["Toggle window grouping"] = "Group", ["Move active window out of group"] = "Ungroup",
	["Next window in group"] = "Next tab", ["Previous window in group"] = "Prev tab",
	["Move grouped window focus left"] = "Prev tab", ["Move grouped window focus right"] = "Next tab",
	["Monitor scaling up"] = "Scale +", ["Monitor scaling down"] = "Scale −",
	["Omarchy menu"] = "Menu", ["Apps menu"] = "Apps", ["Emojis"] = "Emoji", ["Capture menu"] = "Capture",
	["Toggle menu"] = "Toggles", ["Hardware menu"] = "HW", ["System menu"] = "System",
	["Power menu"] = "Power", ["Keybindings"] = "Keys", ["Calculator"] = "Calc",
	["Toggle top bar"] = "Bar", ["Background switcher"] = "Walls", ["Theme menu"] = "Theme",
	["Toggle window transparency"] = "Opaque", ["Toggle window gaps"] = "Gaps",
	["Toggle single-window square aspect"] = "Square",
	["Dismiss last notification"] = "Clear", ["Dismiss all notifications"] = "Clear all",
	["Toggle silencing notifications"] = "Silence", ["Invoke last notification"] = "Invoke",
	["Open notification history"] = "History", ["Toggle locking on idle"] = "Idle",
	["Toggle nightlight"] = "Night", ["Screenshot"] = "Shot", ["Color picker"] = "Picker",
	["Show time"] = "Time", ["Toggle weather"] = "Weather", ["Audio"] = "Audio", ["Bluetooth"] = "BT",
	["Display"] = "Display", ["Calendar"] = "Cal", ["Network"] = "Net", ["Power"] = "Power",
	["Activity"] = "btop", ["Zoom in"] = "Zoom +", ["Zoom out"] = "Zoom −", ["Reset zoom"] = "Zoom 1×",
	["Lock system"] = "Lock",
	["Universal copy"] = "Copy", ["Universal paste"] = "Paste", ["Universal cut"] = "Cut",
	["Clipboard manager"] = "Clips",
	["Volume up"] = "Vol +", ["Volume down"] = "Vol −", ["Mute"] = "Mute", ["Mute microphone"] = "Mic",
	["Brightness up"] = "Bright +", ["Brightness down"] = "Bright −", ["Brightness maximum"] = "Max",
	["Brightness minimum"] = "Min", ["Keyboard brightness up"] = "Kbd +",
	["Keyboard brightness down"] = "Kbd −", ["Keyboard backlight cycle"] = "Kbd light",
	["Volume up precise"] = "Vol +1", ["Volume down precise"] = "Vol −1", ["Next track"] = "Next",
	["Pause"] = "Pause", ["Play"] = "Play", ["Previous track"] = "Prev", ["Eject media"] = "Eject",
	["Switch audio output"] = "Output", ["Switch media source"] = "Source",
	["Maximize window"] = "Max", ["Noctalia settings"] = "Config", ["Notifications"] = "Notifs",
	["Session menu"] = "Session", ["Wallpaper picker"] = "Walls",
	["Edit lock screen widgets"] = "Lock edit", ["Media panel"] = "Media",
	["Move window to previous monitor"] = "To prev mon", ["Move window to next monitor"] = "To next mon",
	["Move window to next workspace on this monitor"] = "To next ws",
	["Move window to previous workspace on this monitor"] = "To prev ws",
	["Previous workspace on this monitor"] = "Prev ws", ["Next workspace on this monitor"] = "Next ws",
}

local function short_for(desc)
	if SHORT[desc] then return SHORT[desc] end
	for _, p in ipairs(SHORT_PATTERNS) do
		local s, n = desc:gsub(p[1], p[2])
		if n > 0 then return p[1]:find("%(") and s or p[2] end
	end
	local base, amount = desc:match("^(.-) a (%a+)$")
	local step = { little = "25", lot = "300" }
	if base and RESIZE[base] then return RESIZE[base] .. " " .. step[amount] end
	if RESIZE[desc] then return RESIZE[desc] .. " 100" end
	-- Any other description: the first words that fit on a keycap
	local short = ""
	for word in desc:gmatch("%S+") do
		if #short + #word + 1 > 11 then break end
		short = short == "" and word or short .. " " .. word
	end
	return short ~= "" and short or desc:sub(1, 10)
end


-- ---- Rows ----

local function modsAndKey(keys)
	local parts = {}
	for p in keys:gmatch("[^+]+") do parts[#parts + 1] = p:match("^%s*(.-)%s*$") end
	local key = table.remove(parts)
	return (table.concat(parts, " "):gsub("CONTROL", "CTRL")), key
end

local function row(record, fields)
	local mods, key = modsAndKey(record.keys)
	local desc = record.opts.description or record.opts.desc or describe(record.action)
	local section = fields.section or sectionFor(fields.file or record.file, fields.line or record.line)
	local action = record.action
	return {
		section = section, group = section,
		mods = mods, key = key, keys = record.keys,
		short = short_for(desc), desc = desc,
		cmd = describe(action),
		exec = type(action) == "table" and action.name == "exec_cmd",
		flags = (record.opts.repeating and "r" or "") .. (record.opts.locked and "l" or ""),
		state = fields.state or "default",
		ov = fields.ov,
		origin = fields.origin,
	}
end

local hook = rawget(_G, "hypr_keymap")
local editable = type(hook) == "table" and hook.applied ~= nil
if type(hook) == "table" and hook.applied == nil then
	warnings[#warnings + 1] = "The keymap hook is loaded but keymap.apply() isn't called at the end of your config, so edits can't take effect."
end

local rows, overrides, added = list(), list(), {}
local resultFor = {}

if editable then
	for _, e in ipairs(hook.registry) do
		if type(e.handle) == "table" and e.handle.record then e.handle.record.entry = e end
	end
	for _, result in ipairs(hook.applied) do
		if result.entry then resultFor[result.entry] = result end
		if type(result.handle) == "table" and result.handle.record then result.handle.record.result = result end
		local o, clean = result.override, {}
		for _, field in ipairs({ "bind", "name", "keys", "description", "command" }) do
			if type(o[field]) == "string" then clean[field] = o[field] end
		end
		if o.disabled == true then clean.disabled = true end
		overrides[#overrides + 1] = clean

		if result.missing then
			warnings[#warnings + 1] = string.format("An edit for “%s” (%s) no longer matches a bind in your config.", tostring(o.name), tostring(o.bind))
			stale[#stale + 1] = result.index - 1
		elseif result.error then
			warnings[#warnings + 1] = string.format("Couldn't bind %s: %s", tostring(result.keys), result.error)
		elseif not result.entry and not result.handle then
			warnings[#warnings + 1] = "Edit " .. result.index .. " in keymap-overrides.lua needs keys, a description and a command."
			stale[#stale + 1] = result.index - 1
		end
	end
end

for _, record in ipairs(records) do
	local e = record.entry
	if e then
		-- origin identifies the bind in keymap-overrides.lua (description may be nil)
		local origin = { keys = e.keys, description = e.description, cmd = describe(e.action) }
		local result = resultFor[e]
		if not result then
			if not record.removed then rows[#rows + 1] = row(record, { origin = origin }) end
		elseif result.override.disabled or result.error then
			rows[#rows + 1] = row(record, { origin = origin, state = "disabled", ov = result.index - 1 })
		elseif type(result.handle) == "table" then
			rows[#rows + 1] = row(result.handle.record, { origin = origin, state = "edited", ov = result.index - 1, file = record.file, line = record.line })
		end
	elseif record.result then
		if not record.result.entry then
			added[#added + 1] = row(record, { section = "Added", state = "added", ov = record.result.index - 1 })
		end
	elseif not record.removed then
		rows[#rows + 1] = row(record, {})
	end
end
for _, r in ipairs(added) do rows[#rows + 1] = r end

io.write(json({
	mode = "lua", config = config, hook = editable,
	overrides_path = editable and hook.overrides_path or nil,
	rows = rows, overrides = overrides, warnings = warnings, stale = stale,
}))
