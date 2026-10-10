--[[
    Bleakfiber's Action Bars - Core.lua
    Gameplay Logic: Bar Containers, Button Skinning, Layouts, Movers,
    Blizzard Art Suppression, Combat Lockdown Safety & Event Dispatching
]]

local addonName, BAB = ...
_G["BleakfibersActionBars"] = BAB

local Core = CreateFrame("Frame", "BleakfibersActionBarsCore", UIParent)
BAB.Core = Core

local Config = BAB.Config or _G["BleakfibersActionBarsConfig"]

local floor, max, min, select, pairs, ipairs = math.floor, math.max, math.min, select, pairs, ipairs
local GetOrCreatePlayerButton

-- Module constants & color palette
local C = {
    FONT_DEFAULT = "Nata Sans Regular",
    FONT_HEADER = "Nata Sans Bold",
    FONT_HEADER_SIZE = 14,
    FONT_BODY_SIZE = 12,
    BORDER_SIZE = 1,
    COLOR_BG = { r = 0.06, g = 0.06, b = 0.08, a = 0.95 },
    COLOR_BORDER = { r = 0.15, g = 0.15, b = 0.18, a = 1.00 },
    COLOR_BORDER_HIGHLIGHT = { r = 0.25, g = 0.40, b = 0.65, a = 1.00 },
    COLOR_ACCENT = { r = 0.20, g = 0.60, b = 1.00, a = 1.00 },
    COLOR_GOLD = { r = 1.00, g = 0.82, b = 0.00, a = 1.00 },
}
BAB.Constants = C

local bars = {}
local skinnedButtons = {}
local registeredMovers = {}
local moversUnlocked = false
local controlFrame = nil

local RANGE_INDICATOR = _G.RANGE_INDICATOR or "\226\128\162"

--[[-----------------------------------------------------------------------------
    1. Typography Helpers
-------------------------------------------------------------------------------]]
function BAB:FetchFont(fontName)
    fontName = fontName or C.FONT_DEFAULT
    local LSM = LibStub and LibStub("LibSharedMedia-3.0", true)
    if LSM then
        local fontPath = LSM:Fetch("font", fontName)
        if fontPath then return fontPath end
    end
    -- Fallback paths within addon Media
    if fontName:find("Bold") then
        return "Interface\\AddOns\\" .. addonName .. "\\Media\\Fonts\\NataSans-Bold.ttf"
    elseif fontName:find("Medium") then
        return "Interface\\AddOns\\" .. addonName .. "\\Media\\Fonts\\NataSans-Medium.ttf"
    end
    return "Interface\\AddOns\\" .. addonName .. "\\Media\\Fonts\\NataSans-Regular.ttf"
end

function BAB:FetchHeaderFont()
    return self:FetchFont(C.FONT_HEADER)
end

function BAB:SetFont(fontString, font, size, flags)
    if not fontString or not fontString.SetFont then return end
    local activeFont = self:FetchFont(font)
    local activeSize = size or C.FONT_BODY_SIZE
    local activeFlags = flags or "OUTLINE"

    pcall(fontString.SetFont, fontString, activeFont, activeSize, activeFlags)
    if fontString.IsObjectType and fontString:IsObjectType("FontString") then
        if not activeFlags or activeFlags == "" or activeFlags == "NONE" then
            pcall(fontString.SetShadowOffset, fontString, 1, -1)
            pcall(fontString.SetShadowColor, fontString, 0, 0, 0, 0.85)
        else
            pcall(fontString.SetShadowOffset, fontString, 0, 0)
        end
    end
end

--[[-----------------------------------------------------------------------------
    2. Pure GPU Texture Backdrops (Zero BackdropTemplate Taint)
-------------------------------------------------------------------------------]]
function BAB:CreateTextureBackdrop(frame, bgAlpha, borderAlpha, bgColor, borderColor)
    if not frame then return end
    if frame.backdrop then return frame.backdrop end

    local bgCol = bgColor or C.COLOR_BG
    local brdCol = borderColor or C.COLOR_BORDER
    local aBg = bgAlpha or (bgCol and bgCol.a) or 0.95
    local aBrd = borderAlpha or (brdCol and brdCol.a) or 1.0

    local parent = (frame.CreateTexture and frame) or (frame.GetParent and frame:GetParent()) or UIParent
    local container = CreateFrame("Frame", nil, parent)
    container:SetPoint("TOPLEFT", frame, "TOPLEFT", -C.BORDER_SIZE, C.BORDER_SIZE)
    container:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", C.BORDER_SIZE, -C.BORDER_SIZE)
    local parentLevel = (frame.GetFrameLevel and frame:GetFrameLevel()) or 1
    container:SetFrameLevel(max(0, parentLevel - 1))

    -- Center fill
    local center = container:CreateTexture(nil, "BACKGROUND", nil, -7)
    center:SetPoint("TOPLEFT", container, "TOPLEFT", C.BORDER_SIZE, -C.BORDER_SIZE)
    center:SetPoint("BOTTOMRIGHT", container, "BOTTOMRIGHT", -C.BORDER_SIZE, C.BORDER_SIZE)
    center:SetColorTexture(bgCol.r, bgCol.g, bgCol.b, aBg)

    -- 4 1-pixel border lines
    local top = container:CreateTexture(nil, "BACKGROUND", nil, -6)
    top:SetPoint("TOPLEFT", container, "TOPLEFT", 0, 0)
    top:SetPoint("TOPRIGHT", container, "TOPRIGHT", 0, 0)
    top:SetHeight(C.BORDER_SIZE)
    top:SetColorTexture(brdCol.r, brdCol.g, brdCol.b, aBrd)

    local bottom = container:CreateTexture(nil, "BACKGROUND", nil, -6)
    bottom:SetPoint("BOTTOMLEFT", container, "BOTTOMLEFT", 0, 0)
    bottom:SetPoint("BOTTOMRIGHT", container, "BOTTOMRIGHT", 0, 0)
    bottom:SetHeight(C.BORDER_SIZE)
    bottom:SetColorTexture(brdCol.r, brdCol.g, brdCol.b, aBrd)

    local left = container:CreateTexture(nil, "BACKGROUND", nil, -6)
    left:SetPoint("TOPLEFT", container, "TOPLEFT", 0, 0)
    left:SetPoint("BOTTOMLEFT", container, "BOTTOMLEFT", 0, 0)
    left:SetWidth(C.BORDER_SIZE)
    left:SetColorTexture(brdCol.r, brdCol.g, brdCol.b, aBrd)

    local right = container:CreateTexture(nil, "BACKGROUND", nil, -6)
    right:SetPoint("TOPRIGHT", container, "TOPRIGHT", 0, 0)
    right:SetPoint("BOTTOMRIGHT", container, "BOTTOMRIGHT", 0, 0)
    right:SetWidth(C.BORDER_SIZE)
    right:SetColorTexture(brdCol.r, brdCol.g, brdCol.b, aBrd)

    container.Center = center
    container.Top = top
    container.Bottom = bottom
    container.Left = left
    container.Right = right

    function container:SetBackdropColor(r, g, b, a)
        self.Center:SetColorTexture(r, g, b, a or aBg)
    end

    function container:SetBackdropBorderColor(r, g, b, a)
        local alpha = a or aBrd
        self.Top:SetColorTexture(r, g, b, alpha)
        self.Bottom:SetColorTexture(r, g, b, alpha)
        self.Left:SetColorTexture(r, g, b, alpha)
        self.Right:SetColorTexture(r, g, b, alpha)
    end

    frame.backdrop = container
    return container
end

function BAB:CreateBackdrop(frame, bgAlpha, borderAlpha, bgColor, borderColor)
    return self:CreateTextureBackdrop(frame, bgAlpha, borderAlpha, bgColor, borderColor)
end

function BAB:StripTextures(frame)
    if not frame then return end
    if frame.GetRegions then
        for i = 1, frame:GetNumRegions() do
            local region = select(i, frame:GetRegions())
            if region and region:IsObjectType("Texture") then
                region:SetTexture(nil)
            end
        end
    end
end

--[[-----------------------------------------------------------------------------
    3. HotKey Text Abbreviation
-------------------------------------------------------------------------------]]
local function FormatHotkey(text)
    if not text or text == "" then return "" end

    if text == RANGE_INDICATOR or text == "\226\128\162" or text == "·" or text == "." or text == "*" or text:find("\226\128\162", 1, true) then
        return ""
    end

    text = text:gsub("[Cc][Tt][Rr][Ll]%-", "C")
    text = text:gsub("[Ss][Hh][Ii][Ff][Tt]%-", "S")
    text = text:gsub("[Aa][Ll][Tt]%-", "A")
    text = text:gsub("[Mm][Ee][Tt][Aa]%-", "M")
    text = text:gsub("([CcSsAaMm])%-", function(m) return m:upper() end)
    text = text:gsub("Mouse Button ", "M")
    text = text:gsub("BUTTON(%d+)", "M%1")
    text = text:gsub("BUTTON", "M")
    text = text:gsub("Middle Mouse", "M3")
    text = text:gsub("MOUSEWHEELUP", "WU")
    text = text:gsub("MOUSEWHEELDOWN", "WD")
    text = text:gsub("Mouse Wheel Down", "WD")
    text = text:gsub("Mouse Wheel Up", "WU")
    text = text:gsub("CAPSLOCK", "Caps")
    text = text:gsub("Caps Lock", "Caps")
    text = text:gsub("NUMPADDECIMAL", "N.")
    text = text:gsub("NUMPADPLUS", "N+")
    text = text:gsub("NUMPADMINUS", "N-")
    text = text:gsub("NUMPADMULTIPLY", "N*")
    text = text:gsub("NUMPADDIVIDE", "N/")
    text = text:gsub("NUMPAD(%d+)", "N%1")
    text = text:gsub("Num Pad (%d+)", "N%1")
    text = text:gsub("Num Pad %+", "N+")
    text = text:gsub("Num Pad %-", "N-")
    text = text:gsub("Spacebar", "Spc")
    text = text:gsub("SPACE", "Spc")
    text = text:gsub("Backspace", "BS")
    text = text:gsub("Delete", "Del")
    text = text:gsub("Insert", "Ins")
    text = text:gsub("Home", "Hm")
    text = text:gsub("End", "End")
    text = text:gsub("Page Up", "PU")
    text = text:gsub("Page Down", "PD")

    if text == RANGE_INDICATOR or text == "\226\128\162" or text == "·" or text == "." or text == "*" or text:trim() == "" then
        return ""
    end

    return text
end

--[[-----------------------------------------------------------------------------
    4. Mover Drag & Position Storage System
-------------------------------------------------------------------------------]]
local function EnsureMoverControlFrame()
    if controlFrame then return controlFrame end

    controlFrame = CreateFrame("Frame", "BleakfibersActionBars_MoverControlFrame", UIParent)
    controlFrame:SetSize(280, 50)
    controlFrame:SetPoint("TOP", UIParent, "TOP", 0, -24)
    controlFrame:SetFrameStrata("DIALOG")
    controlFrame:SetMovable(true)
    controlFrame:EnableMouse(true)
    controlFrame:RegisterForDrag("LeftButton")
    controlFrame:SetScript("OnDragStart", function(self) self:StartMoving() end)
    controlFrame:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
    controlFrame:SetClampedToScreen(true)
    controlFrame:SetScript("OnShow", function(self)
        local isBAC = (_G["BleakfibersAddonConfigForever"] ~= nil or _G["BleakfibersAddonConfig"] ~= nil)
        if isBAC then
            self:Hide()
        end
    end)

    BAB:CreateBackdrop(controlFrame, 0.85, 1.0, C.COLOR_BG, C.COLOR_ACCENT)

    local title = controlFrame:CreateFontString(nil, "OVERLAY")
    BAB:SetFont(title, BAB:FetchHeaderFont(), 12, "OUTLINE")
    title:SetPoint("TOP", controlFrame, "TOP", 0, -8)
    title:SetText("Action Bars: Positioning Mode")
    title:SetTextColor(C.COLOR_GOLD.r, C.COLOR_GOLD.g, C.COLOR_GOLD.b)

    local lockBtn = CreateFrame("Button", nil, controlFrame)
    lockBtn:SetSize(110, 22)
    lockBtn:SetPoint("BOTTOMLEFT", controlFrame, "BOTTOMLEFT", 12, 6)
    BAB:CreateBackdrop(lockBtn, 0.85, 1.0, C.COLOR_BG, C.COLOR_BORDER)
    local lockText = lockBtn:CreateFontString(nil, "OVERLAY")
    BAB:SetFont(lockText, BAB:FetchFont(), 11, "OUTLINE")
    lockText:SetPoint("CENTER")
    lockText:SetText("Lock Bars")
    lockBtn:SetScript("OnClick", function()
        Core:ToggleMovers(false)
    end)

    local resetBtn = CreateFrame("Button", nil, controlFrame)
    resetBtn:SetSize(110, 22)
    resetBtn:SetPoint("BOTTOMRIGHT", controlFrame, "BOTTOMRIGHT", -12, 6)
    BAB:CreateBackdrop(resetBtn, 0.85, 1.0, C.COLOR_BG, C.COLOR_BORDER)
    local resetText = resetBtn:CreateFontString(nil, "OVERLAY")
    BAB:SetFont(resetText, BAB:FetchFont(), 11, "OUTLINE")
    resetText:SetPoint("CENTER")
    resetText:SetText("Reset Defaults")
    resetBtn:SetScript("OnClick", function()
        Core:ResetMovers()
    end)

    controlFrame:Hide()
    return controlFrame
end

local function CreateMoverOverlay(moverData)
    local target = moverData.frame
    local key = moverData.key

    local overlay = CreateFrame("Frame", "BleakfibersActionBars_Mover_" .. key, UIParent)
    overlay:SetFrameStrata("DIALOG")
    overlay:SetClampedToScreen(true)
    overlay:SetMovable(true)
    overlay:EnableMouse(true)
    overlay:RegisterForDrag("LeftButton")

    BAB:CreateBackdrop(overlay, 0.60, 1.0, C.COLOR_BG, C.COLOR_ACCENT)

    local label = overlay:CreateFontString(nil, "OVERLAY")
    BAB:SetFont(label, BAB:FetchHeaderFont(), 11, "OUTLINE")
    label:SetPoint("CENTER")
    label:SetText(moverData.displayName)
    label:SetTextColor(1, 1, 1, 1)

    overlay:SetScript("OnDragStart", function(self)
        self:StartMoving()
    end)

    overlay:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local point, _, relPoint, x, y = self:GetPoint()
        relPoint = relPoint or point
        Core:SaveMoverPosition(key, point, x, y, relPoint)
        target:ClearAllPoints()
        target:SetPoint(point, UIParent, relPoint, x, y)
    end)

    overlay:Hide()
    moverData.overlay = overlay
    target._moverOverlay = overlay
    return overlay
end

function Core:RegisterMover(frame, displayName, key, defaultPoint, defaultX, defaultY, defaultRelPoint)
    if not frame or not key then return end

    registeredMovers[key] = {
        frame = frame,
        displayName = displayName or key,
        key = key,
        defaultPoint = defaultPoint or "CENTER",
        defaultRelPoint = defaultRelPoint or defaultPoint or "CENTER",
        defaultX = defaultX or 0,
        defaultY = defaultY or 0,
    }

    self:ApplyMoverPosition(key, frame)
end

function Core:SaveMoverPosition(key, point, x, y, relPoint)
    if not BleakfibersActionBarsDB then return end
    if not BleakfibersActionBarsDB.movers then
        BleakfibersActionBarsDB.movers = {}
    end
    relPoint = relPoint or point
    BleakfibersActionBarsDB.movers[key] = {
        point = point,
        relPoint = relPoint,
        x = floor(x + 0.5),
        y = floor(y + 0.5),
    }

    local activeProf = Config and Config.GetActiveProfile and Config:GetActiveProfile()
    if BleakfibersActionBarsDB.profiles and activeProf and BleakfibersActionBarsDB.profiles[activeProf] then
        if not BleakfibersActionBarsDB.profiles[activeProf].movers then
            BleakfibersActionBarsDB.profiles[activeProf].movers = {}
        end
        BleakfibersActionBarsDB.profiles[activeProf].movers[key] = BleakfibersActionBarsDB.movers[key]
    end
