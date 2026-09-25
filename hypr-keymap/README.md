# Hyprland Keymap

Your Hyprland binds on a keyboard map, with search and editing. See the [repository README](../README.md) for
install and setup.

| Entry | Id | What it does |
| --- | --- | --- |
| Panel | `flopet/hypr-keymap:keymap` | The keymap. `/` jumps to the search, Escape closes it. |
| Bar widget | `flopet/hypr-keymap:button` | Keyboard icon that toggles the panel. |

Editing needs the hook in `hyprland/keymap.lua`: copy it next to your `hyprland.lua`, then put
`local keymap = require("keymap")` first in that file and `keymap.apply()` last.
