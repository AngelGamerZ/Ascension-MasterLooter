local addonName, addon = ...

addon = type(addon) == "table" and addon or {}
_G.MasterLooterItemData = addon

local SCHEMA = 1
local ITEM_LINK_PATTERN = "(|c%x+|Hitem:[^|]+|h%[[^%]]+%]|h|r)"

local function normalize(value)
    value = tostring(value or ""):lower()
    value = value:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
    value = value:gsub("^%s+", ""):gsub("%s+$", "")
    return value
end

local function itemIDFromLink(link)
    return tonumber(tostring(link or ""):match("item:(%-?%d+)"))
end

local function resolveInstant(itemID)
    if type(GetItemInfoInstant) ~= "function" then
        return nil
    end

    local first, second, third, fourth, fifth, sixth, seventh = GetItemInfoInstant(itemID)
    if type(first) == "table" then
        return {
            name = first.name,
            quality = first.quality,
            classID = first.classID,
            subclassID = first.subclassID,
            inventoryType = first.inventoryType,
            icon = first.icon,
            itemLevel = first.itemLevel,
        }
    end

    return {
        itemID = first,
        classID = third,
        subclassID = fourth,
        inventoryType = fifth,
        icon = seventh or sixth,
    }
end

function addon:Initialize()
    if type(MasterLooterItemDB) ~= "table" or MasterLooterItemDB.schema ~= SCHEMA then
        MasterLooterItemDB = {
            schema = SCHEMA,
            snapshot = "runtime",
            items = {},
            families = {},
        }
    end

    MasterLooterItemDB.items = MasterLooterItemDB.items or {}
    MasterLooterItemDB.families = MasterLooterItemDB.families or {}
    self.DB = MasterLooterItemDB
    self:ImportAtlasLootFamilies()
    self:LearnBags()
end

function addon:Add(itemID, name, quality, link, metadata)
    itemID = tonumber(itemID)
    if not itemID or itemID <= 0 then
        return false
    end

    local current = self.DB.items[itemID] or {}
    local instant = resolveInstant(itemID) or {}
    local infoName, infoLink, infoQuality, infoLevel, _, infoType, infoSubType, _, infoEquip, infoIcon
    if type(GetItemInfo) == "function" then
        infoName, infoLink, infoQuality, infoLevel, _, infoType, infoSubType, _, infoEquip, infoIcon = GetItemInfo(itemID)
    end

    current.name = infoName or name or instant.name or current.name
    current.quality = infoQuality or quality or instant.quality or current.quality
    current.link = infoLink or link or current.link
    current.itemLevel = infoLevel or instant.itemLevel or current.itemLevel
    current.classID = instant.classID or current.classID
    current.subclassID = instant.subclassID or current.subclassID
    current.inventoryType = instant.inventoryType or infoEquip or current.inventoryType
    current.icon = infoIcon or instant.icon or current.icon
    current.verified = infoLink ~= nil or link ~= nil
    current.seenAt = time and time() or 0

    if type(metadata) == "table" then
        for key, value in pairs(metadata) do
            current[key] = value
        end
    end

    if current.name then
        current.searchName = normalize(current.name)
    end
    self.DB.items[itemID] = current
    return current.name ~= nil
end

function addon:LearnLink(link)
    local itemID = itemIDFromLink(link)
    if not itemID then
        return false
    end
    local name = tostring(link):match("%[([^%]]+)%]")
    local color = tostring(link):match("|c(%x%x%x%x%x%x%x%x)")
    return self:Add(itemID, name, nil, link, { color = color })
end

function addon:LearnText(text)
    for link in tostring(text or ""):gmatch(ITEM_LINK_PATTERN) do
        self:LearnLink(link)
    end
end

function addon:LearnBags()
    if type(GetContainerNumSlots) ~= "function" then
        return
    end
    for bag = 0, 4 do
        for slot = 1, GetContainerNumSlots(bag) do
            local link = GetContainerItemLink and GetContainerItemLink(bag, slot)
            if link then
                self:LearnLink(link)
            end
        end
    end
end

function addon:ImportAtlasLootFamilies()
    local source = _G.ItemIDsDatabase
    if type(source) ~= "table" then
        return 0
    end

    local imported = 0
    for baseID, variants in pairs(source) do
        if type(baseID) == "number" and type(variants) == "table" then
            local family = self.DB.families[baseID] or { [3] = baseID }
            for difficulty, itemID in pairs(variants) do
                if type(difficulty) == "number" and type(itemID) == "number" then
                    family[difficulty] = itemID
                    self:Add(itemID, nil, nil, nil, {
                        familyID = baseID,
                        difficulty = difficulty,
                        source = "AtlasLoot",
                    })
                    imported = imported + 1
                end
            end
            self.DB.families[baseID] = family
            self:Add(baseID, nil, nil, nil, { familyID = baseID, difficulty = 3 })
        end
    end
    return imported
end

function addon:Get(itemID)
    return self.DB and self.DB.items[tonumber(itemID)] or nil
end

function addon:GetFamily(itemID)
    local entry = self:Get(itemID)
    local familyID = entry and entry.familyID or tonumber(itemID)
    return self.DB and self.DB.families[familyID] or nil
end

function addon:Search(query, limit)
    query = normalize(query)
    limit = math.max(1, math.min(tonumber(limit) or 20, 100))
    if #query < 2 then
        return {}
    end

    local results = {}
    for itemID, entry in pairs(self.DB.items) do
        local name = entry.searchName or normalize(entry.name)
        local startAt = name:find(query, 1, true)
        if startAt then
            results[#results + 1] = {
                itemID = itemID,
                name = entry.name,
                link = entry.link,
                quality = entry.quality,
                familyID = entry.familyID,
                difficulty = entry.difficulty,
                score = startAt == 1 and 0 or startAt,
            }
        end
    end

    table.sort(results, function(a, b)
        if a.score ~= b.score then return a.score < b.score end
        if a.name ~= b.name then return tostring(a.name) < tostring(b.name) end
        return a.itemID < b.itemID
    end)
    while #results > limit do
        table.remove(results)
    end
    return results
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("BAG_UPDATE")
frame:RegisterEvent("CHAT_MSG_LOOT")
frame:RegisterEvent("CHAT_MSG_SYSTEM")
frame:RegisterEvent("CHAT_MSG_RAID")
frame:RegisterEvent("CHAT_MSG_PARTY")
frame:RegisterEvent("CHAT_MSG_WHISPER")
frame:SetScript("OnEvent", function(_, event, arg1)
    if event == "ADDON_LOADED" then
        if arg1 == addonName then
            addon:Initialize()
        end
        return
    end
    if not addon.DB then return end
    if event == "BAG_UPDATE" then
        addon:LearnBags()
    else
        addon:LearnText(arg1)
    end
end)
