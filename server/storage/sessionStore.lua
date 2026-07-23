local SessionStore = {
    state = {
        counters = {},
        namespaces = {},
    },
}

local function namespace(name)
    name = tostring(name or 'default')
    if not SessionStore.state.namespaces[name] then
        SessionStore.state.namespaces[name] = {}
    end
    return SessionStore.state.namespaces[name]
end

function SessionStore.reset()
    SessionStore.state = {
        counters = {},
        namespaces = {},
    }
end

function SessionStore.getState()
    return SessionStore.state
end

function SessionStore.nextId(prefix)
    prefix = tostring(prefix or 'row')
    SessionStore.state.counters[prefix] = (SessionStore.state.counters[prefix] or 0) + 1
    return ('%s:%d'):format(prefix, SessionStore.state.counters[prefix])
end

function SessionStore.get(namespaceName, id)
    return namespace(namespaceName)[id]
end

function SessionStore.list(namespaceName)
    local rows = {}
    for _, row in pairs(namespace(namespaceName)) do
        rows[#rows + 1] = row
    end
    return rows
end

function SessionStore.set(namespaceName, id, row)
    namespace(namespaceName)[id] = row
    return row
end

function SessionStore.insert(namespaceName, row, prefix)
    row = type(row) == 'table' and row or {}
    local id = row.id or SessionStore.nextId(prefix or namespaceName)
    row.id = id
    namespace(namespaceName)[id] = row
    return row
end

function SessionStore.update(namespaceName, id, changes)
    local row = namespace(namespaceName)[id]
    if type(row) ~= 'table' then
        return nil
    end

    if type(changes) == 'table' then
        for key, value in pairs(changes) do
            row[key] = value
        end
    end

    return row
end

function SessionStore.delete(namespaceName, id)
    namespace(namespaceName)[id] = nil
    return true
end

return SessionStore
