local _, GA = ...

local Multi = { auctions = {}, order = {}, counter = 0, maximum = 4, antiSnipe = 10 }
GA.GDKPMultiAuction = Multi

local function now() return type(GetTime) == "function" and GetTime() or 0 end
local function stamp() return type(time) == "function" and time() or 0 end
local function me() return type(UnitName) == "function" and UnitName("player") or "player" end
local function key(name) return string.lower(string.match(tostring(name or ""), "^[^-]+") or "") end
local function integer(value, minimum, maximum)
    value = tonumber(value); return value and value == math.floor(value) and value >= minimum and value <= maximum and value or nil
end
local function member(name)
    for unit in GA.Compat:IterateGroupUnits() do if key(GA.Compat:UnitFullName(unit)) == key(name) then return true end end
    return key(name) == key(me())
end
local function persist(self)
    if self.store then self.store.auctions, self.store.order, self.store.counter = self.auctions, self.order, self.counter end
end
local function emit(...) GA.Events:Emit(...) end
local function activeCount(self)
    local count = 0; for _, state in pairs(self.auctions) do if state.status == "ACTIVE" then count = count + 1 end end; return count
end

function Multi:GetAuctions()
    local result = {}; for _, id in ipairs(self.order) do if self.auctions[id] then result[#result + 1] = self.auctions[id] end end; return result
end
function Multi:Get(id) return self.auctions[tostring(id or "")] end
function Multi:GetBidderState(id, player)
    local state = self:Get(id); if not state then return nil end
    return { amount = state.bidderAmounts[key(player or me())] or 0, leading = key(state.currentBidder) == key(player or me()), status = state.status }
end

function Multi:Start(itemLink, minimum, increment, duration)
    if not GA.RollSession:IsAuthority(me()) then return nil, "Nur Lootmaster oder Gruppenleiter dürfen Auktionen starten" end
    if activeCount(self) >= self.maximum then return nil, "Maximal vier parallele Auktionen" end
    if type(itemLink) ~= "string" or not GA.Compat:GetItemID(itemLink) then return nil, "Gültiger Itemlink erforderlich" end
    minimum, increment, duration = integer(minimum or 0, 0, 2147483647), integer(increment or 1, 1, 2147483647), integer(duration or 30, 5, 600)
    if not minimum or not increment or not duration then return nil, "Ungültige Auktionsparameter" end
    self.counter = self.counter + 1; local id = key(me()) .. "-multi-" .. stamp() .. "-" .. self.counter
    local state = { id = id, owner = me(), itemLink = itemLink, minimum = minimum, increment = increment, duration = duration,
        endsAt = now() + duration, deadlineAt = stamp() + duration, hardEndsAt = now() + duration + 120, status = "ACTIVE",
        currentBid = 0, bids = {}, bidderAmounts = {}, bidderSequences = {}, sequence = 1 }
    self.auctions[id], self.order[#self.order + 1] = state, id
    local sent, err = GA.Comm:Send("MA_START", { id, 1, itemLink, minimum, increment, duration, stamp() })
    if not sent then self.auctions[id] = nil; table.remove(self.order); return nil, err end
    persist(self); emit("GA_GDKP_MULTI_CHANGED", state, "START"); return state
end

function Multi:Bid(id, amount)
    local state = self:Get(id); if not state or state.status ~= "ACTIVE" or now() >= state.endsAt then return false, "Auktion ist nicht aktiv" end
    amount = integer(amount, 0, 2147483647); local required = state.currentBid > 0 and state.currentBid + state.increment or state.minimum
    if not amount or amount < required then return false, "Mindestgebot: " .. required end
    local bidder = key(me()); local sequence = (state.bidderSequences[bidder] or 0) + 1
    local sent, err = GA.Comm:Send("MA_BID", { id, sequence, amount }, "WHISPER", state.owner)
    if not sent then return false, err end
    state.bidderSequences[bidder] = sequence; persist(self); return true
end

function Multi:Stop(id, reason)
    local state = self:Get(id); if not state or state.status ~= "ACTIVE" then return nil, "Auktion ist nicht aktiv" end
    if key(state.owner) ~= key(me()) or not GA.RollSession:IsAuthority(me()) then return nil, "Nur der Auktionator darf beenden" end
    state.sequence = state.sequence + 1; state.status, state.reason, state.endedAt = "ENDED", tostring(reason or "ENDED"), now()
    local sent, err = GA.Comm:Send("MA_END", { id, state.sequence, state.currentBidder or "", state.currentBid, state.reason })
    if not sent then state.sequence = state.sequence - 1; state.status = "ACTIVE"; return nil, err end
    if state.currentBidder and GA.GDKP and GA.GDKP.active then GA.GDKP:AddSale(state.itemLink, state.currentBidder, state.currentBid) end
    persist(self); emit("GA_GDKP_MULTI_CHANGED", state, "END"); return state
end

function Multi:Remove(id)
    local state = self:Get(id); if state and state.status == "ACTIVE" then return false, "Aktive Auktion zuerst beenden" end
    self.auctions[id] = nil; for index, value in ipairs(self.order) do if value == id then table.remove(self.order, index); break end end
    persist(self); emit("GA_GDKP_MULTI_CHANGED", nil, "REMOVE"); return true
end

function Multi:EnqueueInventory(minimum, increment, duration, minimumQuality)
    if type(GetContainerNumSlots) ~= "function" or type(GetContainerItemLink) ~= "function" then return 0, "Taschen-API nicht verfügbar" end
    minimumQuality = tonumber(minimumQuality) or 2; local added = 0
    for bag = 0, 4 do
        local slots = tonumber(GetContainerNumSlots(bag)) or 0
        for slot = 1, slots do
            local link = GetContainerItemLink(bag, slot)
            if link then
                local _, _, quality = GetItemInfo(link)
                if (tonumber(quality) or 0) >= minimumQuality then
                    local price = GA.GDKP and GA.GDKP:GetPrice(link)
                    local queued = GA.GDKPAuction:Enqueue(link, price and price.minimum or minimum, price and price.increment or increment, duration)
                    if queued then added = added + 1 end
                end
            end
        end
    end
    return added
end

local function receiveStart(fields, sender)
    if not member(sender) or not GA.RollSession:IsAuthority(sender) then return end
    local id, sequence, minimum, increment, duration = fields[1], integer(fields[2], 1, 1000000000), integer(fields[4], 0, 2147483647), integer(fields[5], 1, 2147483647), integer(fields[6], 5, 600)
    if type(id) ~= "string" or #id > 96 or not sequence or not GA.Compat:GetItemID(fields[3]) or not minimum or not increment or not duration then return end
    if Multi.auctions[id] and Multi.auctions[id].sequence >= sequence then return end
    local state = { id = id, sequence = sequence, owner = sender, itemLink = fields[3], minimum = minimum, increment = increment, duration = duration,
        endsAt = now() + duration, hardEndsAt = now() + duration + 120, status = "ACTIVE", currentBid = 0, bids = {}, bidderAmounts = {}, bidderSequences = {} }
    Multi.auctions[id] = state; Multi.order[#Multi.order + 1] = id; persist(Multi); emit("GA_GDKP_MULTI_CHANGED", state, "REMOTE_START")
end
local function receiveBid(fields, sender)
    local state, sequence, amount = Multi:Get(fields[1]), integer(fields[2], 1, 1000000000), integer(fields[3], 0, 2147483647)
    if not state or state.status ~= "ACTIVE" or key(state.owner) ~= key(me()) or not member(sender) or not sequence or not amount or now() >= state.endsAt then return end
    local bidder, required = key(sender), state.currentBid > 0 and state.currentBid + state.increment or state.minimum
    if sequence <= (state.bidderSequences[bidder] or 0) or amount < required then return end
    state.bidderSequences[bidder], state.bidderAmounts[bidder] = sequence, amount; state.currentBid, state.currentBidder = amount, sender
    state.bids[#state.bids + 1] = { player = sender, amount = amount, time = stamp() }
    if state.endsAt - now() <= Multi.antiSnipe then state.endsAt = math.min(now() + Multi.antiSnipe, state.hardEndsAt) end
    state.sequence = state.sequence + 1; GA.Comm:Send("MA_UPDATE", { state.id, state.sequence, sender, amount, math.max(0, state.endsAt - now()) })
    persist(Multi); emit("GA_GDKP_MULTI_CHANGED", state, "BID")
end
local function receiveUpdate(fields, sender)
    local state, sequence, amount, remaining = Multi:Get(fields[1]), integer(fields[2], 1, 1000000000), integer(fields[4], 0, 2147483647), tonumber(fields[5])
    if not state or key(state.owner) ~= key(sender) or not member(sender) or not GA.RollSession:IsAuthority(sender) or not sequence or sequence <= state.sequence or not amount or not remaining or remaining < 0 or remaining > 720 then return end
    state.sequence, state.currentBidder, state.currentBid, state.endsAt = sequence, fields[3], amount, now() + remaining
    state.bidderAmounts[key(fields[3])] = amount; state.bids[#state.bids + 1] = { player = fields[3], amount = amount, time = stamp() }
    persist(Multi); emit("GA_GDKP_MULTI_CHANGED", state, "REMOTE_BID")
end
local function receiveEnd(fields, sender)
    local state, sequence, amount = Multi:Get(fields[1]), integer(fields[2], 1, 1000000000), integer(fields[4], 0, 2147483647)
    if not state or key(state.owner) ~= key(sender) or not member(sender) or not GA.RollSession:IsAuthority(sender) or not sequence or sequence <= state.sequence or not amount then return end
    state.sequence, state.status, state.currentBidder, state.currentBid, state.reason, state.endedAt = sequence, "ENDED", fields[3] ~= "" and fields[3] or nil, amount, fields[5], now()
    persist(Multi); emit("GA_GDKP_MULTI_CHANGED", state, "REMOTE_END")
end

function Multi:OnInitialize()
    GA.DB.data.character.gdkpMultiAuction = GA.DB.data.character.gdkpMultiAuction or { auctions = {}, order = {}, counter = 0 }
    self.store = GA.DB.data.character.gdkpMultiAuction; self.auctions = type(self.store.auctions) == "table" and self.store.auctions or {}; self.order = type(self.store.order) == "table" and self.store.order or {}; self.counter = tonumber(self.store.counter) or 0
    for _, state in pairs(self.auctions) do if state.status == "ACTIVE" then local remaining = (tonumber(state.deadlineAt) or 0) - stamp(); if remaining > 0 and remaining <= 720 then state.endsAt = now() + remaining else state.status = "EXPIRED" end end end
    GA.Comm:RegisterHandler("MA_START", receiveStart); GA.Comm:RegisterHandler("MA_BID", receiveBid); GA.Comm:RegisterHandler("MA_UPDATE", receiveUpdate); GA.Comm:RegisterHandler("MA_END", receiveEnd)
    self.frame = CreateFrame("Frame"); local elapsed = 0; self.frame:SetScript("OnUpdate", function(_, delta)
        elapsed = elapsed + delta; if elapsed < .25 then return end; elapsed = 0
        for _, state in pairs(Multi.auctions) do if state.status == "ACTIVE" then state.deadlineAt = stamp() + math.max(0, state.endsAt - now()); if key(state.owner) == key(me()) and now() >= state.endsAt then Multi:Stop(state.id, "TIMEOUT") end end end; persist(Multi)
    end)
    return true
end
function Multi:OnSave() persist(self) end

GA:RegisterModule("GDKPMultiAuction", Multi)
