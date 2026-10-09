--[[
    Bleakfiber's Action Bars - Config.lua
    Data Layer: Database Defaults, Get/Set Accessors, Slash Commands & Hub Registration
]]

local addonName, BAB = ...

local ADDON_NAME = "BleakfibersActionBars"
local FULL_TITLE = "Bleakfiber's Action Bars"
local DISPLAY_TITLE = "Action Bars"

local Config = {}
BAB.Config = Config
_G["BleakfibersActionBarsConfig"] = Config

local _, playerClass = UnitClass("player")
local petClasses = { HUNTER = true, WARLOCK = true, MAGE = true }
local stanceClasses = { WARRIOR = true, DRUID = true, ROGUE = true, PRIEST = true, PALADIN = true }

local defaultPetEnabled = petClasses[playerClass] or false
local defaultStanceEnabled = stanceClasses[playerClass] or false

-- Database Defaults
local DB_DEFAULTS = {
    general = {
        enabled = true,
        buttonSize = 36,
        spacing = 4,
        fadeOutOfCombat = false,
        outOfCombatAlpha = 0.35,
        mouseoverFade = false,
        abbreviateHotkey = true,
        zoomIcons = true,
        font = "Nata Sans Regular",
        headerFont = "Nata Sans Bold",
        hotkeyFontSize = 14,
        countFontSize = 14,
        macroFontSize = 10,
        fontOutline = "OUTLINE",
        hideKeybindText = false,
        hideMacroText = false,
        hideCountText = false,
        lockPositions = false,
        rangeColor = { r = 0.8, g = 0.1, b = 0.1 },
        rangeDesaturate = false,
        manaColor = { r = 0.2, g = 0.4, b = 0.9 },
        unusableColor = { r = 0.4, g = 0.4, b = 0.4 },
        globalFade = false,
        globalFadeAlpha = 0,
        flyoutDirection = "UP",
        cooldownText = true,
        cooldownFont = "Nata Sans Bold",
        cooldownFontSize = 16,
        cooldownThresholdLow = 3,
        cooldownLowColor = { r = 1.0, g = 0.2, b = 0.2 },
        cooldownSecColor = { r = 1.0, g = 0.9, b = 0.1 },
        cooldownMinColor = { r = 1.0, g = 1.0, b = 1.0 },
        cooldownHourColor = { r = 0.7, g = 0.7, b = 0.7 },
        castOnKeyDown = true,
        cooldownPulse = true,
        cooldownPulseScale = 1.3,
        procGlow = true,
    },
    extraBar = {
        enabled = true,
        scale = 100,
        alpha = 100,
        backdrop = true,
        frameStrata = "LOW",
        frameLevel = 1,
        clickThrough = false,
        inheritGlobalFade = false,
    },
    vehicleLeave = {
        enabled = true,
        scale = 100,
        alpha = 100,
        backdrop = true,
        frameStrata = "LOW",
        frameLevel = 1,
        clickThrough = false,
        inheritGlobalFade = false,
    },
    stanceBar = {
        enabled = defaultStanceEnabled,
        orientation = "HORIZONTAL",
        buttonSize = 28,
        buttonSpacing = 4,
        buttonsPerRow = 10,
        mouseover = false,
        fadeOutOfCombat = false,
        outOfCombatAlpha = 35,
        alpha = 100,
        scale = 100,
        backdrop = true,
        frameStrata = "LOW",
        frameLevel = 1,
        clickThrough = false,
        inheritGlobalFade = false,
        visibilityCondition = "",
    },
    totemBar = {
        enabled = (playerClass == "SHAMAN"),
        orientation = "HORIZONTAL",
        buttonSize = 30,
        buttonSpacing = 4,
        alpha = 100,
        scale = 100,
        backdrop = true,
        frameStrata = "LOW",
        frameLevel = 1,
        clickThrough = false,
        inheritGlobalFade = false,
    },
    petBar = {
        enabled = defaultPetEnabled,
        buttonSize = 28,
        buttonSpacing = 4,
        buttonsPerRow = 10,
        mouseover = false,
        fadeOutOfCombat = false,
        outOfCombatAlpha = 35,
        alpha = 100,
        scale = 100,
        backdrop = true,
        frameStrata = "LOW",
        frameLevel = 1,
        clickThrough = false,
        inheritGlobalFade = false,
        visibilityCondition = "",
    },
    microBar = {
        enabled = true,
        numButtons = 20,
        buttonWidth = 28,
        buttonHeight = 36,
        buttonSpacing = 2,
        buttonsPerRow = 20,
        mouseover = false,
        fadeOutOfCombat = false,
        outOfCombatAlpha = 35,
        alpha = 100,
        scale = 100,
        backdrop = true,
        frameStrata = "LOW",
        frameLevel = 1,
        clickThrough = false,
        inheritGlobalFade = false,
    },
    bagsBar = {
        enabled = true,
        orientation = "HORIZONTAL",
        buttonsPerRow = 6,
        buttonSize = 32,
        buttonSpacing = 4,
        mouseover = false,
        fadeOutOfCombat = false,
        outOfCombatAlpha = 35,
        alpha = 100,
        scale = 100,
        backdrop = true,
        frameStrata = "LOW",
        frameLevel = 1,
        clickThrough = false,
        inheritGlobalFade = false,
        showBackpack = true,
        showBagSlots = true,
        showReagentBag = true,
        showKeyRing = true,
    },
    movers = {},
}

