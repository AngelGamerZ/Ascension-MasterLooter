local _, ns = ...

local Events = { listeners = {}, registrations = {} }
ns.Events = Events

local frame = CreateFrame("Frame")
Events.frame = frame

local function sortListeners(a, b)
    if a.priority == b.priority then
        return a.order < b.order
    end
    return a.priority > b.priority
end

local listenerOrder = 0

function Events:On(event, callback, owner, priority)
    assert(type(event) == "string" and event ~= "", "Events:On requires an event")
    assert(type(callback) == "function", "Events:On requires a callback")
    local list = self.listeners[event]
    if not list then
        list = {}
        self.listeners[event] = list
    end
    listenerOrder = listenerOrder + 1
    local token = {
        event = event,
        callback = callback,
        owner = owner,
        priority = tonumber(priority) or 0,
        order = listenerOrder,
    }
    list[#list + 1] = token
    table.sort(list, sortListeners)
    return token
end

function Events:Off(token)
    if type(token) ~= "table" or not token.event then return false end
    local list = self.listeners[token.event]
    if not list then return false end
    for index = #list, 1, -1 do
        if list[index] == token then
            table.remove(list, index)
            return true
        end
    end
    return false
end

function Events:OffOwner(owner)
    for _, list in pairs(self.listeners) do
        for index = #list, 1, -1 do
            if list[index].owner == owner then
                table.remove(list, index)
            end
        end
    end
end

function Events:Emit(event, ...)
    local list = self.listeners[event]
    if not list then return end
    -- A snapshot permits listeners to unregister safely during dispatch.
    local snapshot = {}
    for index = 1, #list do snapshot[index] = list[index] end
    for index = 1, #snapshot do
        local listener = snapshot[index]
        local ok, err = pcall(listener.callback, listener.owner, event, ...)
        if not ok then ns.ReportError("event " .. event, err) end
    end
end

function Events:RegisterGameEvent(event)
    if not self.registrations[event] then
        frame:RegisterEvent(event)
        self.registrations[event] = true
    end
end

function Events:UnregisterGameEvent(event)
    if self.registrations[event] then
        frame:UnregisterEvent(event)
        self.registrations[event] = nil
    end
end

frame:SetScript("OnEvent", function(_, event, ...)
    Events:Emit(event, ...)
end)

