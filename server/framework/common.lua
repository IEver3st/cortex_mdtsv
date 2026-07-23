local Common = {}

local providers = {}

local function loadProvider(name)
    if providers[name] then
        return providers[name]
    end

    local resourceName = GetCurrentResourceName()
    local path = ('server/framework/%s/provider.lua'):format(name)
    local chunk = LoadResourceFile(resourceName, path)
    local fn = chunk and load(chunk, ('@%s/%s'):format(resourceName, path), 't', _ENV) or nil
    providers[name] = fn and fn() or {}
    return providers[name]
end

local function activeMode()
    local bridge = rawget(_G, 'CortexDutyBridge')
    if type(bridge) == 'table' and type(bridge.getFrameworkMode) == 'function' then
        local ok, mode = pcall(bridge.getFrameworkMode)
        if ok and type(mode) == 'string' then
            return mode
        end
    end

    return 'standalone'
end

local function activeProvider()
    local mode = activeMode()
    if mode == 'qbx' or mode == 'qbox' then
        return loadProvider('qbox')
    end
    if mode == 'ers' then
        return loadProvider('ers')
    end
    return loadProvider('standalone')
end

function Common.getMode()
    local provider = activeProvider()
    return (provider.getMode and provider.getMode()) or activeMode()
end

function Common.getOfficer(source)
    local provider = activeProvider()
    return provider.getOfficer and provider.getOfficer(source) or nil
end

function Common.getCivilian(source)
    local provider = activeProvider()
    return provider.getCivilian and provider.getCivilian(source) or nil
end

function Common.isOnDuty(source)
    local provider = activeProvider()
    return provider.isOnDuty and provider.isOnDuty(source) or false
end

function Common.setDuty(source, enabled)
    local provider = activeProvider()
    return provider.setDuty and provider.setDuty(source, enabled) or false
end

function Common.getStableIdentifier(source)
    local provider = activeProvider()
    return provider.getStableIdentifier and provider.getStableIdentifier(source) or tostring(source)
end

function Common.getDepartment(source)
    local provider = activeProvider()
    return provider.getDepartment and provider.getDepartment(source) or nil
end

_G.CortexMdtFramework = Common

return Common
