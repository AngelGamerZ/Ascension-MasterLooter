local _, GA = ...

local BoostedRolls = {}
GA.BoostedRolls = BoostedRolls

local function key(name) return string.lower(string.match(tostring(name or ""), "^[^-]+") or "") end

function BoostedRolls:Get(player) return tonumber(GA.DB.data.boostedRolls[key(player)]) or 0 end
function BoostedRolls:Set(player, bonus)
    bonus = math.floor(tonumber(bonus) or 0)
    GA.DB.data.boostedRolls[key(player)] = bonus ~= 0 and bonus or nil
    GA.Events:Emit("GA_BOOST_CHANGED", player, bonus)
    return bonus
end
function BoostedRolls:Apply(player, roll) return math.max(1, math.min(100, (tonumber(roll) or 0) + self:Get(player))) end
function BoostedRolls:OnInitialize() return true end
GA:RegisterModule("BoostedRolls", BoostedRolls)
