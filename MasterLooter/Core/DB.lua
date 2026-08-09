local _, ns = ...

local DB = { migrations = {} }
ns.DB = DB

local DEFAULTS = {
    schema = ns.DB_SCHEMA,
    profile = {
        minimap = { hide = false, angle = 220 },
        rollWindow = { scale = 1, point = "CENTER", x = 0, y = 0 },
        masterLooterWindow = { scale = 1, point = "CENTER", x = 0, y = 120 },
        language = "AUTO",
        announceChannel = "RAID_WARNING",
        autoOpenRollWindow = true,
        autoGiveAwards = true,
        defaultRollDuration = 30,
        osRollMaximum = 99,
        sound = true,
        debugMode = true,
    },
    profiles = {},
    profileAssignments = {},
    activeProfile = "Default",
    history = { awards = {}, gdkp = {} },
    lootLedger = { entries = {}, nextID = 0 },
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
    local character = self:GetCharacterKey()
    local name = (character and self.data.profileAssignments and self.data.profileAssignments[character]) or self.data.activeProfile or "Default"
    self.data.activeProfile = name
    local profile = self.data.profiles[name]
    if type(profile) ~= "table" then
        profile = deepCopy(self.data.profile)
        self.data.profiles[name] = profile
    end
    -- Existing profiles also receive settings introduced by newer builds.
    return copyDefaults(DEFAULTS.profile, profile)
end

function DB:GetCharacterKey()
    if type(UnitName) ~= "function" then return nil end
    local name = UnitName("player")
    if not name then return nil end
    local realm = type(GetRealmName) == "function" and GetRealmName() or ""
    return string.lower(tostring(name) .. "-" .. tostring(realm))
end

function DB:GetProfileNames()
    local names = {}
    for name in pairs(self.data.profiles or {}) do names[#names + 1] = name end
    if #names == 0 then self:GetProfile(); names[1] = self.data.activeProfile or "Default" end
    table.sort(names, function(a, b) return string.lower(a) < string.lower(b) end)
    return names
end

function DB:CopyProfile(source, target)
    if type(target) ~= "string" or target == "" or self.data.profiles[target] then return nil, "Profilname existiert bereits oder ist ungültig." end
    local current = self.data.profiles[source or self.data.activeProfile]
    if type(current) ~= "table" then return nil, "Quellprofil nicht gefunden." end
    self.data.profiles[target] = deepCopy(current)
    return self.data.profiles[target]
end

function DB:RenameProfile(source, target)
    if type(source) ~= "string" or type(self.data.profiles[source]) ~= "table" then return false, "Profil nicht gefunden." end
    if type(target) ~= "string" or target == "" or self.data.profiles[target] then return false, "Zielprofil existiert bereits oder ist ungültig." end
    self.data.profiles[target], self.data.profiles[source] = self.data.profiles[source], nil
    if self.data.activeProfile == source then self.data.activeProfile = target end
    for character, profileName in pairs(self.data.profileAssignments or {}) do if profileName == source then self.data.profileAssignments[character] = target end end
    return true
end

function DB:DeleteProfile(name)
    if not self.data.profiles[name] then return false, "Profil nicht gefunden." end
    if #self:GetProfileNames() <= 1 then return false, "Das letzte Profil kann nicht gelöscht werden." end
    self.data.profiles[name] = nil
    for character, profileName in pairs(self.data.profileAssignments or {}) do if profileName == name then self.data.profileAssignments[character] = nil end end
    if self.data.activeProfile == name then self.data.activeProfile = self:GetProfileNames()[1] end
    return true
end

function DB:AssignProfile(name)
    if type(self.data.profiles[name]) ~= "table" then return false, "Profil nicht gefunden." end
    self.data.activeProfile = name
    local character = self:GetCharacterKey()
    if character then self.data.profileAssignments[character] = name end
    return true
end

function DB:ResetAll()
    local target = self.data or {}
    for key in pairs(target) do target[key] = nil end
    copyDefaults(DEFAULTS, target)
    _G.MasterLooterDB, self.data = target, target
    return target
end

function DB:SetProfile(name)
    assert(type(name) == "string" and name ~= "", "Profile name required")
    self.data.activeProfile = name
    local character = self:GetCharacterKey()
    if character then self.data.profileAssignments[character] = name end
    return self:GetProfile()
end

function DB:ResetProfile(name)
    name = name or self.data.activeProfile or "Default"
    self.data.profiles[name] = deepCopy(DEFAULTS.profile)
    return self.data.profiles[name]
end
