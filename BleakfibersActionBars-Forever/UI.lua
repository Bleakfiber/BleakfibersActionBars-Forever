--[[
    Bleakfiber's Action Bars - UI.lua
    Presentation Layer: Dark Slate & Gold Theme, Widget Factory,
    Modular Tabbed Options Panel & Standalone Fallback Window
]]

local addonName, BAB = ...

local ADDON_NAME = "BleakfibersActionBars"
local FULL_TITLE = "Bleakfiber's Action Bars"

local UI = {}
BAB.UI = UI
_G["BleakfibersActionBarsUI"] = UI

local Config = setmetatable({}, {
    __index = function(_, k)
        local c = BAB.Config or _G["BleakfibersActionBarsConfig"]
        if c then return c[k] end
    end,
    __newindex = function(_, k, v)
        local c = BAB.Config or _G["BleakfibersActionBarsConfig"]
        if c then c[k] = v end
    end,
})

local _, playerClass = UnitClass("player")
local petClasses = { HUNTER = true, WARLOCK = true, MAGE = true }
local stanceClasses = { WARRIOR = true, DRUID = true, ROGUE = true, PRIEST = true, PALADIN = true }
local defaultPetEnabled = petClasses[playerClass] or false
local defaultStanceEnabled = stanceClasses[playerClass] or false

-- Visual Theme: Dark Slate & Gold Bevel
local COLORS = {
    bgSlate      = { 0.08, 0.10, 0.13, 0.96 }, -- Dark iron / slate main backdrop
    contentBg    = { 0.05, 0.06, 0.08, 0.94 }, -- Inset dark container
    goldBorder   = { 0.82, 0.68, 0.28, 1.00 }, -- Bright beveled gold border
    goldMuted    = { 0.50, 0.42, 0.20, 0.85 }, -- Secondary / inset gold border
    goldText     = { 1.00, 0.82, 0.25 },       -- #FFD140
    whiteText    = { 0.90, 0.92, 0.94 },
    dimText      = { 0.55, 0.58, 0.63 },
    tabNormal    = { 0.12, 0.14, 0.17, 0.65 },
    tabActive    = { 0.24, 0.21, 0.13, 0.95 },
}

local BACKDROP_TEMPLATE = BackdropTemplateMixin and "BackdropTemplate" or nil

local WINDOW_BACKDROP = {
    bgFile = "Interface\\Buttons\\WHITE8X8",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true,
    tileSize = 16,
    edgeSize = 16,
    insets = { left = 4, right = 4, top = 4, bottom = 4 }
}

local INSET_BACKDROP = {
    bgFile = "Interface\\Buttons\\WHITE8X8",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true,
    tileSize = 12,
    edgeSize = 12,
    insets = { left = 3, right = 3, top = 3, bottom = 3 }
}

-- Registry of UI widgets for live refresh
local registeredWidgets = {}

--[[-----------------------------------------------------------------------------
    Widget Factory: Checkbox
-------------------------------------------------------------------------------]]
function UI:CreateCheckbox(parent, name, labelText, x, y, getFunc, setFunc)
    local cb = CreateFrame("CheckButton", name, parent, "UICheckButtonTemplate")
    cb:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    cb.text = _G[name .. "Text"]
    if cb.text then
        cb.text:SetText(labelText)
        cb.text:SetFontObject("GameFontHighlight")
    end

    cb.getFunc = getFunc
    cb.setFunc = setFunc
    cb:SetChecked(getFunc and getFunc() or false)

    cb:SetScript("OnClick", function(self)
        if self.setFunc then
            self.setFunc(self:GetChecked())
        end
    end)

    table.insert(registeredWidgets, {
        type = "checkbox",
        frame = cb,
        update = function()
            if cb.getFunc then
                cb:SetChecked(cb.getFunc())
            end
        end,
    })

    return cb
end

--[[-----------------------------------------------------------------------------
    Widget Factory: Slider
-------------------------------------------------------------------------------]]
function UI:CreateSlider(parent, name, labelText, minVal, maxVal, step, x, y, getFunc, setFunc, formatStr)
    formatStr = formatStr or (step < 1 and "%.1f" or "%d")
    local slider = CreateFrame("Slider", name, parent, "OptionsSliderTemplate")
    slider:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    slider:SetMinMaxValues(minVal, maxVal)
    slider:SetValueStep(step)
    if slider.SetObeyStepNumbers then
        slider:SetObeyStepNumbers(true)
    end
    slider:SetWidth(180)

    local low = _G[name .. "Low"]
    if low then low:SetText(tostring(minVal)) end
    local high = _G[name .. "High"]
    if high then high:SetText(tostring(maxVal)) end

    slider.getFunc = getFunc
    slider.setFunc = setFunc
    slider.formatStr = formatStr
    slider.labelText = labelText

    local curVal = getFunc and getFunc() or minVal
    local titleText = _G[name .. "Text"]
    if titleText then
        titleText:SetText(labelText .. ": " .. string.format(formatStr, curVal))
    end
    slider:SetValue(curVal)

    slider:SetScript("OnValueChanged", function(self, val)
        val = math.floor(val / step + 0.5) * step
        local tt = _G[name .. "Text"]
        if tt then
            tt:SetText(self.labelText .. ": " .. string.format(self.formatStr, val))
        end
        if self.setFunc then
            self.setFunc(val)
        end
    end)

    table.insert(registeredWidgets, {
        type = "slider",
        frame = slider,
        update = function()
            if slider.getFunc then
                local v = slider.getFunc()
                slider:SetValue(v)
                local tt = _G[name .. "Text"]
                if tt then
                    tt:SetText(slider.labelText .. ": " .. string.format(slider.formatStr, v))
                end
            end
        end,
    })

    return slider
end

--[[-----------------------------------------------------------------------------
    Widget Factory: Dropdown
-------------------------------------------------------------------------------]]
function UI:CreateDropdown(parent, name, labelText, items, x, y, width, getFunc, setFunc)
    width = width or 150
    local label = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    label:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    label:SetText(labelText)
    label:SetTextColor(COLORS.goldText[1], COLORS.goldText[2], COLORS.goldText[3])

    local dd = CreateFrame("Frame", name, parent, "UIDropDownMenuTemplate")
    dd:SetPoint("TOPLEFT", label, "BOTTOMLEFT", -16, -2)
    UIDropDownMenu_SetWidth(dd, width)

    local function OnClick(self)
        UIDropDownMenu_SetSelectedValue(dd, self.value)
        UIDropDownMenu_SetText(dd, items[self.value] or tostring(self.value))
        if setFunc then
            setFunc(self.value)
        end
    end

    local function Init(self, level)
        local cur = getFunc and getFunc()
        for val, text in pairs(items) do
            local info = UIDropDownMenu_CreateInfo()
            info.text = text
            info.value = val
            info.func = OnClick
            info.checked = (val == cur)
            UIDropDownMenu_AddButton(info, level)
        end
    end

    UIDropDownMenu_Initialize(dd, Init)
    local curVal = getFunc and getFunc()
    UIDropDownMenu_SetSelectedValue(dd, curVal)
    UIDropDownMenu_SetText(dd, items[curVal] or tostring(curVal))

    table.insert(registeredWidgets, {
        type = "dropdown",
        frame = dd,
        update = function()
            local v = getFunc and getFunc()
            UIDropDownMenu_SetSelectedValue(dd, v)
            UIDropDownMenu_SetText(dd, items[v] or tostring(v))
        end,
    })

    return dd
end

--[[-----------------------------------------------------------------------------
    Widget Factory: Button
-------------------------------------------------------------------------------]]
function UI:CreateButton(parent, name, text, x, y, width, height, onClick)
    local btn = CreateFrame("Button", name, parent, BACKDROP_TEMPLATE)
    btn:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    btn:SetSize(width or 120, height or 24)
    btn:SetBackdrop(INSET_BACKDROP)
    btn:SetBackdropColor(unpack(COLORS.tabNormal))
    btn:SetBackdropBorderColor(unpack(COLORS.goldMuted))

    local label = btn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    label:SetPoint("CENTER", btn, "CENTER", 0, 0)
    label:SetText(text)
    btn.label = label

    btn:SetScript("OnEnter", function(self)
        self:SetBackdropColor(0.20, 0.22, 0.28, 0.95)
        self:SetBackdropBorderColor(unpack(COLORS.goldBorder))
        label:SetTextColor(COLORS.goldText[1], COLORS.goldText[2], COLORS.goldText[3])
    end)

    btn:SetScript("OnLeave", function(self)
        self:SetBackdropColor(unpack(COLORS.tabNormal))
        self:SetBackdropBorderColor(unpack(COLORS.goldMuted))
        label:SetTextColor(COLORS.whiteText[1], COLORS.whiteText[2], COLORS.whiteText[3])
    end)

    if onClick then
        btn:SetScript("OnClick", onClick)
    end

    return btn
