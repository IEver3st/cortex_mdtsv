local Core = nil
local Registry = {
    pages = {},
    callbacks = {},
}

local function loadCore()
    if Core then
        return Core
    end

    local resourceName = GetCurrentResourceName()
    local chunk = LoadResourceFile(resourceName, 'server/core.lua')
    local fn = chunk and load(chunk, ('@%s/server/core.lua'):format(resourceName), 't', _ENV) or nil
    Core = fn and fn() or rawget(_G, 'CortexMdtCore') or {}
    return Core
end

function Registry.registerPage(name, contract)
    if type(name) ~= 'string' or name == '' then
        return false
    end

    Registry.pages[name] = type(contract) == 'table' and contract or {}
    return true
end

function Registry.getPages()
    return Registry.pages
end

function Registry.register(name, handler, opts)
    opts = type(opts) == 'table' and opts or {}
    Registry.callbacks[name] = {
        handler = handler,
        opts = opts,
    }

    if type(lib) ~= 'table' or type(lib.callback) ~= 'table' or type(lib.callback.register) ~= 'function' then
        return false
    end

    lib.callback.register(name, function(source, data)
        local core = loadCore()

        if opts.admin then
            local officer, err = core.requireAdmin(source, opts.permission)
            if not officer then
                return core.fail(err or 'Admin permission required.', 'admin_required')
            end
        elseif opts.officer then
            local officer, err = core.requireOfficer(source)
            if not officer then
                return core.fail(err or 'Officer profile unavailable.', 'officer_required')
            end
        end

        local ok, result = pcall(handler, source, data)
        if not ok then
            print(('[cortex_mdt] Callback %s failed: %s'):format(name, result))
            return core.fail('Server callback failed.', 'callback_error')
        end

        if opts.audit then
            core.audit(source, opts.audit.action or name, opts.audit.category, opts.audit.targetType, opts.audit.targetId, opts.audit.details)
        end

        if type(result) == 'table' and result.ok ~= nil then
            return result
        end

        return core.ok(type(result) == 'table' and result or { data = result })
    end)

    return true
end

return Registry
