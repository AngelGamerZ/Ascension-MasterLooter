local _, GA = ...

local ItemDataBridge = {}
GA.ItemData = ItemDataBridge

function ItemDataBridge:GetLoadedProvider()
    return _G.MasterLooterItemData
end

function ItemDataBridge:Load()
    if self:GetLoadedProvider() then return self:GetLoadedProvider() end
    if type(LoadAddOn) == "function" then pcall(LoadAddOn, "MasterLooter_ItemData") end
    return self:GetLoadedProvider()
end

-- Loading the optional index is deliberately deferred. LoadAddOn and addon
-- initialization execute on WoW's main thread; doing that from an edit-box
-- click would freeze the complete client until the first index pass finishes.
function ItemDataBridge:LoadAsync()
    if self:GetLoadedProvider() or self.loadScheduled then return true end
    self.loadScheduled = true
    local function load()
        self.loadScheduled = nil
        self:Load()
    end
    if GA.Compat and type(GA.Compat.After) == "function" then
        GA.Compat:After(0, load)
    else
        load()
    end
    return true
end

function ItemDataBridge:Peek(itemID)
    local provider = self:GetLoadedProvider()
    return provider and provider.Get and provider:Get(itemID) or nil
end

function ItemDataBridge:PeekFamily(itemID)
    local provider = self:GetLoadedProvider()
    return provider and provider.GetFamily and provider:GetFamily(itemID) or nil
end

function ItemDataBridge:Get(itemID)
    local provider = self:Load()
    return provider and provider:Get(itemID) or nil
end

function ItemDataBridge:Search(query, limit, filters)
    local provider = self:Load()
    return provider and provider:Search(query, limit, filters) or {}
end

function ItemDataBridge:GetFamily(itemID)
    local provider = self:Load()
    return provider and provider.GetFamily and provider:GetFamily(itemID) or nil
end

function ItemDataBridge:GetStats()
    local provider = self:Load()
    return provider and provider.GetStats and provider:GetStats() or { items = 0, families = 0, verified = 0 }
end

function ItemDataBridge:OnInitialize() return true end
GA:RegisterModule("ItemData", ItemDataBridge)
