-- WowReminder/Data.lua
-- Base de données des sorts : scan du spellbook + recherche

--[[
    LIMITE DE L'API WoW
    ═══════════════════
    Il n'existe PAS de fonction pour lister "tous les sorts du jeu".
    GetSpellInfo(id) fonctionne uniquement si l'on connaît l'ID à l'avance.

    SOLUTION RETENUE : scanner le spellbook du personnage connecté.
    ─ Avantage : dynamique, liste uniquement les sorts connus du perso.
    ─ Inconvénient : ne couvre pas les sorts d'autres classes/specs.
    ─ Complément : bouton "Par ID" pour ajouter n'importe quel sort
      dont on connaît le SpellID (trouvable sur wowhead.com).
]]

local addon = WowReminder

addon.spellDatabase = {}   -- [spellID] = spellData
addon.spellList     = {}   -- liste ordonnée pour l'affichage

-- ── Scan du spellbook ────────────────────────────────────────────────────────

function addon:ScanSpellbook()
    addon.spellDatabase = {}
    addon.spellList     = {}

    local scanned = false

    -- ── API TWW 11.x (C_SpellBook) ──────────────────────────────────────────
    if C_SpellBook and C_SpellBook.GetNumSpellBookSkillLines then
        local numLines = C_SpellBook.GetNumSpellBookSkillLines()
        for lineIndex = 1, numLines do
            local lineInfo = C_SpellBook.GetSpellBookSkillLineInfo(lineIndex)
            if lineInfo then
                local offset = lineInfo.itemIndexOffset
                local count  = lineInfo.numSpellBookItems
                for slotIndex = offset + 1, offset + count do
                    local itemInfo = C_SpellBook.GetSpellBookItemInfo(
                        slotIndex,
                        Enum.SpellBookSpellBank.Player
                    )
                    if itemInfo and itemInfo.itemType == Enum.SpellBookItemType.Spell then
                        addon:_RegisterSpell(itemInfo.actionID)
                    end
                end
            end
        end
        scanned = true
    end

    -- ── Fallback ancienne API (pre-TWW) ─────────────────────────────────────
    if not scanned and GetNumSpellTabs then
        local numTabs = GetNumSpellTabs()
        for tabIndex = 1, numTabs do
            local _, _, offset, numSlots = GetSpellTabInfo(tabIndex)
            for slotIndex = offset + 1, offset + numSlots do
                local itemType, itemID = GetSpellBookItemInfo(slotIndex, BOOKTYPE_SPELL)
                if itemType == "SPELL" and itemID then
                    addon:_RegisterSpell(itemID)
                end
            end
        end
    end

    -- Trier par nom alphabétique
    table.sort(addon.spellList, function(a, b)
        return a.name < b.name
    end)
end

-- Enregistre un spellID dans la base (ignore les doublons)
function addon:_RegisterSpell(spellID)
    if not spellID or addon.spellDatabase[spellID] then return end
    local spellData = addon:GetSpellData(spellID)
    if spellData then
        addon.spellDatabase[spellID] = spellData
        table.insert(addon.spellList, spellData)
    end
end

-- ── Recherche ────────────────────────────────────────────────────────────────

-- Retourne la liste filtrée (insensible à la casse)
function addon:SearchSpells(query)
    if not query or query == "" then
        return addon.spellList
    end
    query = query:lower()
    local results = {}
    for _, spell in ipairs(addon.spellList) do
        if spell.name:lower():find(query, 1, true) then
            table.insert(results, spell)
        end
    end
    return results
end

-- Résout un SpellID saisi manuellement (string → spellData ou nil)
function addon:ResolveManualID(input)
    return addon:GetSpellData(input)
end
