local _, GA = ...

local GDKPAuction = {
    active = nil, counter = 0, defaultAntiSnipe = 10, maxAntiSnipeExtension = 120,
    remoteTimeoutGrace = 5, sessionTTL = 900,
}
GA.GDKPAuction = GDKPAuction

local function now() return type(GetTime) == "function" and GetTime() or 0 end
local function stamp() return type(time) == "function" and time() or 0 end
local function playerName() return type(UnitName) == "function" and UnitName("player") or "player" end
local function base(name) return string.lower(string.match(tostring(name or ""), "^[^-]+") or "") end
local function integer(value, minimum, maximum)
    value = tonumber(value)
    return value and value == math.floor(value) and value >= minimum and value <= maximum and value or nil
end

local function isGroupMember(name)
    for unit in GA.Compat:IterateGroupUnits() do
        if base(GA.Compat:UnitFullName(unit)) == base(name) then return true end
    end
    return false
end

local function emit(event, ...)
    GA.Events:Emit(event, ...)
end

function GDKPAuction:GetState() return self.active end

function GDKPAuction:Start(itemLink, minimum, increment, duration)
    if not GA.RollSession:IsAuthority(playerName()) then return nil, "Nur Lootmaster oder Gruppenleiter dürfen Auktionen starten" end
    if self.active and self.active.status == "ACTIVE" then return nil, "Es läuft bereits eine Auktion" end
    if type(itemLink) ~= "string" or #itemLink > 8192 or not GA.Compat:GetItemID(itemLink) then
        return nil, "Gültiger Itemlink erforderlich"
    end
    minimum = integer(minimum or 0, 0, 2147483647)
    increment = integer(increment or 1, 1, 2147483647)
    if not minimum or not increment then return nil, "Ungültige Gebotsgrenzen" end
    duration = integer(duration or 30, 5, 600)
    if not duration then return nil, "Ungültige Auktionsdauer" end
    self.counter = self.counter + 1
    local state = { id = base(playerName()) .. "-auc-" .. tostring(stamp()) .. "-" .. self.counter,
        owner = playerName(), itemLink = itemLink, minimum = minimum, increment = increment,
        duration = duration, endsAt = now() + duration, status = "ACTIVE", currentBid = 0,
        currentBidder = nil, bids = {}, sequence = 1, bidSequences = {}, bidderAmounts = {}, localBidSequence = 0 }
    state.hardEndsAt = state.endsAt + self.maxAntiSnipeExtension
    self.active = state
    local packet, err = GA.Comm:Send("AUC_START", { state.id, state.sequence, itemLink, minimum, increment, duration, stamp() })
    if not packet then self.active = nil; return nil, err end
    emit("GA_GDKP_AUCTION_STARTED", state, "LOCAL")
    return state
end

function GDKPAuction:Bid(amount)
    local state = self.active
    if not state or state.status ~= "ACTIVE" or now() >= state.endsAt then return nil, "Keine aktive Auktion" end
    amount = integer(amount, 0, 2147483647)
    if not amount then return nil, "Ungültiges Gebot" end
    local required = state.currentBid > 0 and (state.currentBid + state.increment) or state.minimum
    if amount < required then return nil, "Mindestgebot: " .. required end
    local previousSequence = state.localBidSequence or 0
    local bidSequence = previousSequence + 1
    state.localBidSequence = bidSequence
    local packet, err = GA.Comm:Send("AUC_BID", { state.id, bidSequence, amount }, "WHISPER", state.owner)
    if not packet then state.localBidSequence = previousSequence; return nil, err end
    return true
end

function GDKPAuction:Stop(reason)
    local state = self.active
    if not state or state.status ~= "ACTIVE" then return nil, "Keine aktive Auktion" end
    if base(state.owner) ~= base(playerName()) or not GA.RollSession:IsAuthority(playerName()) then return nil, "Nur der Auktionator darf beenden" end
    reason = string.sub(tostring(reason or "ENDED"), 1, 128)
    local nextSequence = state.sequence + 1
    local previousSequence = state.sequence
    state.sequence = nextSequence
    local packet, err = GA.Comm:Send("AUC_END", { state.id, nextSequence, state.currentBidder or "", state.currentBid, reason })
    if not packet then state.sequence = previousSequence; return nil, err end
    state.status, state.reason, state.endedAt = "ENDED", reason, now()
    if state.currentBidder and GA.GDKP and GA.GDKP.active then
        GA.GDKP:AddSale(state.itemLink, state.currentBidder, state.currentBid)
    end
    emit("GA_GDKP_AUCTION_ENDED", state, "LOCAL")
    return state
