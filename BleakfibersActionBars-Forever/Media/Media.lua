local addonName, BAB = ...

local LSM = LibStub and LibStub("LibSharedMedia-3.0", true)

local mediaPath = "Interface\\AddOns\\" .. addonName .. "\\Media\\"
local fontPath = mediaPath .. "Fonts\\"

-- Default Font Constants
BAB.DEFAULT_FONT_NAME = "Nata Sans Regular"
BAB.DEFAULT_FONT_PATH = fontPath .. "NataSans-Regular.ttf"

BAB.DEFAULT_HEADER_FONT_NAME = "Nata Sans Bold"
BAB.DEFAULT_HEADER_FONT_PATH = fontPath .. "NataSans-Bold.ttf"

-- Register Nata Sans Family (Primary Typography)
if LSM then
    LSM:Register("font", "Nata Sans Regular", fontPath .. "NataSans-Regular.ttf")
    LSM:Register("font", "Nata Sans Bold", fontPath .. "NataSans-Bold.ttf")
    LSM:Register("font", "Nata Sans Medium", fontPath .. "NataSans-Medium.ttf")
    LSM:Register("font", "BleakUI Regular", fontPath .. "NataSans-Regular.ttf")
    LSM:Register("font", "BleakUI Bold", fontPath .. "NataSans-Bold.ttf")
end

if LSM then
    -- Register Orbitron Family (Futuristic / Tech Display)
    LSM:Register("font", "Orbitron Regular", fontPath .. "Orbitron-Regular.ttf")
    LSM:Register("font", "Orbitron Medium", fontPath .. "Orbitron-Medium.ttf")
    LSM:Register("font", "Orbitron Bold", fontPath .. "Orbitron-Bold.ttf")

    -- Register Roboto Condensed Family (Compact Sans-Serif)
    LSM:Register("font", "Roboto Condensed Regular", fontPath .. "RobotoCondensed-Regular.ttf")
    LSM:Register("font", "Roboto Condensed Medium", fontPath .. "RobotoCondensed-Medium.ttf")
    LSM:Register("font", "Roboto Condensed Bold", fontPath .. "RobotoCondensed-Bold.ttf")

    -- Register Status Bar Textures
    LSM:Register("statusbar", "BleakFlat", "Interface\\Buttons\\WHITE8x8")
    LSM:Register("statusbar", "Blizzard", "Interface\\TargetingFrame\\UI-StatusBar")
    LSM:Register("statusbar", "Blizzard Raid", "Interface\\RaidFrame\\Raid-Bar-Hp-Fill")
end

-- Media Fetch Helpers with safety fallbacks
function BAB:FetchFont(fontName)
    local fallback = BAB.DEFAULT_FONT_PATH
    if not fontName or fontName == "" then
        fontName = BAB.DEFAULT_FONT_NAME
    end

    if type(fontName) == "string" and (fontName:find("%.ttf$") or fontName:find("%.otf$") or fontName:find("\\") or fontName:find("/")) then
        return fontName
    end

    if LSM then
        local font = LSM:Fetch("font", fontName, true)
        if font and font ~= "" then
            return font
        end

        local def = LSM:Fetch("font", BAB.DEFAULT_FONT_NAME, true)
        if def and def ~= "" then
            return def
        end
    end

    return fallback
end

function BAB:FetchHeaderFont(fontName)
    local fallback = BAB.DEFAULT_HEADER_FONT_PATH
    if not fontName or fontName == "" then
        fontName = BAB.DEFAULT_HEADER_FONT_NAME
    end

    if type(fontName) == "string" and (fontName:find("%.ttf$") or fontName:find("%.otf$") or fontName:find("\\") or fontName:find("/")) then
        return fontName
    end

    if LSM then
        local font = LSM:Fetch("font", fontName, true)
        if font and font ~= "" then
            return font
        end

        local def = LSM:Fetch("font", BAB.DEFAULT_HEADER_FONT_NAME, true)
        if def and def ~= "" then
            return def
        end
    end

    return fallback
end

function BAB:FetchStatusbar(barName)
    if not barName or barName == "" then
        barName = "BleakFlat"
    end

    if LSM then
        local bar = LSM:Fetch("statusbar", barName, true)
        if bar and bar ~= "" then
            return bar
        end
    end

    return "Interface\\Buttons\\WHITE8x8"
end