end

--[[-----------------------------------------------------------------------------
    Widget Factory: Color Picker
-------------------------------------------------------------------------------]]
function UI:CreateColorPicker(parent, name, labelText, x, y, getFunc, setFunc)
    local frame = CreateFrame("Frame", name, parent)
    frame:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    frame:SetSize(160, 26)

    local swatch = CreateFrame("Button", name .. "Swatch", frame, BACKDROP_TEMPLATE)
    swatch:SetSize(20, 20)
    swatch:SetPoint("LEFT", frame, "LEFT", 0, 0)
    swatch:SetBackdrop(INSET_BACKDROP)
    swatch:SetBackdropBorderColor(unpack(COLORS.goldBorder))

    local colorTex = swatch:CreateTexture(nil, "ARTWORK")
    colorTex:SetPoint("TOPLEFT", swatch, "TOPLEFT", 2, -2)
    colorTex:SetPoint("BOTTOMRIGHT", swatch, "BOTTOMRIGHT", -2, 2)

    local cur = getFunc and getFunc() or { r = 1, g = 1, b = 1 }
    colorTex:SetColorTexture(cur.r or 1, cur.g or 1, cur.b or 1, 1)

    local label = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    label:SetPoint("LEFT", swatch, "RIGHT", 8, 0)
    label:SetText(labelText)

    swatch:SetScript("OnClick", function()
        local c = getFunc and getFunc() or { r = 1, g = 1, b = 1 }
        ColorPickerFrame.func = function()
            local r, g, b = ColorPickerFrame:GetColorRGB()
            colorTex:SetColorTexture(r, g, b, 1)
            if setFunc then setFunc({ r = r, g = g, b = b }) end
        end
        ColorPickerFrame.cancelFunc = function(prev)
            colorTex:SetColorTexture(c.r, c.g, c.b, 1)
            if setFunc then setFunc(c) end
        end
        ColorPickerFrame:SetColorRGB(c.r, c.g, c.b)
        ColorPickerFrame.hasOpacity = false
        ColorPickerFrame:Show()
    end)

    table.insert(registeredWidgets, {
        type = "color",
        frame = frame,
        update = function()
            local c = getFunc and getFunc() or { r = 1, g = 1, b = 1 }
            colorTex:SetColorTexture(c.r or 1, c.g or 1, c.b or 1, 1)
        end,
    })

    return frame
end

--[[-----------------------------------------------------------------------------
    Widget Factory: EditBox
-------------------------------------------------------------------------------]]
function UI:CreateEditBox(parent, name, labelText, x, y, width, getFunc, setFunc)
    width = width or 200
    local label = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    label:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    label:SetText(labelText)
    label:SetTextColor(COLORS.goldText[1], COLORS.goldText[2], COLORS.goldText[3])

    local eb = CreateFrame("EditBox", name, parent, BACKDROP_TEMPLATE)
    eb:SetPoint("TOPLEFT", label, "BOTTOMLEFT", 0, -4)
    eb:SetSize(width, 22)
    eb:SetAutoFocus(false)
    eb:SetFontObject("ChatFontNormal")
    eb:SetBackdrop(INSET_BACKDROP)
    eb:SetBackdropColor(unpack(COLORS.contentBg))
    eb:SetBackdropBorderColor(unpack(COLORS.goldMuted))
    eb:SetTextInsets(6, 6, 0, 0)

    local cur = getFunc and getFunc() or ""
    eb:SetText(cur)

    eb:SetScript("OnEnterPressed", function(self)
        self:ClearFocus()
        if setFunc then setFunc(self:GetText()) end
    end)
    eb:SetScript("OnEditFocusLost", function(self)
        if setFunc then setFunc(self:GetText()) end
    end)
    eb:SetScript("OnEscapePressed", function(self)
        self:ClearFocus()
        self:SetText(getFunc and getFunc() or "")
    end)

    table.insert(registeredWidgets, {
        type = "editbox",
        frame = eb,
        update = function()
            local v = getFunc and getFunc() or ""
            eb:SetText(v)
        end,
    })

    return eb
end

