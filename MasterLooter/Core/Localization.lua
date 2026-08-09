local _, GA = ...

-- Central, dependency-free localization service. It is loaded before the
-- database so every module can safely request strings during initialization.
local Locale = {
    translations = {},
    aliases = {},
    supported = { enUS = true, deDE = true },
    fallback = "enUS",
    pendingMode = nil,
    missing = {},
    raw = {},
    rawReverse = {},
    phrases = {},
    phrasesReverse = {},
}

GA.Locale = Locale
GA.Localization = Locale -- descriptive backwards/consumer-facing alias
Locale.TRANSLATIONS = Locale.translations

local function normalize(mode)
    mode = tostring(mode or "AUTO")
    if string.upper(mode) == "AUTO" then return "AUTO" end
    if mode == "deDE" or string.lower(mode) == "de" or string.lower(mode) == "german" then return "deDE" end
    if mode == "enUS" or string.lower(mode) == "en" or string.lower(mode) == "english" then return "enUS" end
    return nil
end

local function clientLocale()
    local value = type(GetLocale) == "function" and GetLocale() or nil
    return Locale.supported[value] and value or Locale.fallback
end

function Locale:Register(locale, values)
    assert(self.supported[locale], "unsupported locale: " .. tostring(locale))
    assert(type(values) == "table", "locale values must be a table")
    local target = self.translations[locale] or {}
    for key, value in pairs(values) do
        if type(key) == "string" and type(value) == "string" then target[key] = value end
    end
    self.translations[locale] = target
    self.TRANSLATIONS = self.translations
    -- Raw aliases allow central UI factories to localize legacy literal text.
    for key, value in pairs(target) do self.aliases[value] = key end
end

function Locale:RegisterRaw(source, english)
    if type(source) ~= "string" or type(english) ~= "string" then return false end
    self.raw[source] = english
    self.rawReverse[english] = source
    return true
end

function Locale:RegisterPhrases(values)
    for _, value in ipairs(values or {}) do
        if type(value) == "table" and type(value[1]) == "string" and type(value[2]) == "string" then
            self.phrases[#self.phrases + 1] = value
            self.phrasesReverse[#self.phrasesReverse + 1] = { value[2], value[1] }
        end
    end
end

local function escapePattern(value)
    return (string.gsub(value, "([%(%)%.%%%+%-%*%?%[%]%^%$])", "%%%1"))
end

local function escapeReplacement(value)
    return (string.gsub(value, "%%", "%%%%"))
end

local function protectHyperlinks(value)
    local links = {}
    value = string.gsub(value, "(|c%x+|H.-|h.-|h|r)", function(link)
        links[#links + 1] = link
        return "\001MLLINK" .. tostring(#links) .. "\002"
    end)
    return value, links
end

local function restoreHyperlinks(value, links)
    return (string.gsub(value, "\001MLLINK(%d+)\002", function(index) return links[tonumber(index)] or "" end))
end

function Locale:GetLanguageMode()
    if self.pendingMode then return self.pendingMode end
    if GA.DB and type(GA.DB.GetProfile) == "function" and GA.DB.data then
        local ok, profile = pcall(GA.DB.GetProfile, GA.DB)
        if ok and type(profile) == "table" then return normalize(profile.language) or "AUTO" end
    end
    return "AUTO"
end

function Locale:GetLocale()
    local mode = self:GetLanguageMode()
    return mode == "AUTO" and clientLocale() or (self.supported[mode] and mode or self.fallback)
end

function Locale:GetLanguage() return self:GetLocale() end

function Locale:SetLocale(mode)
    local normalized = normalize(mode)
    if not normalized then return false, self:Get("error.language.unsupported", tostring(mode)) end
    self.pendingMode = normalized
    if GA.DB and type(GA.DB.GetProfile) == "function" and GA.DB.data then
        local ok, profile = pcall(GA.DB.GetProfile, GA.DB)
        if ok and type(profile) == "table" then profile.language = normalized end
    end
    local resolved = self:GetLocale()
    if GA.Events and type(GA.Events.Emit) == "function" then GA.Events:Emit("GA_LOCALE_CHANGED", resolved, normalized) end
    return true, resolved
end

function Locale:SetLanguage(mode) return self:SetLocale(mode) end

function Locale:Get(key, ...)
    key = tostring(key or "")
    local locale = self:GetLocale()
    local primary = self.translations[locale] or {}
    local fallback = self.translations[self.fallback] or {}
    local value = primary[key] or fallback[key]
    if value == nil then
        self.missing[key] = (tonumber(self.missing[key]) or 0) + 1
        value = key
    end
    if select("#", ...) > 0 then
        local ok, formatted = pcall(string.format, value, ...)
        if ok then return formatted end
    end
    return value
end

function Locale:Translate(text, ...)
    if type(text) ~= "string" then return text end
    local key = self.aliases[text] or text
    if self.aliases[text] then return self:Get(key, ...) end
    local locale = self:GetLocale()
    if locale == "enUS" or locale == "deDE" then
        local dictionary = locale == "enUS" and self.raw or self.rawReverse
        local phrases = locale == "enUS" and self.phrases or self.phrasesReverse
        local translated = dictionary[text]
        if not translated then
            local links
            translated, links = protectHyperlinks(text)
            for _, phrase in ipairs(phrases) do
                translated = string.gsub(translated, escapePattern(phrase[1]), escapeReplacement(phrase[2]))
            end
            translated = restoreHyperlinks(translated, links)
        end
        if select("#", ...) > 0 then
            local ok, formatted = pcall(string.format, translated, ...)
            if ok then return formatted end
        end
        return translated
    end
    return text
end

function Locale:GetMissingKeys() return self.missing end

function GA:L(key, ...) return Locale:Get(key, ...) end
function GA:Localize(text, ...) return Locale:Translate(text, ...) end
