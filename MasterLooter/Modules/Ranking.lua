local _, GA = ...

local Ranking = {}
GA.Ranking = Ranking

local choiceRank = { MS = 3, OS = 2, PASS = 0 }

function Ranking:Score(session, participant)
    local player, item = participant.name, session.itemLink
    local softRes = GA.SoftRes:IsReserved(player, item) and 1 or 0
    local priority = GA.Priority:Get(item, player)
    local plusOne = GA.PlusOnes:Get(player)
    local effectiveRoll = GA.BoostedRolls:Apply(player, participant.roll)
    participant.softReserved = softRes == 1
    participant.priority = priority
    participant.plusOne = plusOne
    participant.effectiveRoll = effectiveRoll
    return { choiceRank[participant.choice] or 0, softRes, priority, -plusOne, effectiveRoll }
end

function Ranking:Compare(session, a, b)
    local left, right = self:Score(session, a), self:Score(session, b)
    for index = 1, #left do
        if left[index] ~= right[index] then return left[index] > right[index] end
    end
    return string.lower(a.name or "") < string.lower(b.name or "")
end

function Ranking:GetSorted(session)
    local result = {}
    for _, participant in pairs(session and session.participants or {}) do
        if participant.choice ~= "PASS" then result[#result + 1] = participant end
    end
    table.sort(result, function(a, b) return Ranking:Compare(session, a, b) end)
    return result
end

function Ranking:OnInitialize()
    GA.Events:On("GA_ROLL_SESSION_UPDATED", function(_, _, session)
        Ranking:GetSorted(session)
    end, self)
    return true
end
GA:RegisterModule("Ranking", Ranking)
