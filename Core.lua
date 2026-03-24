-- WowReminder/Core.lua
-- Point d'entrée : namespace, événements, SavedVariables

WowReminder = WowReminder or {}
local addon = WowReminder

-- ── Valeurs par défaut ───────────────────────────────────────────────────────

local DEFAULTS = {
    rotation    = {},        -- { {spellID, name, icon}, ... }
    windowPos   = nil,       -- { point, x, y }
    overlayPos  = nil,       -- { point, x, y }
    overlaySize = nil,       -- { w, h }
    overlayMode = "list",    -- "list" | "focus"
}

-- ── SavedVariables ───────────────────────────────────────────────────────────

function addon:InitDB()
    if not WowReminderDB then
        WowReminderDB = {}
    end
    for k, v in pairs(DEFAULTS) do
        if WowReminderDB[k] == nil then
            -- Deep copy pour les tables
            if type(v) == "table" then
                WowReminderDB[k] = {}
                for k2, v2 in pairs(v) do
                    WowReminderDB[k][k2] = v2
                end
            else
                WowReminderDB[k] = v
            end
        end
    end
    addon.db = WowReminderDB
end

-- ── Événements ───────────────────────────────────────────────────────────────

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("SPELLS_CHANGED")
eventFrame:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")

eventFrame:SetScript("OnEvent", function(self, event, arg1, arg2, arg3)
    if event == "ADDON_LOADED" and arg1 == "WowReminder" then
        addon:InitDB()
        addon:InitUI()
        addon:InitOverlay()
        print("|cff00ccffWowReminder|r loaded — type |cffffd700/wr|r to open.")

    elseif event == "PLAYER_LOGIN" then
        addon:ScanSpellbook()

    elseif event == "SPELLS_CHANGED" then
        addon:ScanSpellbook()
        if addon.mainFrame and addon.mainFrame:IsShown() then
            addon:RefreshSearchList()
        end

    elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
        -- arg1 = unit, arg2 = castGUID, arg3 = spellID
        if arg1 == "player" and arg3 then
            addon:OnSpellCast(arg3)
        end
    end
end)
