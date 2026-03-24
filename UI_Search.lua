-- WowReminder/UI_Search.lua
-- Left panel: search field + spell list

local addon = WowReminder

-- ── Left panel init ───────────────────────────────────────────────────────────

function addon:InitSearchUI()
    local f  = addon.mainFrame
    local L  = addon.LAYOUT
    local px = L.PADDING
    local py = -(L.TITLE_H + L.PADDING)

    -- Label
    local label = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    label:SetPoint("TOPLEFT", f, "TOPLEFT", px, py)
    label:SetText("|cffffd700Available Spells|r")

    -- Search box
    local search = CreateFrame("EditBox", "WowReminderSearchBox", f, "InputBoxTemplate")
    addon.searchBox = search
    search:SetSize(L.PANEL_W - 90, 22)
    search:SetPoint("TOPLEFT", f, "TOPLEFT", px + 4, py - 18)
    search:SetAutoFocus(false)
    search:SetMaxLetters(64)

    -- Placeholder text
    local placeholder = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    placeholder:SetPoint("LEFT", search, "LEFT", 6, 0)
    placeholder:SetText("Search for a spell...")
    search:SetScript("OnTextChanged", function(self)
        placeholder:SetShown(self:GetText() == "")
        addon:RefreshSearchList()
    end)
    search:SetScript("OnEditFocusGained", function() placeholder:Hide() end)
    search:SetScript("OnEditFocusLost", function()
        placeholder:SetShown(search:GetText() == "")
    end)

    -- By ID button
    local idBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    idBtn:SetSize(78, 22)
    idBtn:SetPoint("LEFT", search, "RIGHT", 6, 0)
    idBtn:SetText("By ID")
    idBtn:SetScript("OnClick", addon.OpenManualIDDialog)

    -- Rescan button
    local scanBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    scanBtn:SetSize(78, 22)
    scanBtn:SetPoint("LEFT", idBtn, "RIGHT", 4, 0)
    scanBtn:SetText("Rescan")
    scanBtn:SetScript("OnClick", function()
        addon:ScanSpellbook()
        addon:RefreshSearchList()
    end)

    -- Scroll frame
    local sf = CreateFrame("ScrollFrame", "WowReminderSpellScroll", f, "UIPanelScrollFrameTemplate")
    addon.spellScrollFrame = sf
    sf:SetPoint("TOPLEFT",    f, "TOPLEFT",    px,    py - 48)
    sf:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", px,    L.PADDING)
    sf:SetWidth(L.PANEL_W)

    -- Scroll child
    local sc = CreateFrame("Frame", "WowReminderSpellScrollChild", sf)
    sc:SetWidth(L.PANEL_W - 20)
    sc:SetHeight(L.ROW_H)
    sf:SetScrollChild(sc)
    addon.spellScrollChild = sc

    addon.spellRows = {}
    addon:RefreshSearchList()
end

-- ── Spell row ─────────────────────────────────────────────────────────────────

function addon:CreateSpellRow(parent, index)
    local L   = addon.LAYOUT
    local row = CreateFrame("Button", nil, parent)
    row:SetHeight(L.ROW_H)
    row:SetPoint("TOPLEFT",  parent, "TOPLEFT",  0, -(index - 1) * L.ROW_H)
    row:SetPoint("TOPRIGHT", parent, "TOPRIGHT", 0, -(index - 1) * L.ROW_H)

    -- Alternating background
    local bg = row:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    if index % 2 == 0 then
        bg:SetColorTexture(0.08, 0.08, 0.10, 0.6)
    else
        bg:SetColorTexture(0.12, 0.12, 0.14, 0.6)
    end

    row:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")

    -- Icon
    local icon = row:CreateTexture(nil, "ARTWORK")
    icon:SetSize(L.ICON_SIZE, L.ICON_SIZE)
    icon:SetPoint("LEFT", row, "LEFT", 4, 0)
    row.icon = icon

    -- Name
    local nameText = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    nameText:SetPoint("TOPLEFT",  icon, "TOPRIGHT",   6,  -2)
    nameText:SetPoint("TOPRIGHT", row,  "TOPRIGHT", -64,  -2)
    nameText:SetJustifyH("LEFT")
    nameText:SetWordWrap(false)
    row.nameText = nameText

    -- Spell ID
    local idText = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    idText:SetPoint("BOTTOMLEFT",  icon, "BOTTOMRIGHT",  6,  2)
    idText:SetPoint("BOTTOMRIGHT", row,  "BOTTOMRIGHT", -64, 2)
    idText:SetJustifyH("LEFT")
    idText:SetTextColor(0.55, 0.55, 0.55)
    row.idText = idText

    -- Add button
    local addBtn = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
    addBtn:SetSize(56, 22)
    addBtn:SetPoint("RIGHT", row, "RIGHT", -4, 0)
    addBtn:SetText("|cff44ff44+|r Add")
    addBtn:SetScript("OnClick", function()
        if row.spellData then
            if addon:AddToRotation(row.spellData) then
                addon:RefreshRotationList()
            end
        end
    end)
    row.addBtn = addBtn

    row:Hide()
    return row
