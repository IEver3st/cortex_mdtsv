local SqlStore = {}

function SqlStore.available()
    return type(MySQL) == 'table' and type(MySQL.query) == 'table'
end

function SqlStore.query(sql, params)
    if not SqlStore.available() then
        return {}
    end
    return MySQL.query.await(sql, params or {}) or {}
end

function SqlStore.scalar(sql, params)
    if type(MySQL) ~= 'table' or type(MySQL.scalar) ~= 'table' then
        return nil
    end
    return MySQL.scalar.await(sql, params or {})
end

function SqlStore.insert(sql, params)
    if type(MySQL) ~= 'table' or type(MySQL.insert) ~= 'table' then
        return nil
    end
    return MySQL.insert.await(sql, params or {})
end

function SqlStore.update(sql, params)
    if type(MySQL) ~= 'table' or type(MySQL.update) ~= 'table' then
        return 0
    end
    return MySQL.update.await(sql, params or {}) or 0
end

return SqlStore