end

local function receiveStart(fields, sender)
    if not isGroupMember(sender) or not GA.RollSession:IsAuthority(sender) then return end
    local id, sequence = fields[1], integer(fields[2], 1, 1000000000)
    local minimum, increment, duration = integer(fields[4], 0, 2147483647),
        integer(fields[5], 1, 2147483647), integer(fields[6], 5, 600)
    if type(id) ~= "string" or id == "" or #id > 96 or not sequence or
        type(fields[3]) ~= "string" or #fields[3] > 8192 or not GA.Compat:GetItemID(fields[3]) or
        not minimum or not increment or not duration then return end
    local existing = GDKPAuction.active
    if existing and existing.id == id and (existing.sequence or 0) >= sequence then return end
    GDKPAuction.active = { id = id, sequence = sequence, owner = sender, itemLink = fields[3], minimum = minimum,
        increment = increment, duration = duration, endsAt = now() + duration, status = "ACTIVE",
        currentBid = 0, bids = {}, startedAt = tonumber(fields[7]), bidSequences = {}, bidderAmounts = {},
        localBidSequence = 0 }
    GDKPAuction.active.hardEndsAt = GDKPAuction.active.endsAt + GDKPAuction.maxAntiSnipeExtension
    emit("GA_GDKP_AUCTION_STARTED", GDKPAuction.active, "REMOTE")
end

