local pages = {
    'dashboard',
    'dispatch',
    'units',
    'roster',
    'citizens',
    'civilian',
    'vehicles',
    'reports',
    'cases',
    'evidence',
    'bolos',
    'warrants',
    'weapons',
    'charges',
    'leaderboard',
    'cctv',
    'bodycams',
    'fto',
    'sops',
    'command',
    'settings',
    'search',
    'citations',
}

local contracts = {}

local ctx = {}

function ctx.registerPage(name, contract)
    contracts[name] = type(contract) == 'table' and contract or {}
    return true
end

local function loadPage(name)
    local resourceName = GetCurrentResourceName()
    local path = ('server/pages/%s.lua'):format(name)
    local chunk = LoadResourceFile(resourceName, path)
    if not chunk then
        error(('[cortex_mdt] Missing page module: %s'):format(path))
    end

    local fn, err = load(chunk, ('@%s/%s'):format(resourceName, path), 't', _ENV)
    if not fn then
        error(('[cortex_mdt] Failed to compile %s: %s'):format(path, err))
    end

    local page = fn()
    if type(page) ~= 'function' then
        error(('[cortex_mdt] Page module must return function: %s'):format(path))
    end

    page(ctx)
end

for i = 1, #pages do
    loadPage(pages[i])
end

_G.CortexMdtPageContracts = contracts

return contracts
