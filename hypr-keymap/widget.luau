--!nonstrict
-- Bar button that toggles the keymap panel.

local PANEL_ID = "flopet/hypr-keymap:keymap" -- update if you change the plugin id

barWidget.setGlyph("keyboard")
barWidget.setGlyphColor("secondary") -- like the neighboring bar icons
barWidget.setTooltip("Keymap")

function onClick()
	noctalia.togglePanel(PANEL_ID)
end

function onIpc(event, _payload)
	if event == "toggle" then
		noctalia.togglePanel(PANEL_ID)
	end
end
