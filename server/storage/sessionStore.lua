local existing = rawget(_G, 'CortexPersistentSessionStore')
if type(existing) == 'table' then
    return existing
end

local resourceName = GetCurrentResourceName()
local STORAGE_KEY = 'cortex_mdt:persistent_namespaces:v2'
local SAVE_DEBOUNCE_MS = 250

local function loadResourceModule(path)
    local chunk = LoadResourceFile(resourceName, path)
    local fn = chunk and load(chunk, ('@%s/%s'):format(resourceName, path), 't', _ENV) or nil
    return fn and fn() or nil
end

local LocalStorage = loadResourceModule('server/localStorage.lua')

local function emptyState()
    return {
        version = 2,
        counters = {},
        namespaces = {},
    }
end

local function restoreState()
    if type(LocalStorage) ~= 'table' or type(LocalStorage.get) ~= 'function' then
        return emptyState()
    end

    local stored = LocalStorage.get(STORAGE_KEY)
    if type(stored) ~= 'table' then
        return emptyState()
    end

    stored.version = 2
    stored.counters = type(stored.counters) == 'table' and stored.counters or {}
    stored.namespaces = type(stored.namespaces) == 'table' and stored.namespaces or {}
    return stored
end

local SessionStore = {
    state = restoreState(),
}

local dirty = false
local flushScheduled = false

local function namespace(name)
    name = tostring(name or 'default')
    if type(SessionStore.state.namespaces[name]) ~= 'table' then
        SessionStore.state.namespaces[name] = {}
    end
    return SessionStore.state.namespaces[name]
end

local function flush()
    flushScheduled = false
    if not dirty then
        return true
    end

    if type(LocalStorage) ~= 'table' or type(LocalStorage.set) ~= 'function' then
        return false
    end

    local ok = LocalStorage.set(STORAGE_KEY, SessionStore.state)
    if ok then
        dirty = false
    else
        print('[cortex_mdt] Failed to persist feature namespaces; the current in-memory state remains active.')
    end
    return ok == true
end

local function markDirty()
    dirty = true
    if flushScheduled then
        return
    end

    flushScheduled = true
    SetTimeout(SAVE_DEBOUNCE_MS, flush)
end

function SessionStore.reset()
    SessionStore.state = emptyState()
    markDirty()
end

function SessionStore.getState()
    return SessionStore.state
end

function SessionStore.flush()
    return flush()
end

function SessionStore.nextId(prefix)
    prefix = tostring(prefix or 'row')
    SessionStore.state.counters[prefix] = (tonumber(SessionStore.state.counters[prefix]) or 0) + 1
    markDirty()
    return ('%s:%d'):format(prefix, SessionStore.state.counters[prefix])
end

function SessionStore.get(namespaceName, id)
    return namespace(namespaceName)[tostring(id)]
end

function SessionStore.list(namespaceName)
    local rows = {}
    for _, row in pairs(namespace(namespaceName)) do
        rows[#rows + 1] = row
    end
    return rows
end

function SessionStore.set(namespaceName, id, row)
    namespace(namespaceName)[tostring(id)] = row
    markDirty()
    return row
end

function SessionStore.insert(namespaceName, row, prefix)
    row = type(row) == 'table' and row or {}
    local id = row.id or SessionStore.nextId(prefix or namespaceName)
    row.id = id
    namespace(namespaceName)[tostring(id)] = row
    markDirty()
    return row
end

function SessionStore.update(namespaceName, id, changes)
    local row = namespace(namespaceName)[tostring(id)]
    if type(row) ~= 'table' then
        return nil
    end

    if type(changes) == 'table' then
        for key, value in pairs(changes) do
            row[key] = value
        end
    end

    markDirty()
    return row
end

function SessionStore.delete(namespaceName, id)
    namespace(namespaceName)[tostring(id)] = nil
    markDirty()
    return true
end

AddEventHandler('onResourceStop', function(stoppedResource)
    if stoppedResource == resourceName then
        flush()
    end
end)

_G.CortexPersistentSessionStore = SessionStore

return SessionStore
