-- WowReminder/UI_Overlay.lua
-- HUD en jeu : deux modes (liste complète / prochain sort uniquement)
-- Comportement : mauvais sort lancé → retour au début de la rotation

local addon = WowReminder

local ROW_H  = 34
local ICON_S = 26
local BAR_W  = 5

-- État runtime (non persisté)
addon.overlayState = {
    index     = 1,      -- prochain sort attendu
    results   = {},     -- [i] = "neutral" | "green" | "red"
    recording = false,  -- true = mode enregistrement actif
}

-- ── Initialisation ────────────────────────────────────────────────────────────

function addon:InitOverlay()
    local f = CreateFrame("Frame", "WowReminderOverlay", UIParent, "BackdropTemplate")
    addon.overlayFrame = f

    f:SetSize(240, 320)
    f:SetFrameStrata("MEDIUM")
    f:SetMovable(true)
    f:SetResizable(true)
    -- Taille minimale / maximale (API TWW + fallback)
    if f.SetResizeBounds then
        f:SetResizeBounds(220, 180, 700, 900)
    else
        f:SetMinResize(220, 180)
        f:SetMaxResize(700, 900)
    end
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local point, _, _, x, y = self:GetPoint()
        addon.db.overlayPos = { point = point, x = x, y = y }
    end)
    -- Adapter la largeur du contenu scrollable quand la fenêtre est redimensionnée
    f:SetScript("OnSizeChanged", function(self)
        local innerW = math.max(self:GetWidth() - 30, 100)
        if addon.overlayScrollChild then
            addon.overlayScrollChild:SetWidth(innerW)
        end
        addon.db.overlaySize = { w = self:GetWidth(), h = self:GetHeight() }
    end)

    f:SetBackdrop({
        bgFile   = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 },
    })
    f:SetBackdropColor(0, 0, 0, 0.88)
    f:SetBackdropBorderColor(0.4, 0.4, 0.4, 0.9)

    -- ── Barre de titre ────────────────────────────────────────────────────────

    local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    title:SetPoint("TOPLEFT", f, "TOPLEFT", 10, -7)
    title:SetText("|cff00ccffRotation|r")

    -- REC indicator (visible only while recording — Unicode dot does not render in WoW fonts)
    local recIndicator = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    recIndicator:SetPoint("LEFT", title, "RIGHT", 6, 0)
    recIndicator:SetText("|cffff2222[REC]|r")
    recIndicator:Hide()
    addon.overlayRecIndicator = recIndicator

    -- Bouton fermer
    local closeBtn = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    closeBtn:SetSize(24, 24)
    closeBtn:SetPoint("TOPRIGHT", f, "TOPRIGHT", 4, 4)
    closeBtn:SetScript("OnClick", function() f:Hide() end)

    -- Mode buttons — "List" / "Next" (Unicode ≡ ◎ do not render in WoW fonts)
    local btnFocus = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    btnFocus:SetSize(40, 18)
    btnFocus:SetPoint("TOPRIGHT", f, "TOPRIGHT", -22, -4)
    btnFocus:SetText("Next")
    btnFocus:SetScript("OnClick", function() addon:SetOverlayMode("focus") end)
    addon.overlayBtnFocus = btnFocus

    local btnList = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    btnList:SetSize(38, 18)
    btnList:SetPoint("RIGHT", btnFocus, "LEFT", -2, 0)
    btnList:SetText("List")
    btnList:SetScript("OnClick", function() addon:SetOverlayMode("list") end)
    addon.overlayBtnList = btnList

    btnList:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
        GameTooltip:SetText("List Mode\nShows the full rotation")
        GameTooltip:Show()
    end)
    btnList:SetScript("OnLeave", function() GameTooltip:Hide() end)

    btnFocus:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
        GameTooltip:SetText("Next Spell Mode\nShows only the spell to cast")
        GameTooltip:Show()
    end)
    btnFocus:SetScript("OnLeave", function() GameTooltip:Hide() end)

    -- Séparateur titre
    local sep = f:CreateTexture(nil, "ARTWORK")
    sep:SetColorTexture(0.3, 0.3, 0.3, 0.8)
    sep:SetPoint("TOPLEFT",  f, "TOPLEFT",  4, -24)
    sep:SetPoint("TOPRIGHT", f, "TOPRIGHT", -4, -24)
    sep:SetHeight(1)

    -- ── MODE LISTE : ScrollFrame ──────────────────────────────────────────────

    local sf = CreateFrame("ScrollFrame", "WowReminderOverlayScroll", f, "UIPanelScrollFrameTemplate")
    addon.overlayScroll = sf
    sf:SetPoint("TOPLEFT",     f, "TOPLEFT",     6,  -28)
    sf:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -22,  38)

    local sc = CreateFrame("Frame", nil, sf)
    sc:SetWidth(206)
    sc:SetHeight(ROW_H)
    sf:SetScrollChild(sc)
    addon.overlayScrollChild = sc
    addon.overlayRows = {}

    -- ── MODE FOCUS : affichage grand format ───────────────────────────────────

    local ff = CreateFrame("Frame", nil, f)
    ff:SetPoint("TOPLEFT",     f, "TOPLEFT",     4, -28)
    ff:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -4,  38)
    addon.overlayFocusFrame = ff

    -- Cadre de l'icône
    local iconFrame = CreateFrame("Frame", nil, ff, "BackdropTemplate")
    iconFrame:SetSize(90, 90)
    iconFrame:SetPoint("CENTER", ff, "CENTER", 0, 28)
    iconFrame:SetBackdrop({
        edgeFile = "Interface\\Glues\\Common\\TextPanel-Border",
        edgeSize = 8,
    })
    iconFrame:SetBackdropBorderColor(0.7, 0.7, 0.1, 1)

    local bigIcon = iconFrame:CreateTexture(nil, "ARTWORK")
    bigIcon:SetPoint("TOPLEFT",     iconFrame, "TOPLEFT",     4,  -4)
    bigIcon:SetPoint("BOTTOMRIGHT", iconFrame, "BOTTOMRIGHT", -4,   4)
    addon.overlayFocusIcon = bigIcon

    -- Nom du sort (grand)
    local focusName = ff:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    focusName:SetPoint("TOP",   iconFrame, "BOTTOM", 0,  -10)
    focusName:SetPoint("LEFT",  ff,        "LEFT",   6,    0)
    focusName:SetPoint("RIGHT", ff,        "RIGHT",  -6,   0)
    focusName:SetJustifyH("CENTER")
    focusName:SetWordWrap(false)
    addon.overlayFocusName = focusName

    -- Compteur "#3 / 7"
    local focusCounter = ff:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    focusCounter:SetPoint("TOP", focusName, "BOTTOM", 0, -6)
    focusCounter:SetJustifyH("CENTER")
    addon.overlayFocusCounter = focusCounter

    -- Message vide (mode focus)
    local focusEmpty = ff:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    focusEmpty:SetPoint("CENTER", ff, "CENTER")
    focusEmpty:SetText("Rotation is empty.\nType |cffffd700/wr|r to configure.")
    focusEmpty:SetJustifyH("CENTER")
    addon.overlayFocusEmpty = focusEmpty

    -- ── Séparateur bas + Reset ────────────────────────────────────────────────

    local sepBot = f:CreateTexture(nil, "ARTWORK")
    sepBot:SetColorTexture(0.3, 0.3, 0.3, 0.8)
    sepBot:SetPoint("BOTTOMLEFT",  f, "BOTTOMLEFT",  4, 36)
    sepBot:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -4, 36)
    sepBot:SetHeight(1)

    -- Record button (left) — Unicode ⏺ does not render in WoW fonts
    local recBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    recBtn:SetSize(108, 26)
    recBtn:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 8, 6)
    recBtn:SetText("|cffff4444o|r Record")
    recBtn:SetScript("OnClick", function() addon:ToggleRecording() end)
    addon.overlayRecBtn = recBtn

    -- Restart button (right) — Unicode arrow does not render in WoW fonts
    local resetBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    resetBtn:SetSize(108, 26)
    resetBtn:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -8, 6)
    resetBtn:SetText("Restart")
    resetBtn:SetScript("OnClick", function() addon:ResetOverlay() end)

    -- ── Intégration Mode Édition ──────────────────────────────────────────────

    local editBorder = CreateFrame("Frame", nil, f, "BackdropTemplate")
    editBorder:SetPoint("TOPLEFT",     f, "TOPLEFT",     -4, 4)
    editBorder:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT",  4, -4)
    editBorder:SetFrameLevel(f:GetFrameLevel() + 10)
    editBorder:SetBackdrop({ edgeFile = "Interface\\Glues\\Common\\TextPanel-Border", edgeSize = 10 })
    editBorder:SetBackdropBorderColor(1, 0.82, 0, 1)
    editBorder:Hide()

    local editLabel = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    editLabel:SetPoint("BOTTOM", f, "TOP", 0, 4)
    editLabel:SetText("|cffffd700WowReminder Overlay|r  —  Click and drag to move")
    editLabel:Hide()

    local function onEnterEditMode()
        if f:IsShown() then editBorder:Show() editLabel:Show() end
    end
    local function onExitEditMode()
        editBorder:Hide() editLabel:Hide()
        local point, _, _, x, y = f:GetPoint()
        addon.db.overlayPos = { point = point, x = x, y = y }
    end

    if EditModeManagerFrame then
        if EditModeManagerFrame.EnterEditMode then
            hooksecurefunc(EditModeManagerFrame, "EnterEditMode", onEnterEditMode)
        end
        if EditModeManagerFrame.ExitEditMode then
            hooksecurefunc(EditModeManagerFrame, "ExitEditMode", onExitEditMode)
        end
    end
    local editEvt = CreateFrame("Frame")
    editEvt:RegisterEvent("EDIT_MODE_LAYOUTS_UPDATED")
    editEvt:SetScript("OnEvent", function()
        if EditModeManagerFrame and EditModeManagerFrame:IsEditModeActive() then
            onEnterEditMode()
        else
            onExitEditMode()
        end
    end)

    -- ── Grip de redimensionnement (coin bas-droit) ────────────────────────────

    local grip = CreateFrame("Button", nil, f)
    grip:SetSize(16, 16)
    grip:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 0, 0)
    grip:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
    grip:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
    grip:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
    grip:SetScript("OnMouseDown", function(self, btn)
        if btn == "LeftButton" then f:StartSizing("BOTTOMRIGHT") end
    end)
    grip:SetScript("OnMouseUp", function()
        f:StopMovingOrSizing()
        addon.db.overlaySize = { w = f:GetWidth(), h = f:GetHeight() }
        -- Adapter la largeur du scroll child après resize manuel
        local innerW = math.max(f:GetWidth() - 30, 100)
        if addon.overlayScrollChild then
            addon.overlayScrollChild:SetWidth(innerW)
        end
    end)

    -- ── Position et taille sauvegardées ──────────────────────────────────────

    if addon.db.overlaySize then
        f:SetSize(addon.db.overlaySize.w, addon.db.overlaySize.h)
    end

    if addon.db.overlayPos then
        local p = addon.db.overlayPos
        f:ClearAllPoints()
        f:SetPoint(p.point or "CENTER", UIParent, p.point or "CENTER", p.x or 0, p.y or 0)
    else
        f:SetPoint("RIGHT", UIParent, "RIGHT", -60, 0)
    end

    f:Hide()

    -- Appliquer le mode sauvegardé (sans rafraîchir encore, ResetOverlay le fera)
    addon:SetOverlayMode(addon.db.overlayMode or "list", true)
    addon:ResetOverlay()