-- Bars 1 through 15 defaults
for i = 1, 15 do
    DB_DEFAULTS["bar" .. i] = {
        enabled = (i <= 5),
        numButtons = 12,
        buttonsPerRow = 12,
        buttonSize = 36,
        buttonSpacing = 4,
        mouseover = false,
        fadeOutOfCombat = false,
        outOfCombatAlpha = 35,
        showEmptyButtons = true,
        alpha = 100,
        scale = 100,
        backdrop = true,
        anchorPoint = "BOTTOMLEFT",
        frameStrata = "LOW",
        frameLevel = 1,
        clickThrough = false,
        inheritGlobalFade = false,
        flyoutDirection = "UP",
        visibilityCondition = "",
        stancePaging = (i == 1),
        shiftPaging = (i == 1 and 2 or 0),
        ctrlPaging = (i == 1 and 3 or 0),
        altPaging = (i == 1 and 4 or 0),
    }
end

Config.DEFAULTS = DB_DEFAULTS

--[[-----------------------------------------------------------------------------
    Deep Copy Utility
-------------------------------------------------------------------------------]]
local function DeepCopy(orig)
    if type(orig) ~= "table" then return orig end
    local copy = {}
    for k, v in pairs(orig) do
        if type(v) == "table" then
            copy[k] = DeepCopy(v)
        else
            copy[k] = v
        end
    end
    return copy
end

--[[-----------------------------------------------------------------------------
    Database Initialization & Multi-Profile Support
-------------------------------------------------------------------------------]]
local function EnsureProfileDefaults(profileTable)
    if type(profileTable) ~= "table" then return end
    for section, secDefaults in pairs(DB_DEFAULTS) do
        if type(secDefaults) == "table" then
            if type(profileTable[section]) ~= "table" then
                profileTable[section] = {}
            end
            for k, v in pairs(secDefaults) do
                if profileTable[section][k] == nil then
                    profileTable[section][k] = DeepCopy(v)
                end
            end
        elseif profileTable[section] == nil then
            profileTable[section] = secDefaults
        end
    end
end

function Config:InitDB()
    if type(BleakfibersActionBarsDB) ~= "table" then
        BleakfibersActionBarsDB = {}
    end

    -- Multi-profile initialization & automatic migration of flat settings
    if type(BleakfibersActionBarsDB.profiles) ~= "table" then
        local defaultProfile = {}
        for section, secDefaults in pairs(DB_DEFAULTS) do
            if BleakfibersActionBarsDB[section] ~= nil then
                defaultProfile[section] = DeepCopy(BleakfibersActionBarsDB[section])
            end
        end
        if BleakfibersActionBarsDB.movers ~= nil then
            defaultProfile.movers = DeepCopy(BleakfibersActionBarsDB.movers)
        end
        EnsureProfileDefaults(defaultProfile)

        BleakfibersActionBarsDB.profiles = {
            ["Default"] = defaultProfile
        }
        BleakfibersActionBarsDB.activeProfile = "Default"
    end

    local active = BleakfibersActionBarsDB.activeProfile or "Default"
    if not BleakfibersActionBarsDB.profiles[active] then
        BleakfibersActionBarsDB.profiles[active] = DeepCopy(DB_DEFAULTS)
    end
    EnsureProfileDefaults(BleakfibersActionBarsDB.profiles[active])

    -- Point active profile tables directly to root BleakfibersActionBarsDB for seamless backward compatibility
    for section in pairs(DB_DEFAULTS) do
        BleakfibersActionBarsDB[section] = BleakfibersActionBarsDB.profiles[active][section]
    end
    if not BleakfibersActionBarsDB.profiles[active].movers then
        BleakfibersActionBarsDB.profiles[active].movers = {}
    end
    BleakfibersActionBarsDB.movers = BleakfibersActionBarsDB.profiles[active].movers

    -- Wire reference to BAB.db for seamless access
    BAB.db = BleakfibersActionBarsDB
    if not BAB.db.profile then
        BAB.db.profile = {}
    end
    BAB.db.profile.actionbars = BleakfibersActionBarsDB
    BAB.db.profile.general = BleakfibersActionBarsDB.general
