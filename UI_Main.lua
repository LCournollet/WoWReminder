-- WowReminder/UI_Main.lua
-- Fenêtre principale + commande slash

local addon = WowReminder

-- ── Constantes de layout ─────────────────────────────────────────────────────

addon.LAYOUT = {
    W          = 720,
    H          = 520,
    PADDING    = 10,
    TITLE_H    = 28,      -- hauteur approximative du titre BasicFrameTemplate
    PANEL_W    = 340,     -- largeur de chaque panneau (gauche / droite)
    ROW_H      = 36,
    ICON_SIZE  = 28,
}

-- ── Initialisation ───────────────────────────────────────────────────────────

function addon:InitUI()
    local L = addon.LAYOUT

    -- Fenêtre principale
    local f = CreateFrame("Frame", "WowReminderFrame", UIParent, "BasicFrameTemplateWithInset")
    addon.mainFrame = f

    f:SetSize(L.W, L.H)
    f:SetPoint("CENTER")
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local point, _, relPoint, x, y = self:GetPoint()
        addon.db.windowPos = { point = point, x = x, y = y }
    end)

    f.TitleText:SetText("WowReminder  —  Rotation Builder")

    -- Restaurer la position sauvegardée
    if addon.db.windowPos then
        local p = addon.db.windowPos
        f:ClearAllPoints()
        f:SetPoint(p.point or "CENTER", UIParent, p.point or "CENTER", p.x or 0, p.y or 0)
    end

    -- Séparateur vertical central
    local sep = f:CreateTexture(nil, "ARTWORK")
    sep:SetColorTexture(0.25, 0.25, 0.25, 1)
    sep:SetSize(2, L.H - L.TITLE_H - L.PADDING * 2)
    sep:SetPoint("TOP",    f, "TOP",    0, -(L.TITLE_H + L.PADDING))
    sep:SetPoint("BOTTOM", f, "BOTTOM", 0, L.PADDING)

    f:Hide()

    -- Construire les deux panneaux
    addon:InitSearchUI()
    addon:InitRotationUI()

    -- Bouton toggle overlay dans la fenêtre principale
    local overlayBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    overlayBtn:SetSize(130, 22)
    overlayBtn:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", L.PADDING, L.PADDING - 2)
    overlayBtn:SetText("Show Overlay")
    overlayBtn:SetScript("OnClick", function()
        if addon.overlayFrame then
            if addon.overlayFrame:IsShown() then
                addon.overlayFrame:Hide()
                overlayBtn:SetText("Show Overlay")
            else
                addon.overlayFrame:Show()
                addon:RefreshOverlay()
                overlayBtn:SetText("Hide Overlay")
            end
        end
    end)
    addon.overlayToggleBtn = overlayBtn

    -- ── Commandes slash ──────────────────────────────────────────────────────
    SLASH_WOWREMINDER1 = "/wr"
    SLASH_WOWREMINDER2 = "/wowreminder"
    SlashCmdList["WOWREMINDER"] = function(msg)
        msg = msg and msg:lower() or ""

        if msg == "reset" then
            addon.db.windowPos = nil
            addon.mainFrame:ClearAllPoints()
            addon.mainFrame:SetPoint("CENTER")
            print("|cff00ccffWowReminder|r: window position reset.")
            return
        end

        if msg == "overlay" or msg == "o" then
            if addon.overlayFrame then
                if addon.overlayFrame:IsShown() then
                    addon.overlayFrame:Hide()
                else
                    addon.overlayFrame:Show()
                    addon:RefreshOverlay()
                end
            end
            return
        end

        if addon.mainFrame:IsShown() then
            addon.mainFrame:Hide()
        else
            addon.mainFrame:Show()
            addon:RefreshSearchList()
            addon:RefreshRotationList()
        end
    end
end