end

function Core:ApplyMoverPosition(key, frame)
    local mover = registeredMovers[key]
    if not mover then return end
    frame = frame or mover.frame
    if not frame then return end

    local saved = BleakfibersActionBarsDB and BleakfibersActionBarsDB.movers and BleakfibersActionBarsDB.movers[key]
    frame:ClearAllPoints()
    if saved and saved.point then
        frame:SetPoint(saved.point, UIParent, saved.relPoint or saved.point, saved.x, saved.y)
    else
        frame:SetPoint(mover.defaultPoint, UIParent, mover.defaultRelPoint or mover.defaultPoint, mover.defaultX, mover.defaultY)
    end
end

function Core:ApplyAllMoverPositions()
    for key, mover in pairs(registeredMovers) do
        if mover.frame then
            self:ApplyMoverPosition(key, mover.frame)
        end
    end
end

function Core:ResetMovers()
    if BleakfibersActionBarsDB then
        BleakfibersActionBarsDB.movers = {}
        local activeProf = Config and Config.GetActiveProfile and Config:GetActiveProfile()
        if BleakfibersActionBarsDB.profiles and activeProf and BleakfibersActionBarsDB.profiles[activeProf] then
            BleakfibersActionBarsDB.profiles[activeProf].movers = {}
        end
    end
    for key, mover in pairs(registeredMovers) do
        if mover.frame then
            mover.frame:ClearAllPoints()
            mover.frame:SetPoint(mover.defaultPoint, UIParent, mover.defaultRelPoint or mover.defaultPoint, mover.defaultX, mover.defaultY)
        end
        if mover.overlay then
            mover.overlay:ClearAllPoints()
            mover.overlay:SetPoint(mover.defaultPoint, UIParent, mover.defaultRelPoint or mover.defaultPoint, mover.defaultX, mover.defaultY)
        end
    end
    DEFAULT_CHAT_FRAME:AddMessage("|cff3399ff[Bleakfiber's Action Bars]|r All action bar positions reset to defaults.")
end

local function IsMoverBarEnabled(key)
    local db = BleakfibersActionBarsDB
    if not db then return true end
    if key:find("^ActionBar(%d+)$") then
        local idx = key:match("^ActionBar(%d+)$")
        local cfg = db["bar" .. idx]
        return cfg and (cfg.enabled ~= false)
    elseif key == "PetBar" then
        return db.petBar and (db.petBar.enabled ~= false)
    elseif key == "StanceBar" then
        return db.stanceBar and (db.stanceBar.enabled ~= false)
    elseif key == "MicroBar" then
        return db.microBar and (db.microBar.enabled ~= false)
    elseif key == "BagsBar" then
        return db.bagsBar and (db.bagsBar.enabled ~= false)
    elseif key == "TotemBar" then
        return db.totemBar and (db.totemBar.enabled ~= false)
    elseif key == "ExtraBar" then
        return db.extraBar and (db.extraBar.enabled ~= false)
    elseif key == "VehicleLeave" then
        return db.vehicleLeave and (db.vehicleLeave.enabled ~= false)
    end
    return true
end

function Core:ToggleMovers(forcedState)
    if InCombatLockdown() then
        DEFAULT_CHAT_FRAME:AddMessage("|cff3399ff[Bleakfiber's Action Bars]|r Cannot configure bar positions while in combat.")
        return
    end

    if forcedState ~= nil then
        moversUnlocked = forcedState
    else
        moversUnlocked = not moversUnlocked
    end

    local isBAC = (_G["BleakfibersAddonConfigForever"] ~= nil or _G["BleakfibersAddonConfig"] ~= nil)
    local ctrl = EnsureMoverControlFrame()
    if moversUnlocked then
        if not isBAC then
            ctrl:Show()
        else
            ctrl:Hide()
            local BAC = _G["BleakfibersAddonConfigForever"] or _G["BleakfibersAddonConfig"]
            if BAC and BAC.ShowMoverControlFrame then
                BAC:ShowMoverControlFrame()
            end
        end
        for key, mover in pairs(registeredMovers) do
            local overlay = mover.overlay or CreateMoverOverlay(mover)
            if IsMoverBarEnabled(key) then
                overlay:SetSize(max(40, mover.frame:GetWidth()), max(24, mover.frame:GetHeight()))
                overlay:ClearAllPoints()
                overlay:SetAllPoints(mover.frame)
                overlay:Show()
            else
                overlay:Hide()
            end
        end
    else
        ctrl:Hide()
        if isBAC then
            local BAC = _G["BleakfibersAddonConfigForever"] or _G["BleakfibersAddonConfig"]
            if BAC and BAC.HideMoverControlFrame and (not BAC.AreMoversUnlocked or not BAC:AreMoversUnlocked()) then
                BAC:HideMoverControlFrame()
            end
        end
        for _, mover in pairs(registeredMovers) do
            if mover.overlay then
                mover.overlay:Hide()
            end
        end
    end

    self:LayoutExtraBar()
    self:LayoutVehicleLeave()
end

function Core:IsMoversUnlocked()
    return moversUnlocked
end

--[[-----------------------------------------------------------------------------
    4b. Interactive Quick Keybinding Mode (/bab bind)
-------------------------------------------------------------------------------]]
local inQuickKeybind = false
local keybindDialog = nil
local keybindHighlight = nil
local keybindListener = nil
local hoveredKeybindButton = nil

local function GetButtonCommandName(btn)
    if not btn then return nil end
    if btn.commandName then return btn.commandName end
    local name = btn.GetName and btn:GetName()
    if not name then return nil end

    local bIdx = tonumber(name:match("^ActionButton(%d+)$"))
    if bIdx then return "ACTIONBUTTON" .. bIdx end

    bIdx = tonumber(name:match("^MultiBarBottomLeftButton(%d+)$"))
    if bIdx then return "MULTIACTIONBAR1BUTTON" .. bIdx end

    bIdx = tonumber(name:match("^MultiBarBottomRightButton(%d+)$"))
    if bIdx then return "MULTIACTIONBAR2BUTTON" .. bIdx end

    bIdx = tonumber(name:match("^MultiBarRightButton(%d+)$"))
    if bIdx then return "MULTIACTIONBAR3BUTTON" .. bIdx end

    bIdx = tonumber(name:match("^MultiBarLeftButton(%d+)$"))
    if bIdx then return "MULTIACTIONBAR4BUTTON" .. bIdx end

    bIdx = tonumber(name:match("^MultiBar5Button(%d+)$"))
    if bIdx then return "MULTIACTIONBAR5BUTTON" .. bIdx end

    bIdx = tonumber(name:match("^MultiBar6Button(%d+)$"))
    if bIdx then return "MULTIACTIONBAR6BUTTON" .. bIdx end

    bIdx = tonumber(name:match("^MultiBar7Button(%d+)$"))
    if bIdx then return "MULTIACTIONBAR7BUTTON" .. bIdx end

    bIdx = tonumber(name:match("^PetActionButton(%d+)$"))
    if bIdx then return "BONUSACTIONBUTTON" .. bIdx end

    bIdx = tonumber(name:match("^StanceButton(%d+)$"))
    if bIdx then return "SHAPESHIFTBUTTON" .. bIdx end

    if name == "ExtraActionButton1" then return "EXTRAACTIONBUTTON1" end

    local barNum, btnNum = name:match("^BleakfibersActionBars_Bar(%d+)Button(%d+)$")
    if barNum and btnNum then
        barNum = tonumber(barNum)
        btnNum = tonumber(btnNum)
        if barNum == 1 then return "ACTIONBUTTON" .. btnNum
        elseif barNum == 2 then return "MULTIACTIONBAR1BUTTON" .. btnNum
        elseif barNum == 3 then return "MULTIACTIONBAR2BUTTON" .. btnNum
        elseif barNum == 4 then return "MULTIACTIONBAR3BUTTON" .. btnNum
        elseif barNum == 5 then return "MULTIACTIONBAR4BUTTON" .. btnNum
        elseif barNum == 6 then return "MULTIACTIONBAR5BUTTON" .. btnNum
        elseif barNum == 7 then return "MULTIACTIONBAR6BUTTON" .. btnNum
        elseif barNum == 8 then return "MULTIACTIONBAR7BUTTON" .. btnNum
        end
    end

    return "CLICK " .. name .. ":LeftButton"
end

local function GetActionNameOrSpell(btn)
    if not btn then return "Action Button" end
    local action = btn.action or (btn.GetAttribute and btn:GetAttribute("action"))
    if action and HasAction and HasAction(action) then
        local text = GetActionText and GetActionText(action)
        if text and text ~= "" then return text end
        local actionType, id = GetActionInfo(action)
        if actionType == "spell" and id then
            local name = GetSpellInfo and GetSpellInfo(id)
            if name then return name end
        elseif actionType == "item" and id then
            local name = GetItemInfo and GetItemInfo(id)
            if name then return name end
        elseif actionType == "macro" and id then
            local name = GetMacroInfo and GetMacroInfo(id)
            if name then return name end
        end
    end
    return btn.GetName and btn:GetName() or "Action Button"
end

