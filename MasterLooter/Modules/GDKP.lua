local _, GA = ...

local GDKP = { active = nil }
GA.GDKP = GDKP

local function timestamp() return type(time) == "function" and time() or 0 end
local function trim(value) return string.match(tostring(value or ""), "^%s*(.-)%s*$") end
local function validPlayer(player)
    return type(player) == "string" and player ~= "" and #player <= 64 and not string.find(player, "[%c]")
end
local function persist(self) if self.store then self.store.active = self.active end end

function GDKP:Start(name)
    if self.active then return nil, "Es läuft bereits eine GDKP-Sitzung" end
    if name ~= nil then
        name = trim(name)
        if name == "" or #name > 100 or string.find(name, "[%c]") then return nil, "Ungültiger Sitzungsname" end
    end
    self.active = {
        name = name or (type(date) == "function" and date("%Y-%m-%d") or "GDKP"),
        startedAt = timestamp(), pot = 0, sales = {}, adjustments = {}, players = {},
    }
    persist(self)
    GA.Events:Emit("GA_GDKP_STARTED", self.active)
    return self.active
end

function GDKP:AddPlayer(player)
    if not self.active then return false, "Keine aktive GDKP-Sitzung" end
    player = type(player) == "string" and trim(player) or player
    if not validPlayer(player) then return false, "Ungültiger Spielername" end
    self.active.players[string.lower(player)] = player
    persist(self)
    return true
end

function GDKP:AddSale(itemLink, buyer, amount)
    if not self.active then return nil, "Keine aktive GDKP-Sitzung" end
    local id = type(itemLink) == "string" and GA.Compat:GetItemID(itemLink) or nil
    if not id or id <= 0 then return nil, "Ungültiges Item" end
    buyer = type(buyer) == "string" and trim(buyer) or buyer
    if not validPlayer(buyer) then return nil, "Ungültiger Käufer" end
    amount = tonumber(amount)
    if not amount or amount ~= math.floor(amount) or amount <= 0 or amount > 2147483647 then
        return nil, "Betrag muss eine positive ganze Zahl sein"
    end
    local sale = { itemLink = itemLink, buyer = buyer, amount = amount, time = timestamp() }
    self.active.sales[#self.active.sales + 1] = sale
    self.active.pot = self.active.pot + amount
    self:AddPlayer(buyer)
    persist(self)
    GA.Events:Emit("GA_GDKP_SALE", sale, self.active)
    return sale
end

function GDKP:Adjust(amount, reason)
    if not self.active then return false, "Keine aktive GDKP-Sitzung" end
    amount = tonumber(amount)
    if not amount or amount ~= math.floor(amount) or amount < -2147483647 or amount > 2147483647 then
        return false, "Ungültiger Anpassungsbetrag"
    end
    reason = tostring(reason or "")
    if #reason > 500 or string.find(reason, "[%c]") then return false, "Ungültiger Grund" end
    self.active.adjustments[#self.active.adjustments + 1] = { amount = amount, reason = reason, time = timestamp() }
    self.active.pot = math.max(0, self.active.pot + amount)
    persist(self)
    return true
end

function GDKP:GetCut(count)
    if not self.active then return 0 end
    if count == nil then
        count = 0
        for _ in pairs(self.active.players) do count = count + 1 end
    end
    count = tonumber(count) or 0
    return count > 0 and math.floor(self.active.pot / count) or 0
end

function GDKP:Finish()
    if not self.active then return nil end
    local finished = self.active
    finished.finishedAt = timestamp()
    GA.DB.data.history.gdkp[#GA.DB.data.history.gdkp + 1] = finished
    self.active = nil
    persist(self)
    GA.Events:Emit("GA_GDKP_FINISHED", finished)
    return finished
end

function GDKP:OnInitialize()
    GA.DB.data.character.gdkp = GA.DB.data.character.gdkp or { active = nil }
    self.store = GA.DB.data.character.gdkp
    self.active = type(self.store.active) == "table" and self.store.active or nil
    if self.active then
        self.active.sales = type(self.active.sales) == "table" and self.active.sales or {}
        self.active.adjustments = type(self.active.adjustments) == "table" and self.active.adjustments or {}
        self.active.players = type(self.active.players) == "table" and self.active.players or {}
        self.active.pot = math.max(0, tonumber(self.active.pot) or 0)
    end
    persist(self)
    return true
end

function GDKP:OnSave() persist(self) end

GA:RegisterModule("GDKP", GDKP)