end

--[[-----------------------------------------------------------------------------
    Profile Accessors & Management
-------------------------------------------------------------------------------]]
function Config:GetActiveProfile()
    return (BleakfibersActionBarsDB and BleakfibersActionBarsDB.activeProfile) or "Default"
end

function Config:GetProfiles()
    local list = {}
    if BleakfibersActionBarsDB and BleakfibersActionBarsDB.profiles then
        for name in pairs(BleakfibersActionBarsDB.profiles) do
            table.insert(list, name)
        end
    end
    if #list == 0 then table.insert(list, "Default") end
    table.sort(list)
    return list
end

function Config:SetActiveProfile(name)
    if not name or name == "" then return end
    self:InitDB()

    if not BleakfibersActionBarsDB.profiles[name] then
        local current = self:GetActiveProfile()
        BleakfibersActionBarsDB.profiles[name] = DeepCopy(BleakfibersActionBarsDB.profiles[current] or DB_DEFAULTS)
    end
    EnsureProfileDefaults(BleakfibersActionBarsDB.profiles[name])
    BleakfibersActionBarsDB.activeProfile = name

    -- Re-link root section tables to the newly active profile
    for section in pairs(DB_DEFAULTS) do
        BleakfibersActionBarsDB[section] = BleakfibersActionBarsDB.profiles[name][section]
    end
    if not BleakfibersActionBarsDB.profiles[name].movers then
        BleakfibersActionBarsDB.profiles[name].movers = {}
    end
    BleakfibersActionBarsDB.movers = BleakfibersActionBarsDB.profiles[name].movers

    BAB.db = BleakfibersActionBarsDB
    if not BAB.db.profile then BAB.db.profile = {} end
    BAB.db.profile.actionbars = BleakfibersActionBarsDB
    BAB.db.profile.general = BleakfibersActionBarsDB.general

    -- Live re-apply all bars and movers
    if BAB.Core and BAB.Core.UpdateAllBars then
        BAB.Core:UpdateAllBars()
    end
    if BAB.Core and BAB.Core.ApplyAllMoverPositions then
        BAB.Core:ApplyAllMoverPositions()
    end
    if BAB.UI and BAB.UI.Refresh then
        BAB.UI:Refresh()
    end
end

function Config:SaveCurrentAs(name)
    if not name or name == "" then return end
    self:InitDB()
    local curActive = self:GetActiveProfile()
    BleakfibersActionBarsDB.profiles[name] = DeepCopy(BleakfibersActionBarsDB.profiles[curActive] or BleakfibersActionBarsDB or DB_DEFAULTS)
    EnsureProfileDefaults(BleakfibersActionBarsDB.profiles[name])
    self:SetActiveProfile(name)
end

function Config:CreateProfile(name, fromName)
    if not name or name == "" then return end
    self:InitDB()
    -- Never overwrite existing profile!
    if not BleakfibersActionBarsDB.profiles[name] then
        local source = fromName and BleakfibersActionBarsDB.profiles[fromName]
        if not source then
            local curActive = self:GetActiveProfile()
            source = BleakfibersActionBarsDB.profiles[curActive] or BleakfibersActionBarsDB or DB_DEFAULTS
        end
        BleakfibersActionBarsDB.profiles[name] = DeepCopy(source)
        EnsureProfileDefaults(BleakfibersActionBarsDB.profiles[name])
    end
    self:SetActiveProfile(name)
end

function Config:DeleteProfile(name)
    if not name or name == "Default" then return end
    self:InitDB()
    BleakfibersActionBarsDB.profiles[name] = nil
    if BleakfibersActionBarsDB.activeProfile == name then
        self:SetActiveProfile("Default")
    end
end

function Config:CopyProfile(fromName, toName)
    self:InitDB()
    if BleakfibersActionBarsDB.profiles[fromName] then
        BleakfibersActionBarsDB.profiles[toName] = DeepCopy(BleakfibersActionBarsDB.profiles[fromName])
        if BleakfibersActionBarsDB.activeProfile == toName then
            self:SetActiveProfile(toName)
        end
    end
end

function Config:ResetProfile(name)
    name = name or self:GetActiveProfile()
    self:InitDB()
    BleakfibersActionBarsDB.profiles[name] = DeepCopy(DB_DEFAULTS)
    if BleakfibersActionBarsDB.activeProfile == name then
        self:SetActiveProfile(name)
    end