local function receiveBid(fields, sender)
    local state, bidSequence, amount = GDKPAuction.active, integer(fields[2], 1, 1000000000),
        integer(fields[3], 0, 2147483647)
    if not state or state.id ~= fields[1] or state.status ~= "ACTIVE" or base(state.owner) ~= base(playerName()) then return end
    if not isGroupMember(sender) or now() >= state.endsAt then return end
    if not bidSequence or not amount then return end
    local bidderKey = base(sender)
    if bidSequence <= (state.bidSequences[bidderKey] or 0) or amount <= (state.bidderAmounts[bidderKey] or -1) then return end
    local required = state.currentBid > 0 and (state.currentBid + state.increment) or state.minimum
    if not amount or amount < required then return end
    local previousBid, previousBidder, previousEndsAt = state.currentBid, state.currentBidder, state.endsAt
    local previousBidCount, previousBidSequence, previousBidderAmount = #state.bids,
        state.bidSequences[bidderKey], state.bidderAmounts[bidderKey]
    state.currentBid, state.currentBidder = amount, sender
    state.bids[#state.bids + 1] = { player = sender, amount = amount, time = stamp(), sequence = bidSequence }
    state.bidSequences[bidderKey], state.bidderAmounts[bidderKey] = bidSequence, amount
    if state.endsAt - now() <= GDKPAuction.defaultAntiSnipe then
        state.endsAt = math.min(now() + GDKPAuction.defaultAntiSnipe, state.hardEndsAt)
    end
    local nextSequence = state.sequence + 1
    local previousSequence = state.sequence
    state.sequence = nextSequence
    local packet = GA.Comm:Send("AUC_UPDATE", { state.id, nextSequence, sender, amount,
        math.max(0, state.endsAt - now()), bidSequence })
    if not packet then
        state.sequence, state.currentBid, state.currentBidder, state.endsAt = previousSequence, previousBid, previousBidder, previousEndsAt
        state.bidSequences[bidderKey], state.bidderAmounts[bidderKey] = previousBidSequence, previousBidderAmount
        if base(sender) == base(playerName()) and state.localBidSequence == bidSequence then
            state.localBidSequence = bidSequence - 1
        end
        while #state.bids > previousBidCount do table.remove(state.bids) end
        return
    end
    emit("GA_GDKP_AUCTION_UPDATED", state, "BID")
end

local function receiveUpdate(fields, sender)
    local state, sequence = GDKPAuction.active, integer(fields[2], 1, 1000000000)
    if not state or state.status ~= "ACTIVE" or state.id ~= fields[1] or not isGroupMember(sender) or
        base(state.owner) ~= base(sender) or not GA.RollSession:IsAuthority(sender) then return end
    if not sequence or sequence <= (state.sequence or 0) then return end
    local bidder, amount, remaining, bidSequence = fields[3], integer(fields[4], 0, 2147483647),
        tonumber(fields[5]), integer(fields[6], 1, 1000000000)
    if not isGroupMember(bidder) or not amount or not remaining or remaining < 0 or
        remaining > state.duration + GDKPAuction.maxAntiSnipeExtension or not bidSequence then return end
    if now() + remaining > state.hardEndsAt then return end
    local required = state.currentBid > 0 and state.currentBid + state.increment or state.minimum
    local bidderKey = base(bidder)
    if amount < required or bidSequence <= (state.bidSequences[bidderKey] or 0) or
        amount <= (state.bidderAmounts[bidderKey] or -1) then return end
    state.sequence, state.currentBid, state.currentBidder, state.endsAt = sequence, amount, bidder, now() + remaining
    state.bidSequences[bidderKey], state.bidderAmounts[bidderKey] = bidSequence, amount
    state.bids[#state.bids + 1] = { player = bidder, amount = amount, time = stamp(), sequence = bidSequence }
    emit("GA_GDKP_AUCTION_UPDATED", state, "BID")
end

local function receiveEnd(fields, sender)
    local state, sequence = GDKPAuction.active, integer(fields[2], 1, 1000000000)
    if not state or state.status ~= "ACTIVE" or state.id ~= fields[1] or not isGroupMember(sender) or
        base(state.owner) ~= base(sender) or not GA.RollSession:IsAuthority(sender) then return end
    if not sequence or sequence <= (state.sequence or 0) then return end
    local finalBid = integer(fields[4], 0, 2147483647)
    local finalBidder = fields[3] ~= "" and fields[3] or nil
    if not finalBid or (finalBidder and not isGroupMember(finalBidder)) or #tostring(fields[5] or "") > 128 then return end
    state.sequence, state.status, state.currentBidder = sequence, "ENDED", finalBidder
    state.currentBid, state.reason, state.endedAt = finalBid, tostring(fields[5] or "ENDED"), now()
    emit("GA_GDKP_AUCTION_ENDED", state, "REMOTE")
end

function GDKPAuction:OnInitialize()
    GA.Comm:RegisterHandler("AUC_START", receiveStart)
    GA.Comm:RegisterHandler("AUC_BID", receiveBid)
    GA.Comm:RegisterHandler("AUC_UPDATE", receiveUpdate)
    GA.Comm:RegisterHandler("AUC_END", receiveEnd)
    self.frame = CreateFrame("Frame")
    local elapsed = 0
    self.frame:SetScript("OnUpdate", function(_, delta)
        elapsed = elapsed + delta; if elapsed < 0.25 then return end; elapsed = 0
        local state = GDKPAuction.active
        if state and state.status == "ACTIVE" then
            if base(state.owner) == base(playerName()) and now() >= state.endsAt then GDKPAuction:Stop("TIMEOUT")
            elseif base(state.owner) ~= base(playerName()) and now() >= state.endsAt + GDKPAuction.remoteTimeoutGrace then
                state.status, state.reason, state.endedAt = "EXPIRED", "TIMEOUT_LOCAL", now()
                emit("GA_GDKP_AUCTION_ENDED", state, "LOCAL_TIMEOUT")
            else emit("GA_GDKP_AUCTION_TICK", state, math.max(0, state.endsAt - now())) end
        elseif state and state.endedAt and now() - state.endedAt > GDKPAuction.sessionTTL then
            GDKPAuction.active = nil
        end
    end)
    return true
end

GA:RegisterModule("GDKPAuction", GDKPAuction)
