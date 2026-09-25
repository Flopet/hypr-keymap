--!nonstrict
-- Keymap panel: every Hyprland bind on a keyboard map, with search and editing.
-- Binds come from backend/gen.lua, which loads your Lua config against a stand-in
-- hl (or from `hyprctl binds` when there's no Lua config). Edits are saved by
-- backend/save.py through the keymap hook (hyprland/keymap.lua); see README.md.

local PLUGIN_DIR = noctalia.pluginDir()

local function configPath()
	return noctalia.expandPath(noctalia.getConfig("hyprland_config") or "~/.config/hypr/hyprland.lua")
end
local U = 42 -- one key unit in px
local GAP = 4

local ORDER = { "SUPER", "CTRL", "ALT", "SHIFT" }
local MODNAME = { SUPER = "Super", CTRL = "Ctrl", ALT = "Alt", SHIFT = "Shift" }
local LAYER_ORDER = {
	"SUPER", "SUPER SHIFT", "SUPER CTRL", "SUPER ALT", "SUPER CTRL SHIFT", "SUPER ALT SHIFT", "SUPER CTRL ALT",
	"ALT", "ALT SHIFT", "CTRL ALT", "CTRL ALT SHIFT", "CTRL SHIFT", "SHIFT", "",
}
local MODKEY = { shift_l = "SHIFT", shift_r = "SHIFT", ctrl_l = "CTRL", ctrl_r = "CTRL", alt_l = "ALT", alt_r = "ALT", super_l = "SUPER" }
local STATES = { edited = "edited", added = "added", disabled = "off" }

-- ---- Keyboard layout (US ANSI full size) ----
-- A key is { id, legend, width?, height? } in key units; { gap = n } is empty space.

local function letters(s)
	local out = {}
	for c in string.gmatch(s, ".") do
		table.insert(out, { string.lower(c), c })
	end
	return out
end

local function join(...)
	local out = {}
	for i = 1, select("#", ...) do
		for _, v in ipairs((select(i, ...))) do
			table.insert(out, v)
		end
	end
	return out
end

local DIGITS = {}
for c in string.gmatch("1234567890", ".") do
	table.insert(DIGITS, { c, c })
end

local MAIN = {
	{ { "escape", "Esc" }, { gap = 1 }, { "f1", "F1" }, { "f2", "F2" }, { "f3", "F3" }, { "f4", "F4" }, { gap = 0.5 },
		{ "f5", "F5" }, { "f6", "F6" }, { "f7", "F7" }, { "f8", "F8" }, { gap = 0.5 },
		{ "f9", "F9" }, { "f10", "F10" }, { "f11", "F11" }, { "f12", "F12" } },
	join({ { "grave", "`" } }, DIGITS, { { "minus", "-" }, { "equal", "=" }, { "backspace", "Bksp", 2 } }),
	join({ { "tab", "Tab", 1.5 } }, letters("QWERTYUIOP"), { { "bracketleft", "[" }, { "bracketright", "]" }, { "backslash", "\\", 1.5 } }),
	join({ { "caps", "Caps", 1.75 } }, letters("ASDFGHJKL"), { { "semicolon", ";" }, { "apostrophe", "'" }, { "return", "Enter", 2.25 } }),
	join({ { "shift_l", "Shift", 2.25 } }, letters("ZXCVBNM"), { { "comma", "," }, { "period", "." }, { "slash", "/" }, { "shift_r", "Shift", 2.75 } }),
	{ { "ctrl_l", "Ctrl", 1.25 }, { "super_l", "Super", 1.25 }, { "alt_l", "Alt", 1.25 }, { "space", "Space", 6.25 },
		{ "alt_r", "Alt", 1.25 }, { "fn", "Fn", 1.25 }, { "menu", "Menu", 1.25 }, { "ctrl_r", "Ctrl", 1.25 } },
}
local NAV = {
	{ { "print", "PrtSc" }, { "scroll", "ScrLk" }, { "pause", "Pause" } },
	{ { "insert", "Ins" }, { "home", "Home" }, { "pgup", "PgUp" } },
	{ { "delete", "Del" }, { "end", "End" }, { "pgdn", "PgDn" } },
	{ { gap = 3 } },
	{ { gap = 1 }, { "up", "↑" } },
	{ { "left", "←" }, { "down", "↓" }, { "right", "→" } },
}
local NUMPAD_LEFT = {
	{ { "numlock", "Num" }, { "kp_divide", "/" }, { "kp_multiply", "*" } },
	{ { "kp_7", "7" }, { "kp_8", "8" }, { "kp_9", "9" } },
	{ { "kp_4", "4" }, { "kp_5", "5" }, { "kp_6", "6" } },
	{ { "kp_1", "1" }, { "kp_2", "2" }, { "kp_3", "3" } },
	{ { "kp_0", "0", 2 }, { "kp_decimal", "." } },
}
local NUMPAD_RIGHT = { { "kp_subtract", "−" }, { "kp_add", "+", 1, 2 }, { "kp_enter", "Ent", 1, 2 } }
local MOUSE = { { "lmb", "Left" }, { "rmb", "Right" }, { "wheel_up", "Wheel ↑" }, { "wheel_down", "Wheel ↓" } }
local MEDIA = {
	{ "xf86audiolowervolume", "Vol −" }, { "xf86audioraisevolume", "Vol +" }, { "xf86audiomute", "Mute" },
	{ "xf86audiomicmute", "Mic" }, { "xf86audioprev", "Prev" }, { "xf86audioplay", "Play" },
	{ "xf86audiopause", "Pause" }, { "xf86audionext", "Next" }, { "xf86eject", "Eject" },
	{ "xf86monbrightnessdown", "Bri −" }, { "xf86monbrightnessup", "Bri +" }, { "xf86kbdbrightnessdown", "Kbd −" },
	{ "xf86kbdbrightnessup", "Kbd +" }, { "xf86kbdlightonoff", "Kbd" }, { "xf86calculator", "Calc" },
	{ "xf86poweroff", "Power" }, { "copilot", "Copilot" },
}

local LEGEND = {} -- key id -> legend
local function collect(rows)
	for _, row in ipairs(rows) do
		for _, k in ipairs(row) do
			if k[1] then LEGEND[k[1]] = k[2] end
		end
	end
end
collect(MAIN); collect(NAV); collect(NUMPAD_LEFT); collect({ NUMPAD_RIGHT, MOUSE, MEDIA })

-- Key id -> Hyprland key name, for picking a key. The number row and keypad go
-- by keycode, like binds.lua.
local KEYNAME = {
	escape = "Escape", tab = "Tab", caps = "Caps_Lock", ["return"] = "Return", space = "Space", backspace = "BackSpace",
	menu = "Menu", left = "Left", right = "Right", up = "Up", down = "Down", insert = "Insert", delete = "Delete",
	home = "Home", ["end"] = "End", pgup = "Page_Up", pgdn = "Page_Down", print = "Print", scroll = "Scroll_Lock",
	pause = "Pause", grave = "grave", minus = "code:20", equal = "code:21", bracketleft = "bracketleft",
	bracketright = "bracketright", backslash = "backslash", semicolon = "semicolon", apostrophe = "apostrophe",
	comma = "comma", period = "period", slash = "slash", numlock = "Num_Lock", kp_divide = "code:106",
	kp_multiply = "code:63", kp_subtract = "code:82", kp_add = "code:86", kp_enter = "code:104", kp_decimal = "code:91",
	kp_0 = "code:90", kp_1 = "code:87", kp_2 = "code:88", kp_3 = "code:89", kp_4 = "code:83", kp_5 = "code:84",
	kp_6 = "code:85", kp_7 = "code:79", kp_8 = "code:80", kp_9 = "code:81",
	lmb = "mouse:272", rmb = "mouse:273", wheel_up = "mouse_up", wheel_down = "mouse_down", copilot = "code:201",
	xf86audiolowervolume = "XF86AudioLowerVolume", xf86audioraisevolume = "XF86AudioRaiseVolume",
	xf86audiomute = "XF86AudioMute", xf86audiomicmute = "XF86AudioMicMute", xf86audioprev = "XF86AudioPrev",
	xf86audioplay = "XF86AudioPlay", xf86audiopause = "XF86AudioPause", xf86audionext = "XF86AudioNext",
	xf86eject = "XF86Eject", xf86monbrightnessdown = "XF86MonBrightnessDown", xf86monbrightnessup = "XF86MonBrightnessUp",
	xf86kbdbrightnessdown = "XF86KbdBrightnessDown", xf86kbdbrightnessup = "XF86KbdBrightnessUp",
	xf86kbdlightonoff = "XF86KbdLightOnOff", xf86calculator = "XF86Calculator", xf86poweroff = "XF86PowerOff",
}
for c in string.gmatch("abcdefghijklmnopqrstuvwxyz", ".") do
	KEYNAME[c] = string.upper(c)
end
for d = 0, 9 do
	KEYNAME[tostring(d)] = "code:" .. (d == 0 and 19 or 9 + d)
end
for f = 1, 12 do
	KEYNAME["f" .. f] = "F" .. f
end

local KEYID = {} -- Hyprland key name (lowercased) -> key id
for id, name in pairs(KEYNAME) do
	KEYID[string.lower(name)] = id
end

local KEYLABEL = {
	["code:82"] = "Keypad −", ["code:86"] = "Keypad +", ["mouse:272"] = "Left drag", ["mouse:273"] = "Right drag",
	mouse_up = "Scroll ↑", mouse_down = "Scroll ↓", XF86MonBrightnessUp = "Bright +", XF86MonBrightnessDown = "Bright −",
	XF86KbdLightOnOff = "Kbd light", XF86AudioMicMute = "Mic mute", XF86Calculator = "Calculator",
}

local function keyId(k)
	return KEYID[string.lower(k)] or string.lower(k)
end

local function keyLabel(k)
	if KEYLABEL[k] then return KEYLABEL[k] end
	local id = keyId(k)
	local legend = LEGEND[id]
	if not legend then return k end
	if string.sub(id, 1, 3) == "kp_" then return "Keypad " .. legend end
	return legend
end

local function canon(s)
	local present = {}
	for word in string.gmatch(s or "", "[^%s+]+") do
		local m = string.upper(word)
		if m == "CONTROL" then m = "CTRL" end
		present[m] = true
	end
	local out = {}
	for _, m in ipairs(ORDER) do
		if present[m] then table.insert(out, m) end
	end
	return table.concat(out, " ")
end

local function layerName(l)
	if l == "" then return "No modifier" end
	local out = {}
	for m in string.gmatch(l, "%S+") do
		table.insert(out, MODNAME[m])
	end
	return table.concat(out, " + ")
end

-- Same comparison as normalize_keys() in binds.lua
local function normKeys(keys)
	local parts = {}
	for p in string.gmatch(keys, "[^+]+") do
		table.insert(parts, noctalia.string.trim(p))
	end
	local key = string.lower(table.remove(parts) or "")
	local mods = canon(table.concat(parts, " "))
	return mods == "" and key or (string.gsub(mods, " ", " + ")) .. " + " .. key
end

-- ---- State ----

local overrides, warnings, stale = {}, {}, {}
local binds, byId, byLayerId, layerCount, layers = {}, {}, {}, {}, {}
local mods = { SUPER = true }
local sel = "1"
local query = ""
local searchRev = 0
local editing = nil
local editRev = 0
local status = nil
local statusUntil = 0
local loaded = false
local busy = false
local canEdit = false -- the config loads the keymap hook
local dataMode = "lua" -- "lua", or "hyprctl" when there's no Lua config

local render, capClicked, selectBind, setLayer, openEditor, saveEditor, post, load

local function currentLayer()
	local out = {}
	for _, m in ipairs(ORDER) do
		if mods[m] then table.insert(out, m) end
	end
	return table.concat(out, " ")
end

local function setStatus(text, kind)
	status = text and { text = text, kind = kind } or nil
	statusUntil = kind == "ok" and noctalia.nowMs() + 4000 or 0
	panel.setWantsSecondTicks(statusUntil > 0)
end

local function setData(d)
	canEdit = d.hook == true
	dataMode = d.mode or "lua"
	overrides = d.overrides or {}
	warnings = d.warnings or {}
	stale = d.stale or {}
	binds, byId, byLayerId, layerCount, layers = {}, {}, {}, {}, {}
	for i, b in ipairs(d.rows or {}) do
		b.i = i
		b.layer = canon(b.mods)
		b.id = keyId(b.key)
		b.label = keyLabel(b.key)
		b.active = b.state ~= "disabled"
		b.text = string.lower(table.concat({ layerName(b.layer), b.label, b.key, b.short or "", b.desc or "", b.cmd or "", b.section or "", STATES[b.state] or "" }, " "))
		table.insert(binds, b)
		byId[b.id] = byId[b.id] or {}
		table.insert(byId[b.id], b)
		if b.active then
			local k = b.layer .. "|" .. b.id
			if not byLayerId[k] then byLayerId[k] = b end -- first bind wins the keycap label
			layerCount[b.layer] = (layerCount[b.layer] or 0) + 1
		end
	end
	for _, l in ipairs(LAYER_ORDER) do
		if layerCount[l] then table.insert(layers, l) end
	end
	loaded = true
end

local function hasActive(id)
	for _, b in ipairs(byId[id] or {}) do
		if b.active then return true end
	end
	return false
end

local function layerIndex(l)
	for i, x in ipairs(layers) do
		if x == l then return i end
	end
	return 999
end

-- ---- Small pieces ----

local function kbd(text, big)
	return ui.row({ paddingH = big and 8 or 5, paddingV = big and 4 or 1, radius = 5, fill = "surface_variant", border = "outline", borderWidth = 1 }, {
		ui.label({ text = text, fontSize = big and 14 or 11 }),
	})
end

local function combo(layer, label, big, width)
	local chips = {}
	for m in string.gmatch(layer, "%S+") do
		table.insert(chips, kbd(MODNAME[m], big))
	end
	table.insert(chips, kbd(label, big))
	return ui.row({ gap = 4, align = "center", width = width }, chips)
end

local function chip(text, color)
	return ui.row({ paddingH = 6, paddingV = 1, radius = 8, fill = color .. "/0.18" }, {
		ui.label({ text = text, fontSize = 10, color = color }),
	})
end

local function stateChip(b)
	if not STATES[b.state] then return nil end
	return chip(STATES[b.state], b.state == "disabled" and "error" or "secondary")
end

local function small(text, color)
	return ui.label({ text = text, fontSize = 11, color = color or "on_surface_variant" })
end

local function nodes(...)
	local out = {}
	for i = 1, select("#", ...) do
		local v = select(i, ...)
		if v then table.insert(out, v) end
	end
	return out
end

-- ---- Keyboard ----

-- Empty space in the keyboard layout (a box without a fill would paint black)
local function space(w, h)
	return ui.box({ width = w, height = h, fill = "#00000000" })
end

local function cap(k, layer)
	local id, legend, w, h = k[1], k[2], k[3] or 1, k[4] or 1
	local cur = byLayerId[layer .. "|" .. id]
	local mod = MODKEY[id]
	local on = mod ~= nil and mods[mod] == true
	local selected = id == sel
	local fill, border, text = "surface_variant/0.5", "outline", "on_surface_variant"
	if on then
		fill, border, text = "secondary", "secondary", "on_secondary"
	elseif cur then
		fill, border, text = "primary/0.32", "primary", "on_surface"
	end
	if selected then border = "secondary" end
	local head = { ui.label({ text = legend, fontSize = k.small and 9 or 10, color = text, maxLines = 1, flexGrow = 1 }) }
	if not cur and not mod and hasActive(id) then
		table.insert(head, ui.box({ width = 4, height = 4, radius = 2, fill = "on_surface_variant/0.8" }))
	end
	local children = { ui.row({ gap = 2, align = "start" }, head) }
	if cur then
		table.insert(children, ui.label({ text = cur.short, fontSize = 8.5, color = "secondary", maxLines = 1, maxWidth = w * U - GAP - 8 }))
	end
	return ui.column({
		key = "cap-" .. id, width = w * U - GAP, height = h * U - GAP, padding = 4, gap = 1,
		fill = fill, radius = 6, border = border, borderWidth = selected and 2 or 1,
		onClick = function() capClicked(id) end,
	}, children)
end

local function capRow(keys, layer)
	local children = {}
	for _, k in ipairs(keys) do
		if k.gap then
			table.insert(children, space(k.gap * U - GAP, U - GAP))
		else
			table.insert(children, cap(k, layer))
		end
	end
	return ui.row({ gap = GAP, align = "start" }, children)
end

local function block(rows, layer, key)
	local children = {}
	for i, row in ipairs(rows) do
		table.insert(children, capRow(row, layer))
		if i == 1 then table.insert(children, space(1, U * 0.25 - GAP)) end
	end
	return ui.column({ key = key, gap = GAP, align = "start" }, children)
end

local function keyboard(layer)
	local left = {}
	for _, row in ipairs(NUMPAD_LEFT) do
		table.insert(left, capRow(row, layer))
	end
	local right = {}
	for _, k in ipairs(NUMPAD_RIGHT) do
		table.insert(right, cap(k, layer))
	end
	local numpad = ui.column({ key = "numpad", gap = GAP, align = "start" }, {
		space(4 * U - GAP, U - GAP),
		space(1, U * 0.25 - GAP),
		ui.row({ gap = GAP, align = "start" }, {
			ui.column({ gap = GAP, align = "start" }, left),
			ui.column({ gap = GAP, align = "start" }, right),
		}),
	})
	return ui.row({ key = "keyboard", justify = "center" }, {
		ui.row({ gap = 0, align = "start" }, {
			block(MAIN, layer, "main"),
			space(U * 0.5 + GAP, 1),
			block(NAV, layer, "nav"),
			space(U * 0.5 + GAP, 1),
			numpad,
		}),
	})
end

local function specialKeys(layer)
	local children = {}
	for _, k in ipairs(MOUSE) do
		table.insert(children, cap({ k[1], k[2], 1.25, small = true }, layer))
	end
	table.insert(children, space(12, 1))
	for _, k in ipairs(MEDIA) do
		table.insert(children, cap({ k[1], k[2], 1.2, small = true }, layer))
	end
	return ui.row({ key = "special", justify = "center" }, { ui.row({ gap = GAP, align = "center" }, children) })
end

-- ---- Header and layers ----

local function header(layer)
	local n = layerCount[layer] or 0
	local summary = n > 0 and (layerName(layer) .. " · " .. n .. " binds") or ("Nothing bound to " .. layerName(layer))
	return ui.row({ key = "header", gap = 10, align = "center" }, nodes(
		ui.glyph({ name = "keyboard", size = 22, color = "secondary" }),
		ui.label({ text = "Keymap", fontSize = 18, fontWeight = "bold" }),
		ui.label({ text = summary, fontSize = 12, color = "on_surface_variant" }),
		status and ui.label({ text = status.text, fontSize = 12, color = status.kind == "err" and "error" or "secondary", maxLines = 1, maxWidth = 420 }) or nil,
		ui.spacer({ flexGrow = 1 }),
		ui.input({
			key = "search-" .. searchRev, value = query, placeholder = "Search (press /)", controlSize = "sm", width = 280,
			focus = searchRev > 0,
			onChange = function(v)
				query = v
				render()
			end,
		}),
		canEdit and ui.button({ text = "Add bind", glyph = "plus", controlSize = "sm", variant = "outline", onClick = function() openEditor(nil, nil) end }) or nil,
		ui.button({ glyph = "close", controlSize = "sm", variant = "ghost", tooltip = "Close (Esc)", onClick = function() panel.close() end })
	))
end

local function layerChips(layer)
	local rows, current = {}, {}
	for _, l in ipairs(layers) do
		table.insert(current, ui.button({
			key = "layer-" .. l, text = layerName(l) .. "   " .. layerCount[l], controlSize = "sm",
			variant = l == layer and "primary" or "outline", selected = l == layer,
			onClick = function() setLayer(l) end,
		}))
		if #current == 7 then
			table.insert(rows, ui.row({ gap = 6 }, current))
			current = {}
		end
	end
	if #current > 0 then table.insert(rows, ui.row({ gap = 6 }, current)) end
	return ui.column({ key = "layers", gap = 6 }, rows)
end

-- ---- Bind list ----

local function bindRow(b, layer)
	return ui.row({
		key = "row-" .. b.i, gap = 10, align = "center", paddingH = 8, paddingV = 4, radius = 6,
		fill = (b.id == sel and b.layer == layer) and "primary/0.22" or nil,
		opacity = b.active and 1 or 0.55,
		onClick = function() selectBind(b) end,
	}, nodes(
		combo(b.layer, b.label, false, 200),
		ui.label({ text = b.desc, fontSize = 13, maxLines = 1, flexGrow = 1 }),
		stateChip(b),
		ui.label({ text = b.cmd, fontSize = 11, color = "on_surface_variant", maxLines = 1, maxWidth = 250 })
	))
end

local function listPane(layer)
	local items, title = {}, nil
	local q = string.lower(noctalia.string.trim(query))
	if q ~= "" then
		for _, b in ipairs(binds) do
			if string.find(b.text, q, 1, true) then table.insert(items, b) end
		end
		title = #items == 0 and ("No binds match “" .. query .. "”") or (#items .. " result" .. (#items == 1 and "" or "s") .. " for “" .. query .. "”")
	else
		for _, b in ipairs(binds) do
			if b.layer == layer then table.insert(items, b) end
		end
		title = layerName(layer) .. (#items == 0 and ": nothing bound" or "")
	end

	local children = { small(title) }
	if #warnings > 0 then
		table.insert(children, ui.row({ key = "warnings", gap = 8, align = "center", paddingH = 8, paddingV = 6, radius = 6, fill = "error/0.14" }, nodes(
			ui.label({ text = table.concat(warnings, " "), fontSize = 12, color = "error", flexGrow = 1, maxLines = 3 }),
			(canEdit and #stale > 0) and ui.button({ text = "Remove those edits", controlSize = "sm", variant = "outline", onClick = function()
				local keep = {}
				local drop = {}
				for _, i in ipairs(stale) do drop[i + 1] = true end
				for i, o in ipairs(overrides) do
					if not drop[i] then table.insert(keep, o) end
				end
				post(keep)
			end }) or nil
		)))
	end
	local section = nil
	for _, b in ipairs(items) do
		if b.section ~= section then
			section = b.section
			table.insert(children, ui.label({ key = "sec-" .. section, text = section, fontSize = 12, fontWeight = "semibold", color = "secondary" }))
		end
		table.insert(children, bindRow(b, layer))
	end
	return ui.scroll({ key = "list", flexGrow = 1, gap = 2 }, children)
end

-- ---- Selected key and editor ----

local function copyOverrides()
	local list = {}
	for i, o in ipairs(overrides) do
		list[i] = table.clone(o)
	end
	return list
end

local function compact(list, drop)
	local out = {}
	for i, o in ipairs(list) do
		if not drop[i] then table.insert(out, o) end
	end
	return out
end

local function turnOff(b, list, drop)
	if b.state == "added" then
		drop[b.ov + 1] = true
	elseif b.ov ~= nil then
		list[b.ov + 1] = { bind = b.origin.keys, name = b.origin.description, disabled = true }
	else
		table.insert(list, { bind = b.origin.keys, name = b.origin.description, disabled = true })
	end
end

local function withoutOverride(index)
	local list = {}
	for i, o in ipairs(overrides) do
		if i ~= index then table.insert(list, o) end
	end
	return list
end

local function detailPane(layer)
	local list = {}
	for _, b in ipairs(byId[sel] or {}) do
		table.insert(list, b)
	end
	table.sort(list, function(a, b)
		if layerIndex(a.layer) ~= layerIndex(b.layer) then return layerIndex(a.layer) < layerIndex(b.layer) end
		return a.i < b.i
	end)
	local name = list[1] and list[1].label or LEGEND[sel] or sel
	local rows = {}
	for _, b in ipairs(list) do
		table.insert(rows, ui.row({
			key = "d-" .. b.i, gap = 8, align = "center", paddingH = 8, paddingV = 5, radius = 6,
			fill = (b.active and b.layer == layer) and "primary/0.22" or nil, opacity = b.active and 1 or 0.55,
		}, nodes(
			combo(b.layer, b.label, false),
			ui.label({ text = b.desc, fontSize = 12, maxLines = 2, flexGrow = 1 }),
			stateChip(b),
			-- Binds made before the hook loaded have no origin and can't be edited
			(canEdit and (b.origin ~= nil or b.state == "added")) and ui.button({
				text = b.active and "Edit" or "Turn on", controlSize = "sm", variant = "outline", enabled = not busy,
				onClick = function()
					if b.active then openEditor(b, nil) else post(withoutOverride(b.ov + 1)) end
				end,
			}) or nil
		)))
	end
	if #rows == 0 then
		table.insert(rows, small("Keys with a dot are bound on another layer. Pick a lit key to see its binds."))
	end
	local byKeycode = false
	for _, b in ipairs(list) do
		if string.match(b.key, "^code:") then byKeycode = true end
	end
	local readOnly = nil
	if not canEdit then
		readOnly = dataMode == "hyprctl"
			and "Read-only: these binds come from hyprctl. Editing needs a Lua Hyprland config with the keymap hook."
			or "Read-only: add the keymap hook to your Hyprland config to edit binds (see the plugin README)."
	end
	return nodes(
		small("SELECTED KEY"),
		ui.row({ gap = 10, align = "center" }, {
			ui.label({ text = name, fontSize = 22, fontWeight = "bold" }),
			small(#list == 0 and "Nothing bound" or (#list .. " bind" .. (#list == 1 and "" or "s"))),
		}),
		byKeycode and small("Bound by keycode, so it works the same on any keyboard layout.") or nil,
		ui.scroll({ key = "detail-list", flexGrow = 1, gap = 2 }, rows),
		readOnly and ui.label({ text = readOnly, fontSize = 11, color = "on_surface_variant", maxLines = 3 }) or nil,
		(canEdit and KEYNAME[sel]) and ui.button({ text = "Add a bind on this key", glyph = "plus", controlSize = "sm", variant = "outline", onClick = function() openEditor(nil, sel) end }) or nil
	)
end

-- Keys that type or edit text; binding one without a modifier takes it from every app
local function typesText(key)
	if string.match(key, "^F%d+$") or string.match(key, "^XF86") or key == "Print" or string.match(key, "^mouse") then
		return false
	end
	local code = tonumber(string.match(key, "^code:(%d+)$"))
	if code and (code == 63 or (code >= 79 and code <= 91) or code == 104 or code == 106 or code == 201) then
		return false -- keypad and Copilot keys
	end
	return true
end

local function editorConflicts(layer)
	local e = editing
	if not e.key then return {} end
	local t = e.target
	if t and t.layer == layer and t.id == e.keyId then return {} end
	local out = {}
	for _, b in ipairs(byId[e.keyId] or {}) do
		if b.active and b.layer == layer and b ~= t then table.insert(out, b) end
	end
	return out
end

local function editorPane(layer)
	local e = editing
	local t = e.target
	local fromBinds = t ~= nil and t.state ~= "added"
	e.conflicts = editorConflicts(layer)

	local shortcut
	if e.key then
		shortcut = combo(layer, keyLabel(e.key), true)
	else
		local chips = {}
		for m in string.gmatch(layer, "%S+") do table.insert(chips, kbd(MODNAME[m], true)) end
		table.insert(chips, small("Click a key on the board"))
		shortcut = ui.row({ gap = 4, align = "center" }, chips)
	end

	local notes = {}
	if e.keyId and not e.key then
		table.insert(notes, small("That key can't be bound. Pick another.", "error"))
	elseif #e.conflicts > 0 then
		local names = {}
		for _, b in ipairs(e.conflicts) do table.insert(names, "“" .. b.desc .. "”") end
		table.insert(notes, ui.label({ text = "Already used by " .. table.concat(names, " and ") .. ".", fontSize = 12, color = "error", maxLines = 3 }))
		table.insert(notes, ui.row({ gap = 8, align = "center" }, {
			ui.toggle({ checked = e.replace, onChange = function(v) e.replace = v == "true"; render() end }),
			small("Turn " .. (#e.conflicts > 1 and "those binds" or "that bind") .. " off when saving", "on_surface"),
		}))
	elseif t and e.key and t.layer == layer and t.id == e.keyId then
		table.insert(notes, small("This is its current shortcut.", "on_surface_variant"))
	elseif e.key then
		table.insert(notes, small("Free on this layer.", "secondary"))
	end
	if e.key and layer == "" and typesText(e.key) then
		table.insert(notes, small("Without a modifier, this key stops working for typing in every app.", "error"))
	end

	local useCommand = not fromBinds or e.mode == "command"
	local children = nodes(
		small(t and "EDIT BIND" or "NEW BIND"),
		shortcut,
		small("Pick modifiers with the layer buttons or the modifier keys, then click a key. Unlit keys are free on that layer."),
		#notes > 0 and ui.column({ gap = 4 }, notes) or nil,
		small("Description", "on_surface"),
		ui.input({ key = "ed-desc-" .. editRev, value = e.desc, placeholder = "Open htop", controlSize = "sm", onChange = function(v) e.desc = v end, onSubmit = function(v) e.desc = v; saveEditor() end }),
		fromBinds and ui.row({ gap = 8, align = "center" }, {
			ui.toggle({ checked = e.mode == "command", onChange = function(v) e.mode = v == "true" and "command" or "keep"; render() end }),
			small("Run a command instead", "on_surface"),
		}) or nil,
		fromBinds and ui.label({ text = "Now: " .. t.origin.cmd, fontSize = 11, color = "on_surface_variant", maxLines = 2 }) or nil,
		useCommand and small("Command", "on_surface") or nil,
		useCommand and ui.input({ key = "ed-cmd-" .. editRev, value = e.cmd, placeholder = "uwsm app -- kitty -e htop", controlSize = "sm", onChange = function(v) e.cmd = v end, onSubmit = function(v) e.cmd = v; saveEditor() end }) or nil,
		e.error and ui.label({ text = e.error, fontSize = 12, color = "error", maxLines = 4 }) or nil,
		ui.spacer({ flexGrow = 1 }),
		ui.row({ gap = 8, align = "center" }, nodes(
			ui.button({ text = busy and "Saving…" or "Save", controlSize = "sm", variant = "primary", enabled = not busy, onClick = function() saveEditor() end }),
			ui.button({ text = "Cancel", controlSize = "sm", variant = "ghost", onClick = function() editing = nil; render() end }),
			(t and t.state == "edited") and ui.button({ text = "Reset to default", controlSize = "sm", variant = "outline", enabled = not busy, onClick = function() post(withoutOverride(t.ov + 1)) end }) or nil,
			t and ui.button({
				text = t.state == "added" and "Delete" or "Turn off", controlSize = "sm", variant = "destructive", enabled = not busy,
				onClick = function()
					local list, drop = copyOverrides(), {}
					turnOff(t, list, drop)
					post(compact(list, drop))
				end,
			}) or nil
		))
	)
	return children
end

local function sidePane(layer)
	return ui.column({ key = "side", width = 440, gap = 8, padding = 12, radius = 10, fill = "surface_variant/0.45" },
		editing and editorPane(layer) or detailPane(layer))
end

-- ---- Actions ----

function setLayer(l)
	mods = {}
	for m in string.gmatch(l, "%S+") do
		mods[m] = true
	end
	render()
end

function capClicked(id)
	local mod = MODKEY[id]
	if mod then
		mods[mod] = not mods[mod] or nil
	elseif editing then
		editing.keyId = id
		editing.key = KEYNAME[id]
		sel = id
	else
		sel = id
	end
	render()
end

function selectBind(b)
	if editing then
		setStatus("Save or cancel the bind you're editing first.", "err")
		return render()
	end
	mods = {}
	for m in string.gmatch(b.layer, "%S+") do
		mods[m] = true
	end
	sel = b.id
	render()
end

function openEditor(target, newKey)
	editRev += 1
	local ov = (target and target.ov ~= nil) and overrides[target.ov + 1] or nil
	local fromBinds = target ~= nil and target.state ~= "added"
	editing = {
		target = target,
		keyId = target and target.id or newKey,
		key = target and target.key or (newKey and KEYNAME[newKey]) or nil,
		desc = target and target.desc or "",
		mode = (not fromBinds or (ov and ov.command)) and "command" or "keep",
		cmd = (ov and ov.command) or ((target and target.exec) and target.cmd) or "",
		replace = true,
		conflicts = {},
	}
	if target then
		mods = {}
		for m in string.gmatch(target.layer, "%S+") do
			mods[m] = true
		end
		sel = target.id
	elseif newKey then
		sel = newKey
	end
	render()
end

function saveEditor()
	local e = editing
	if not e or busy then return end
	local t = e.target
	local layer = currentLayer()
	local function fail(msg)
		e.error = msg
		render()
	end
	if not e.key then return fail("Pick a key on the board.") end
	local keys = (layer == "" and "" or (string.gsub(layer, " ", " + ")) .. " + ") .. e.key
	local desc = noctalia.string.trim(e.desc or "")
	local cmd = noctalia.string.trim(e.cmd or "")
	local useCommand = t == nil or t.state == "added" or e.mode == "command"
	if desc == "" then return fail("Add a description.") end
	if useCommand and cmd == "" then return fail("Add the command to run.") end

	local list, drop = copyOverrides(), {}
	if not t then
		table.insert(list, { keys = keys, description = desc, command = cmd })
	elseif t.state == "added" then
		list[t.ov + 1] = { keys = keys, description = desc, command = cmd }
	else
		local o = { bind = t.origin.keys, name = t.origin.description }
		if normKeys(keys) ~= normKeys(t.origin.keys) then o.keys = keys end
		if desc ~= t.origin.description then o.description = desc end
		if useCommand then o.command = cmd end
		local changed = o.keys ~= nil or o.description ~= nil or o.command ~= nil
		if t.ov ~= nil then
			if changed then list[t.ov + 1] = o else drop[t.ov + 1] = true end
		elseif changed then
			table.insert(list, o)
		else
			editing = nil
			return render()
		end
	end
	if e.replace then
		for _, b in ipairs(e.conflicts or {}) do
			turnOff(b, list, drop)
		end
	end
	post(compact(list, drop))
end

function post(list)
	if busy then return end
	busy = true
	setStatus("Saving…")
	render()
	local payload = noctalia.json.encode(list) or "[]"
	noctalia.runAsync({ "python3", PLUGIN_DIR .. "/backend/save.py", configPath(), payload }, function(res)
		busy = false
		local out = (res.exitCode == 0 and res.stdout ~= "") and noctalia.json.decode(res.stdout) or nil
		if out and out.ok then
			editing = nil
			setData(out.data)
			setStatus("Saved. Hyprland reloaded.", "ok")
		else
			local msg = (out and out.error) or (res.stderr ~= "" and res.stderr) or "Not saved."
			if editing then editing.error = msg end
			setStatus(msg, "err")
		end
		render()
	end, 30000)
end

-- Without a Lua config, read the live binds from hyprctl (read-only)
local MODBITS = { { 64, "SUPER" }, { 4, "CTRL" }, { 8, "ALT" }, { 1, "SHIFT" } }

local function shortFrom(desc)
	local out = ""
	for word in string.gmatch(desc, "%S+") do
		if #out + #word + 1 > 11 then break end
		out = out == "" and word or out .. " " .. word
	end
	return out ~= "" and out or string.sub(desc, 1, 10)
end

local function loadFromHyprctl()
	noctalia.runAsync({ "hyprctl", "binds", "-j" }, function(res)
		local list = res.exitCode == 0 and noctalia.json.decode(res.stdout) or nil
		if type(list) ~= "table" then
			setStatus("Couldn't read binds from hyprctl.", "err")
			return render()
		end
		local rows = {}
		for _, b in ipairs(list) do
			local mods = {}
			for _, bit in ipairs(MODBITS) do
				if math.floor((b.modmask or 0) / bit[1]) % 2 == 1 then table.insert(mods, bit[2]) end
			end
			local key = (b.key ~= nil and b.key ~= "") and b.key or ("code:" .. tostring(b.keycode or 0))
			local cmd = tostring(b.dispatcher or "") .. ((b.arg and b.arg ~= "") and (" " .. b.arg) or "")
			local desc = (b.has_description and b.description ~= "") and b.description or cmd
			local keys = table.concat(mods, " + ")
			table.insert(rows, {
				section = "Binds", group = "Binds", mods = table.concat(mods, " "), key = key,
				keys = keys == "" and key or keys .. " + " .. key,
				short = shortFrom(desc), desc = desc, cmd = cmd, exec = b.dispatcher == "exec",
				flags = (b["repeat"] and "r" or "") .. (b.locked and "l" or ""), state = "default",
			})
		end
		setData({ mode = "hyprctl", rows = rows })
		render()
	end, 10000)
end

function load()
	noctalia.runAsync({ "lua", PLUGIN_DIR .. "/backend/gen.lua", configPath() }, function(res)
		local d, err = nil, nil
		if res.exitCode == 0 and not res.stdoutTruncated then
			d, err = noctalia.json.decode(res.stdout)
		else
			err = res.stdoutTruncated and "bind data too large" or res.stderr
		end
		if d and d.mode == "none" then
			return loadFromHyprctl()
		elseif d then
			setData(d)
		else
			setStatus("Couldn't read your binds: " .. tostring(err), "err")
		end
		render()
	end, 15000)
end

function render()
	local layer = currentLayer()
	local children = { header(layer), layerChips(layer) }
	if loaded then
		table.insert(children, keyboard(layer))
		table.insert(children, specialKeys(layer))
		table.insert(children, ui.row({ key = "bottom", gap = 14, flexGrow = 1, align = "stretch" }, { listPane(layer), sidePane(layer) }))
	else
		table.insert(children, small("Loading your binds…"))
	end
	panel.render(ui.column({ key = "root", padding = 16, gap = 10, flexGrow = 1, align = "stretch" }, children))
end

-- ---- Host callbacks ----

function onOpen(_context)
	query = ""
	searchRev = 0
	if status and status.kind ~= "err" then setStatus(nil) end
	render()
	load()
end

function onKey(chord, pressed)
	if chord == "slash" and pressed then
		searchRev += 1
		render()
	end
end

function update()
	if statusUntil > 0 and noctalia.nowMs() > statusUntil then
		setStatus(nil)
		render()
	end
end
