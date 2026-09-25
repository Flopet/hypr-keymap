-- Keymap hook for the Hyprland Keymap Noctalia plugin (flopet/hypr-keymap).
--
-- Lets the keymap panel move, change, turn off and add binds without rewriting
-- your config: edits are kept in keymap-overrides.lua next to this file and
-- applied on top of your binds each time Hyprland loads its config.
--
-- Setup: copy this file to ~/.config/hypr/keymap.lua, then in hyprland.lua add
--
--   local keymap = require("keymap")   -- first line, before any binds
--   keymap.apply()                      -- last line, after every bind
--
-- It works with any bind style (hl.bind directly, helpers, Omarchy's o.bind),
-- because it records binds by wrapping hl.bind itself.

local M = { registry = {} }

-- Same key comparison as the panel: modifiers in a fixed order, key lowercased
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

-- Edits live next to this file
local source = debug and debug.getinfo and debug.getinfo(1, "S").source or ""
local dir = source:match("^@(.*)/[^/]*$") or ((os.getenv("HOME") or "") .. "/.config/hypr")
M.overrides_path = dir .. "/keymap-overrides.lua"

-- Hyprland starts a fresh Lua state on every config reload, so these are always
-- the originals
local real_bind, real_unbind = hl.bind, hl.unbind

hl.bind = function(keys, action, opts)
	local handle = real_bind(keys, action, opts)
	table.insert(M.registry, {
		keys = keys, action = action, opts = opts or {}, handle = handle,
		description = opts and (opts.description or opts.desc),
	})
	return handle
end

hl.unbind = function(keys)
	local want = normalize(keys)
	for _, e in ipairs(M.registry) do
		if normalize(e.keys) == want then e.unbound = true end
	end
	return real_unbind(keys)
end

-- Applies keymap-overrides.lua. Each entry either changes a recorded bind, found
-- by its keys (bind) and description (name, left out when the bind has none), or
-- adds a new one. An entry that no longer matches anything is skipped; the panel
-- lists it so it can be removed.
function M.apply()
	M.applied = {}
	local file = io.open(M.overrides_path, "r")
	if not file then return M.applied end
	file:close()

	local ok, overrides = pcall(dofile, M.overrides_path)
	if not ok or type(overrides) ~= "table" then
		pcall(hl.notification.create, { text = "Keymap edits not loaded: " .. tostring(overrides), timeout = 8000 })
		return M.applied
	end

	for index, o in ipairs(overrides) do
		local result = { index = index, override = o }
		table.insert(M.applied, result)

		local entry
		if o.bind then
			for _, e in ipairs(M.registry) do
				if not e.unbound and not e.overridden and e.description == o.name and normalize(e.keys) == normalize(o.bind) then
					-- o.name is nil for a bind that has no description
					entry = e
					break
				end
			end
			result.missing = entry == nil
		end

		if entry or (not o.bind and o.keys and o.description and o.command) then
			if entry then
				entry.handle:unbind()
				entry.overridden = index
				result.entry = entry
			end
			if not o.disabled then
				local opts = {}
				if entry then
					for k, v in pairs(entry.opts) do opts[k] = v end
				end
				opts.description = o.description or entry.description
				local action = o.command and hl.dsp.exec_cmd(o.command) or entry.action
				result.keys = o.keys or entry.keys
				local bound, handle = pcall(real_bind, result.keys, action, opts)
				if bound then result.handle = handle else result.error = tostring(handle) end
			end
		end
	end
	return M.applied
end

-- The plugin reads this when it loads your config to show and edit binds
_G.hypr_keymap = M

return M