local function EnsureKeybindUI()
    if keybindDialog then return keybindDialog end

    -- Main Dialog Window
    local dlg = CreateFrame("Frame", "BleakfibersActionBars_KeybindDialog", UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
    dlg:SetSize(460, 160)
    dlg:SetPoint("TOP", UIParent, "TOP", 0, -60)
    dlg:SetFrameStrata("DIALOG")
    dlg:SetToplevel(true)
    dlg:SetClampedToScreen(true)
    dlg:EnableMouse(true)
    dlg:SetMovable(true)

    BAB:CreateBackdrop(dlg, 0.95, 1.0, C.COLOR_BG, C.COLOR_GOLD)

    -- Drag Handle Title Bar
    local drag = CreateFrame("Frame", nil, dlg)
    drag:SetPoint("TOPLEFT", dlg, "TOPLEFT", 6, -6)
    drag:SetPoint("TOPRIGHT", dlg, "TOPRIGHT", -30, -6)
    drag:SetHeight(28)
    drag:EnableMouse(true)
    drag:RegisterForDrag("LeftButton")
    drag:SetScript("OnDragStart", function() dlg:StartMoving() end)
    drag:SetScript("OnDragStop", function() dlg:StopMovingOrSizing() end)

    local title = drag:CreateFontString(nil, "OVERLAY")
    BAB:SetFont(title, C.FONT_HEADER, 14, "OUTLINE")
    title:SetPoint("LEFT", drag, "LEFT", 8, 0)
    title:SetText("|cFFFFD100Bleakfiber's Action Bars|r — Quick Keybind Mode")

    -- Close Button
    local close = CreateFrame("Button", nil, dlg, "UIPanelCloseButton")
    close:SetSize(26, 26)
    close:SetPoint("TOPRIGHT", dlg, "TOPRIGHT", -4, -4)
    close:SetScript("OnClick", function()
        Core:ToggleKeybindMode(false)
    end)

    -- Instructions
    local instr = dlg:CreateFontString(nil, "OVERLAY")
    BAB:SetFont(instr, C.FONT_DEFAULT, 11, "OUTLINE")
    instr:SetPoint("TOPLEFT", dlg, "TOPLEFT", 14, -38)
    instr:SetPoint("TOPRIGHT", dlg, "TOPRIGHT", -14, -38)
    instr:SetJustifyH("LEFT")
    instr:SetText("Hover over any action button and press a key to bind it.\nPress |cFFFF5555ESCAPE|r while hovering to unbind that button.")

    -- Target Button Info Text
    local targetText = dlg:CreateFontString(nil, "OVERLAY")
    BAB:SetFont(targetText, C.FONT_HEADER, 12, "OUTLINE")
    targetText:SetPoint("TOPLEFT", dlg, "TOPLEFT", 14, -76)
    targetText:SetText("Hovered: |cFF888888None|r")
    dlg.targetText = targetText

    -- Checkbox: Character-Specific Keybinds
    local charCb = CreateFrame("CheckButton", "BAB_KeybindCharSpecific", dlg, "UICheckButtonTemplate")
    charCb:SetPoint("BOTTOMLEFT", dlg, "BOTTOMLEFT", 10, 12)
    charCb.text = _G["BAB_KeybindCharSpecificText"]
    if charCb.text then
        charCb.text:SetText("Character Specific Keybinds")
        BAB:SetFont(charCb.text, C.FONT_DEFAULT, 11, "OUTLINE")
    end
    charCb:SetScript("OnClick", function(self)
        local isChar = self:GetChecked()
        if isChar then
            LoadBindings(2)
            SaveBindings(2)
            DEFAULT_CHAT_FRAME:AddMessage("|cff3399ff[Bleakfiber's Action Bars]|r Switched to Character-Specific keybindings.")
        else
            LoadBindings(1)
            SaveBindings(1)
            DEFAULT_CHAT_FRAME:AddMessage("|cff3399ff[Bleakfiber's Action Bars]|r Switched to Account-Wide keybindings.")
        end
        Core:SkinAllButtons()
    end)
    dlg.charCb = charCb

    -- Button: Save Keybinds
    local saveBtn = CreateFrame("Button", nil, dlg, BackdropTemplateMixin and "BackdropTemplate" or nil)
    saveBtn:SetSize(110, 26)
    saveBtn:SetPoint("BOTTOMRIGHT", dlg, "BOTTOMRIGHT", -124, 12)
    BAB:CreateBackdrop(saveBtn, 0.8, 1.0, C.COLOR_BG, C.COLOR_GOLD)
    local saveLbl = saveBtn:CreateFontString(nil, "OVERLAY")
    BAB:SetFont(saveLbl, C.FONT_HEADER, 12, "OUTLINE")
    saveLbl:SetPoint("CENTER")
    saveLbl:SetText("|cFFFFD100Save|r")
    saveBtn:SetScript("OnClick", function()
        SaveBindings(GetCurrentBindingSet())
        DEFAULT_CHAT_FRAME:AddMessage("|cff3399ff[Bleakfiber's Action Bars]|r All keybindings successfully saved.")
        Core:ToggleKeybindMode(false)
    end)

    -- Button: Discard Changes
    local discardBtn = CreateFrame("Button", nil, dlg, BackdropTemplateMixin and "BackdropTemplate" or nil)
    discardBtn:SetSize(100, 26)
    discardBtn:SetPoint("BOTTOMRIGHT", dlg, "BOTTOMRIGHT", -14, 12)
    BAB:CreateBackdrop(discardBtn, 0.8, 1.0, C.COLOR_BG, C.COLOR_BORDER)
    local discLbl = discardBtn:CreateFontString(nil, "OVERLAY")
    BAB:SetFont(discLbl, C.FONT_HEADER, 12, "OUTLINE")
    discLbl:SetPoint("CENTER")
    discLbl:SetText("Discard")
    discardBtn:SetScript("OnClick", function()
        LoadBindings(GetCurrentBindingSet())
        DEFAULT_CHAT_FRAME:AddMessage("|cff3399ff[Bleakfiber's Action Bars]|r Keybinding changes discarded.")
        Core:ToggleKeybindMode(false)
    end)

    -- Hover Highlight Frame
    local hl = CreateFrame("Frame", nil, UIParent)
    hl:SetFrameStrata("TOOLTIP")
    hl:Hide()

    local hlTex = hl:CreateTexture(nil, "OVERLAY")
    hlTex:SetAllPoints()
    hlTex:SetColorTexture(1.0, 0.82, 0.0, 0.35)

    local hlBorder = CreateFrame("Frame", nil, hl, BackdropTemplateMixin and "BackdropTemplate" or nil)
    hlBorder:SetAllPoints()
    BAB:CreateBackdrop(hlBorder, 0, 1.0, nil, C.COLOR_GOLD)

    keybindHighlight = hl

    -- Global Keyboard & Mouse Listener Frame
    local listener = CreateFrame("Frame", "BleakfibersActionBars_KeybindListener", UIParent)
    listener:SetFrameStrata("DIALOG")
    listener:EnableKeyboard(true)
    listener:EnableMouseWheel(true)
    listener:Hide()

    local function ApplyKeybind(keyStr)
        if not hoveredKeybindButton then return end
        local cmd = GetButtonCommandName(hoveredKeybindButton)
        if not cmd then return end

        if keyStr == "ESCAPE" then
            local k1, k2 = GetBindingKey(cmd)
            if k1 then SetBinding(k1, nil) end
            if k2 then SetBinding(k2, nil) end
            DEFAULT_CHAT_FRAME:AddMessage("|cff3399ff[Bleakfiber's Action Bars]|r Cleared bindings for |cffffd100" .. cmd .. "|r")
        else
            SetBinding(keyStr, cmd)
            DEFAULT_CHAT_FRAME:AddMessage("|cff3399ff[Bleakfiber's Action Bars]|r Bound |cffffff00" .. keyStr .. "|r to |cff00ffff" .. cmd .. "|r")
        end

        Core:UpdateButtonVisuals(hoveredKeybindButton)
        Core:SetKeybindTarget(hoveredKeybindButton)
    end

    listener:SetScript("OnKeyDown", function(self, key)
        if not inQuickKeybind then return end
        if key == "LSHIFT" or key == "RSHIFT" or key == "LCTRL" or key == "RCTRL" or key == "LALT" or key == "RALT" then
            return
        end

        if not hoveredKeybindButton then
            if key == "ESCAPE" then
                Core:ToggleKeybindMode(false)
            end
            return
        end

        if key == "ESCAPE" then
            ApplyKeybind("ESCAPE")
            return
        end

        local prefix = ""
        if IsAltKeyDown() then prefix = prefix .. "ALT-" end
        if IsControlKeyDown() then prefix = prefix .. "CTRL-" end
        if IsShiftKeyDown() then prefix = prefix .. "SHIFT-" end
        ApplyKeybind(prefix .. key)
    end)

    listener:SetScript("OnMouseWheel", function(self, delta)
        if not inQuickKeybind or not hoveredKeybindButton then return end
        local prefix = ""
        if IsAltKeyDown() then prefix = prefix .. "ALT-" end
        if IsControlKeyDown() then prefix = prefix .. "CTRL-" end
        if IsShiftKeyDown() then prefix = prefix .. "SHIFT-" end
        local wheel = prefix .. (delta > 0 and "MOUSEWHEELUP" or "MOUSEWHEELDOWN")
        ApplyKeybind(wheel)
    end)

    listener:SetScript("OnUpdate", function(self, elapsed)
        if not inQuickKeybind then return end
        local focus = nil
        if GetMouseFoci then
            local foci = GetMouseFoci()
            focus = foci and foci[1]
        elseif GetMouseFocus then
            focus = GetMouseFocus()
        end

        if focus and skinnedButtons[focus] then
            if hoveredKeybindButton ~= focus then
                Core:SetKeybindTarget(focus)
            end
        elseif focus and focus.GetName and focus:GetName() and (focus:GetName():match("ActionButton") or focus:GetName():match("MultiBar") or focus:GetName():match("PetActionButton") or focus:GetName():match("StanceButton") or focus:GetName():match("ExtraActionButton")) then
            if hoveredKeybindButton ~= focus then
                Core:SetKeybindTarget(focus)
            end
        else
            if hoveredKeybindButton and (not focus or (focus ~= hoveredKeybindButton and focus ~= keybindHighlight)) then
                if not (hoveredKeybindButton.IsMouseOver and hoveredKeybindButton:IsMouseOver()) then
                    Core:SetKeybindTarget(nil)
                end
            end
        end
    end)

    keybindListener = listener
    keybindDialog = dlg
    return dlg
end

function Core:SetKeybindTarget(btn)
    if not inQuickKeybind then return end
    hoveredKeybindButton = btn

    if not btn then
        if keybindHighlight then keybindHighlight:Hide() end
        if keybindDialog and keybindDialog.targetText then
            keybindDialog.targetText:SetText("Hovered: |cFF888888None|r")
        end
        return
    end

    if keybindHighlight then
        keybindHighlight:ClearAllPoints()
        keybindHighlight:SetAllPoints(btn)
        keybindHighlight:Show()
    end

    local cmd = GetButtonCommandName(btn) or "Unknown"
    local actionLabel = GetActionNameOrSpell(btn)
    local k1, k2 = GetBindingKey(cmd)
    local boundText = k1 and ("|cFF00FF00" .. k1 .. (k2 and (", " .. k2) or "") .. "|r") or "|cFFFF5555Not Bound|r"

    if keybindDialog and keybindDialog.targetText then
        keybindDialog.targetText:SetText("Hovered: |cFFFFD100" .. actionLabel .. "|r (" .. cmd .. ") | " .. boundText)
    end
end

function Core:ToggleKeybindMode(state)
    if InCombatLockdown() then
        DEFAULT_CHAT_FRAME:AddMessage("|cff3399ff[Bleakfiber's Action Bars]|r Cannot change keybindings during combat.")
        return
    end

    if state ~= nil then
        inQuickKeybind = state
    else
        inQuickKeybind = not inQuickKeybind
    end

    local dlg = EnsureKeybindUI()
    if inQuickKeybind then
        dlg:Show()
        if dlg.charCb then
            dlg.charCb:SetChecked(GetCurrentBindingSet() == 2)
        end
        if keybindListener then keybindListener:Show() end

        for barIdx = 1, 15 do
            for i = 1, 12 do
                local b = GetOrCreatePlayerButton(barIdx, i)
                if b then
                    b:SetAttribute("showgrid", 1)
                    if ActionButton_ShowGrid then ActionButton_ShowGrid(b) end
                    b:Show()
                end
            end
        end
        if ExtraActionBar_ForceShowIfNeeded then
            ExtraActionBar_ForceShowIfNeeded()
        end

        DEFAULT_CHAT_FRAME:AddMessage("|cff3399ff[Bleakfiber's Action Bars]|r Quick Keybind Mode |cff00ff00ENABLED|r. Hover buttons and press keys to bind. Press ESC to clear.")
    else
        dlg:Hide()
        if keybindListener then keybindListener:Hide() end
        if keybindHighlight then keybindHighlight:Hide() end
        hoveredKeybindButton = nil

        if ExtraActionBar_CancelForceShow then
            ExtraActionBar_CancelForceShow()
        end
        self:UpdateAllBars()
        self:SkinAllButtons()

        DEFAULT_CHAT_FRAME:AddMessage("|cff3399ff[Bleakfiber's Action Bars]|r Quick Keybind Mode |cffff5555DISABLED|r.")
    end
end

--[[-----------------------------------------------------------------------------
    5. Blizzard Default Art & Frame Suppression
-------------------------------------------------------------------------------]]
local function SuppressBlizzardFrame(frame)
    if not frame then return end
    frame:SetAlpha(0)

    local isProtected = (frame.IsProtected and frame:IsProtected())
    if not isProtected and not InCombatLockdown() then
        if frame.EnableMouse then pcall(frame.EnableMouse, frame, false) end
        if frame.SetSize then pcall(frame.SetSize, frame, 0.001, 0.001) end
        pcall(frame.ClearAllPoints, frame)
        pcall(frame.SetPoint, frame, "BOTTOM", UIParent, "BOTTOM", 0, -5000)
    end

    if frame.GetRegions then
        for _, region in ipairs({ frame:GetRegions() }) do
            if region and region.IsObjectType and region:IsObjectType("Texture") then
                pcall(region.SetTexture, region, nil)
                pcall(region.SetAlpha, region, 0)
                pcall(region.Hide, region)
            end
        end
    end

    if frame.GetChildren then
        for _, child in ipairs({ frame:GetChildren() }) do
            local name = child.GetName and child:GetName()
            if not (name and (name:match("^ActionButton%d+$") or name:match("^MultiBar.*Button%d+$") or name:match("^PetActionButton%d+$") or name:match("^StanceButton%d+$"))) then
                local childProtected = (child.IsProtected and child:IsProtected())
                if child.SetAlpha then pcall(child.SetAlpha, child, 0) end
                if not childProtected and not InCombatLockdown() then
                    if child.EnableMouse then pcall(child.EnableMouse, child, false) end
                    if child.SetSize then pcall(child.SetSize, child, 0.001, 0.001) end
                end
            end
        end
    end

    if not isProtected and not frame._buiHideHooked then
        frame._buiHideHooked = true
        hooksecurefunc(frame, "Show", function(self)
            self:SetAlpha(0)
            if not (self.IsProtected and self:IsProtected()) and not InCombatLockdown() then
                if self.EnableMouse then pcall(self.EnableMouse, self, false) end
                if self.SetSize then pcall(self.SetSize, self, 0.001, 0.001) end
                pcall(self.ClearAllPoints, self)
                pcall(self.SetPoint, self, "BOTTOM", UIParent, "BOTTOM", 0, -5000)
            end
        end)
    end
end

function Core:HideBlizzardArt()
    if MainActionBar then
        SuppressBlizzardFrame(MainActionBar)
        if MainActionBar.EndCaps then MainActionBar.EndCaps:Hide() end
        if MainActionBar.Border then MainActionBar.Border:Hide() end
        if MainActionBar.Background then MainActionBar.Background:Hide() end
        if MainActionBar.ActionBarPageNumber then MainActionBar.ActionBarPageNumber:Hide() end

        if MainActionBar.actionButtonContainer then
            SuppressBlizzardFrame(MainActionBar.actionButtonContainer)
        end

        if RegisterStateDriver and not InCombatLockdown() then
            pcall(RegisterStateDriver, MainActionBar, "visibility", "hide")
        end
    end

    for i = 1, 12 do
        local container = _G["MainActionBarButtonContainer" .. i]
        if container then SuppressBlizzardFrame(container) end
    end

    -- Classic 3.3.5 / Ascension MainMenuBar & ArtFrame complete suppression
    if MainMenuBarArtFrame then
        MainMenuBarArtFrame:Hide()
        MainMenuBarArtFrame:SetAlpha(0)
        if not MainMenuBarArtFrame._buiArtHooked then
            MainMenuBarArtFrame._buiArtHooked = true
            hooksecurefunc(MainMenuBarArtFrame, "Show", function(self)
                self:Hide()
                self:SetAlpha(0)
            end)
        end
    end

    local blizzardArtTextures = {
        _G.MainMenuBarLeftEndCap,
        _G.MainMenuBarRightEndCap,
        _G.MainMenuBarTexture0,
        _G.MainMenuBarTexture1,
        _G.MainMenuBarTexture2,
        _G.MainMenuBarTexture3,
        _G.MainMenuMaxLevelBar0,
        _G.MainMenuMaxLevelBar1,
        _G.MainMenuMaxLevelBar2,
        _G.MainMenuMaxLevelBar3,
        _G.BonusActionBarTexture0,
        _G.BonusActionBarTexture1,
        _G.ShapeshiftBarLeft,
        _G.ShapeshiftBarMiddle,
        _G.ShapeshiftBarRight,
        _G.PossessBackground1,
        _G.PossessBackground2,
    }
    for _, tex in ipairs(blizzardArtTextures) do
        if tex then
            tex:SetTexture(nil)
            tex:SetAlpha(0)
            tex:Hide()
            if not tex._buiArtHooked then
                tex._buiArtHooked = true
                hooksecurefunc(tex, "Show", function(self)
                    self:SetTexture(nil)
                    self:SetAlpha(0)
                    self:Hide()
                end)
                hooksecurefunc(tex, "SetTexture", function(self, t)
                    if t ~= nil and not self._buiSuppressing then
                        self._buiSuppressing = true
                        self:SetTexture(nil)
                        self:SetAlpha(0)
                        self:Hide()
                        self._buiSuppressing = false
                    end
                end)
            end
        end
    end

    local blizzardArtFrames = {
        _G.MainMenuBarPageNumber,
        _G.ActionBarUpButton,
        _G.ActionBarDownButton,
    }
    for _, frame in ipairs(blizzardArtFrames) do
        if frame then
            frame:Hide()
            frame:SetAlpha(0)
            if not frame._buiArtHooked then
                frame._buiArtHooked = true
                hooksecurefunc(frame, "Show", function(self)
                    self:Hide()
                    self:SetAlpha(0)
                end)
            end
        end
    end

    local microContainers = {
        _G.MicroMenu,
        _G.MicroMenuContainer,
        _G.MicroButtonAndBagsBar,
    }
    for _, mm in ipairs(microContainers) do
        if mm then
            if mm.BorderArt then
                pcall(mm.BorderArt.SetTexture, mm.BorderArt, nil)
                pcall(mm.BorderArt.SetAlpha, mm.BorderArt, 0)
                pcall(mm.BorderArt.Hide, mm.BorderArt)
            end
            if mm.BackgroundArt then
                pcall(mm.BackgroundArt.SetTexture, mm.BackgroundArt, nil)
                pcall(mm.BackgroundArt.SetAlpha, mm.BackgroundArt, 0)
                pcall(mm.BackgroundArt.Hide, mm.BackgroundArt)
            end
            SuppressBlizzardFrame(mm)
        end
    end

    local bagContainers = {
        _G.BagsBar,
        _G.BagsBarContainer,
    }
    for _, bb in ipairs(bagContainers) do
        if bb then
            if bb.BorderArt then
                pcall(bb.BorderArt.SetTexture, bb.BorderArt, nil)
                pcall(bb.BorderArt.SetAlpha, bb.BorderArt, 0)
                pcall(bb.BorderArt.Hide, bb.BorderArt)
            end
            if bb.BackgroundArt then
                pcall(bb.BackgroundArt.SetTexture, bb.BackgroundArt, nil)
                pcall(bb.BackgroundArt.SetAlpha, bb.BackgroundArt, 0)
                pcall(bb.BackgroundArt.Hide, bb.BackgroundArt)
            end
            SuppressBlizzardFrame(bb)
        end
    end
    if self.HookBlizzardBagsBar then self:HookBlizzardBagsBar() end

    local multiBars = {
        _G.MultiBarBottomLeft,
        _G.MultiBarBottomRight,
        _G.MultiBarRight,
        _G.MultiBarLeft,
        _G.MultiBar5,
        _G.MultiBar6,
        _G.MultiBar7,
        _G.PossessActionBar,
        _G.PossessBarFrame,
        _G.PetActionBar,
        _G.PetActionBarFrame,
        _G.StanceBar,
        _G.StanceBarFrame,
        _G.MainMenuBar,
        _G.MainMenuBarArtFrame,
        _G.MicroMenu,
        _G.MicroMenuContainer,
        _G.MicroButtonAndBagsBar,
        _G.BagsBar,
        _G.BagsBarContainer,
        _G.StatusTrackingBarManager,
        _G.MainStatusTrackingBarContainer,
        _G.SecondaryStatusTrackingBarContainer,
        _G.MainMenuBarPageNumber,
    }

    for _, bar in ipairs(multiBars) do
        SuppressBlizzardFrame(bar)
        if RegisterStateDriver and not InCombatLockdown() then
            pcall(RegisterStateDriver, bar, "visibility", "hide")
        end
    end
end

--[[-----------------------------------------------------------------------------
    6. Button Management & Visual Skinning
-----------------------------------------------------------------------------]]
GetOrCreatePlayerButton = function(barIndex, buttonIndex, parent)
    local btn
    if barIndex == 1 then
        btn = _G["ActionButton" .. buttonIndex]
    elseif barIndex == 2 then
        btn = _G["MultiBarBottomLeftButton" .. buttonIndex]
    elseif barIndex == 3 then
        btn = _G["MultiBarBottomRightButton" .. buttonIndex]
    elseif barIndex == 4 then
        btn = _G["MultiBarRightButton" .. buttonIndex]
    elseif barIndex == 5 then
        btn = _G["MultiBarLeftButton" .. buttonIndex]
    elseif barIndex == 6 and _G["MultiBar5Button" .. buttonIndex] then
        btn = _G["MultiBar5Button" .. buttonIndex]
    elseif barIndex == 7 and _G["MultiBar6Button" .. buttonIndex] then
        btn = _G["MultiBar6Button" .. buttonIndex]
    elseif barIndex == 8 and _G["MultiBar7Button" .. buttonIndex] then
        btn = _G["MultiBar7Button" .. buttonIndex]
    end

    if not btn then
        local name = "BleakfibersActionBars_Bar" .. barIndex .. "Button" .. buttonIndex
        btn = _G[name]
        if not btn and not InCombatLockdown() then
            btn = CreateFrame("CheckButton", name, parent or UIParent, "ActionBarButtonTemplate")
            if not btn then
                btn = CreateFrame("CheckButton", name, parent or UIParent, "SecureActionButtonTemplate, ActionButtonTemplate")
            end
            if btn then
                local actionID = 0
                if barIndex == 6 then actionID = 144 + buttonIndex
                elseif barIndex == 7 then actionID = 156 + buttonIndex
                elseif barIndex == 8 then actionID = 168 + buttonIndex
                else actionID = ((barIndex - 1) * 12) + buttonIndex
                end
                btn:SetAttribute("type", "action")
                btn:SetAttribute("action", actionID)
                btn:SetID(actionID)
            end
        end
    end
    return btn
end

function Core:ShowCustomProcGlow(btn)
    if not btn then return end
    local gen = BleakfibersActionBarsDB and BleakfibersActionBarsDB.general or {}
    if gen.procGlow == false then
        if btn._babProcGlow then btn._babProcGlow:Hide() end
        return
    end

    local glow = btn._babProcGlow
    if not glow then
        glow = CreateFrame("Frame", nil, btn)
        glow:SetAllPoints(btn)
        glow:SetFrameStrata("HIGH")
        glow:SetFrameLevel(btn:GetFrameLevel() + 5)

        local top = glow:CreateTexture(nil, "OVERLAY")
        top:SetColorTexture(C.COLOR_GOLD.r, C.COLOR_GOLD.g, C.COLOR_GOLD.b, 1.0)
        top:SetPoint("TOPLEFT", glow, "TOPLEFT", 0, 0)
        top:SetPoint("TOPRIGHT", glow, "TOPRIGHT", 0, 0)
        top:SetHeight(2)

        local bottom = glow:CreateTexture(nil, "OVERLAY")
        bottom:SetColorTexture(C.COLOR_GOLD.r, C.COLOR_GOLD.g, C.COLOR_GOLD.b, 1.0)
        bottom:SetPoint("BOTTOMLEFT", glow, "BOTTOMLEFT", 0, 0)
        bottom:SetPoint("BOTTOMRIGHT", glow, "BOTTOMRIGHT", 0, 0)
        bottom:SetHeight(2)

        local left = glow:CreateTexture(nil, "OVERLAY")
        left:SetColorTexture(C.COLOR_GOLD.r, C.COLOR_GOLD.g, C.COLOR_GOLD.b, 1.0)
        left:SetPoint("TOPLEFT", glow, "TOPLEFT", 0, 0)
        left:SetPoint("BOTTOMLEFT", glow, "BOTTOMLEFT", 0, 0)
        left:SetWidth(2)

        local right = glow:CreateTexture(nil, "OVERLAY")
        right:SetColorTexture(C.COLOR_GOLD.r, C.COLOR_GOLD.g, C.COLOR_GOLD.b, 1.0)
        right:SetPoint("TOPRIGHT", glow, "TOPRIGHT", 0, 0)
        right:SetPoint("BOTTOMRIGHT", glow, "BOTTOMRIGHT", 0, 0)
        right:SetWidth(2)

        local ag = glow:CreateAnimationGroup()
        ag:SetLooping("BOUNCE")
        local alpha = ag:CreateAnimation("Alpha")
        alpha:SetFromAlpha(0.35)
        alpha:SetToAlpha(1.0)
        alpha:SetDuration(0.6)
        glow.anim = ag

        btn._babProcGlow = glow
    end

    glow:Show()
    if glow.anim and not glow.anim:IsPlaying() then
        glow.anim:Play()
    end
end

function Core:HideCustomProcGlow(btn)
    if btn and btn._babProcGlow then
        if btn._babProcGlow.anim then btn._babProcGlow.anim:Stop() end
        btn._babProcGlow:Hide()
    end
end

function Core:AdjustOverlayGlow(btn)
    if not btn then return end
    local gen = BleakfibersActionBarsDB and BleakfibersActionBarsDB.general or {}
    local alert = btn.SpellActivationAlert or btn.overlay

    if gen.procGlow == false then
        if alert then alert:Hide() end
        self:HideCustomProcGlow(btn)
        return
    end

    if alert then
        if alert._buiAdjusting then return end
        alert._buiAdjusting = true

        pcall(function()
            alert:ClearAllPoints()
            alert:SetAllPoints(btn)
            if alert.SetClipsChildren then alert:SetClipsChildren(true) end
            if alert.outerGlow then alert.outerGlow:SetAlpha(0); alert.outerGlow:Hide() end
            if alert.outerGlowOver then alert.outerGlowOver:SetAlpha(0); alert.outerGlowOver:Hide() end
            if alert.spark then alert.spark:SetAlpha(0); alert.spark:Hide() end
            if alert.ants then alert.ants:ClearAllPoints(); alert.ants:SetAllPoints(alert) end
            if alert.innerGlow then alert.innerGlow:ClearAllPoints(); alert.innerGlow:SetAllPoints(alert) end
            if alert.innerGlowOver then alert.innerGlowOver:ClearAllPoints(); alert.innerGlowOver:SetAllPoints(alert) end
        end)

        alert._buiAdjusting = false

        if not alert._buiGlowHooked then
            alert._buiGlowHooked = true
            hooksecurefunc(alert, "Show", function(self)
                if self._buiAdjusting then return end
                local p = self:GetParent()
                if p then Core:AdjustOverlayGlow(p) end
            end)
            hooksecurefunc(alert, "SetPoint", function(self)
                if self._buiAdjusting then return end
                local p = self:GetParent()
                if p then Core:AdjustOverlayGlow(p) end
            end)
        end
    end

    self:ShowCustomProcGlow(btn)
end

function Core:HookOverlayGlow()
    if self._buiGlowHooksSet then return end
    self._buiGlowHooksSet = true

    if ActionButton_ShowOverlayGlow then
        hooksecurefunc("ActionButton_ShowOverlayGlow", function(btn)
            if btn then Core:AdjustOverlayGlow(btn) end
        end)
    end
    if ActionButton_HideOverlayGlow then
        hooksecurefunc("ActionButton_HideOverlayGlow", function(btn)
            if btn then Core:HideCustomProcGlow(btn) end
        end)
    end
    if ActionButtonSpellAlertManager then
        if ActionButtonSpellAlertManager.ShowAlert then
            hooksecurefunc(ActionButtonSpellAlertManager, "ShowAlert", function(mgr, btn)
                if btn then Core:AdjustOverlayGlow(btn) end
            end)
        end
        if ActionButtonSpellAlertManager.HideAlert then
            hooksecurefunc(ActionButtonSpellAlertManager, "HideAlert", function(mgr, btn)
                if btn then Core:HideCustomProcGlow(btn) end
            end)
        end
    end
end

--[[-----------------------------------------------------------------------------
    Cooldown Display Engine & Pulse Animation (Native C++ countdown, Secret-Number Safe)
-------------------------------------------------------------------------------]]
Core.cooldownFrames = Core.cooldownFrames or {}

function Core:TriggerCooldownPulse(btn)
    if not btn or not btn:IsShown() then return end
    local gen = BleakfibersActionBarsDB and BleakfibersActionBarsDB.general or {}
    if gen.cooldownPulse == false then return end

    local iconTex
    if btn.icon and btn.icon.GetTexture and btn.icon:GetTexture() then
        iconTex = btn.icon:GetTexture()
    elseif btn.GetNormalTexture then
        local nt = btn:GetNormalTexture()
        if nt and nt.GetTexture then iconTex = nt:GetTexture() end
    end
    if not iconTex then return end

    local pulse = btn._babPulseFrame
    if not pulse then
        pulse = CreateFrame("Frame", nil, btn)
        pulse:SetAllPoints(btn)
        pulse:SetFrameStrata("HIGH")
        pulse:SetFrameLevel(btn:GetFrameLevel() + 10)

        local t = pulse:CreateTexture(nil, "OVERLAY")
        t:SetAllPoints()
        t:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        pulse.tex = t

        local glow = pulse:CreateTexture(nil, "OVERLAY", nil, 1)
        glow:SetAllPoints()
        glow:SetColorTexture(C.COLOR_GOLD.r, C.COLOR_GOLD.g, C.COLOR_GOLD.b, 0.35)
        glow:SetBlendMode("ADD")
        pulse.glow = glow

        local ag = pulse:CreateAnimationGroup()
        local scale = ag:CreateAnimation("Scale")
        scale:SetOrigin("CENTER", 0, 0)
        local pulseScale = gen.cooldownPulseScale or 1.35
        scale:SetScale(pulseScale, pulseScale)
        scale:SetDuration(0.3)
        scale:SetOrder(1)

        local alpha = ag:CreateAnimation("Alpha")
        alpha:SetFromAlpha(0.9)
        alpha:SetToAlpha(0)
        alpha:SetDuration(0.3)
        alpha:SetOrder(1)

        ag:SetScript("OnFinished", function()
            pulse:Hide()
        end)
        pulse.anim = ag
        btn._babPulseFrame = pulse
    end

    pulse.tex:SetTexture(iconTex)
    pulse:Show()
    pulse.anim:Stop()
    pulse.anim:Play()
end

function Core:UpdateCooldownFont(cd)
    if not cd then return end
    local gen = BleakfibersActionBarsDB and BleakfibersActionBarsDB.general or {}
    local fontName = gen.cooldownFont or "Nata Sans Bold"
    local fontFile = BAB:FetchFont(fontName)
    if cd.SetCountdownFont then
        pcall(cd.SetCountdownFont, cd, fontFile)
    end
end

function Core:UpdateAllCooldownFonts()
    local gen = BleakfibersActionBarsDB and BleakfibersActionBarsDB.general or {}
    local showNumbers = gen.cooldownText ~= false
    if SetCVar then
        pcall(SetCVar, "countdownForCooldowns", showNumbers and "1" or "0")
    end

    for _, cd in ipairs(self.cooldownFrames) do
        if cd and cd.SetHideCountdownNumbers then
            cd:SetHideCountdownNumbers(not showNumbers)
            self:UpdateCooldownFont(cd)
        end
    end
end

function Core:HookButtonCooldown(btn)
    local btnName = btn.GetName and btn:GetName()
    local cd = btn.cooldown or (btnName and _G[btnName .. "Cooldown"])
    if not cd or cd._babHooked then return end
    cd._babHooked = true

    table.insert(self.cooldownFrames, cd)

    local gen = BleakfibersActionBarsDB and BleakfibersActionBarsDB.general or {}
    local showNumbers = gen.cooldownText ~= false
    if cd.SetHideCountdownNumbers then
        cd:SetHideCountdownNumbers(not showNumbers)
        self:UpdateCooldownFont(cd)
    end

    if cd.HookScript then
        pcall(function()
            cd:HookScript("OnCooldownDone", function(self)
                local p = self:GetParent()
                if p and Core.TriggerCooldownPulse then
                    Core:TriggerCooldownPulse(p)
                end
            end)
        end)
    end

    hooksecurefunc(cd, "SetCooldown", function(self, start, duration)
        if duration and duration > 2 then
            self._babHasCooldown = true
        elseif duration == 0 and self._babHasCooldown then
            self._babHasCooldown = false
            local p = self:GetParent()
            if p and Core.TriggerCooldownPulse then
                Core:TriggerCooldownPulse(p)
            end
        end
    end)
end

function Core:SkinButton(btn)
    if not btn then return end
    if not skinnedButtons[btn] then
        skinnedButtons[btn] = true

        local btnName = btn.GetName and btn:GetName()
        if btnName then
            if not btn.HotKey and _G[btnName .. "HotKey"] then btn.HotKey = _G[btnName .. "HotKey"] end
            if not btn.Count and _G[btnName .. "Count"] then btn.Count = _G[btnName .. "Count"] end
            if not btn.Name and _G[btnName .. "Name"] then btn.Name = _G[btnName .. "Name"] end
            if not btn.icon and _G[btnName .. "Icon"] then btn.icon = _G[btnName .. "Icon"] end
        end

        BAB:CreateBackdrop(btn, 0.50, 1.0, C.COLOR_BG, C.COLOR_BORDER)

        if btn.SetPushedTexture then
            local pushed = btn:CreateTexture(nil, "OVERLAY")
            pushed:SetColorTexture(1, 1, 1, 0.15)
            pushed:SetAllPoints()
            btn:SetPushedTexture(pushed)
        end

        if btn.SetHighlightTexture then
            local hl = btn:CreateTexture(nil, "HIGHLIGHT")
            hl:SetColorTexture(1, 1, 1, 0.12)
            hl:SetAllPoints()
            btn:SetHighlightTexture(hl)
        end

        if btn.SetCheckedTexture then
            local checked = btn:CreateTexture(nil, "OVERLAY")
            checked:SetColorTexture(1, 1, 1, 0.20)
            checked:SetAllPoints()
            btn:SetCheckedTexture(checked)
        end

        local hk = btn.HotKey
        if hk and not hk._buiHooked then
            hk._buiHooked = true
            hooksecurefunc(hk, "SetText", function(self, text)
                if self._buiFormatting then return end
                local gen = BleakfibersActionBarsDB and BleakfibersActionBarsDB.general or {}
                if not text or text == "" or text == RANGE_INDICATOR or text == "\226\128\162" or text == "·" or text == "." or text == "*" or text:find("\226\128\162", 1, true) then
                    self._buiFormatting = true
                    self:SetText("")
                    self:Hide()
                    self._buiFormatting = false
                    return
                end

                local formatted = FormatHotkey(text)
                if formatted == "" then
                    self._buiFormatting = true
                    self:SetText("")
                    self:Hide()
                    self._buiFormatting = false
                elseif gen.abbreviateHotkey ~= false and formatted ~= text then
                    self._buiFormatting = true
                    self:SetText(formatted)
                    self:Show()
                    self._buiFormatting = false
                else
                    self:Show()
                end
            end)

            hooksecurefunc(hk, "Show", function(self)
                local txt = self:GetText()
                if not txt or txt == "" or txt == RANGE_INDICATOR or txt == "\226\128\162" or txt == "·" or txt == "." or txt == "*" then
                    self:Hide()
                end
            end)
        end

        btn.commandName = GetButtonCommandName(btn)

        if not btn._buiKeybindHoverHooked then
            btn._buiKeybindHoverHooked = true
            btn:HookScript("OnEnter", function(self)
                if inQuickKeybind then
                    Core:SetKeybindTarget(self)
                end
            end)
            btn:HookScript("OnLeave", function(self)
                if inQuickKeybind and hoveredKeybindButton == self then
                    Core:SetKeybindTarget(nil)
                end
            end)
        end

        if not btn._buiKeybindClickHooked then
            btn._buiKeybindClickHooked = true
            btn:HookScript("OnClick", function(self, mouseBtn)
                if inQuickKeybind and mouseBtn ~= "LeftButton" and mouseBtn ~= "RightButton" then
                    local prefix = ""
                    if IsAltKeyDown() then prefix = prefix .. "ALT-" end
                    if IsControlKeyDown() then prefix = prefix .. "CTRL-" end
                    if IsShiftKeyDown() then prefix = prefix .. "SHIFT-" end
                    local mb = mouseBtn:upper()
                    local cmd = GetButtonCommandName(self)
                    if cmd then
                        SetBinding(prefix .. mb, cmd)
                        DEFAULT_CHAT_FRAME:AddMessage("|cff3399ff[Bleakfiber's Action Bars]|r Bound |cffffff00" .. prefix .. mb .. "|r to |cff00ffff" .. cmd .. "|r")
                        Core:UpdateButtonVisuals(self)
                        Core:SetKeybindTarget(self)
                    end
                end
            end)
        end
    end

    self:UpdateButtonVisuals(btn)
    self:HookButtonCooldown(btn)
end

function Core:UpdateButtonVisuals(btn, barConfig)
    if not btn then return end
    local gen = BleakfibersActionBarsDB and BleakfibersActionBarsDB.general or {}
    barConfig = barConfig or {}

    local btnName = btn.GetName and btn:GetName()
    if btnName then
        if not btn.HotKey and _G[btnName .. "HotKey"] then btn.HotKey = _G[btnName .. "HotKey"] end
        if not btn.Count and _G[btnName .. "Count"] then btn.Count = _G[btnName .. "Count"] end
        if not btn.Name and _G[btnName .. "Name"] then btn.Name = _G[btnName .. "Name"] end
        if not btn.icon and _G[btnName .. "Icon"] then btn.icon = _G[btnName .. "Icon"] end
    end

    -- Icon crop and zoom
    local icon = btn.icon or btn.Icon
    if icon then
        if btn.IconMask and icon.RemoveMaskTexture then icon:RemoveMaskTexture(btn.IconMask) end
        if gen.zoomIcons ~= false then
            icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        else
            icon:SetTexCoord(0, 1, 0, 1)
        end
        icon:ClearAllPoints()
        icon:SetAllPoints(btn)
    end

    -- De-mask cooldown textures
    if btn.IconMask then
        if btn.cooldown and btn.cooldown.RemoveMaskTexture then btn.cooldown:RemoveMaskTexture(btn.IconMask) end
        btn.IconMask:Hide()
    end

    -- Permanently suppress Blizzard rounded borders and quickslot textures
    local normal = (btnName and _G[btnName .. "NormalTexture"]) or btn.NormalTexture or (btn.GetNormalTexture and btn:GetNormalTexture())
    if normal then
        normal:SetTexture(nil)
        normal:SetAlpha(0)
        normal:Hide()
        if not normal._buiSuppressHooked then
            normal._buiSuppressHooked = true
            hooksecurefunc(normal, "SetVertexColor", function(self)
                if not self._buiSuppressing then
                    self._buiSuppressing = true
                    self:SetTexture(nil)
                    self:SetAlpha(0)
                    self:Hide()
                    self._buiSuppressing = false
                end
            end)
            hooksecurefunc(normal, "Show", function(self)
                if not self._buiSuppressing then
                    self._buiSuppressing = true
                    self:SetTexture(nil)
                    self:SetAlpha(0)
                    self:Hide()
                    self._buiSuppressing = false
                end
            end)
            hooksecurefunc(normal, "SetTexture", function(self, tex)
                if tex ~= nil and not self._buiSuppressing then
                    self._buiSuppressing = true
                    self:SetTexture(nil)
                    self:SetAlpha(0)
                    self:Hide()
                    self._buiSuppressing = false
                end
            end)
        end
    end
    local fbg = (btnName and _G[btnName .. "FloatingBG"]) or btn.FloatingBG
    if fbg then
        fbg:SetAlpha(0)
        fbg:Hide()
    end
    local border = (btnName and _G[btnName .. "Border"]) or btn.Border
    if border then
        border:SetAlpha(0)
        border:Hide()
    end

    -- Hotkey typography
    local hk = btn.HotKey
    if hk then
        if gen.hideKeybindText or barConfig.hideHotkey then
            hk:Hide()
        else
            local fontName = barConfig.hotkeyFont or gen.headerFont or C.FONT_HEADER
            local fontSize = barConfig.hotkeyFontSize or gen.hotkeyFontSize or 14
            local fontOutline = barConfig.fontOutline or gen.fontOutline or "OUTLINE"
            if fontOutline == "NONE" or fontOutline == "None" then fontOutline = "" end
            local fontFile = BAB:FetchFont(fontName)
            hk:SetFont(fontFile, fontSize, fontOutline)
            hk:ClearAllPoints()
            hk:SetPoint("TOPRIGHT", btn, "TOPRIGHT", -2, -3)

            local currentText = hk:GetText()
            if currentText and currentText ~= "" and currentText ~= RANGE_INDICATOR then
                local formatted = FormatHotkey(currentText)
                if formatted ~= "" and gen.abbreviateHotkey ~= false then
                    hk._buiFormatting = true
                    hk:SetText(formatted)
                    hk._buiFormatting = false
                end
                hk:Show()
            end
        end
    end

    -- Stack Count typography
    local cnt = btn.Count
    if cnt then
        if gen.hideCountText or barConfig.hideCount then
            cnt:Hide()
        else
            local fontName = barConfig.countFont or gen.headerFont or C.FONT_HEADER
            local fontSize = barConfig.countFontSize or gen.countFontSize or 14
            local fontOutline = barConfig.fontOutline or gen.fontOutline or "OUTLINE"
            if fontOutline == "NONE" or fontOutline == "None" then fontOutline = "" end
            local fontFile = BAB:FetchFont(fontName)
            cnt:SetFont(fontFile, fontSize, fontOutline)
            cnt:ClearAllPoints()
            cnt:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", -1, 1)
            cnt:Show()
        end
    end

    -- Macro Name typography
    local name = btn.Name
    if name then
        if gen.hideMacroText or barConfig.hideMacro then
            name:Hide()
        else
            local fontName = barConfig.macroFont or gen.font or C.FONT_DEFAULT
            local fontSize = barConfig.macroFontSize or gen.macroFontSize or 9
            local fontOutline = barConfig.fontOutline or gen.fontOutline or "OUTLINE"
            if fontOutline == "NONE" or fontOutline == "None" then fontOutline = "" end
            local fontFile = BAB:FetchFont(fontName)
            name:SetFont(fontFile, fontSize, fontOutline)
            name:ClearAllPoints()
            name:SetPoint("BOTTOM", btn, "BOTTOM", 0, 1)
            name:Show()
        end
    end

    if btn.backdrop then btn.backdrop:Show() end
end

function Core:SkinAllButtons()
    for barIdx = 1, 15 do
        for i = 1, 12 do
            local btn = GetOrCreatePlayerButton(barIdx, i)
            if btn then self:SkinButton(btn) end
        end
    end
    for i = 1, 10 do
        local btn = _G["PetActionButton" .. i]
        if btn then self:SkinButton(btn) end
    end
    for i = 1, 10 do
        local btn = _G["StanceButton" .. i]
        if btn then self:SkinButton(btn) end
    end
    if _G.ExtraActionButton1 then
        self:SkinButton(_G.ExtraActionButton1)
    end
    if _G.MainMenuBarVehicleLeaveButton then
        self:SkinButton(_G.MainMenuBarVehicleLeaveButton)
    end
end

--[[-----------------------------------------------------------------------------
    7. Layout Calculations & Containers
-------------------------------------------------------------------------------]]
local function GetBarDefaultPosition(barIndex)
    if barIndex == 1 then return "BOTTOM", 0, 28 end
    if barIndex == 2 then return "BOTTOM", 0, 68 end
    if barIndex == 3 then return "BOTTOM", 0, 108 end
    if barIndex == 4 then return "RIGHT", -4, 0 end
    if barIndex == 5 then return "RIGHT", -46, 0 end
    if barIndex == 6 then return "BOTTOM", 0, 148 end
    if barIndex == 7 then return "BOTTOM", 0, 188 end
    if barIndex == 8 then return "BOTTOM", 0, 228 end
    if barIndex == 9 then return "RIGHT", -88, 0 end
    if barIndex == 10 then return "RIGHT", -130, 0 end
    return "CENTER", 0, (barIndex - 11) * 44
end

function Core:CreateBarContainers()
    for i = 1, 15 do
        local key = "bar" .. i
        if not bars[key] then
            local b = CreateFrame("Frame", "BleakfibersActionBars_Bar" .. i, UIParent, "SecureHandlerStateTemplate")
            local point, x, y = GetBarDefaultPosition(i)
            b:SetPoint(point, UIParent, point, x, y)
            BAB:CreateBackdrop(b, 0.40, 1.0, C.COLOR_BG, C.COLOR_BORDER)
            self:RegisterMover(b, "Action Bar " .. i, "ActionBar" .. i, point, x, y)
            bars[key] = b
            self:SetupMouseoverFade(b, key)
        end
    end

    if not bars.petBar then
        local pb = CreateFrame("Frame", "BleakfibersActionBars_PetBar", UIParent, "SecureHandlerStateTemplate")
        pb:SetPoint("BOTTOM", UIParent, "BOTTOM", 0, 148)
        BAB:CreateBackdrop(pb, 0.40, 1.0, C.COLOR_BG, C.COLOR_BORDER)
        self:RegisterMover(pb, "Pet Action Bar", "PetBar", "BOTTOM", 0, 148)
        bars.petBar = pb
        self:SetupMouseoverFade(pb, "petBar")
    end

    if not bars.stanceBar then
        local sb = CreateFrame("Frame", "BleakfibersActionBars_StanceBar", UIParent, "SecureHandlerStateTemplate")
        sb:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", 280, 28)
        BAB:CreateBackdrop(sb, 0.40, 1.0, C.COLOR_BG, C.COLOR_BORDER)
        self:RegisterMover(sb, "Stance / Shapeshift Bar", "StanceBar", "BOTTOMLEFT", 280, 28)
        bars.stanceBar = sb
        self:SetupMouseoverFade(sb, "stanceBar")
    end

    if not bars.microBar then
        local mb = CreateFrame("Frame", "BleakfibersActionBars_MicroBar", UIParent, "SecureHandlerStateTemplate")
        mb:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", -4, 4)
        BAB:CreateBackdrop(mb, 0.40, 1.0, C.COLOR_BG, C.COLOR_BORDER)
        self:RegisterMover(mb, "Micro Menu Bar", "MicroBar", "BOTTOMRIGHT", -4, 4)
        bars.microBar = mb
        self:SetupMouseoverFade(mb, "microBar")
    end

    if not bars.extraBar then
        local eb = CreateFrame("Frame", "BleakfibersActionBars_ExtraBar", UIParent, "SecureHandlerStateTemplate")
        eb:SetSize(52, 52)
        eb:SetPoint("BOTTOM", UIParent, "BOTTOM", 0, 190)
        BAB:CreateBackdrop(eb, 0.40, 1.0, C.COLOR_BG, C.COLOR_BORDER)
        self:RegisterMover(eb, "Extra Action Button", "ExtraBar", "BOTTOM", 0, 190)
        bars.extraBar = eb
        self:SetupMouseoverFade(eb, "extraBar")
        eb:Hide()
    end

    if not bars.vehicleLeave then
        local vb = CreateFrame("Frame", "BleakfibersActionBars_VehicleLeaveBar", UIParent, "SecureHandlerStateTemplate")
        vb:SetSize(40, 40)
        vb:SetPoint("BOTTOM", UIParent, "BOTTOM", 140, 28)
        BAB:CreateBackdrop(vb, 0.40, 1.0, C.COLOR_BG, C.COLOR_BORDER)
        self:RegisterMover(vb, "Vehicle Exit Button", "VehicleLeave", "BOTTOM", 140, 28)
        bars.vehicleLeave = vb
        self:SetupMouseoverFade(vb, "vehicleLeave")
        vb:Hide()
    end

    if not bars.bagsBar then
        local bb = CreateFrame("Frame", "BleakfibersActionBars_BagsBar", UIParent, "SecureHandlerStateTemplate")
        bb:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", -4, 44)
        BAB:CreateBackdrop(bb, 0.40, 1.0, C.COLOR_BG, C.COLOR_BORDER)
        self:RegisterMover(bb, "Bags Bar", "BagsBar", "BOTTOMRIGHT", -4, 44)
        bars.bagsBar = bb
        self:SetupMouseoverFade(bb, "bagsBar")
    end

    if not bars.totemBar then
        local tb = CreateFrame("Frame", "BleakfibersActionBars_TotemBar", UIParent, "SecureHandlerStateTemplate")
        tb:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", 280, 70)
        BAB:CreateBackdrop(tb, 0.40, 1.0, C.COLOR_BG, C.COLOR_BORDER)
        self:RegisterMover(tb, "Totem Bar", "TotemBar", "BOTTOMLEFT", 280, 70)
        bars.totemBar = tb
        self:SetupMouseoverFade(tb, "totemBar")
    end
end

local function BuildBar1PageDriver(barConfig)
    barConfig = barConfig or {}
    local parts = {}

    -- Blizzard overrides & vehicles first
    table.insert(parts, "[overridebar] 14")
    table.insert(parts, "[vehicleui] 12")
    table.insert(parts, "[possessbar] 12")
    table.insert(parts, "[shapeshift] 13")

    -- Modifier paging (Shift, Ctrl, Alt)
    if barConfig.shiftPaging and barConfig.shiftPaging > 0 then
        table.insert(parts, "[mod:shift] " .. barConfig.shiftPaging)
    end
    if barConfig.ctrlPaging and barConfig.ctrlPaging > 0 then
        table.insert(parts, "[mod:ctrl] " .. barConfig.ctrlPaging)
    end
    if barConfig.altPaging and barConfig.altPaging > 0 then
        table.insert(parts, "[mod:alt] " .. barConfig.altPaging)
    end

    -- Class / Stance paging
    if barConfig.stancePaging ~= false then
        local _, class = UnitClass("player")
        if class == "DRUID" then
            table.insert(parts, "[bonusbar:1,stealth:1] 7")
            table.insert(parts, "[bonusbar:1] 7")
            table.insert(parts, "[bonusbar:2] 8")
            table.insert(parts, "[bonusbar:3] 9")
            table.insert(parts, "[bonusbar:4] 10")
        elseif class == "ROGUE" then
            table.insert(parts, "[bonusbar:1] 7")
            table.insert(parts, "[form:1] 7")
            table.insert(parts, "[form:2] 7")
            table.insert(parts, "[stealth] 7")
        elseif class == "WARRIOR" then
            table.insert(parts, "[bonusbar:1] 7")
            table.insert(parts, "[bonusbar:2] 8")
            table.insert(parts, "[bonusbar:3] 9")
        elseif class == "PRIEST" then
            table.insert(parts, "[bonusbar:1] 7")
        end
    end

    -- Default bar page state (page 1 through 6)
    table.insert(parts, "[bar:2] 2")
    table.insert(parts, "[bar:3] 3")
    table.insert(parts, "[bar:4] 4")
    table.insert(parts, "[bar:5] 5")
    table.insert(parts, "[bar:6] 6")
    table.insert(parts, "1")

    return table.concat(parts, "; ")
end

function Core:LayoutBar(barFrame, barKey, barConfig, defaultSize, defaultSpacing, buttonResolver, maxButtons)
    if not barFrame or not barConfig then return end
    if InCombatLockdown() then
        self._needsLayoutUpdate = true
        return
    end

    maxButtons = maxButtons or 12
    if not barConfig.enabled then
        barFrame:Hide()
        if barFrame._moverOverlay then
            barFrame._moverOverlay:Hide()
        end
        for i = 1, maxButtons do
            local btn = buttonResolver(i)
            if btn then
                btn:Hide()
                if btn.HotKey then btn.HotKey:Hide() end
                if btn.Count then btn.Count:Hide() end
                if btn.Name then btn.Name:Hide() end
            end
        end
        return
    end

    -- Page driver for Bar 1
    if barKey == "bar1" and not InCombatLockdown() then
        local pageDriver = BuildBar1PageDriver(barConfig)
        pcall(RegisterStateDriver, barFrame, "actionpage", pageDriver)
    end

    -- Custom visibility macro condition
    if not InCombatLockdown() then
        local vis = barConfig.visibilityCondition
        if vis and vis ~= "" and type(vis) == "string" then
            pcall(RegisterStateDriver, barFrame, "visibility", vis)
        else
            pcall(UnregisterStateDriver, barFrame, "visibility")
            barFrame:SetShown(barConfig.enabled ~= false)
        end
    end

    local size = barConfig.buttonSize or defaultSize
    local spacing = barConfig.buttonSpacing or defaultSpacing
    local numButtons = min(maxButtons, barConfig.numButtons or maxButtons)
    local isVertical = (barConfig.orientation == "VERTICAL")
    local perRow = isVertical and 1 or min(maxButtons, barConfig.buttonsPerRow or maxButtons)
    if perRow < 1 then perRow = 1 end

    local numRows = math.ceil(numButtons / perRow)
    local actualCols = min(numButtons, perRow)
    local width = (actualCols * size) + max(0, actualCols - 1) * spacing
    local height = (numRows * size) + max(0, numRows - 1) * spacing

    barFrame:SetSize(max(1, width), max(1, height))
    if barFrame._moverOverlay then
        barFrame._moverOverlay:SetSize(max(40, width), max(24, height))
    end
    barFrame:SetAlpha(((barConfig.alpha or 100) / 100))
    barFrame:SetScale(((barConfig.scale or 100) / 100))
    barFrame:SetFrameStrata(barConfig.frameStrata or "LOW")
    barFrame:SetFrameLevel(barConfig.frameLevel or 1)
    barFrame:EnableMouse(not barConfig.clickThrough)

    if barFrame.backdrop then
        barFrame.backdrop:SetShown(barConfig.backdrop ~= false)
    end

    barFrame:Show()

    local anchor = barConfig.anchorPoint or "BOTTOMLEFT"
    local showEmpty = (barConfig.showEmptyButtons ~= false)

    for i = 1, maxButtons do
        local btn = buttonResolver(i)
        if btn then
            if i <= numButtons then
                local row = math.floor((i - 1) / perRow)
                local col = (i - 1) % perRow
                local x, y

                if anchor == "TOPRIGHT" then
                    x = -col * (size + spacing)
                    y = -row * (size + spacing)
                    btn:ClearAllPoints()
                    btn:SetPoint("TOPRIGHT", barFrame, "TOPRIGHT", x, y)
                elseif anchor == "BOTTOMRIGHT" then
                    x = -col * (size + spacing)
                    y = row * (size + spacing)
                    btn:ClearAllPoints()
                    btn:SetPoint("BOTTOMRIGHT", barFrame, "BOTTOMRIGHT", x, y)
                elseif anchor == "TOPLEFT" then
                    x = col * (size + spacing)
                    y = -row * (size + spacing)
                    btn:ClearAllPoints()
                    btn:SetPoint("TOPLEFT", barFrame, "TOPLEFT", x, y)
                else -- BOTTOMLEFT
                    x = col * (size + spacing)
                    y = row * (size + spacing)
                    btn:ClearAllPoints()
                    btn:SetPoint("BOTTOMLEFT", barFrame, "BOTTOMLEFT", x, y)
                end

                btn:SetParent(barFrame)
                btn:SetSize(size, size)
                btn:EnableMouse(not barConfig.clickThrough)
                btn._barKey = barKey
                btn.flyoutDirection = barConfig.flyoutDirection or "UP"
                if barKey == "bar1" and not InCombatLockdown() then
                    btn:SetAttribute("useparent-actionpage", true)
                end
                self:SkinButton(btn)
                self:UpdateButtonVisuals(btn, barConfig)

                if showEmpty then
                    btn:SetAttribute("showgrid", 1)
                    if ActionButton_ShowGrid then ActionButton_ShowGrid(btn) end
                    btn:Show()
                else
                    btn:SetAttribute("showgrid", 0)
                    if ActionButton_HideGrid then ActionButton_HideGrid(btn) end
                    if btn.action and not HasAction(btn.action) then
                        btn:Hide()
                    else
                        btn:Show()
                    end
                end

                self:HookButtonMouseover(btn, barFrame, barKey)
            else
                btn:Hide()
            end
        end
    end
end

function Core:LayoutExtraBar()
    local barFrame = bars.extraBar
    if not barFrame then return end
    if InCombatLockdown() then
        self._needsLayoutUpdate = true
        return
    end

    local db = BleakfibersActionBarsDB
    local cfg = db and db.extraBar or {}

    if not cfg.enabled then
        barFrame:Hide()
        if barFrame._moverOverlay then
            barFrame._moverOverlay:Hide()
        end
        if ExtraActionBarFrame then ExtraActionBarFrame:Hide() end
        return
    end

    local scale = (cfg.scale or 100) / 100
    local alpha = (cfg.alpha or 100) / 100

    barFrame:SetScale(scale)
    barFrame:SetAlpha(alpha)
    barFrame:SetFrameStrata(cfg.frameStrata or "LOW")
    barFrame:SetFrameLevel(cfg.frameLevel or 1)
    barFrame:EnableMouse(not cfg.clickThrough)
    if barFrame.backdrop then
        barFrame.backdrop:SetShown(cfg.backdrop ~= false)
    end

    local extraFrame = _G.ExtraActionBarFrame
    local btn = _G.ExtraActionButton1
    if extraFrame then
        extraFrame:SetParent(barFrame)
        extraFrame:ClearAllPoints()
        extraFrame:SetPoint("CENTER", barFrame, "CENTER", 0, 0)
        if btn then
            btn:EnableMouse(not cfg.clickThrough)
            self:SkinButton(btn)
            self:UpdateButtonVisuals(btn, cfg)
        end
    end

    local isExtraActive = false
    if HasExtraActionBar and HasExtraActionBar() then
        isExtraActive = true
    elseif btn and btn.action and HasAction and HasAction(btn.action) then
        isExtraActive = true
    end

    if moversUnlocked then
        barFrame:Show()
        if extraFrame then extraFrame:Show() end
    elseif isExtraActive then
        barFrame:Show()
        if extraFrame then extraFrame:Show() end
    else
        barFrame:Hide()
        if extraFrame then extraFrame:Hide() end
    end
end

function Core:LayoutVehicleLeave()
    local barFrame = bars.vehicleLeave
    if not barFrame then return end
    if InCombatLockdown() then
        self._needsLayoutUpdate = true
        return
    end

    local db = BleakfibersActionBarsDB
    local cfg = db and db.vehicleLeave or {}

    if not cfg.enabled then
        barFrame:Hide()
        if barFrame._moverOverlay then
            barFrame._moverOverlay:Hide()
        end
        if MainMenuBarVehicleLeaveButton then MainMenuBarVehicleLeaveButton:Hide() end
        return
    end

    local scale = (cfg.scale or 100) / 100
    local alpha = (cfg.alpha or 100) / 100

    barFrame:SetScale(scale)
    barFrame:SetAlpha(alpha)
    barFrame:SetFrameStrata(cfg.frameStrata or "LOW")
    barFrame:SetFrameLevel(cfg.frameLevel or 1)
    barFrame:EnableMouse(not cfg.clickThrough)
    if barFrame.backdrop then
        barFrame.backdrop:SetShown(cfg.backdrop ~= false)
    end

    local leaveBtn = _G.MainMenuBarVehicleLeaveButton
    if leaveBtn then
        leaveBtn:SetParent(barFrame)
        leaveBtn:ClearAllPoints()
        leaveBtn:SetPoint("CENTER", barFrame, "CENTER", 0, 0)
        leaveBtn:EnableMouse(not cfg.clickThrough)
        self:SkinButton(leaveBtn)
        self:UpdateButtonVisuals(leaveBtn, cfg)
    end

    local inVehicle = false
    if CanExitVehicle and CanExitVehicle() then
        inVehicle = true
    elseif UnitInVehicle and UnitInVehicle("player") then
        inVehicle = true
    elseif UnitControllingVehicle and UnitControllingVehicle("player") then
        inVehicle = true
    elseif UnitHasVehicleUI and UnitHasVehicleUI("player") then
        inVehicle = true
    end

    if moversUnlocked then
        barFrame:Show()
        if leaveBtn then leaveBtn:Show() end
    elseif inVehicle then
        barFrame:Show()
        if leaveBtn then leaveBtn:Show() end
    else
        barFrame:Hide()
        if leaveBtn then leaveBtn:Hide() end
    end
end

function Core:UpdateAllBars()
    if InCombatLockdown() then
        self._needsLayoutUpdate = true
        return
    end

    local db = BleakfibersActionBarsDB
    if not db then return end

    local gen = db.general or {}
    local defaultSpacing = gen.spacing or 4
    local defaultSize = gen.buttonSize or 36

    for i = 1, 15 do
        local key = "bar" .. i
        local barFrame = bars[key]
        local barConfig = db[key]
        if barFrame and barConfig then
            self:LayoutBar(barFrame, key, barConfig, defaultSize, defaultSpacing, function(bIdx)
                return GetOrCreatePlayerButton(i, bIdx, barFrame)
            end, 12)
        end
    end

    if bars.petBar and db.petBar then
        self:LayoutBar(bars.petBar, "petBar", db.petBar, db.petBar.buttonSize or 28, db.petBar.buttonSpacing or defaultSpacing, function(bIdx)
            return _G["PetActionButton" .. bIdx]
        end, 10)
    end

    if bars.stanceBar and db.stanceBar then
        self:LayoutBar(bars.stanceBar, "stanceBar", db.stanceBar, db.stanceBar.buttonSize or 28, db.stanceBar.buttonSpacing or defaultSpacing, function(bIdx)
            return _G["StanceButton" .. bIdx]
        end, 10)
    end

    if bars.microBar and db.microBar then
        self:LayoutMicroBar()
    end

    if bars.extraBar and db.extraBar then
        self:LayoutExtraBar()
    end

    if bars.vehicleLeave and db.vehicleLeave then
        self:LayoutVehicleLeave()
    end

    if bars.bagsBar and db.bagsBar then
        self:LayoutBagsBar()
    end

    if bars.totemBar and db.totemBar then
        self:LayoutTotemBar()
    end

    self:ApplyCastOnKeyDown()

    self:ApplyCombatAlpha()
end

--[[-----------------------------------------------------------------------------
    8. MicroBar Support (1.60.1 MicroMenu and legacy fallback)
-------------------------------------------------------------------------------]]
function Core:GetActiveMicroButtons()
    local buttons = {}
    local seen = {}
    local maxButtons = 20

    local function IsMicroButtonValid(btn)
        if not btn then return false end
        if type(btn) == "string" then
            btn = _G[btn]
        end
        if not btn then return false end

        -- Must be a button frame
        if btn.IsObjectType and not (btn:IsObjectType("Button") or btn:IsObjectType("CheckButton")) then
            return false
        end

        local name = (btn.GetName and btn:GetName()) or ""

        -- Skip redundant SpellbookMicroButton if modern PlayerSpellsMicroButton exists
        if name == "SpellbookMicroButton" then
            local pSpells = _G["PlayerSpellsMicroButton"]
            if pSpells and pSpells.IsObjectType and pSpells:IsObjectType("Button") then
                if btn.Hide then btn:Hide() end
                return false
            end
        end

        -- Skip Blizzard Store micro buttons on WoW Forever (not applicable on private server)
        if name == "StoreMicroButton" or name == "AccountStoreMicroButton" or name == "ShopMicroButton" then
            if btn.Hide then btn:Hide() end
            return false
        end

        -- Check if button has a valid normal texture or icon
        local normal = (btn.GetNormalTexture and btn:GetNormalTexture()) or btn.icon or btn.Icon
        if not normal then
            if btn.Hide then btn:Hide() end
            return false
        end

        local tex = normal.GetTexture and normal:GetTexture()
        local atlas = normal.GetAtlas and normal:GetAtlas()

        -- If neither texture nor atlas is defined, button has no artwork
        if not tex and not atlas then
            if btn.Hide then btn:Hide() end
            return false
        end

        -- If texture is the engine fallback placeholder (red question mark: FileDataID 134400 or QuestionMark), reject
        if tex then
            if type(tex) == "number" and tex == 134400 then
                if btn.Hide then btn:Hide() end
                return false
            elseif type(tex) == "string" and tex:lower():find("questionmark") then
                if btn.Hide then btn:Hide() end
                return false
            end
        end

        return true
    end

    local function TryAddButton(btn)
        if #buttons >= maxButtons then return end
        if not btn then return end
        if type(btn) == "string" then
            btn = _G[btn]
        end
        if not btn or seen[btn] then return end

        if not IsMicroButtonValid(btn) then
            return
        end

        seen[btn] = true
        table.insert(buttons, btn)
    end

    -- 1. Standard Blizzard MICRO_BUTTONS array if available
    if type(_G.MICRO_BUTTONS) == "table" then
        for _, btnRef in ipairs(_G.MICRO_BUTTONS) do
            TryAddButton(btnRef)
        end
    end

    -- 2. Ordered canonical MicroButton candidates across WoW expansions
    local priorityList = {
        "CharacterMicroButton",
        "ProfessionMicroButton",
        "PlayerSpellsMicroButton",
        "SpellbookMicroButton",
        "TalentMicroButton",
        "AchievementMicroButton",
        "QuestLogMicroButton",
        "GuildMicroButton",
        "LFDMicroButton",
        "LFGMicroButton",
        "CollectionsMicroButton",
        "EJMicroButton",
        "GarrisonMicroButton",
        "OrderHallMicroButton",
        "CovenantMicroButton",
        "HousingMicroButton",
        "CommunityMicroButton",
        "CommunitiesMicroButton",
        "RaidMicroButton",
        "StoreMicroButton",
        "MainMenuMicroButton",
        "HelpMicroButton",
    }
    for _, name in ipairs(priorityList) do
        TryAddButton(name)
    end

    -- 3. Containers and Edit Mode micro frame children
    local menuContainers = { _G.MicroMenu, _G.MicroMenuContainer, _G.MicroButtonAndBagsBar }
    for _, container in ipairs(menuContainers) do
        if container then
            if type(container.buttons) == "table" then
                for _, b in ipairs(container.buttons) do
                    TryAddButton(b)
                end
            end
            if container.GetChildren then
                local children = { container:GetChildren() }
                for _, child in ipairs(children) do
                    local cName = (child and child.GetName and child:GetName()) or ""
                    if cName:find("Micro") and (child.IsObjectType and (child:IsObjectType("Button") or child:IsObjectType("CheckButton"))) then
                        TryAddButton(child)
                    end
                end
            end
        end
    end

    return buttons
end

function Core:LayoutMicroBar()
    local barFrame = bars.microBar
    if not barFrame then return end
    if InCombatLockdown() then
        self._needsLayoutUpdate = true
        return
    end

    local db = BleakfibersActionBarsDB
    local cfg = db and db.microBar or {}
    local microMenu = _G.MicroMenu
    local buttons = self:GetActiveMicroButtons()

    if not cfg.enabled then
        barFrame:Hide()
        if barFrame._moverOverlay then
            barFrame._moverOverlay:Hide()
        end
        if microMenu then microMenu:Hide() end
        for _, btn in ipairs(buttons) do btn:Hide() end
        return
    end

    local maxButtons = 20
    local numButtons = min(maxButtons, cfg.numButtons or maxButtons)
    local perRow = min(maxButtons, cfg.buttonsPerRow or 20)
    if perRow < 1 then perRow = 1 end

    local btnWidth = cfg.buttonWidth or 28
    local btnHeight = cfg.buttonHeight or 36
    local spacing = cfg.buttonSpacing or 2

    local totalAvailable = #buttons
    if totalAvailable == 0 and not microMenu then return end

    local activeCount = min(totalAvailable, numButtons)
    local numRows = math.ceil(activeCount / perRow)
    local actualCols = min(activeCount, perRow)
    local width = (actualCols * btnWidth) + max(0, actualCols - 1) * spacing
    local height = (numRows * btnHeight) + max(0, numRows - 1) * spacing

    barFrame:SetSize(max(1, width), max(1, height))
    if barFrame._moverOverlay then
        barFrame._moverOverlay:SetSize(max(40, width), max(24, height))
    end
    barFrame:SetAlpha(((cfg.alpha or 100) / 100))
    barFrame:SetScale(((cfg.scale or 100) / 100))
    barFrame:SetFrameStrata(cfg.frameStrata or "LOW")
    barFrame:SetFrameLevel(cfg.frameLevel or 1)
    barFrame:EnableMouse(not cfg.clickThrough)

    if barFrame.backdrop then
        barFrame.backdrop:SetShown(cfg.backdrop ~= false)
    end
    barFrame:Show()

    for i = 1, totalAvailable do
        local btn = buttons[i]
        if i <= activeCount then
            local row = math.floor((i - 1) / perRow)
            local col = (i - 1) % perRow
            local x = col * (btnWidth + spacing)
            local y = (numRows - 1 - row) * (btnHeight + spacing)

            btn:ClearAllPoints()
            btn:SetPoint("BOTTOMLEFT", barFrame, "BOTTOMLEFT", x, y)
            btn:SetParent(barFrame)
            btn:SetSize(btnWidth, btnHeight)
            btn:EnableMouse(not cfg.clickThrough)

            -- Ensure micro button textures are visible and un-tinted
            if btn.backdrop then btn.backdrop:Hide() end
            local normal = btn.NormalTexture or (btn.GetNormalTexture and btn:GetNormalTexture())
            if normal then
                normal:SetAlpha(1)
                if normal.Show then normal:Show() end
            end
            btn:SetAlpha(1)
            btn:Show()
        else
            btn:Hide()
        end
    end

    if microMenu then
        if microMenu.BorderArt then
            pcall(microMenu.BorderArt.SetTexture, microMenu.BorderArt, nil)
            pcall(microMenu.BorderArt.SetAlpha, microMenu.BorderArt, 0)
            pcall(microMenu.BorderArt.Hide, microMenu.BorderArt)
        end
        if microMenu.BackgroundArt then
            pcall(microMenu.BackgroundArt.SetTexture, microMenu.BackgroundArt, nil)
            pcall(microMenu.BackgroundArt.SetAlpha, microMenu.BackgroundArt, 0)
            pcall(microMenu.BackgroundArt.Hide, microMenu.BackgroundArt)
        end
        microMenu:SetAlpha(0)
        microMenu:Hide()
        SuppressBlizzardFrame(microMenu)
    end

    if MainMenuBarPerformanceBarFrame then
        MainMenuBarPerformanceBarFrame:Hide()
    end
end

--[[-----------------------------------------------------------------------------
    8b. Dedicated Bags Bar Support
-------------------------------------------------------------------------------]]
function Core:GetActiveBagButtons()
    local db = BleakfibersActionBarsDB
    local cfg = db and db.bagsBar or {}
    local buttons = {}

    -- 1. Main backpack
    if cfg.showBackpack ~= false and _G.MainMenuBarBackpackButton then
        table.insert(buttons, _G.MainMenuBarBackpackButton)
    end

    -- 2. Character bags 0..3
    if cfg.showBagSlots ~= false then
        for i = 0, 3 do
            local b = _G["CharacterBag" .. i .. "Slot"]
            if b then
                table.insert(buttons, b)
            end
        end
    end

    -- 3. Reagent bag (if present)
    if cfg.showReagentBag ~= false and _G.CharacterReagentBag0Slot then
        table.insert(buttons, _G.CharacterReagentBag0Slot)
    end

    -- 4. Keyring (if present)
    if cfg.showKeyRing ~= false and _G.KeyRingButton then
        table.insert(buttons, _G.KeyRingButton)
    end

    return buttons
end

function Core:SkinBagButton(btn)
    if not btn then return end
    if not skinnedButtons[btn] then
        skinnedButtons[btn] = true

        BAB:CreateBackdrop(btn, 0.50, 1.0, C.COLOR_BG, C.COLOR_BORDER)

        local icon = btn.icon or (btn.GetName and _G[btn:GetName() .. "IconTexture"]) or btn.Icon
        if icon then
            icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
            icon:ClearAllPoints()
            icon:SetPoint("TOPLEFT", btn, "TOPLEFT", 1, -1)
            icon:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", -1, 1)
        end

        local normal = btn.GetNormalTexture and btn:GetNormalTexture()
        if normal then
            normal:SetTexture(nil)
            normal:SetAlpha(0)
            normal:Hide()
        end

        local pushed = btn.GetPushedTexture and btn:GetPushedTexture()
        if pushed then
            pushed:SetColorTexture(1, 1, 1, 0.15)
            pushed:SetAllPoints(btn)
        end

        local hl = btn.GetHighlightTexture and btn:GetHighlightTexture()
        if hl then
            hl:SetColorTexture(1, 1, 1, 0.12)
            hl:SetAllPoints(btn)
        end

        if btn.SlotHighlightTexture then
            btn.SlotHighlightTexture:SetTexture(nil)
            btn.SlotHighlightTexture:Hide()
        end

        if btn.SquareMask then
            btn.SquareMask:Hide()
        end

        if btn.CircleMask then
            btn.CircleMask:Hide()
        end
    end
end

local isPositioningBags = false
local bagLayoutQueued = false

local function QueueBagsBarLayout()
    if bagLayoutQueued or InCombatLockdown() then return end
    bagLayoutQueued = true
    C_Timer.After(0, function()
        bagLayoutQueued = false
        if not InCombatLockdown() and not isPositioningBags then
            local db = BleakfibersActionBarsDB
            if db and db.bagsBar and db.bagsBar.enabled ~= false and Core.LayoutBagsBar then
                Core:LayoutBagsBar()
            end
        end
    end)
end

local function HookBagButtonProtection(btn)
    if not btn or btn._buiProtectedHooked then return end
    btn._buiProtectedHooked = true

    hooksecurefunc(btn, "ClearAllPoints", function(self)
        if isPositioningBags or InCombatLockdown() then return end
        local db = BleakfibersActionBarsDB
        if db and db.bagsBar and db.bagsBar.enabled ~= false and bars.bagsBar then
            QueueBagsBarLayout()
        end
    end)

    hooksecurefunc(btn, "SetPoint", function(self)
        if isPositioningBags or InCombatLockdown() then return end
        local db = BleakfibersActionBarsDB
        if db and db.bagsBar and db.bagsBar.enabled ~= false and bars.bagsBar then
            local _, relTo = self:GetPoint()
            if relTo ~= bars.bagsBar then
                QueueBagsBarLayout()
            end
        end
    end)

    hooksecurefunc(btn, "SetParent", function(self, newParent)
        if isPositioningBags or InCombatLockdown() then return end
        local db = BleakfibersActionBarsDB
        if db and db.bagsBar and db.bagsBar.enabled ~= false and bars.bagsBar then
            if newParent ~= bars.bagsBar then
                QueueBagsBarLayout()
            end
        end
    end)
end

function Core:HookBlizzardBagsBar()
    local onLayout = function()
        if not InCombatLockdown() and not isPositioningBags then
            local db = BleakfibersActionBarsDB
            if db and db.bagsBar and db.bagsBar.enabled ~= false then
                QueueBagsBarLayout()
            end
        end
    end

    if _G.BagsBar and _G.BagsBar.Layout and not self._buiBagsBarLayoutHooked then
        self._buiBagsBarLayoutHooked = true
        hooksecurefunc(_G.BagsBar, "Layout", onLayout)
    end

    if _G.BagsBarMixin and _G.BagsBarMixin.Layout and not self._buiBagsBarMixinLayoutHooked then
        self._buiBagsBarMixinLayoutHooked = true
        hooksecurefunc(_G.BagsBarMixin, "Layout", onLayout)
    end

    if _G.MainMenuBarBagManager and _G.MainMenuBarBagManager.OnExpandBarChanged and not self._buiBagManagerHooked then
        self._buiBagManagerHooked = true
        hooksecurefunc(_G.MainMenuBarBagManager, "OnExpandBarChanged", onLayout)
    end

    if EventRegistry and EventRegistry.RegisterCallback and not self._buiExpandEventHooked then
        self._buiExpandEventHooked = true
        EventRegistry:RegisterCallback("MainMenuBarManager.OnExpandChanged", onLayout, self)
    end
end

function Core:LayoutBagsBar()
    local barFrame = bars.bagsBar
    if not barFrame then return end
    if InCombatLockdown() then
        self._needsLayoutUpdate = true
        return
    end

    local db = BleakfibersActionBarsDB
    local cfg = db and db.bagsBar or {}
    local bagsBarBlizz = _G.BagsBar

    if not cfg.enabled then
        barFrame:Hide()
        if barFrame._moverOverlay then
            barFrame._moverOverlay:Hide()
        end
        if bagsBarBlizz then bagsBarBlizz:Hide() end
        local buttons = self:GetActiveBagButtons()
        for _, btn in ipairs(buttons) do btn:Hide() end
        return
    end

    local buttons = self:GetActiveBagButtons()
    local numButtons = #buttons
    if numButtons == 0 then
        barFrame:Hide()
        return
    end

    if not moversUnlocked then
        self:ApplyMoverPosition("BagsBar", barFrame)
    end

    local isVertical = (cfg.orientation == "VERTICAL")
    local perRow = isVertical and 1 or min(numButtons, cfg.buttonsPerRow or 6)
    if perRow < 1 then perRow = 1 end

    local btnSize = cfg.buttonSize or 32
    local spacing = cfg.buttonSpacing or 4

    local numRows = math.ceil(numButtons / perRow)
    local actualCols = min(numButtons, perRow)
    local width = (actualCols * btnSize) + max(0, actualCols - 1) * spacing
    local height = (numRows * btnSize) + max(0, numRows - 1) * spacing

    barFrame:SetSize(max(1, width), max(1, height))
    if barFrame._moverOverlay then
        barFrame._moverOverlay:SetSize(max(40, width), max(24, height))
    end
    barFrame:SetAlpha(((cfg.alpha or 100) / 100))
    barFrame:SetScale(((cfg.scale or 100) / 100))
    barFrame:SetFrameStrata(cfg.frameStrata or "LOW")
    barFrame:SetFrameLevel(cfg.frameLevel or 1)
    barFrame:EnableMouse(not cfg.clickThrough)

    if barFrame.backdrop then
        barFrame.backdrop:SetShown(cfg.backdrop ~= false)
    end
    barFrame:Show()

    isPositioningBags = true
    for i = 1, numButtons do
        local btn = buttons[i]
        local row = math.floor((i - 1) / perRow)
        local col = (i - 1) % perRow
        local x = col * (btnSize + spacing)
        local y = (numRows - 1 - row) * (btnSize + spacing)

        btn:ClearAllPoints()
        btn:SetPoint("BOTTOMLEFT", barFrame, "BOTTOMLEFT", x, y)
        btn:SetParent(barFrame)
        btn:SetSize(btnSize, btnSize)
        btn:EnableMouse(not cfg.clickThrough)

        self:SkinBagButton(btn)
        self:HookButtonMouseover(btn, barFrame, "bagsBar")
        HookBagButtonProtection(btn)
        btn:SetAlpha(1)
        btn:Show()
    end
    isPositioningBags = false

    if bagsBarBlizz then
        if bagsBarBlizz.BorderArt then
            pcall(bagsBarBlizz.BorderArt.SetTexture, bagsBarBlizz.BorderArt, nil)
            pcall(bagsBarBlizz.BorderArt.SetAlpha, bagsBarBlizz.BorderArt, 0)
            pcall(bagsBarBlizz.BorderArt.Hide, bagsBarBlizz.BorderArt)
        end
        if bagsBarBlizz.BackgroundArt then
            pcall(bagsBarBlizz.BackgroundArt.SetTexture, bagsBarBlizz.BackgroundArt, nil)
            pcall(bagsBarBlizz.BackgroundArt.SetAlpha, bagsBarBlizz.BackgroundArt, 0)
            pcall(bagsBarBlizz.BackgroundArt.Hide, bagsBarBlizz.BackgroundArt)
        end
        bagsBarBlizz:SetAlpha(0)
        bagsBarBlizz:Hide()
        SuppressBlizzardFrame(bagsBarBlizz)
    end

    self:HookBlizzardBagsBar()
end

--[[-----------------------------------------------------------------------------
    8c. Shaman Totem Bar & Paladin Aura Support
-------------------------------------------------------------------------------]]
function Core:LayoutTotemBar()
    local barFrame = bars.totemBar
    if not barFrame then return end
    if InCombatLockdown() then
        self._needsLayoutUpdate = true
        return
    end

    local db = BleakfibersActionBarsDB
    local cfg = db and db.totemBar or {}

    if not cfg.enabled then
        barFrame:Hide()
        if barFrame._moverOverlay then barFrame._moverOverlay:Hide() end
        if MultiCastActionBarFrame then MultiCastActionBarFrame:Hide() end
        if TotemFrame then TotemFrame:Hide() end
        return
    end

    local scale = (cfg.scale or 100) / 100
    local alpha = (cfg.alpha or 100) / 100

    barFrame:SetScale(scale)
    barFrame:SetAlpha(alpha)
    barFrame:SetFrameStrata(cfg.frameStrata or "LOW")
    barFrame:SetFrameLevel(cfg.frameLevel or 1)
    barFrame:EnableMouse(not cfg.clickThrough)
    if barFrame.backdrop then
        barFrame.backdrop:SetShown(cfg.backdrop ~= false)
    end
    barFrame:Show()

    local btnSize = cfg.buttonSize or 30
    local spacing = cfg.buttonSpacing or 4

    if MultiCastActionBarFrame then
        MultiCastActionBarFrame:SetParent(barFrame)
        MultiCastActionBarFrame:ClearAllPoints()
        MultiCastActionBarFrame:SetPoint("BOTTOMLEFT", barFrame, "BOTTOMLEFT", 0, 0)
        MultiCastActionBarFrame:SetScale(1.0)
        MultiCastActionBarFrame:Show()

        local mcButtons = {
            _G.MultiCastRecallSpellButton,
            _G.MultiCastSummonSpellButton,
            _G.MultiCastSlotButton1,
            _G.MultiCastSlotButton2,
            _G.MultiCastSlotButton3,
            _G.MultiCastSlotButton4,
            _G.MultiCastActionButton1,
            _G.MultiCastActionButton2,
            _G.MultiCastActionButton3,
            _G.MultiCastActionButton4,
        }
        for _, btn in ipairs(mcButtons) do
            if btn then
                self:SkinButton(btn)
                btn:SetSize(btnSize, btnSize)
                self:HookButtonMouseover(btn, barFrame, "totemBar")
            end
        end

        local totalWidth = (4 * btnSize) + (3 * spacing) + 30
        local totalHeight = btnSize + 4
        barFrame:SetSize(max(100, totalWidth), max(30, totalHeight))
        if barFrame._moverOverlay then
            barFrame._moverOverlay:SetSize(max(100, totalWidth), max(30, totalHeight))
        end
    elseif TotemFrame then
        TotemFrame:SetParent(barFrame)
        TotemFrame:ClearAllPoints()
        TotemFrame:SetPoint("BOTTOMLEFT", barFrame, "BOTTOMLEFT", 0, 0)
        TotemFrame:Show()
        barFrame:SetSize(128, 40)
        if barFrame._moverOverlay then
            barFrame._moverOverlay:SetSize(128, 40)
        end
    end
end

--[[-----------------------------------------------------------------------------
    8d. Cast On Key Down Support (ActionButtonUseKeyDown CVar)
-------------------------------------------------------------------------------]]
function Core:ApplyCastOnKeyDown()
    local db = BleakfibersActionBarsDB
    local useKeyDown = (db and db.general and db.general.castOnKeyDown ~= false)
    if SetCVar then
        pcall(SetCVar, "ActionButtonUseKeyDown", useKeyDown and "1" or "0")
    end

    local clickType = useKeyDown and "AnyDown" or "AnyUp"
    for btn in pairs(skinnedButtons) do
        if btn and btn.RegisterForClicks and not InCombatLockdown() then
            pcall(btn.RegisterForClicks, btn, clickType)
        end
    end
end

--[[-----------------------------------------------------------------------------
    9. Mouseover Fading & Out-of-Combat Alpha Transitions
-------------------------------------------------------------------------------]]
local function IsMouseOverFrame(frame)
    if not frame then return false end
    if frame.IsMouseOver then return frame:IsMouseOver() end
    if MouseIsOver then return MouseIsOver(frame) end
    return false
end

local function GetBarRestingAlpha(barConfig, gen)
    local barAlpha = (barConfig.alpha or 100) / 100
    if InCombatLockdown() then
        return barAlpha
    end
    if barConfig.mouseover then
        return 0
    end
    if barConfig.inheritGlobalFade or (gen and gen.globalFade) then
        local gf = (gen and gen.globalFadeAlpha or 0) / 100
        return gf * barAlpha
    end
    if barConfig.fadeOutOfCombat then
        local ooc = (barConfig.outOfCombatAlpha or 35) / 100
        return ooc * barAlpha
    elseif gen and gen.fadeOutOfCombat then
        local ooc = (gen.outOfCombatAlpha or 0.35)
        return ooc * barAlpha
    end
    return barAlpha
end

function Core:HookButtonMouseover(btn, barFrame, barKey)
    if not btn or btn._buiMouseHooked then return end
    btn._buiMouseHooked = true

    btn:HookScript("OnEnter", function()
        local db = BleakfibersActionBarsDB
        local barConfig = db and db[barKey] or {}
        local gen = db and db.general or {}
        if not InCombatLockdown() then
            if barConfig.mouseover or barConfig.fadeOutOfCombat or barConfig.inheritGlobalFade or gen.mouseoverFade or gen.fadeOutOfCombat or gen.globalFade then
                barFrame:SetAlpha(((barConfig.alpha or 100) / 100))
            end
        end
    end)

    btn:HookScript("OnLeave", function()
        local db = BleakfibersActionBarsDB
        local barConfig = db and db[barKey] or {}
        local gen = db and db.general or {}
        if not InCombatLockdown() then
            C_Timer.After(0.05, function()
                if not IsMouseOverFrame(barFrame) then
                    barFrame:SetAlpha(GetBarRestingAlpha(barConfig, gen))
                end
            end)
        end
    end)
end

function Core:SetupMouseoverFade(barFrame, barKey)
    if not barFrame then return end
    barFrame:EnableMouse(true)
    barFrame:HookScript("OnEnter", function()
        local db = BleakfibersActionBarsDB
        local barConfig = db and db[barKey] or {}
        local gen = db and db.general or {}
        if not InCombatLockdown() then
            if barConfig.mouseover or barConfig.fadeOutOfCombat or barConfig.inheritGlobalFade or gen.mouseoverFade or gen.fadeOutOfCombat or gen.globalFade then
                barFrame:SetAlpha(((barConfig.alpha or 100) / 100))
            end
        end
    end)

    barFrame:HookScript("OnLeave", function()
        local db = BleakfibersActionBarsDB
        local barConfig = db and db[barKey] or {}
        local gen = db and db.general or {}
        if not InCombatLockdown() then
            C_Timer.After(0.05, function()
                if not IsMouseOverFrame(barFrame) then
                    barFrame:SetAlpha(GetBarRestingAlpha(barConfig, gen))
                end
            end)
        end
    end)
end

function Core:ApplyCombatAlpha()
    local db = BleakfibersActionBarsDB
    if not db then return end
    local gen = db.general or {}
    local inCombat = InCombatLockdown()

    for key, bar in pairs(bars) do
        local barConfig = db[key] or {}
        local barAlpha = (barConfig.alpha or 100) / 100
        if inCombat then
            bar:SetAlpha(barAlpha)
        elseif IsMouseOverFrame(bar) and (barConfig.mouseover or barConfig.fadeOutOfCombat or barConfig.inheritGlobalFade or gen.mouseoverFade or gen.fadeOutOfCombat or gen.globalFade) then
            bar:SetAlpha(barAlpha)
        else
            bar:SetAlpha(GetBarRestingAlpha(barConfig, gen))
        end
    end
end

--[[-----------------------------------------------------------------------------
    10. Range & Usability Indicators
-------------------------------------------------------------------------------]]
local function UpdateButtonColor(btn, checksRange, inRange)
    local db = BleakfibersActionBarsDB
    local gen = db and db.general or {}
    if not btn or not btn.icon then return end

    local action = btn.action
    if not action then return end

    if checksRange == nil then
        if btn.ChecksRange then checksRange = btn:ChecksRange()
        elseif ActionHasRange then checksRange = ActionHasRange(action) end
    end

    if inRange == nil and checksRange then
        if btn.InRange then inRange = btn:InRange()
        elseif IsActionInRange then inRange = IsActionInRange(action) end
    end

    if checksRange and (inRange == false or inRange == 0) then
        if gen.rangeDesaturate then
            btn.icon:SetDesaturated(true)
        else
            btn.icon:SetDesaturated(false)
        end
        local c = gen.rangeColor or { r = 0.8, g = 0.1, b = 0.1 }
        btn.icon:SetVertexColor(c.r, c.g, c.b)
    else
        btn.icon:SetDesaturated(false)
        local isUsable, notEnoughMana = true, false
        if IsUsableAction then isUsable, notEnoughMana = IsUsableAction(action) end
        if notEnoughMana then
            local c = gen.manaColor or { r = 0.2, g = 0.4, b = 0.9 }
            btn.icon:SetVertexColor(c.r, c.g, c.b)
        elseif isUsable then
            btn.icon:SetVertexColor(1, 1, 1)
        else
            local c = gen.unusableColor or { r = 0.4, g = 0.4, b = 0.4 }
            btn.icon:SetVertexColor(c.r, c.g, c.b)
        end
    end
end

function Core:HookIndicatorColors()
    if self._indicatorColorsHooked then return end
    self._indicatorColorsHooked = true

    if ActionButton_UpdateRangeIndicator then
        hooksecurefunc("ActionButton_UpdateRangeIndicator", function(btn, checksRange, inRange)
            UpdateButtonColor(btn, checksRange, inRange)
        end)
    end
    if ActionButtonMixin and ActionButtonMixin.UpdateRangeIndicator then
        hooksecurefunc(ActionButtonMixin, "UpdateRangeIndicator", function(btn, checksRange, inRange)
            UpdateButtonColor(btn, checksRange, inRange)
        end)
    end
    if ActionButton_UpdateUsable then
        hooksecurefunc("ActionButton_UpdateUsable", function(btn)
            UpdateButtonColor(btn)
        end)
    end
    if ActionButtonMixin and ActionButtonMixin.UpdateUsable then
        hooksecurefunc(ActionButtonMixin, "UpdateUsable", function(btn)
            UpdateButtonColor(btn)
        end)
    end
end

--[[-----------------------------------------------------------------------------
    11. Reactive Settings Observer
-------------------------------------------------------------------------------]]
function Core:OnSettingChanged(section, key, value)
    if section == "general" then
        if key == "buttonSize" or key == "spacing" then
            self:UpdateAllBars()
        elseif key == "fadeOutOfCombat" or key == "outOfCombatAlpha" or key == "mouseoverFade" or key == "globalFade" or key == "globalFadeAlpha" then
            self:ApplyCombatAlpha()
        elseif key == "lockPositions" then
            SetCVar("lockActionBars", value and "1" or "0")
        elseif key == "cooldownText" or key:find("cooldown") or key:find("Cooldown") then
            self:UpdateAllCooldownFonts()
        elseif key:find("Font") or key:find("Outline") or key == "font" or key == "fontOutline" or key:find("Text") or key == "abbreviateHotkey" or key == "zoomIcons" or key == "countFontSize" or key == "macroFontSize" then
            self:SkinAllButtons()
        elseif key == "castOnKeyDown" then
            self:ApplyCastOnKeyDown()
        elseif key == "procGlow" then
            for btn in pairs(skinnedButtons) do
                if btn then self:AdjustOverlayGlow(btn) end
            end
        elseif key == "rangeColor" or key == "manaColor" or key == "unusableColor" or key == "rangeDesaturate" then
            for barIdx = 1, 15 do
                for i = 1, 12 do
                    local btn = GetOrCreatePlayerButton(barIdx, i)
                    if btn then UpdateButtonColor(btn) end
                end
            end
        end
    else
        self:UpdateAllBars()
    end
end

--[[-----------------------------------------------------------------------------
    12. Event Dispatching & Initialization
-------------------------------------------------------------------------------]]
Core:RegisterEvent("PLAYER_ENTERING_WORLD")
Core:RegisterEvent("PLAYER_REGEN_DISABLED")
Core:RegisterEvent("PLAYER_REGEN_ENABLED")
Core:RegisterEvent("ACTIONBAR_SHOWGRID")
Core:RegisterEvent("ACTIONBAR_HIDEGRID")
Core:RegisterEvent("ACTIONBAR_PAGE_CHANGED")
Core:RegisterEvent("UPDATE_BONUS_ACTIONBAR")
Core:RegisterEvent("UPDATE_VEHICLE_ACTIONBAR")
Core:RegisterEvent("UPDATE_OVERRIDE_ACTIONBAR")
Core:RegisterEvent("UPDATE_EXTRA_ACTIONBAR")
Core:RegisterEvent("UNIT_ENTERED_VEHICLE")
Core:RegisterEvent("UNIT_EXITED_VEHICLE")
Core:RegisterEvent("UPDATE_SHAPESHIFT_FORM")
Core:RegisterEvent("UPDATE_POSSESS_BAR")
Core:RegisterEvent("PET_BAR_UPDATE")
Core:RegisterEvent("PLAYER_TOTEM_UPDATE")
Core:RegisterEvent("ADDON_LOADED")

Core:SetScript("OnEvent", function(self, event, ...)
    if event == "PLAYER_ENTERING_WORLD" then
        if Config and Config.InitDB then
            Config:InitDB()
        end
        self:CreateBarContainers()
        self:UpdateAllBars()
        self:HideBlizzardArt()
        self:SkinAllButtons()
        self:HookIndicatorColors()
        self:HookOverlayGlow()
        self:ApplyCastOnKeyDown()

        local gen = BleakfibersActionBarsDB and BleakfibersActionBarsDB.general
        if gen and gen.lockPositions ~= nil then
            SetCVar("lockActionBars", gen.lockPositions and "1" or "0")
        end
        self:UpdateAllCooldownFonts()

        if ActionButton_Update and not self._buiActionButtonUpdateHooked then
            self._buiActionButtonUpdateHooked = true
            hooksecurefunc("ActionButton_Update", function(btn)
                if btn then Core:UpdateButtonVisuals(btn) end
            end)
        end

        if ActionButton_ShowGrid and not self._buiShowGridHooked then
            self._buiShowGridHooked = true
            hooksecurefunc("ActionButton_ShowGrid", function(btn)
                if btn then Core:UpdateButtonVisuals(btn) end
            end)
        end

        if MainMenuBar_UpdateArt and not self._buiArtHooked then
            self._buiArtHooked = true
            hooksecurefunc("MainMenuBar_UpdateArt", function()
                Core:HideBlizzardArt()
            end)
        end

        if MainMenuBar_UpdateExperienceBars and not self._buiExpHooked then
            self._buiExpHooked = true
            hooksecurefunc("MainMenuBar_UpdateExperienceBars", function()
                Core:HideBlizzardArt()
            end)
        end

        if ExtraActionBar_Update and not self._buiExtraHooked then
            self._buiExtraHooked = true
            hooksecurefunc("ExtraActionBar_Update", function()
                Core:LayoutExtraBar()
            end)
        end

        if MainMenuBarVehicleLeaveButton and not self._buiVehicleHooked then
            self._buiVehicleHooked = true
            hooksecurefunc(MainMenuBarVehicleLeaveButton, "SetPoint", function(btn, _, parent)
                if parent ~= bars.vehicleLeave and not InCombatLockdown() then
                    Core:LayoutVehicleLeave()
                end
            end)
        end

        if EditModeManagerFrame and not self._buiEditModeHooked then
            self._buiEditModeHooked = true
            hooksecurefunc(EditModeManagerFrame, "UpdateLayoutInfo", function()
                if not InCombatLockdown() then
                    Core:HideBlizzardArt()
                end
            end)
        end

        if UpdateMicroButtonsParent and not self._buiMicroParentHooked then
            self._buiMicroParentHooked = true
            hooksecurefunc("UpdateMicroButtonsParent", function()
                Core:LayoutMicroBar()
            end)
        end

        if UpdateMicroButtons and not self._buiMicroUpdateHooked then
            self._buiMicroUpdateHooked = true
            hooksecurefunc("UpdateMicroButtons", function()
                Core:LayoutMicroBar()
            end)
        end

        if SpellFlyout and not self._buiFlyoutHooked then
            self._buiFlyoutHooked = true
            hooksecurefunc(SpellFlyout, "Toggle", function(flyout, flyoutID, parent)
                if SpellFlyout:IsShown() then
                    for i = 1, 30 do
                        local btn = _G["SpellFlyoutPopupButton" .. i]
                        if btn then Core:SkinButton(btn) end
                    end
                end
                if parent then
                    local db = BleakfibersActionBarsDB
                    local g = db and db.general or {}
                    local bKey = parent._barKey
                    local dir = parent.flyoutDirection or (bKey and db and db[bKey] and db[bKey].flyoutDirection) or (g and g.flyoutDirection) or "UP"
                    if flyout and flyout.SetDirection then
                        flyout:SetDirection(dir)
                    end
                end
            end)
        end
    elseif event == "PLAYER_REGEN_DISABLED" then
        self:ApplyCombatAlpha()
    elseif event == "PLAYER_REGEN_ENABLED" then
        self:ApplyCombatAlpha()
        if self._needsLayoutUpdate then
            self._needsLayoutUpdate = false
            self:UpdateAllBars()
        end
        if self._needsGridUpdate then
            self._needsGridUpdate = false
            self:UpdateGrid()
        end
    elseif event == "ACTIONBAR_SHOWGRID" then
        for barIdx = 1, 15 do
            for i = 1, 12 do
                local btn = GetOrCreatePlayerButton(barIdx, i)
                if btn and ActionButton_ShowGrid then
                    ActionButton_ShowGrid(btn)
                end
            end
        end
    elseif event == "ACTIONBAR_HIDEGRID" then
        local db = BleakfibersActionBarsDB
        for barIdx = 1, 15 do
            local key = "bar" .. barIdx
            local barConfig = db and db[key] or {}
            local show = (barConfig.showEmptyButtons ~= false)
            if not show then
                for i = 1, 12 do
                    local btn = GetOrCreatePlayerButton(barIdx, i)
                    if btn and ActionButton_HideGrid then
                        ActionButton_HideGrid(btn)
                    end
                end
            end
        end
    elseif event == "ACTIONBAR_PAGE_CHANGED" or event == "UPDATE_BONUS_ACTIONBAR" or event == "UPDATE_VEHICLE_ACTIONBAR" or event == "UPDATE_OVERRIDE_ACTIONBAR" or event == "UPDATE_SHAPESHIFT_FORM" or event == "UPDATE_POSSESS_BAR" or event == "UPDATE_EXTRA_ACTIONBAR" or event == "UNIT_ENTERED_VEHICLE" or event == "UNIT_EXITED_VEHICLE" then
        self:HideBlizzardArt()
        self:LayoutVehicleLeave()
        self:LayoutExtraBar()
        if self.LayoutTotemBar then self:LayoutTotemBar() end
        if self.LayoutBagsBar then self:LayoutBagsBar() end
        for i = 1, 12 do
            local btn = _G["ActionButton" .. i]
            if btn then self:UpdateButtonVisuals(btn) end
        end
    elseif event == "PET_BAR_UPDATE" then
        for i = 1, 10 do
            local btn = _G["PetActionButton" .. i]
            if btn then
                self:UpdateButtonVisuals(btn, BleakfibersActionBarsDB and BleakfibersActionBarsDB.petBar)
            end
        end
    elseif event == "PLAYER_TOTEM_UPDATE" then
        if self.LayoutTotemBar then self:LayoutTotemBar() end
    elseif event == "ADDON_LOADED" then
        local loadedAddon = ...
        if loadedAddon == "Blizzard_MicroMenu" or loadedAddon == "Blizzard_MainMenuBarBagButtons" then
            self:HideBlizzardArt()
            self:LayoutMicroBar()
            if self.HookBlizzardBagsBar then self:HookBlizzardBagsBar() end
            if self.LayoutBagsBar then self:LayoutBagsBar() end
            if self.LayoutTotemBar then self:LayoutTotemBar() end
        end
    end
end)