end

-- ── Changement de mode ────────────────────────────────────────────────────────

function addon:SetOverlayMode(mode, silent)
    addon.db.overlayMode = mode

    local islist = (mode == "list")
    addon.overlayScroll:SetShown(islist)
    addon.overlayFocusFrame:SetShown(not islist)

    -- Mettre en valeur le bouton actif
    if islist then
        addon.overlayBtnList:SetText("|cffffd700List|r")
        addon.overlayBtnFocus:SetText("Next")
    else
        addon.overlayBtnList:SetText("List")
        addon.overlayBtnFocus:SetText("|cffffd700Next|r")
    end

    if not silent then
        addon:RefreshOverlay()
    end
end

-- ── Logique de suivi ──────────────────────────────────────────────────────────

-- ── Enregistrement ───────────────────────────────────────────────────────────

function addon:ToggleRecording()
    local state = addon.overlayState
    state.recording = not state.recording

    if state.recording then
        addon.overlayRecBtn:SetText("|cffff4444Stop|r")
        addon.overlayRecIndicator:Show()
        print("|cff00ccffWowReminder|r: |cffff4444[REC]|r Recording started. Cast your spells.")
    else
        addon.overlayRecBtn:SetText("|cffff4444o|r Record")
        addon.overlayRecIndicator:Hide()
        print("|cff00ccffWowReminder|r: Recording stopped — "
            .. #addon.db.rotation .. " spell(s) in rotation.")
        addon:ResetOverlay()
    end
end

-- ── Suivi des sorts lancés ────────────────────────────────────────────────────

-- Appelé par Core.lua sur UNIT_SPELLCAST_SUCCEEDED
function addon:OnSpellCast(spellID)
    -- ── Mode Enregistrement ───────────────────────────────────────────────────
    if addon.overlayState.recording then
        local spellData = addon:GetSpellData(spellID)
        if spellData then
            -- Insertion directe (sans passer par AddToRotation qui réinitialise l'overlay)
            table.insert(addon.db.rotation, {
                spellID = spellData.spellID,
                name    = spellData.name,
                icon    = spellData.icon,
            })
            addon:RefreshRotationList()
            addon:RefreshOverlay()
        end
        return
    end

    -- ── Mode Suivi normal ─────────────────────────────────────────────────────
    local rot = addon.db.rotation
    if #rot == 0 then return end

    local idx      = addon.overlayState.index
    local expected = rot[idx]
    if not expected then return end

    -- Comparaison par ID d'abord, puis par nom en fallback
    -- (certains sorts ont un ID différent spellbook vs cast)
    local isMatch = (expected.spellID == spellID)

    if not isMatch then
        local castName
        if C_Spell and C_Spell.GetSpellInfo then
            local info = C_Spell.GetSpellInfo(spellID)
            castName = info and info.name
        end
        if not castName then
            castName = GetSpellInfo(spellID)
        end
        isMatch = (castName ~= nil and castName == expected.name)
    end

    if isMatch then
        -- ✓ Bon sort : vert, on avance
        addon.overlayState.results[idx] = "green"
        addon.overlayState.index = (idx % #rot) + 1
        addon:RefreshOverlay()
    else
        -- ✗ Mauvais sort : retour au début
        addon:ResetOverlay()
    end
end

-- Remet l'état à zéro (index 1, tout neutral)
function addon:ResetOverlay()
    local rot = addon.db.rotation
    addon.overlayState.index   = 1
    addon.overlayState.results = {}
    for i = 1, #rot do
        addon.overlayState.results[i] = "neutral"
    end
    addon:RefreshOverlay()
end

-- ── Affichage ─────────────────────────────────────────────────────────────────

function addon:CreateOverlayRow(parent, index)
    local row = CreateFrame("Frame", nil, parent)
    row:SetHeight(ROW_H)
    row:SetPoint("TOPLEFT",  parent, "TOPLEFT",  0, -(index - 1) * ROW_H)
    row:SetPoint("TOPRIGHT", parent, "TOPRIGHT", 0, -(index - 1) * ROW_H)

    local bg = row:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    row.bg = bg

    local bar = row:CreateTexture(nil, "ARTWORK")
    bar:SetSize(BAR_W, ROW_H - 6)
    bar:SetPoint("LEFT", row, "LEFT", 2, 0)
    row.bar = bar

    local icon = row:CreateTexture(nil, "ARTWORK")
    icon:SetSize(ICON_S, ICON_S)
    icon:SetPoint("LEFT", row, "LEFT", BAR_W + 6, 0)
    row.icon = icon

    local nameText = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    nameText:SetPoint("TOPLEFT",  icon, "TOPRIGHT",   5,  -2)
    nameText:SetPoint("TOPRIGHT", row,  "TOPRIGHT",  -4,  -2)
    nameText:SetJustifyH("LEFT")
    nameText:SetWordWrap(false)
    row.nameText = nameText

    local numText = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    numText:SetPoint("BOTTOMLEFT", icon, "BOTTOMRIGHT", 5, 2)
    numText:SetTextColor(0.4, 0.4, 0.4)
    row.numText = numText

    row:Hide()
    return row
end

function addon:RefreshOverlay()
    local rot     = addon.db.rotation
    local n       = #rot
    local current = addon.overlayState.index
    local mode    = addon.db.overlayMode or "list"

    -- ── Mode Liste ────────────────────────────────────────────────────────────

    local sc = addon.overlayScrollChild
    local sf = addon.overlayScroll
    if sc then
        sc:SetHeight(math.max(n * ROW_H, ROW_H))

        for _, row in ipairs(addon.overlayRows) do row:Hide() end

        for i, spell in ipairs(rot) do
            if not addon.overlayRows[i] then
                addon.overlayRows[i] = addon:CreateOverlayRow(sc, i)
            end
            local row = addon.overlayRows[i]

            row:SetPoint("TOPLEFT",  sc, "TOPLEFT",  0, -(i - 1) * ROW_H)
            row:SetPoint("TOPRIGHT", sc, "TOPRIGHT", 0, -(i - 1) * ROW_H)

            row.icon:SetTexture(spell.icon or "Interface\\Icons\\INV_Misc_QuestionMark")
            row.nameText:SetText(spell.name)
            row.numText:SetText("#" .. i)

            local state     = addon.overlayState.results[i] or "neutral"
            local isCurrent = (i == current)

            if isCurrent then
                row.bg:SetColorTexture(0.28, 0.22, 0, 0.7)
                row.bar:SetColorTexture(1, 0.85, 0, 1)
                row.nameText:SetTextColor(1, 0.9, 0.1)
            elseif state == "green" then
                row.bg:SetColorTexture(0, 0.14, 0.04, 0.6)
                row.bar:SetColorTexture(0.15, 0.9, 0.3, 1)
                row.nameText:SetTextColor(0.3, 1, 0.4)
            elseif state == "red" then
                row.bg:SetColorTexture(0.16, 0.03, 0.03, 0.6)
                row.bar:SetColorTexture(1, 0.2, 0.2, 1)
                row.nameText:SetTextColor(1, 0.3, 0.3)
            else
                row.bg:SetColorTexture(0.05, 0.05, 0.05, 0.5)
                row.bar:SetColorTexture(0.25, 0.25, 0.25, 0.7)
                row.nameText:SetTextColor(0.65, 0.65, 0.65)
            end
            row:Show()
        end

        if not addon.overlayEmptyMsg then
            local msg = sc:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
            msg:SetPoint("TOP", sc, "TOP", 0, -20)
            msg:SetText("Rotation is empty.\nType |cffffd700/wr|r to configure.")
            msg:SetJustifyH("CENTER")
            addon.overlayEmptyMsg = msg
        end
        addon.overlayEmptyMsg:SetShown(n == 0)

        -- Auto-scroll vers le sort courant
        if sf and n > 0 then
            local target = ((current - 1) * ROW_H) - (sf:GetHeight() / 2) + (ROW_H / 2)
            sf:SetVerticalScroll(math.max(0, math.min(target, sf:GetVerticalScrollRange())))
        end
    end

    -- ── Mode Focus ────────────────────────────────────────────────────────────

    if addon.overlayFocusFrame then
        if n == 0 then
            addon.overlayFocusIcon:SetTexture(nil)
            addon.overlayFocusName:SetText("")
            addon.overlayFocusCounter:SetText("")
            addon.overlayFocusEmpty:Show()
        else
            local spell = rot[current]
            addon.overlayFocusIcon:SetTexture(spell.icon or "Interface\\Icons\\INV_Misc_QuestionMark")
            addon.overlayFocusName:SetText(spell.name)
            addon.overlayFocusName:SetTextColor(1, 0.9, 0.1)
            addon.overlayFocusCounter:SetText("|cff999999#" .. current .. " / " .. n .. "|r")
            addon.overlayFocusEmpty:Hide()
        end
    end
end
