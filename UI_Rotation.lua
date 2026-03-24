-- WowReminder/UI_Rotation.lua
-- Right panel: rotation display and management

local addon = WowReminder

-- ── Right panel init ──────────────────────────────────────────────────────────

function addon:InitRotationUI()
    local f  = addon.mainFrame
    local L  = addon.LAYOUT
    local py = -(L.TITLE_H + L.PADDING)

    -- Label
    local label = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    label:SetPoint("TOPLEFT", f, "TOP", L.PADDING, py)
    label:SetText("|cffffd700My Rotation|r")

    -- Clear all button
    local clearBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    clearBtn:SetSize(100, 22)
    clearBtn:SetPoint("TOPRIGHT", f, "TOPRIGHT", -L.PADDING, py)
    clearBtn:SetText("Clear All")
    clearBtn:SetScript("OnClick", function()
        addon.db.rotation = {}
        addon:RefreshRotationList()
        addon:ResetOverlay()
    end)

    -- Scroll frame
    local sf = CreateFrame("ScrollFrame", "WowReminderRotScroll", f, "UIPanelScrollFrameTemplate")
    addon.rotScrollFrame = sf
    sf:SetPoint("TOPLEFT",     f, "TOP",         L.PADDING,  py - 28)
    sf:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -L.PADDING, L.PADDING)

    -- Scroll child
    local sc = CreateFrame("Frame", "WowReminderRotScrollChild", sf)
    sc:SetWidth(L.PANEL_W - 20)
    sc:SetHeight(L.ROW_H)
    sf:SetScrollChild(sc)
    addon.rotScrollChild = sc

    addon.rotRows = {}

    -- Empty rotation message
    local emptyMsg = sc:CreateFontString(nil, "OVERLAY", "GameFontDisable")
    emptyMsg:SetPoint("TOP", sc, "TOP", 0, -30)
    emptyMsg:SetText("Rotation is empty.\nAdd spells from the left panel\nor use the |cffffd700By ID|r button.")
    emptyMsg:SetJustifyH("CENTER")
    addon.rotEmptyMsg = emptyMsg

    addon:RefreshRotationList()
end

-- ── Rotation row ──────────────────────────────────────────────────────────────

