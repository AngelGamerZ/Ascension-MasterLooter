local _, ns = ...

local DB = { migrations = {} }
ns.DB = DB

local DEFAULTS = {
    schema = ns.DB_SCHEMA,
    profile = {
        minimap = { hide = false, angle = 220 },
        rollWindow = { scale = 1, point = "CENTER", x = 0, y = 0 },
        masterLooterWindow = { scale = 1, point = "CENTER", x = 0, y = 120 },
        announceChannel = "RAID",
        autoOpenRollWindow = true,
        autoGiveAwards = true,
        defaultRollDuration = 30,
        osRollMaximum = 99,
        sound = true,
    },
    profiles = {},
    activeProfile = "Default",
    history = { awards = {}, gdkp = {} },
    softRes = { reservations = {}, hardReserved = {} },
    plusOnes = {},
    priorities = {},
    boostedRolls = {},
    packMule = { target = nil, queue = {} },
    character = {},
}

local function copyDefaults(defaults, destination)
    if type(destination) ~= "table" then destination = {} end
    for key, value in pairs(defaults) do
        if type(value) == "table" then
            destination[key] = copyDefaults(value, destination[key])
        elseif destination[key] == nil then
            destination[key] = value
        end
    end
    return destination
end

local function deepCopy(value, seen)
    if type(value) ~= "table" then return value end
    seen = seen or {}
    if seen[value] then return seen[value] end
    local result = {}
    seen[value] = result
    for key, child in pairs(value) do
        result[deepCopy(key, seen)] = deepCopy(child, seen)
    end
    return result
end

DB.migrations[1] = function(database)
    database.schema = 1
    return database
end

function DB:RegisterMigration(version, callback)
    assert(type(version) == "number" and version > 0, "Migration version must be positive")
    assert(type(callback) == "function", "Migration must be a function")
    self.migrations[version] = callback
end

function DB:Migrate(database)
    local current = tonumber(database.schema) or 0
    if current > ns.DB_SCHEMA then
        ns.ReportError("database", "Saved data is newer than this addon; preserving it without downgrade")
        return database
    end
    for version = current + 1, ns.DB_SCHEMA do
        local migration = self.migrations[version]
        if not migration then
            error("Missing database migration " .. version)
        end
        local ok, result = pcall(migration, database)
        if not ok then
            error("Database migration " .. version .. " failed: " .. tostring(result))
        end
        database = result or database
        database.schema = version
    end
    return database
end

function DB:Initialize(saved)
    if type(saved) ~= "table" then saved = {} end
    local ok, result = pcall(function() return self:Migrate(saved) end)
    if not ok then
        ns.ReportError("database", result)
        saved = { corruptBackup = saved, schema = ns.DB_SCHEMA }
    else
        saved = result
    end
    saved = copyDefaults(DEFAULTS, saved)
    _G.MasterLooterDB = saved
    self.data = saved
    return saved
end

function DB:GetProfile()
    local name = self.data.activeProfile or "Default"
    local profile = self.data.profiles[name]
    if type(profile) ~= "table" then
        profile = deepCopy(self.data.profile)
        self.data.profiles[name] = profile
    end
    -- Existing profiles also receive settings introduced by newer builds.
    return copyDefaults(DEFAULTS.profile, profile)
end

function DB:SetProfile(name)
    assert(type(name) == "string" and name ~= "", "Profile name required")
    self.data.activeProfile = name
    return self:GetProfile()
end

function DB:ResetProfile(name)
    name = name or self.data.activeProfile or "Default"
    self.data.profiles[name] = deepCopy(DEFAULTS.profile)
    return self.data.profiles[name]
end