end

-- ── Refresh list ──────────────────────────────────────────────────────────────

function addon:RefreshSearchList()
    local query   = addon.searchBox and addon.searchBox:GetText() or ""
    local results = addon:SearchSpells(query)
    local L       = addon.LAYOUT
    local sc      = addon.spellScrollChild
    if not sc then return end

    sc:SetHeight(math.max(#results * L.ROW_H, L.ROW_H))

    for i = 1, math.max(#results, #addon.spellRows) do
        local row   = addon.spellRows[i]
        local spell = results[i]

        if spell then
            if not row then
                row = addon:CreateSpellRow(sc, i)
                addon.spellRows[i] = row
            end
            row:SetPoint("TOPLEFT",  sc, "TOPLEFT",  0, -(i - 1) * L.ROW_H)
            row:SetPoint("TOPRIGHT", sc, "TOPRIGHT", 0, -(i - 1) * L.ROW_H)
            row.spellData = spell
            row.nameText:SetText(spell.name)
            row.idText:SetText("ID: " .. spell.spellID)
            row.icon:SetTexture(spell.icon or "Interface\\Icons\\INV_Misc_QuestionMark")
            row:Show()
        elseif row then
            row:Hide()
            row.spellData = nil
        end
    end

    if not addon.spellEmptyMsg then
        local msg = sc:CreateFontString(nil, "OVERLAY", "GameFontDisable")
        msg:SetPoint("TOP", sc, "TOP", 0, -20)
        msg:SetText("No spells found.")
        addon.spellEmptyMsg = msg
    end
    addon.spellEmptyMsg:SetShown(#results == 0)
end

-- ── Manual Spell ID dialog ────────────────────────────────────────────────────

function addon:OpenManualIDDialog()
    if addon.manualDialog and addon.manualDialog:IsShown() then
        addon.manualDialog:Hide()
        return
    end

    local dlg = CreateFrame("Frame", "WowReminderManualDlg", addon.mainFrame, "BackdropTemplate")
    addon.manualDialog = dlg
    dlg:SetSize(260, 96)
    dlg:SetPoint("CENTER", addon.mainFrame)
    dlg:SetFrameLevel(addon.mainFrame:GetFrameLevel() + 20)
    dlg:SetBackdrop({
        bgFile   = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 32,
        insets = { left = 11, right = 12, top = 12, bottom = 11 },
    })
    dlg:EnableMouse(true)

    local lbl = dlg:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    lbl:SetPoint("TOPLEFT", dlg, "TOPLEFT", 18, -16)
    lbl:SetText("Add by Spell ID:")

    local edit = CreateFrame("EditBox", nil, dlg, "InputBoxTemplate")
    edit:SetSize(180, 20)
    edit:SetPoint("TOPLEFT", dlg, "TOPLEFT", 18, -38)
    edit:SetNumeric(true)
    edit:SetAutoFocus(true)
    edit:SetMaxLetters(10)

    local function confirm()
        local spellData = addon:ResolveManualID(edit:GetText())
        if spellData then
            if addon:AddToRotation(spellData) then
                addon:RefreshRotationList()
                print("|cff00ccffWowReminder|r: |cffffd700" .. spellData.name .. "|r added (ID " .. spellData.spellID .. ").")
            end
        else
            print("|cffff4444WowReminder|r: Invalid Spell ID.")
        end
        dlg:Hide()
    end

    local okBtn = CreateFrame("Button", nil, dlg, "UIPanelButtonTemplate")
    okBtn:SetSize(80, 22)
    okBtn:SetPoint("BOTTOMLEFT", dlg, "BOTTOMLEFT", 18, 12)
    okBtn:SetText("Add")
    okBtn:SetScript("OnClick", confirm)

    local cancelBtn = CreateFrame("Button", nil, dlg, "UIPanelButtonTemplate")
    cancelBtn:SetSize(80, 22)
    cancelBtn:SetPoint("BOTTOMRIGHT", dlg, "BOTTOMRIGHT", -18, 12)
    cancelBtn:SetText("Cancel")
    cancelBtn:SetScript("OnClick", function() dlg:Hide() end)

    edit:SetScript("OnEnterPressed", confirm)
    edit:SetScript("OnEscapePressed", function() dlg:Hide() end)

    dlg:Show()
end