--[[-----------------------------------------------------------------------------
    Options Panel Layout (Tabbed)
-------------------------------------------------------------------------------]]
function UI:BuildOptions(parentContainer, isMasterHub)
    isMasterHub = isMasterHub or (parentContainer and parentContainer.isMasterHub) or false

    local realConfig = BAB.Config or _G["BleakfibersActionBarsConfig"]
    if realConfig and realConfig.InitDB then
        realConfig:InitDB()
    end

    registeredWidgets = {}

    local subtext = parentContainer:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    subtext:SetText("Configure action bars, pet and stance controls, layout grids and positioning.")
    subtext:SetTextColor(COLORS.dimText[1], COLORS.dimText[2], COLORS.dimText[3])

    -- Quick Keybind Button
    self:CreateButton(parentContainer, "BAB_HeaderKeybind", "Quick Keybind", 0, 0, 105, 22, function()
        if BAB.Core and BAB.Core.ToggleKeybindMode then
            BAB.Core:ToggleKeybindMode(true)
        end
    end)
    local btnKeybind = _G["BAB_HeaderKeybind"]
    btnKeybind:ClearAllPoints()
    btnKeybind:SetPoint("TOPRIGHT", parentContainer, "TOPRIGHT", -16, -10)

    if not isMasterHub then
        -- Standalone mode: Render standalone Header Title and local Toggle Movers button
        local header = parentContainer:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        header:SetPoint("TOPLEFT", parentContainer, "TOPLEFT", 16, -14)
        header:SetText(FULL_TITLE)
        header:SetTextColor(COLORS.goldText[1], COLORS.goldText[2], COLORS.goldText[3])

        self:CreateButton(parentContainer, "BAB_HeaderMovers", "Toggle Movers", 0, 0, 110, 22, function()
            if BAB.Core and BAB.Core.ToggleMovers then
                BAB.Core:ToggleMovers()
            end
        end)
        local btnMovers = _G["BAB_HeaderMovers"]
        btnMovers:ClearAllPoints()
        btnMovers:SetPoint("RIGHT", btnKeybind, "LEFT", -8, 0)
        btnMovers:Show()

        subtext:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, -4)
    else
        -- Master Hub mode: Hide local movers (handled by master hub title bar and content header)
        if _G["BAB_HeaderMovers"] then
            _G["BAB_HeaderMovers"]:Hide()
        end
        subtext:SetPoint("TOPLEFT", parentContainer, "TOPLEFT", 16, -12)
    end

    -- Sub-Tab Navigation Bar
    local tabsContainer = CreateFrame("Frame", nil, parentContainer)
    tabsContainer:SetHeight(28)
    tabsContainer:SetPoint("TOPLEFT", subtext, "BOTTOMLEFT", 0, -8)
    tabsContainer:SetPoint("RIGHT", parentContainer, "RIGHT", -16, 0)

    -- Inset Content Pane for Active Tab
    local tabContent = CreateFrame("Frame", nil, parentContainer, BACKDROP_TEMPLATE)
    tabContent:SetPoint("TOPLEFT", tabsContainer, "BOTTOMLEFT", 0, -6)
    tabContent:SetPoint("BOTTOMRIGHT", parentContainer, "BOTTOMRIGHT", -16, 12)
    tabContent:SetBackdrop(INSET_BACKDROP)
    tabContent:SetBackdropColor(unpack(COLORS.contentBg))
    tabContent:SetBackdropBorderColor(unpack(COLORS.goldMuted))

    -- ScrollFrame for Tab Content
    local scrollFrame = CreateFrame("ScrollFrame", "BleakActionBarsOptionsScrollFrame", tabContent, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", tabContent, "TOPLEFT", 8, -8)
    scrollFrame:SetPoint("BOTTOMRIGHT", tabContent, "BOTTOMRIGHT", -26, 8)

    local pWidth = parentContainer:GetWidth()
    local contentWidth = (pWidth and pWidth > 150) and (pWidth - 48) or 540
    local scrollChild = CreateFrame("Frame", nil, scrollFrame)
    scrollChild:SetSize(contentWidth, 750)
    scrollFrame:SetScrollChild(scrollChild)

    scrollFrame:SetScript("OnSizeChanged", function(self, width, height)
        if width and width > 60 then
            scrollChild:SetWidth(width - 24)
        end
    end)

    -- Tab definition and navigation
    local tabs = {
        { id = "general",   title = "General" },
        { id = "bars",      title = "Action Bars" },
        { id = "petBar",    title = "Pet Bar" },
        { id = "stanceBar", title = "Stance Bar" },
        { id = "microBar",  title = "Micro Menu" },
        { id = "extraBars", title = "Extras" },
    }

    local tabButtons = {}
    local tabPanes = {}

    local tabHeights = {
        general   = 1080,
        bars      = 940,
        petBar    = 780,
        stanceBar = 780,
        microBar  = 720,
        extraBars = 580,
    }

    local function ShowTab(tabID)
        scrollChild:SetHeight(tabHeights[tabID] or 900)
        scrollFrame:SetVerticalScroll(0)
        for _, t in ipairs(tabs) do
            local btn = tabButtons[t.id]
            local pane = tabPanes[t.id]
            if t.id == tabID then
                if btn then
                    btn:SetBackdropColor(unpack(COLORS.tabActive))
                    btn:SetBackdropBorderColor(unpack(COLORS.goldBorder))
                    btn.label:SetTextColor(COLORS.goldText[1], COLORS.goldText[2], COLORS.goldText[3])
                end
                if pane then pane:Show() end
            else
                if btn then
                    btn:SetBackdropColor(unpack(COLORS.tabNormal))
                    btn:SetBackdropBorderColor(unpack(COLORS.goldMuted))
                    btn.label:SetTextColor(COLORS.whiteText[1], COLORS.whiteText[2], COLORS.whiteText[3])
                end
                if pane then pane:Hide() end
            end
        end
    end

    local function LayoutTabButtons()
        local cWidth = tabsContainer:GetWidth()
        if not cWidth or cWidth < 200 then cWidth = 540 end
        local gap = 4
        local btnW = math.floor((cWidth - ((#tabs - 1) * gap)) / #tabs)
        if btnW > 92 then btnW = 92 end
        local curX = 0
        for _, t in ipairs(tabs) do
            local b = tabButtons[t.id]
            if b then
                b:SetSize(btnW, 24)
                b:ClearAllPoints()
                b:SetPoint("TOPLEFT", tabsContainer, "TOPLEFT", curX, 0)
            end
            curX = curX + btnW + gap
        end
    end

    tabsContainer:SetScript("OnSizeChanged", LayoutTabButtons)

    for _, t in ipairs(tabs) do
        local tID = t.id
        local btn = CreateFrame("Button", nil, tabsContainer, BACKDROP_TEMPLATE)
        btn:SetSize(86, 24)
        btn:SetBackdrop(INSET_BACKDROP)
        btn:SetBackdropColor(unpack(COLORS.tabNormal))
        btn:SetBackdropBorderColor(unpack(COLORS.goldMuted))

        local lbl = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        lbl:SetPoint("CENTER")
        lbl:SetText(t.title)
        btn.label = lbl

        btn:SetScript("OnClick", function() ShowTab(tID) end)
        tabButtons[tID] = btn

        -- Create pane container
        local pane = CreateFrame("Frame", nil, scrollChild)
        pane:SetAllPoints(scrollChild)
        pane:Hide()
        tabPanes[tID] = pane
    end

    LayoutTabButtons()

    local visPresets = {
        [""] = "Always Show",
        ["[combat] show; hide"] = "Combat Only",
        ["[mod:shift] show; hide"] = "Hold Shift",
        ["[vehicleui] hide; show"] = "Hide in Vehicle",
        ["[pet] show; hide"] = "Pet Active Only",
    }

    local flyoutItems = {
        ["UP"]    = "Up",
        ["DOWN"]  = "Down",
        ["LEFT"]  = "Left",
        ["RIGHT"] = "Right",
    }

    local strataItems = {
        ["BACKGROUND"] = "Background",
        ["LOW"]        = "Low",
        ["MEDIUM"]     = "Medium",
        ["HIGH"]       = "High",
        ["DIALOG"]     = "Dialog",
    }

    -- =========================================================================
    -- PANE 1: GENERAL SETTINGS
    -- =========================================================================
    local pGeneral = tabPanes["general"]
    local y = -10

    local hGeneral = pGeneral:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    hGeneral:SetPoint("TOPLEFT", pGeneral, "TOPLEFT", 12, y)
    hGeneral:SetText("Global Behavior & Toggles")
    hGeneral:SetTextColor(COLORS.goldText[1], COLORS.goldText[2], COLORS.goldText[3])
    y = y - 28

    self:CreateCheckbox(pGeneral, "BAB_CbEnable", "Enable Action Bars", 12, y,
        function() return Config:Get("general", "enabled", true) end,
        function(v) Config:Set("general", "enabled", v) end
    )
    self:CreateCheckbox(pGeneral, "BAB_CbZoomIcons", "Zoom & Crop Icons (Clean Square)", 230, y,
        function() return Config:Get("general", "zoomIcons", true) end,
        function(v) Config:Set("general", "zoomIcons", v) end
    )
    y = y - 32

    self:CreateCheckbox(pGeneral, "BAB_CbAbbrHotkeys", "Abbreviate Hotkey Text (S1, C1, A1)", 12, y,
        function() return Config:Get("general", "abbreviateHotkey", true) end,
        function(v) Config:Set("general", "abbreviateHotkey", v) end
    )
    self:CreateCheckbox(pGeneral, "BAB_CbLockActionBars", "Lock ActionBars (Shift-drag unlock)", 230, y,
        function() return Config:Get("general", "lockPositions", false) end,
        function(v) Config:Set("general", "lockPositions", v) end
    )
    y = y - 32

    self:CreateCheckbox(pGeneral, "BAB_CbHideKeybinds", "Hide Keybind Hotkey Text", 12, y,
        function() return Config:Get("general", "hideKeybindText", false) end,
        function(v) Config:Set("general", "hideKeybindText", v) end
    )
    self:CreateCheckbox(pGeneral, "BAB_CbHideMacro", "Hide Macro Name Text", 230, y,
        function() return Config:Get("general", "hideMacroText", false) end,
        function(v) Config:Set("general", "hideMacroText", v) end
    )
    y = y - 32

    self:CreateCheckbox(pGeneral, "BAB_CbHideCount", "Hide Stack Count Text", 12, y,
        function() return Config:Get("general", "hideCountText", false) end,
        function(v) Config:Set("general", "hideCountText", v) end
    )
    y = y - 40

    local hSliders = pGeneral:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    hSliders:SetPoint("TOPLEFT", pGeneral, "TOPLEFT", 12, y)
    hSliders:SetText("Sizes, Padding & Typography")
    hSliders:SetTextColor(COLORS.goldText[1], COLORS.goldText[2], COLORS.goldText[3])
    y = y - 32

    self:CreateSlider(pGeneral, "BAB_SlGlobalBtnSize", "Default Button Size", 20, 60, 1, 16, y,
        function() return Config:Get("general", "buttonSize", 36) end,
        function(v) Config:Set("general", "buttonSize", v) end
    )
    self:CreateSlider(pGeneral, "BAB_SlGlobalSpacing", "Default Spacing", 0, 16, 1, 230, y,
        function() return Config:Get("general", "spacing", 4) end,
        function(v) Config:Set("general", "spacing", v) end
    )
    y = y - 48

    self:CreateSlider(pGeneral, "BAB_SlHkFontSize", "Hotkey Font Size", 8, 24, 1, 16, y,
        function() return Config:Get("general", "hotkeyFontSize", 14) end,
        function(v) Config:Set("general", "hotkeyFontSize", v) end
    )
    self:CreateSlider(pGeneral, "BAB_SlCountFontSize", "Count Font Size", 8, 24, 1, 230, y,
        function() return Config:Get("general", "countFontSize", 14) end,
        function(v) Config:Set("general", "countFontSize", v) end
    )
    y = y - 48

    self:CreateSlider(pGeneral, "BAB_SlMacroFontSize", "Macro Font Size", 8, 20, 1, 16, y,
        function() return Config:Get("general", "macroFontSize", 10) end,
        function(v) Config:Set("general", "macroFontSize", v) end
    )
    y = y - 48

    local fontItems = {
        ["Nata Sans Regular"] = "Nata Sans Regular",
        ["Nata Sans Bold"] = "Nata Sans Bold",
        ["Nata Sans Medium"] = "Nata Sans Medium",
        ["Orbitron Regular"] = "Orbitron Regular",
        ["Orbitron Bold"] = "Orbitron Bold",
        ["Roboto Condensed Regular"] = "Roboto Condensed Regular",
        ["Roboto Condensed Bold"] = "Roboto Condensed Bold",
    }
    self:CreateDropdown(pGeneral, "BAB_DdFont", "Default Body Font", fontItems, 16, y, 160,
        function() return Config:Get("general", "font", "Nata Sans Regular") end,
        function(v) Config:Set("general", "font", v) end
    )
    self:CreateDropdown(pGeneral, "BAB_DdHkFont", "Header / Hotkey Font", fontItems, 230, y, 160,
        function() return Config:Get("general", "headerFont", "Nata Sans Bold") end,
        function(v) Config:Set("general", "headerFont", v) end
    )
    y = y - 52

    local hGlobalFade = pGeneral:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    hGlobalFade:SetPoint("TOPLEFT", pGeneral, "TOPLEFT", 12, y)
    hGlobalFade:SetText("Global Fade & Spell Flyouts")
    hGlobalFade:SetTextColor(COLORS.goldText[1], COLORS.goldText[2], COLORS.goldText[3])
    y = y - 28

    self:CreateCheckbox(pGeneral, "BAB_CbGlobalFade", "Enable Global Fade (All Bars)", 12, y,
        function() return Config:Get("general", "globalFade", false) end,
        function(v) Config:Set("general", "globalFade", v) end
    )
    self:CreateSlider(pGeneral, "BAB_SlGlobalFadeAlpha", "Global Fade Alpha (%)", 0, 90, 5, 230, y,
        function() return Config:Get("general", "globalFadeAlpha", 0) end,
        function(v) Config:Set("general", "globalFadeAlpha", v) end
    )
    y = y - 48

    self:CreateDropdown(pGeneral, "BAB_DdGlobalFlyout", "Default Flyout Direction", flyoutItems, 16, y, 160,
        function() return Config:Get("general", "flyoutDirection", "UP") end,
        function(v) Config:Set("general", "flyoutDirection", v) end
    )
    y = y - 52

    local hCooldown = pGeneral:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    hCooldown:SetPoint("TOPLEFT", pGeneral, "TOPLEFT", 12, y)
    hCooldown:SetText("Cooldown Display & Threshold Colors")
    hCooldown:SetTextColor(COLORS.goldText[1], COLORS.goldText[2], COLORS.goldText[3])
    y = y - 28

    self:CreateCheckbox(pGeneral, "BAB_CbCdText", "Display Numeric Cooldowns", 12, y,
        function() return Config:Get("general", "cooldownText", true) end,
        function(v) Config:Set("general", "cooldownText", v) end
    )
    self:CreateSlider(pGeneral, "BAB_SlCdFontSize", "Cooldown Font Size", 10, 32, 1, 230, y,
        function() return Config:Get("general", "cooldownFontSize", 16) end,
        function(v) Config:Set("general", "cooldownFontSize", v) end
    )
    y = y - 48

    self:CreateDropdown(pGeneral, "BAB_DdCdFont", "Cooldown Font", fontItems, 16, y, 160,
        function() return Config:Get("general", "cooldownFont", "Nata Sans Bold") end,
        function(v) Config:Set("general", "cooldownFont", v) end
    )
    y = y - 48

    self:CreateColorPicker(pGeneral, "BAB_ColCdLow", "Under 3s (<3s) Color", 16, y,
        function() return Config:Get("general", "cooldownLowColor", { r = 1.0, g = 0.2, b = 0.2 }) end,
        function(c) Config:Set("general", "cooldownLowColor", c) end
    )
    self:CreateColorPicker(pGeneral, "BAB_ColCdSec", "Seconds (<60s) Color", 220, y,
        function() return Config:Get("general", "cooldownSecColor", { r = 1.0, g = 0.9, b = 0.1 }) end,
        function(c) Config:Set("general", "cooldownSecColor", c) end
    )
    y = y - 46

    self:CreateColorPicker(pGeneral, "BAB_ColCdMin", "Minutes (<1h) Color", 16, y,
        function() return Config:Get("general", "cooldownMinColor", { r = 1.0, g = 1.0, b = 1.0 }) end,
        function(c) Config:Set("general", "cooldownMinColor", c) end
    )
    self:CreateColorPicker(pGeneral, "BAB_ColCdHour", "Hours / Days Color", 220, y,
        function() return Config:Get("general", "cooldownHourColor", { r = 0.7, g = 0.7, b = 0.7 }) end,
        function(c) Config:Set("general", "cooldownHourColor", c) end
    )
    y = y - 50

    local hColors = pGeneral:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    hColors:SetPoint("TOPLEFT", pGeneral, "TOPLEFT", 12, y)
    hColors:SetText("Range & Usability Colors")
    hColors:SetTextColor(COLORS.goldText[1], COLORS.goldText[2], COLORS.goldText[3])
    y = y - 26

    self:CreateColorPicker(pGeneral, "BAB_ColRange", "Out of Range Color", 16, y,
        function() return Config:Get("general", "rangeColor", { r = 0.8, g = 0.1, b = 0.1 }) end,
        function(c) Config:Set("general", "rangeColor", c) end
    )
    self:CreateColorPicker(pGeneral, "BAB_ColMana", "Out of Mana Color", 220, y,
        function() return Config:Get("general", "manaColor", { r = 0.2, g = 0.4, b = 0.9 }) end,
        function(c) Config:Set("general", "manaColor", c) end
    )
    y = y - 46

    self:CreateColorPicker(pGeneral, "BAB_ColUnusable", "Not Usable Color", 16, y,
        function() return Config:Get("general", "unusableColor", { r = 0.4, g = 0.4, b = 0.4 }) end,
        function(c) Config:Set("general", "unusableColor", c) end
    )
    self:CreateCheckbox(pGeneral, "BAB_CbRangeDesat", "Desaturate Out of Range", 220, y,
        function() return Config:Get("general", "rangeDesaturate", false) end,
        function(v) Config:Set("general", "rangeDesaturate", v) end
    )
    y = y - 46

    local hKeybinds = pGeneral:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    hKeybinds:SetPoint("TOPLEFT", pGeneral, "TOPLEFT", 12, y)
    hKeybinds:SetText("Keybinding & Positioning Tools")
    hKeybinds:SetTextColor(COLORS.goldText[1], COLORS.goldText[2], COLORS.goldText[3])
    y = y - 28

    self:CreateButton(pGeneral, "BAB_BtnLaunchKeybindGeneral", "Quick Keybind Mode", 16, y, 160, 26, function()
        if BAB.Core and BAB.Core.ToggleKeybindMode then
            BAB.Core:ToggleKeybindMode(true)
        end
    end)
    self:CreateButton(pGeneral, "BAB_BtnLaunchMoversGeneral", "Toggle Anchor Movers", 186, y, 160, 26, function()
        if BAB.Core and BAB.Core.ToggleMovers then
            BAB.Core:ToggleMovers()
        end
    end)

    -- =========================================================================
    -- PANE 2: ACTION BARS 1 THROUGH 15
    -- =========================================================================
    local pBars = tabPanes["bars"]
    local selectedBarIndex = 1

    local barSelectorLabel = pBars:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    barSelectorLabel:SetPoint("TOPLEFT", pBars, "TOPLEFT", 12, -10)
    barSelectorLabel:SetText("Select Action Bar to Configure:")
    barSelectorLabel:SetTextColor(COLORS.goldText[1], COLORS.goldText[2], COLORS.goldText[3])

    local barBtnX = 12
    local barBtnY = -28
    for b = 1, 15 do
        local barNum = b
        local bBtn = CreateFrame("Button", nil, pBars, BACKDROP_TEMPLATE)
        bBtn:SetPoint("TOPLEFT", pBars, "TOPLEFT", barBtnX, barBtnY)
        bBtn:SetSize(28, 22)
        bBtn:SetBackdrop(INSET_BACKDROP)
        if b == 1 then
            bBtn:SetBackdropColor(unpack(COLORS.tabActive))
            bBtn:SetBackdropBorderColor(unpack(COLORS.goldBorder))
        else
            bBtn:SetBackdropColor(unpack(COLORS.tabNormal))
            bBtn:SetBackdropBorderColor(unpack(COLORS.goldMuted))
        end

        local bTxt = bBtn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        bTxt:SetPoint("CENTER")
        bTxt:SetText(tostring(b))
        bBtn.text = bTxt

        bBtn:SetScript("OnClick", function()
            selectedBarIndex = barNum
            for _, btn in pairs(pBars.selectorButtons) do
                btn:SetBackdropColor(unpack(COLORS.tabNormal))
                btn:SetBackdropBorderColor(unpack(COLORS.goldMuted))
            end
            bBtn:SetBackdropColor(unpack(COLORS.tabActive))
            bBtn:SetBackdropBorderColor(unpack(COLORS.goldBorder))
            UI:Refresh()
        end)

        pBars.selectorButtons = pBars.selectorButtons or {}
        pBars.selectorButtons[b] = bBtn

        barBtnX = barBtnX + 31
        if b == 8 then
            barBtnX = 12
            barBtnY = barBtnY - 25
        end
    end

    local function barKey() return "bar" .. selectedBarIndex end

    local barY = barBtnY - 34

    self:CreateCheckbox(pBars, "BAB_CbBarEnable", "Enable This Bar", 12, barY,
        function() return Config:Get(barKey(), "enabled", true) end,
        function(v) Config:Set(barKey(), "enabled", v) end
    )
    self:CreateCheckbox(pBars, "BAB_CbBarMouseover", "Mouseover Only", 160, barY,
        function() return Config:Get(barKey(), "mouseover", false) end,
        function(v) Config:Set(barKey(), "mouseover", v) end
    )
    self:CreateCheckbox(pBars, "BAB_CbBarFadeOOC", "Fade Out of Combat", 300, barY,
        function() return Config:Get(barKey(), "fadeOutOfCombat", false) end,
        function(v) Config:Set(barKey(), "fadeOutOfCombat", v) end
    )
    barY = barY - 32

    self:CreateCheckbox(pBars, "BAB_CbBarClickThrough", "Click-Through (Pass Clicks)", 12, barY,
        function() return Config:Get(barKey(), "clickThrough", false) end,
        function(v) Config:Set(barKey(), "clickThrough", v) end
    )
    self:CreateCheckbox(pBars, "BAB_CbBarInheritGF", "Inherit Global Fade", 230, barY,
        function() return Config:Get(barKey(), "inheritGlobalFade", false) end,
        function(v) Config:Set(barKey(), "inheritGlobalFade", v) end
    )
    barY = barY - 42

    self:CreateSlider(pBars, "BAB_SlBarOOCAlpha", "Out-of-Combat Alpha (%)", 0, 95, 5, 16, barY,
        function() return Config:Get(barKey(), "outOfCombatAlpha", 35) end,
        function(v) Config:Set(barKey(), "outOfCombatAlpha", v) end
    )
    self:CreateSlider(pBars, "BAB_SlBarAlpha", "Normal Alpha (%)", 10, 100, 5, 230, barY,
        function() return Config:Get(barKey(), "alpha", 100) end,
        function(v) Config:Set(barKey(), "alpha", v) end
    )
    barY = barY - 46

    self:CreateSlider(pBars, "BAB_SlBarScale", "Bar Scale (%)", 50, 200, 5, 16, barY,
        function() return Config:Get(barKey(), "scale", 100) end,
        function(v) Config:Set(barKey(), "scale", v) end
    )
    self:CreateSlider(pBars, "BAB_SlBarNumButtons", "Number of Buttons", 1, 12, 1, 230, barY,
        function() return Config:Get(barKey(), "numButtons", 12) end,
        function(v) Config:Set(barKey(), "numButtons", v) end
    )
    barY = barY - 46

    self:CreateSlider(pBars, "BAB_SlBarPerRow", "Buttons Per Row", 1, 12, 1, 16, barY,
        function() return Config:Get(barKey(), "buttonsPerRow", 12) end,
        function(v) Config:Set(barKey(), "buttonsPerRow", v) end
    )
    self:CreateSlider(pBars, "BAB_SlBarBtnSize", "Button Size", 20, 60, 1, 230, barY,
        function() return Config:Get(barKey(), "buttonSize", 36) end,
        function(v) Config:Set(barKey(), "buttonSize", v) end
    )
    barY = barY - 46

    self:CreateSlider(pBars, "BAB_SlBarSpacing", "Button Spacing", 0, 16, 1, 16, barY,
        function() return Config:Get(barKey(), "buttonSpacing", 4) end,
        function(v) Config:Set(barKey(), "buttonSpacing", v) end
    )
    self:CreateCheckbox(pBars, "BAB_CbBarBackdrop", "Show Bar Backdrop Frame", 230, barY,
        function() return Config:Get(barKey(), "backdrop", true) end,
        function(v) Config:Set(barKey(), "backdrop", v) end
    )
    barY = barY - 34

    self:CreateCheckbox(pBars, "BAB_CbBarEmpty", "Show Empty Buttons (Grid)", 12, barY,
        function() return Config:Get(barKey(), "showEmptyButtons", true) end,
        function(v) Config:Set(barKey(), "showEmptyButtons", v) end
    )
    barY = barY - 40

    local anchorItems = {
        ["BOTTOMLEFT"] = "Bottom Left",
        ["BOTTOMRIGHT"] = "Bottom Right",
        ["TOPLEFT"] = "Top Left",
        ["TOPRIGHT"] = "Top Right",
    }
    self:CreateDropdown(pBars, "BAB_DdBarAnchor", "Bar Anchor Point", anchorItems, 16, barY, 120,
        function() return Config:Get(barKey(), "anchorPoint", "BOTTOMLEFT") end,
        function(v) Config:Set(barKey(), "anchorPoint", v) end
    )
    self:CreateDropdown(pBars, "BAB_DdBarStrata", "Frame Strata", strataItems, 148, barY, 110,
        function() return Config:Get(barKey(), "frameStrata", "LOW") end,
        function(v) Config:Set(barKey(), "frameStrata", v) end
    )
    self:CreateDropdown(pBars, "BAB_DdBarFlyout", "Flyout Direction", flyoutItems, 270, barY, 110,
        function() return Config:Get(barKey(), "flyoutDirection", "UP") end,
        function(v) Config:Set(barKey(), "flyoutDirection", v) end
    )
    barY = barY - 48

    self:CreateSlider(pBars, "BAB_SlBarFrameLevel", "Frame Level", 1, 20, 1, 16, barY,
        function() return Config:Get(barKey(), "frameLevel", 1) end,
        function(v) Config:Set(barKey(), "frameLevel", v) end
    )
    barY = barY - 48

    self:CreateEditBox(pBars, "BAB_EbBarVis", "Custom Visibility Macro Condition", 16, barY, 240,
        function() return Config:Get(barKey(), "visibilityCondition", "") end,
        function(v) Config:Set(barKey(), "visibilityCondition", v) end
    )
    self:CreateDropdown(pBars, "BAB_DdBarVisPresets", "Visibility Presets", visPresets, 270, barY, 140,
        function() return Config:Get(barKey(), "visibilityCondition", "") end,
        function(v) Config:Set(barKey(), "visibilityCondition", v); UI:Refresh() end
    )
    barY = barY - 50

    -- Bar 1 Stance & Modifier Paging Container
    local pagingContainer = CreateFrame("Frame", nil, pBars)
    pagingContainer:SetPoint("TOPLEFT", pBars, "TOPLEFT", 0, barY)
    pagingContainer:SetSize(450, 95)
    pBars.pagingContainer = pagingContainer

    local hPaging = pagingContainer:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    hPaging:SetPoint("TOPLEFT", pagingContainer, "TOPLEFT", 12, 0)
    hPaging:SetText("Bar 1 Stance & Modifier Paging")
    hPaging:SetTextColor(COLORS.goldText[1], COLORS.goldText[2], COLORS.goldText[3])

    self:CreateCheckbox(pagingContainer, "BAB_CbStancePaging", "Enable Class / Stance Paging", 12, -22,
        function() return Config:Get("bar1", "stancePaging", true) end,
        function(v) Config:Set("bar1", "stancePaging", v) end
    )

    local pageItems = {
        [0] = "Disabled",
        [1] = "Page 1",
        [2] = "Page 2",
        [3] = "Page 3",
        [4] = "Page 4",
        [5] = "Page 5",
        [6] = "Page 6",
    }
    self:CreateDropdown(pagingContainer, "BAB_DdShiftPaging", "Shift Page", pageItems, 16, -56, 110,
        function() return Config:Get("bar1", "shiftPaging", 2) end,
        function(v) Config:Set("bar1", "shiftPaging", tonumber(v) or 0) end
    )
    self:CreateDropdown(pagingContainer, "BAB_DdCtrlPaging", "Ctrl Page", pageItems, 150, -56, 110,
        function() return Config:Get("bar1", "ctrlPaging", 3) end,
        function(v) Config:Set("bar1", "ctrlPaging", tonumber(v) or 0) end
    )
    self:CreateDropdown(pagingContainer, "BAB_DdAltPaging", "Alt Page", pageItems, 284, -56, 110,
        function() return Config:Get("bar1", "altPaging", 4) end,
        function(v) Config:Set("bar1", "altPaging", tonumber(v) or 0) end
    )

    table.insert(registeredWidgets, {
        type = "pagingContainer",
        frame = pagingContainer,
        update = function()
            pagingContainer:SetShown(selectedBarIndex == 1)
        end,
    })

    barY = barY - 105

    -- Copy Settings Utility
    local hCopy = pBars:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    hCopy:SetPoint("TOPLEFT", pBars, "TOPLEFT", 12, barY)
    hCopy:SetText("Copy Configuration:")
    hCopy:SetTextColor(COLORS.goldText[1], COLORS.goldText[2], COLORS.goldText[3])

    self:CreateButton(pBars, "BAB_BtnCopyFromBar1", "Copy From Bar 1", 160, barY + 4, 130, 22, function()
        Config:CopyBarSettings("bar1", barKey())
    end)

    -- =========================================================================
    -- PANE 3: PET BAR
    -- =========================================================================
    local pPet = tabPanes["petBar"]
    local py = -10

    local hPet = pPet:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    hPet:SetPoint("TOPLEFT", pPet, "TOPLEFT", 12, py)
    hPet:SetText("Pet Action Bar Configuration")
    hPet:SetTextColor(COLORS.goldText[1], COLORS.goldText[2], COLORS.goldText[3])
    py = py - 26

    self:CreateCheckbox(pPet, "BAB_CbPetEnable", "Enable Pet Bar", 12, py,
        function() return Config:Get("petBar", "enabled", defaultPetEnabled) end,
        function(v) Config:Set("petBar", "enabled", v) end
    )
    self:CreateCheckbox(pPet, "BAB_CbPetMouseover", "Mouseover Only", 160, py,
        function() return Config:Get("petBar", "mouseover", false) end,
        function(v) Config:Set("petBar", "mouseover", v) end
    )
    self:CreateCheckbox(pPet, "BAB_CbPetFadeOOC", "Fade Out of Combat", 300, py,
        function() return Config:Get("petBar", "fadeOutOfCombat", false) end,
        function(v) Config:Set("petBar", "fadeOutOfCombat", v) end
    )
    py = py - 32

    self:CreateCheckbox(pPet, "BAB_CbPetClickThrough", "Click-Through (Pass Clicks)", 12, py,
        function() return Config:Get("petBar", "clickThrough", false) end,
        function(v) Config:Set("petBar", "clickThrough", v) end
    )
    self:CreateCheckbox(pPet, "BAB_CbPetInheritGF", "Inherit Global Fade", 230, py,
        function() return Config:Get("petBar", "inheritGlobalFade", false) end,
        function(v) Config:Set("petBar", "inheritGlobalFade", v) end
    )
    py = py - 42

    self:CreateSlider(pPet, "BAB_SlPetOOCAlpha", "Out-of-Combat Alpha (%)", 0, 95, 5, 16, py,
        function() return Config:Get("petBar", "outOfCombatAlpha", 35) end,
        function(v) Config:Set("petBar", "outOfCombatAlpha", v) end
    )
    self:CreateSlider(pPet, "BAB_SlPetAlpha", "Normal Alpha (%)", 10, 100, 5, 230, py,
        function() return Config:Get("petBar", "alpha", 100) end,
        function(v) Config:Set("petBar", "alpha", v) end
    )
    py = py - 46

    self:CreateSlider(pPet, "BAB_SlPetScale", "Pet Bar Scale (%)", 50, 200, 5, 16, py,
        function() return Config:Get("petBar", "scale", 100) end,
        function(v) Config:Set("petBar", "scale", v) end
    )
    self:CreateSlider(pPet, "BAB_SlPetPerRow", "Buttons Per Row", 1, 10, 1, 230, py,
        function() return Config:Get("petBar", "buttonsPerRow", 10) end,
        function(v) Config:Set("petBar", "buttonsPerRow", v) end
    )
    py = py - 46

    self:CreateSlider(pPet, "BAB_SlPetSize", "Button Size", 20, 50, 1, 16, py,
        function() return Config:Get("petBar", "buttonSize", 28) end,
        function(v) Config:Set("petBar", "buttonSize", v) end
    )
    self:CreateSlider(pPet, "BAB_SlPetSpacing", "Button Spacing", 0, 16, 1, 230, py,
        function() return Config:Get("petBar", "buttonSpacing", 4) end,
        function(v) Config:Set("petBar", "buttonSpacing", v) end
    )
    py = py - 46

    self:CreateCheckbox(pPet, "BAB_CbPetBackdrop", "Show Pet Bar Backdrop Frame", 12, py,
        function() return Config:Get("petBar", "backdrop", true) end,
        function(v) Config:Set("petBar", "backdrop", v) end
    )
    py = py - 40

    self:CreateDropdown(pPet, "BAB_DdPetStrata", "Frame Strata", strataItems, 16, py, 140,
        function() return Config:Get("petBar", "frameStrata", "LOW") end,
        function(v) Config:Set("petBar", "frameStrata", v) end
    )
    self:CreateSlider(pPet, "BAB_SlPetFrameLevel", "Frame Level", 1, 20, 1, 230, py,
        function() return Config:Get("petBar", "frameLevel", 1) end,
        function(v) Config:Set("petBar", "frameLevel", v) end
    )
    py = py - 48

    self:CreateEditBox(pPet, "BAB_EbPetVis", "Custom Visibility Macro Condition", 16, py, 240,
        function() return Config:Get("petBar", "visibilityCondition", "") end,
        function(v) Config:Set("petBar", "visibilityCondition", v) end
    )
    self:CreateDropdown(pPet, "BAB_DdPetVisPresets", "Visibility Presets", visPresets, 270, py, 140,
        function() return Config:Get("petBar", "visibilityCondition", "") end,
        function(v) Config:Set("petBar", "visibilityCondition", v); UI:Refresh() end
    )

    -- =========================================================================
    -- PANE 4: STANCE BAR
    -- =========================================================================
    local pStance = tabPanes["stanceBar"]
    local sy = -10

    local hStance = pStance:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    hStance:SetPoint("TOPLEFT", pStance, "TOPLEFT", 12, sy)
    hStance:SetText("Stance / Shapeshift Bar Configuration")
    hStance:SetTextColor(COLORS.goldText[1], COLORS.goldText[2], COLORS.goldText[3])
    sy = sy - 26

    self:CreateCheckbox(pStance, "BAB_CbStanceEnable", "Enable Stance Bar", 12, sy,
        function() return Config:Get("stanceBar", "enabled", defaultStanceEnabled) end,
        function(v) Config:Set("stanceBar", "enabled", v) end
    )
    self:CreateCheckbox(pStance, "BAB_CbStanceMouseover", "Mouseover Only", 160, sy,
        function() return Config:Get("stanceBar", "mouseover", false) end,
        function(v) Config:Set("stanceBar", "mouseover", v) end
    )
    self:CreateCheckbox(pStance, "BAB_CbStanceFadeOOC", "Fade Out of Combat", 300, sy,
        function() return Config:Get("stanceBar", "fadeOutOfCombat", false) end,
        function(v) Config:Set("stanceBar", "fadeOutOfCombat", v) end
    )
    sy = sy - 32

    self:CreateCheckbox(pStance, "BAB_CbStanceClickThrough", "Click-Through (Pass Clicks)", 12, sy,
        function() return Config:Get("stanceBar", "clickThrough", false) end,
        function(v) Config:Set("stanceBar", "clickThrough", v) end
    )
    self:CreateCheckbox(pStance, "BAB_CbStanceInheritGF", "Inherit Global Fade", 230, sy,
        function() return Config:Get("stanceBar", "inheritGlobalFade", false) end,
        function(v) Config:Set("stanceBar", "inheritGlobalFade", v) end
    )
    sy = sy - 42

    self:CreateSlider(pStance, "BAB_SlStanceOOCAlpha", "Out-of-Combat Alpha (%)", 0, 95, 5, 16, sy,
        function() return Config:Get("stanceBar", "outOfCombatAlpha", 35) end,
        function(v) Config:Set("stanceBar", "outOfCombatAlpha", v) end
    )
    self:CreateSlider(pStance, "BAB_SlStanceAlpha", "Normal Alpha (%)", 10, 100, 5, 230, sy,
        function() return Config:Get("stanceBar", "alpha", 100) end,
        function(v) Config:Set("stanceBar", "alpha", v) end
    )
    sy = sy - 46

    self:CreateSlider(pStance, "BAB_SlStanceScale", "Stance Bar Scale (%)", 50, 200, 5, 16, sy,
        function() return Config:Get("stanceBar", "scale", 100) end,
        function(v) Config:Set("stanceBar", "scale", v) end
    )
    self:CreateSlider(pStance, "BAB_SlStancePerRow", "Buttons Per Row", 1, 10, 1, 230, sy,
        function() return Config:Get("stanceBar", "buttonsPerRow", 10) end,
        function(v) Config:Set("stanceBar", "buttonsPerRow", v) end
    )
    sy = sy - 46

    self:CreateSlider(pStance, "BAB_SlStanceSize", "Button Size", 20, 50, 1, 16, sy,
        function() return Config:Get("stanceBar", "buttonSize", 28) end,
        function(v) Config:Set("stanceBar", "buttonSize", v) end
    )
    self:CreateSlider(pStance, "BAB_SlStanceSpacing", "Button Spacing", 0, 16, 1, 230, sy,
        function() return Config:Get("stanceBar", "buttonSpacing", 4) end,
        function(v) Config:Set("stanceBar", "buttonSpacing", v) end
    )
    sy = sy - 46

    self:CreateCheckbox(pStance, "BAB_CbStanceBackdrop", "Show Stance Bar Backdrop Frame", 12, sy,
        function() return Config:Get("stanceBar", "backdrop", true) end,
        function(v) Config:Set("stanceBar", "backdrop", v) end
    )
    sy = sy - 40

    self:CreateDropdown(pStance, "BAB_DdStanceStrata", "Frame Strata", strataItems, 16, sy, 140,
        function() return Config:Get("stanceBar", "frameStrata", "LOW") end,
        function(v) Config:Set("stanceBar", "frameStrata", v) end
    )
    self:CreateSlider(pStance, "BAB_SlStanceFrameLevel", "Frame Level", 1, 20, 1, 230, sy,
        function() return Config:Get("stanceBar", "frameLevel", 1) end,
        function(v) Config:Set("stanceBar", "frameLevel", v) end
    )
    sy = sy - 48

    self:CreateEditBox(pStance, "BAB_EbStanceVis", "Custom Visibility Macro Condition", 16, sy, 240,
        function() return Config:Get("stanceBar", "visibilityCondition", "") end,
        function(v) Config:Set("stanceBar", "visibilityCondition", v) end
    )
    self:CreateDropdown(pStance, "BAB_DdStanceVisPresets", "Visibility Presets", visPresets, 270, sy, 140,
        function() return Config:Get("stanceBar", "visibilityCondition", "") end,
        function(v) Config:Set("stanceBar", "visibilityCondition", v); UI:Refresh() end
    )

    -- =========================================================================
    -- PANE 5: MICRO BAR
    -- =========================================================================
    local pMicro = tabPanes["microBar"]
    local my = -10

    local hMicro = pMicro:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    hMicro:SetPoint("TOPLEFT", pMicro, "TOPLEFT", 12, my)
    hMicro:SetText("Micro Menu Bar Configuration")
    hMicro:SetTextColor(COLORS.goldText[1], COLORS.goldText[2], COLORS.goldText[3])
    my = my - 26

    self:CreateCheckbox(pMicro, "BAB_CbMicroEnable", "Enable Micro Menu Bar", 12, my,
        function() return Config:Get("microBar", "enabled", true) end,
        function(v) Config:Set("microBar", "enabled", v) end
    )
    self:CreateCheckbox(pMicro, "BAB_CbMicroMouseover", "Mouseover Only", 160, my,
        function() return Config:Get("microBar", "mouseover", false) end,
        function(v) Config:Set("microBar", "mouseover", v) end
    )
    self:CreateCheckbox(pMicro, "BAB_CbMicroFadeOOC", "Fade Out of Combat", 300, my,
        function() return Config:Get("microBar", "fadeOutOfCombat", false) end,
        function(v) Config:Set("microBar", "fadeOutOfCombat", v) end
    )
    my = my - 32

    self:CreateCheckbox(pMicro, "BAB_CbMicroClickThrough", "Click-Through (Pass Clicks)", 12, my,
        function() return Config:Get("microBar", "clickThrough", false) end,
        function(v) Config:Set("microBar", "clickThrough", v) end
    )
    self:CreateCheckbox(pMicro, "BAB_CbMicroInheritGF", "Inherit Global Fade", 230, my,
        function() return Config:Get("microBar", "inheritGlobalFade", false) end,
        function(v) Config:Set("microBar", "inheritGlobalFade", v) end
    )
    my = my - 42

    self:CreateSlider(pMicro, "BAB_SlMicroOOCAlpha", "Out-of-Combat Alpha (%)", 0, 95, 5, 16, my,
        function() return Config:Get("microBar", "outOfCombatAlpha", 35) end,
        function(v) Config:Set("microBar", "outOfCombatAlpha", v) end
    )
    self:CreateSlider(pMicro, "BAB_SlMicroAlpha", "Normal Alpha (%)", 10, 100, 5, 230, my,
        function() return Config:Get("microBar", "alpha", 100) end,
        function(v) Config:Set("microBar", "alpha", v) end
    )
    my = my - 46

    self:CreateSlider(pMicro, "BAB_SlMicroNumButtons", "Number of Buttons", 1, 20, 1, 16, my,
        function() return Config:Get("microBar", "numButtons", 20) end,
        function(v) Config:Set("microBar", "numButtons", v) end
    )
    self:CreateSlider(pMicro, "BAB_SlMicroPerRow", "Buttons Per Row", 1, 20, 1, 230, my,
        function() return Config:Get("microBar", "buttonsPerRow", 20) end,
        function(v) Config:Set("microBar", "buttonsPerRow", v) end
    )
    my = my - 46

    self:CreateSlider(pMicro, "BAB_SlMicroScale", "Micro Bar Scale (%)", 50, 200, 5, 16, my,
        function() return Config:Get("microBar", "scale", 100) end,
        function(v) Config:Set("microBar", "scale", v) end
    )
    self:CreateSlider(pMicro, "BAB_SlMicroSpacing", "Button Spacing", 0, 10, 1, 230, my,
        function() return Config:Get("microBar", "buttonSpacing", 2) end,
        function(v) Config:Set("microBar", "buttonSpacing", v) end
    )
    my = my - 46

    self:CreateSlider(pMicro, "BAB_SlMicroWidth", "Button Width", 16, 40, 1, 16, my,
        function() return Config:Get("microBar", "buttonWidth", 28) end,
        function(v) Config:Set("microBar", "buttonWidth", v) end
    )
    self:CreateSlider(pMicro, "BAB_SlMicroHeight", "Button Height", 20, 50, 1, 230, my,
        function() return Config:Get("microBar", "buttonHeight", 36) end,
        function(v) Config:Set("microBar", "buttonHeight", v) end
    )
    my = my - 46

    self:CreateCheckbox(pMicro, "BAB_CbMicroBackdrop", "Show Backdrop Frame", 16, my,
        function() return Config:Get("microBar", "backdrop", true) end,
        function(v) Config:Set("microBar", "backdrop", v) end
    )
    my = my - 40

    self:CreateDropdown(pMicro, "BAB_DdMicroStrata", "Frame Strata", strataItems, 16, my, 140,
        function() return Config:Get("microBar", "frameStrata", "LOW") end,
        function(v) Config:Set("microBar", "frameStrata", v) end
    )
    self:CreateSlider(pMicro, "BAB_SlMicroFrameLevel", "Frame Level", 1, 20, 1, 230, my,
        function() return Config:Get("microBar", "frameLevel", 1) end,
        function(v) Config:Set("microBar", "frameLevel", v) end
    )

    -- =========================================================================
    -- PANE 6: EXTRAS & MOVERS
    -- =========================================================================
    local pExtra = tabPanes["extraBars"]
    local ey = -10

    local hExtra = pExtra:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    hExtra:SetPoint("TOPLEFT", pExtra, "TOPLEFT", 12, ey)
    hExtra:SetText("Extra Action Button")
    hExtra:SetTextColor(COLORS.goldText[1], COLORS.goldText[2], COLORS.goldText[3])
    ey = ey - 26

    self:CreateCheckbox(pExtra, "BAB_CbExtraEnable", "Enable Extra Action Button Mover", 12, ey,
        function() return Config:Get("extraBar", "enabled", true) end,
        function(v) Config:Set("extraBar", "enabled", v) end
    )
    self:CreateCheckbox(pExtra, "BAB_CbExtraClickThrough", "Click-Through", 230, ey,
        function() return Config:Get("extraBar", "clickThrough", false) end,
        function(v) Config:Set("extraBar", "clickThrough", v) end
    )
    ey = ey - 38

    self:CreateSlider(pExtra, "BAB_SlExtraScale", "Extra Button Scale (%)", 50, 200, 5, 16, ey,
        function() return Config:Get("extraBar", "scale", 100) end,
        function(v) Config:Set("extraBar", "scale", v) end
    )
    self:CreateSlider(pExtra, "BAB_SlExtraAlpha", "Extra Button Alpha (%)", 10, 100, 5, 230, ey,
        function() return Config:Get("extraBar", "alpha", 100) end,
        function(v) Config:Set("extraBar", "alpha", v) end
    )
    ey = ey - 48

    local hVeh = pExtra:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    hVeh:SetPoint("TOPLEFT", pExtra, "TOPLEFT", 12, ey)
    hVeh:SetText("Vehicle Exit Button")
    hVeh:SetTextColor(COLORS.goldText[1], COLORS.goldText[2], COLORS.goldText[3])
    ey = ey - 26

    self:CreateCheckbox(pExtra, "BAB_CbVehEnable", "Enable Vehicle Exit Button Mover", 12, ey,
        function() return Config:Get("vehicleLeave", "enabled", true) end,
        function(v) Config:Set("vehicleLeave", "enabled", v) end
    )
    self:CreateCheckbox(pExtra, "BAB_CbVehClickThrough", "Click-Through", 230, ey,
        function() return Config:Get("vehicleLeave", "clickThrough", false) end,
        function(v) Config:Set("vehicleLeave", "clickThrough", v) end
    )
    ey = ey - 38

    self:CreateSlider(pExtra, "BAB_SlVehScale", "Vehicle Exit Scale (%)", 50, 200, 5, 16, ey,
        function() return Config:Get("vehicleLeave", "scale", 100) end,
        function(v) Config:Set("vehicleLeave", "scale", v) end
    )
    self:CreateSlider(pExtra, "BAB_SlVehAlpha", "Vehicle Exit Alpha (%)", 10, 100, 5, 230, ey,
        function() return Config:Get("vehicleLeave", "alpha", 100) end,
        function(v) Config:Set("vehicleLeave", "alpha", v) end
    )
    ey = ey - 48

    local hMovers = pExtra:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    hMovers:SetPoint("TOPLEFT", pExtra, "TOPLEFT", 12, ey)
    hMovers:SetText("Mover Controls")
    hMovers:SetTextColor(COLORS.goldText[1], COLORS.goldText[2], COLORS.goldText[3])
    ey = ey - 28

    self:CreateButton(pExtra, "BAB_BtnToggleMoversExtra", "Unlock Movers", 16, ey, 120, 26, function()
        if BAB.Core and BAB.Core.ToggleMovers then
            BAB.Core:ToggleMovers()
        end
    end)
    self:CreateButton(pExtra, "BAB_BtnLockMoversExtra", "Lock Movers", 146, ey, 100, 26, function()
        if BAB.Core and BAB.Core.ToggleMovers then
            BAB.Core:ToggleMovers(false)
        end
    end)
    self:CreateButton(pExtra, "BAB_BtnResetMoversExtra", "Reset Positions", 256, ey, 120, 26, function()
        if BAB.Core and BAB.Core.ResetMovers then
            BAB.Core:ResetMovers()
        end
    end)

    -- Default show first tab
    ShowTab("general")
end


--[[-----------------------------------------------------------------------------
    Live Refresh
-------------------------------------------------------------------------------]]
function UI:Refresh()
    for _, widget in ipairs(registeredWidgets) do
        if widget.update then
            widget.update()
        end
    end
end

--[[-----------------------------------------------------------------------------
    Standalone Fallback Window (When Master Hub is not loaded)
-------------------------------------------------------------------------------]]
function UI:CreateStandaloneWindow()
    if self.standaloneFrame then return self.standaloneFrame end

    local f = CreateFrame("Frame", ADDON_NAME .. "StandaloneWindow", UIParent, BACKDROP_TEMPLATE)
    f:SetSize(760, 520)
    f:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    f:SetFrameStrata("HIGH")
    f:SetToplevel(true)
    f:SetClampedToScreen(true)
    f:EnableMouse(true)
    f:SetMovable(true)

    tinsert(UISpecialFrames, ADDON_NAME .. "StandaloneWindow")

    f:SetBackdrop(WINDOW_BACKDROP)
    f:SetBackdropColor(unpack(COLORS.bgSlate))
    f:SetBackdropBorderColor(unpack(COLORS.goldBorder))

    -- Title Bar (Drag Handle)
    local titleBar = CreateFrame("Frame", nil, f)
    titleBar:SetHeight(32)
    titleBar:SetPoint("TOPLEFT", f, "TOPLEFT", 6, -6)
    titleBar:SetPoint("TOPRIGHT", f, "TOPRIGHT", -32, -6)
    titleBar:EnableMouse(true)
    titleBar:RegisterForDrag("LeftButton")
    titleBar:SetScript("OnDragStart", function() f:StartMoving() end)
    titleBar:SetScript("OnDragStop", function() f:StopMovingOrSizing() end)

    local title = titleBar:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("LEFT", titleBar, "LEFT", 10, 0)
    title:SetText("|cFFFFD100" .. FULL_TITLE .. "|r")

    local closeBtn = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    closeBtn:SetSize(28, 28)
    closeBtn:SetPoint("TOPRIGHT", f, "TOPRIGHT", -4, -4)
    closeBtn:SetScript("OnClick", function() f:Hide() end)

    -- Inset Content Container
    local content = CreateFrame("Frame", nil, f, BACKDROP_TEMPLATE)
    content:SetPoint("TOPLEFT", f, "TOPLEFT", 10, -38)
    content:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -10, 10)
    content:SetBackdrop(INSET_BACKDROP)
    content:SetBackdropColor(unpack(COLORS.contentBg))
    content:SetBackdropBorderColor(unpack(COLORS.goldMuted))

    self:BuildOptions(content, false)

    f:Hide()
    self.standaloneFrame = f
    return f
end

function UI:ToggleStandaloneWindow()
    local win = self:CreateStandaloneWindow()
    if win:IsShown() then
        win:Hide()
    else
        win:Show()
    end
end