end

--[[-----------------------------------------------------------------------------
    Database Accessors with Instant Auto-Save
-------------------------------------------------------------------------------]]
function Config:Get(section, key, default)
    if not BleakfibersActionBarsDB then return default end
    if section and key then
        local secTable = BleakfibersActionBarsDB[section]
        if secTable and secTable[key] ~= nil then
            return secTable[key]
        end
    elseif section and not key then
        if BleakfibersActionBarsDB[section] ~= nil then
            return BleakfibersActionBarsDB[section]
        end
    end
    return default
end

function Config:Set(section, key, value)
    if not BleakfibersActionBarsDB then
        self:InitDB()
    end

    local activeProf = self:GetActiveProfile()
    local profTable = BleakfibersActionBarsDB.profiles and BleakfibersActionBarsDB.profiles[activeProf]

    if section and key then
        if type(BleakfibersActionBarsDB[section]) ~= "table" then
            BleakfibersActionBarsDB[section] = {}
        end
        BleakfibersActionBarsDB[section][key] = value

        if profTable then
            if type(profTable[section]) ~= "table" then
                profTable[section] = {}
            end
            profTable[section][key] = value
        end
    elseif section and not key then
        BleakfibersActionBarsDB[section] = value
        if profTable then
            profTable[section] = value
        end
    end

    -- Notify Core logic of setting change
    if BAB.Core and BAB.Core.OnSettingChanged then
        BAB.Core:OnSettingChanged(section, key, value)
    end

    -- Live refresh UI if active
    if BAB.UI and BAB.UI.Refresh then
        BAB.UI:Refresh()
    end
end

function Config:ResetDB()
    BleakfibersActionBarsDB = DeepCopy(DB_DEFAULTS)
    self:InitDB()

    if BAB.Core and BAB.Core.UpdateAllBars then
        BAB.Core:UpdateAllBars()
    end
    if BAB.Core and BAB.Core.ResetMovers then
        BAB.Core:ResetMovers()
    end
    if BAB.UI and BAB.UI.Refresh then
        BAB.UI:Refresh()
    end

    DEFAULT_CHAT_FRAME:AddMessage("|cff3399ff[" .. FULL_TITLE .. "]|r All settings reset to defaults.")
end

function Config:CopyBarSettings(sourceKey, targetKey)
    local src = BleakfibersActionBarsDB[sourceKey]
    local dest = BleakfibersActionBarsDB[targetKey]
    if not src or not dest then return end

    for k, v in pairs(src) do
        if type(v) == "table" then
            dest[k] = DeepCopy(v)
        else
            dest[k] = v
        end
    end

    if BAB.Core and BAB.Core.UpdateAllBars then
        BAB.Core:UpdateAllBars()
    end
    if BAB.UI and BAB.UI.Refresh then
        BAB.UI:Refresh()
    end

    local srcName = sourceKey:gsub("bar", "Bar "):gsub("petBar", "Pet Bar"):gsub("stanceBar", "Stance Bar")
    local destName = targetKey:gsub("bar", "Bar "):gsub("petBar", "Pet Bar"):gsub("stanceBar", "Stance Bar")
    DEFAULT_CHAT_FRAME:AddMessage("|cff3399ff[" .. FULL_TITLE .. "]|r Copied settings from " .. srcName .. " to " .. destName .. ".")
end

--[[-----------------------------------------------------------------------------
    Open / Toggle Configuration Window
-------------------------------------------------------------------------------]]
function Config:Open(forceStandalone)
    if not forceStandalone and BleakfibersAddonConfigForever and BleakfibersAddonConfigForever.SelectModule then
        BleakfibersAddonConfigForever:ShowUI()
        BleakfibersAddonConfigForever:SelectModule(ADDON_NAME)
    else
        local ui = BAB.UI or _G["BleakfibersActionBarsUI"]
        if ui and ui.ToggleStandaloneWindow then
            ui:ToggleStandaloneWindow()
        end
    end
end

--[[-----------------------------------------------------------------------------
    Slash Command Routing
-------------------------------------------------------------------------------]]
SLASH_BLEAKFIBERSACTIONBARS1 = "/bab"
SLASH_BLEAKFIBERSACTIONBARS2 = "/bfab"
SLASH_BLEAKFIBERSACTIONBARS3 = "/actionbars"

