local _, GA = ...

local ItemDataBridge = {}
GA.ItemData = ItemDataBridge

function ItemDataBridge:Load()
    if _G.MasterLooterItemData then return _G.MasterLooterItemData end
    if type(LoadAddOn) == "function" then pcall(LoadAddOn, "MasterLooter_ItemData") end
    return _G.MasterLooterItemData
end

function ItemDataBridge:Get(itemID)
    local provider = self:Load()
    return provider and provider:Get(itemID) or nil
end

function ItemDataBridge:Search(query, limit)
    local provider = self:Load()
    return provider and provider:Search(query, limit) or {}
end

function ItemDataBridge:GetFamily(itemID)
    local provider = self:Load()
    return provider and provider.GetFamily and provider:GetFamily(itemID) or nil
end

function ItemDataBridge:OnInitialize() return true end
GA:RegisterModule("ItemData", ItemDataBridge)
