-- WowReminder/Utils.lua
-- Fonctions utilitaires : données de sort, gestion de la rotation

local addon = WowReminder

-- ── Données de sort ──────────────────────────────────────────────────────────

-- Retourne { spellID, name, icon } ou nil
function addon:GetSpellData(spellID)
    if not spellID then return nil end
    spellID = tonumber(spellID)
    if not spellID then return nil end

    local name, icon

    -- API moderne (TWW 11.x)
    if C_Spell and C_Spell.GetSpellInfo then
        local info = C_Spell.GetSpellInfo(spellID)
        if info and info.name and info.name ~= "" then
            name = info.name
            icon = info.iconID
        end
    end

    -- Fallback ancienne API
    if not name then
        local n, _, i = GetSpellInfo(spellID)
        if n and n ~= "" then
            name = n
            icon = i
        end
    end

    if not name then return nil end

    return { spellID = spellID, name = name, icon = icon }
end

-- ── Gestion de la rotation ───────────────────────────────────────────────────

-- Ajoute un sort (les doublons sont autorisés)
function addon:AddToRotation(spellData)
    if not spellData or not spellData.spellID then return false end
    table.insert(addon.db.rotation, {
        spellID = spellData.spellID,
        name    = spellData.name,
        icon    = spellData.icon,
    })
    addon:ResetOverlay()
    return true
end

-- Supprime à l'index donné
function addon:RemoveFromRotation(index)
    if index and addon.db.rotation[index] then
        table.remove(addon.db.rotation, index)
        return true
    end
    return false
end

-- Monte d'une position
function addon:MoveUp(index)
    local rot = addon.db.rotation
    if index and index > 1 and rot[index] then
        rot[index], rot[index - 1] = rot[index - 1], rot[index]
        return true
    end
    return false
end

-- Descend d'une position
function addon:MoveDown(index)
    local rot = addon.db.rotation
    if index and index < #rot and rot[index] then
        rot[index], rot[index + 1] = rot[index + 1], rot[index]
        return true
    end
    return false
end
