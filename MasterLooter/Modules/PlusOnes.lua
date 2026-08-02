local _, GA = ...

local PlusOnes = {}
GA.PlusOnes = PlusOnes

local function key(name) return string.lower(string.match(tostring(name or ""), "^[^-]+") or "") end

function PlusOnes:Get(player) return tonumber(GA.DB.data.plusOnes[key(player)]) or 0 end
function PlusOnes:Set(player, value)
    value = math.max(0, math.floor(tonumber(value) or 0))
    GA.DB.data.plusOnes[key(player)] = value
    GA.Events:Emit("GA_PLUSONE_CHANGED", player, value)
    return value
end
function PlusOnes:Add(player, amount) return self:Set(player, self:Get(player) + (tonumber(amount) or 1)) end
function PlusOnes:Reset() wipe(GA.DB.data.plusOnes); GA.Events:Emit("GA_PLUSONE_RESET") end
function PlusOnes:Compare(a, b)
    local av, bv = self:Get(a), self:Get(b)
    if av ~= bv then return av < bv end
    return string.lower(a) < string.lower(b)
end
function PlusOnes:OnInitialize() return true end
GA:RegisterModule("PlusOnes", PlusOnes)
