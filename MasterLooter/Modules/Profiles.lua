local _, GA = ...

local Profiles = {}
GA.Profiles = Profiles

local function valid(name)
    name = tostring(name or ""):match("^%s*(.-)%s*$")
    return name ~= "" and #name <= 40 and not name:find("[%c]") and name or nil
end

function Profiles:List() return GA.DB:GetProfileNames() end
function Profiles:GetActive() GA.DB:GetProfile(); return GA.DB.data.activeProfile end
function Profiles:Activate(name)
    name = valid(name); if not name then return false, "Ungültiger Profilname." end
    local ok, err = GA.DB:AssignProfile(name)
    if ok then GA.Events:Emit("GA_PROFILE_CHANGED", name) end
    return ok, err
end
function Profiles:Create(name)
    name = valid(name); if not name then return nil, "Ungültiger Profilname." end
    if GA.DB.data.profiles[name] then return nil, "Profil existiert bereits." end
    GA.DB.data.profiles[name] = {}
    GA.DB.data.activeProfile = name
    GA.DB:GetProfile()
    GA.DB:AssignProfile(name)
    GA.Events:Emit("GA_PROFILE_LIST_CHANGED", name, "CREATED")
    return GA.DB.data.profiles[name]
end
function Profiles:Copy(source, target)
    target = valid(target); if not target then return nil, "Ungültiger Profilname." end
    local result, err = GA.DB:CopyProfile(source, target)
    if result then GA.Events:Emit("GA_PROFILE_LIST_CHANGED", target, "COPIED") end
    return result, err
end
function Profiles:Rename(source, target)
    target = valid(target); if not target then return false, "Ungültiger Profilname." end
    local ok, err = GA.DB:RenameProfile(source, target)
    if ok then GA.Events:Emit("GA_PROFILE_LIST_CHANGED", target, "RENAMED") end
    return ok, err
end
function Profiles:Delete(name)
    local ok, err = GA.DB:DeleteProfile(name)
    if ok then GA.Events:Emit("GA_PROFILE_LIST_CHANGED", name, "DELETED") end
    return ok, err
end
function Profiles:OnInitialize() GA.DB:GetProfile(); return true end
GA:RegisterModule("Profiles", Profiles)
