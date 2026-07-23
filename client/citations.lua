local isOpen = false

local function closeCitationNui()
    if not isOpen then return end
    isOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'cortex_mdt:hideCitation' })
end

RegisterNUICallback('cortex_mdt:closeCitation', function(_, cb)
    closeCitationNui()
    cb('ok')
end)

RegisterCommand(Config.Citations.showCommand or 'showcitation', function()
    if isOpen then
        closeCitationNui()
        return
    end

    isOpen = true
    SetNuiFocus(true, true)

    SendNUIMessage({
        action = 'cortex_mdt:showCitation',
        data = {
            playerName = GetPlayerName(PlayerId()) or 'Unknown',
        },
    })
end, false)

RegisterKeyMapping(Config.Citations.showCommand or 'showcitation', 'Show MDT Citations', 'keyboard', '')

RegisterNUICallback('cortex_mdt:getMyCitations', function(_, cb)
    if not _G.CortexMdtServerCallback then
        cb({ ok = false, citations = {} })
        return
    end

    local response = _G.CortexMdtServerCallback('cortex_mdt:getMyCitations') or { ok = false, citations = {} }
    cb(response)
end)

RegisterNUICallback('cortex_mdt:getCitation', function(data, cb)
    if not _G.CortexMdtServerCallback then
        cb({ ok = false, error = 'Server unavailable.' })
        return
    end

    local response = _G.CortexMdtServerCallback('cortex_mdt:getCitation', data) or { ok = false, error = 'Failed to load citation.' }
    cb(response)
end)

RegisterNUICallback('cortex_mdt:markCitationViewed', function(data, cb)
    if not _G.CortexMdtServerCallback then
        cb({ ok = false })
        return
    end

    local response = _G.CortexMdtServerCallback('cortex_mdt:markCitationViewed', data) or { ok = false }
    cb(response)
end)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then
        return
    end
    if isOpen then
        closeCitationNui()
    end
end)