SlashCmdList["BLEAKFIBERSACTIONBARS"] = function(msg)
    msg = msg and string.trim and string.trim(msg:lower()) or (msg and msg:lower() or "")
    if msg == "move" or msg == "unlock" or msg == "movers" then
        local BAC = _G["BleakfibersAddonConfigForever"] or _G["BleakfibersAddonConfig"]
        if BAC and BAC.ToggleAllMovers then
            BAC:ToggleAllMovers(true)
        elseif BAB.Core and BAB.Core.ToggleMovers then
            BAB.Core:ToggleMovers(true)
        end
    elseif msg == "lock" then
        local BAC = _G["BleakfibersAddonConfigForever"] or _G["BleakfibersAddonConfig"]
        if BAC and BAC.ToggleAllMovers then
            BAC:ToggleAllMovers(false)
        elseif BAB.Core and BAB.Core.ToggleMovers then
            BAB.Core:ToggleMovers(false)
        end
    elseif msg == "bind" or msg == "keybind" then
        if BAB.Core and BAB.Core.ToggleKeybindMode then
            BAB.Core:ToggleKeybindMode()
        end
    elseif msg == "standalone" or msg == "ui" or msg == "panel" or msg == "solo" then
        Config:Open(true)
    elseif msg == "reset" then
        Config:ResetDB()
    else
        Config:Open()
    end
end

--[[-----------------------------------------------------------------------------
    Event Handling & Hub Registration
-------------------------------------------------------------------------------]]
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")

local function ToggleMoversHook(state)
    local core = BAB.Core or _G["BleakfibersActionBarsCore"]
    if core and core.ToggleMovers then
        core:ToggleMovers(state)
    end
end

local function ResetMoversHook()
    local core = BAB.Core or _G["BleakfibersActionBarsCore"]
    if core and core.ResetMovers then
        core:ResetMovers()
    end
end

local function IsMoversUnlockedHook()
    local core = BAB.Core or _G["BleakfibersActionBarsCore"]
    if core and core.IsMoversUnlocked then
        return core:IsMoversUnlocked()
    end
    return false
end

-- Global cross-addon movers registry for master HUD / config integration
_G.Bleakfibers_MoversRegistry = _G.Bleakfibers_MoversRegistry or {}
_G.Bleakfibers_MoversRegistry["ActionBars"] = {
    name = FULL_TITLE,
    sidebarName = DISPLAY_TITLE,
    Toggle = ToggleMoversHook,
    Reset = ResetMoversHook,
    IsUnlocked = IsMoversUnlockedHook,
}

eventFrame:SetScript("OnEvent", function(self, event, arg1)
    if arg1 == addonName then
        Config:InitDB()
    end

    if arg1 == "BleakfibersAddonConfig-Forever" or arg1 == addonName then
        if BleakfibersAddonConfigForever and BleakfibersAddonConfigForever.RegisterModule then
            BleakfibersAddonConfigForever:RegisterModule(ADDON_NAME, {
                name = FULL_TITLE,
                sidebarName = DISPLAY_TITLE,
                author = "Bleakfiber",
                isBleakfiber = true,
                description = "Modular, minimalist action bar suite for WoW Forever.",
                db = BleakfibersActionBarsDB,
                profiles = {
                    GetCurrent = function() return Config:GetActiveProfile() end,
                    SetCurrent = function(p) Config:SetActiveProfile(p) end,
                    SaveCurrentAs = function(p) Config:SaveCurrentAs(p) end,
                    List       = function() return Config:GetProfiles() end,
                    Create     = function(p, from) Config:CreateProfile(p, from) end,
                    Delete     = function(p) Config:DeleteProfile(p) end,
                    Copy       = function(f, t) Config:CopyProfile(f, t) end,
                    Reset      = function(p) Config:ResetProfile(p) end,
                },
                toggleMovers = ToggleMoversHook,
                resetMovers = ResetMoversHook,
                isMoversUnlocked = IsMoversUnlockedHook,
                refresh = function()
                    local core = BAB.Core or _G["BleakfibersActionBarsCore"]
                    if core and core.ApplyAllMoverPositions then
                        core:ApplyAllMoverPositions()
                    end
                    if core and core.LayoutBagsBar then
                        core:LayoutBagsBar()
                    end
                    if core and core.UpdateAllBars then
                        core:UpdateAllBars()
                    end
                    local ui = BAB.UI or _G["BleakfibersActionBarsUI"]
                    if ui and ui.Refresh then ui:Refresh() end
                end,
                buildUI = function(container, isMasterHub)
                    local ui = BAB.UI or _G["BleakfibersActionBarsUI"]
                    if ui and ui.BuildOptions then
                        ui:BuildOptions(container, isMasterHub)
                    end
                end,
            })
        end
    end
end)