function addon:CreateRotationRow(parent, index)
    local L   = addon.LAYOUT
    local row = CreateFrame("Frame", nil, parent)
    row:SetHeight(L.ROW_H)
    row:SetPoint("TOPLEFT",  parent, "TOPLEFT",  0, -(index - 1) * L.ROW_H)
    row:SetPoint("TOPRIGHT", parent, "TOPRIGHT", 0, -(index - 1) * L.ROW_H)

    -- Alternating background (slight green tint to distinguish from left panel)
    local bg = row:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    if index % 2 == 0 then
        bg:SetColorTexture(0.06, 0.10, 0.08, 0.6)
    else
        bg:SetColorTexture(0.10, 0.14, 0.10, 0.6)
    end

    -- Position number
    local numText = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    numText:SetSize(22, L.ROW_H)
    numText:SetPoint("LEFT", row, "LEFT", 2, 0)
    numText:SetJustifyH("RIGHT")
    numText:SetTextColor(0.8, 0.8, 0.3)
    row.numText = numText

    -- Icon
    local icon = row:CreateTexture(nil, "ARTWORK")
    icon:SetSize(L.ICON_SIZE, L.ICON_SIZE)
    icon:SetPoint("LEFT", row, "LEFT", 26, 0)
    row.icon = icon

    -- Name
    local nameText = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    nameText:SetPoint("TOPLEFT",  icon, "TOPRIGHT",   6,  -2)
    nameText:SetPoint("TOPRIGHT", row,  "TOPRIGHT", -108, -2)
    nameText:SetJustifyH("LEFT")
    nameText:SetWordWrap(false)
    row.nameText = nameText

    -- Spell ID
    local idText = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    idText:SetPoint("BOTTOMLEFT",  icon, "BOTTOMRIGHT",  6,  2)
    idText:SetPoint("BOTTOMRIGHT", row,  "BOTTOMRIGHT", -108, 2)
    idText:SetJustifyH("LEFT")
    idText:SetTextColor(0.45, 0.45, 0.45)
    row.idText = idText

    -- ── Action buttons ────────────────────────────────────────────────────────

    -- Delete (plain button, "X" text — Unicode cross does not render in WoW fonts)
    local btnDel = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
    btnDel:SetSize(30, 22)
    btnDel:SetPoint("RIGHT", row, "RIGHT", -4, 0)
    btnDel:SetText("X")
    btnDel:SetScript("OnClick", function()
        if row.rotIndex and addon:RemoveFromRotation(row.rotIndex) then
            addon:RefreshRotationList()
            addon:ResetOverlay()
        end
    end)
    row.btnDel = btnDel

    -- Move down (WoW native arrow texture — Unicode triangles do not render)
    local btnDown = CreateFrame("Button", nil, row)
    btnDown:SetSize(22, 22)
    btnDown:SetPoint("RIGHT", btnDel, "LEFT", -2, 0)
    btnDown:SetNormalTexture("Interface\\Buttons\\Arrow-Down-Up")
    btnDown:SetPushedTexture("Interface\\Buttons\\Arrow-Down-Down")
    btnDown:SetDisabledTexture("Interface\\Buttons\\Arrow-Down-Disabled")
    btnDown:SetHighlightTexture("Interface\\Buttons\\Arrow-Down-Hilight", "ADD")
    btnDown:SetScript("OnClick", function()
        if row.rotIndex and addon:MoveDown(row.rotIndex) then
            addon:RefreshRotationList()
            addon:ResetOverlay()
        end
    end)
    row.btnDown = btnDown

    -- Move up
    local btnUp = CreateFrame("Button", nil, row)
    btnUp:SetSize(22, 22)
    btnUp:SetPoint("RIGHT", btnDown, "LEFT", -2, 0)
    btnUp:SetNormalTexture("Interface\\Buttons\\Arrow-Up-Up")
    btnUp:SetPushedTexture("Interface\\Buttons\\Arrow-Up-Down")
    btnUp:SetDisabledTexture("Interface\\Buttons\\Arrow-Up-Disabled")
    btnUp:SetHighlightTexture("Interface\\Buttons\\Arrow-Up-Hilight", "ADD")
    btnUp:SetScript("OnClick", function()
        if row.rotIndex and addon:MoveUp(row.rotIndex) then
            addon:RefreshRotationList()
            addon:ResetOverlay()
        end
    end)
    row.btnUp = btnUp

    row:Hide()
    return row
end

-- ── Refresh rotation list ─────────────────────────────────────────────────────

function addon:RefreshRotationList()
    local sc = addon.rotScrollChild
    if not sc then return end

    local rot = addon.db.rotation
    local n   = #rot
    local L   = addon.LAYOUT

    sc:SetHeight(math.max(n * L.ROW_H, L.ROW_H))

    for _, row in ipairs(addon.rotRows) do
        row:Hide()
    end

    for i, spell in ipairs(rot) do
        if not addon.rotRows[i] then
            addon.rotRows[i] = addon:CreateRotationRow(sc, i)
        end
        local row = addon.rotRows[i]

        row:SetPoint("TOPLEFT",  sc, "TOPLEFT",  0, -(i - 1) * L.ROW_H)
        row:SetPoint("TOPRIGHT", sc, "TOPRIGHT", 0, -(i - 1) * L.ROW_H)

        row.rotIndex = i
        row.numText:SetText(i .. ".")
        row.nameText:SetText(spell.name)
        row.idText:SetText("ID: " .. spell.spellID)
        row.icon:SetTexture(spell.icon or "Interface\\Icons\\INV_Misc_QuestionMark")

        row.btnUp:SetEnabled(i > 1)
        row.btnDown:SetEnabled(i < n)

        row:Show()
    end

    if addon.rotEmptyMsg then
        addon.rotEmptyMsg:SetShown(n == 0)
    end
end
