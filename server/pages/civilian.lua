return function(ctx)
    ctx.registerPage('civilian', {
        callbacks = {
            'cortex_mdt:getStandaloneCivilianState',
            'cortex_mdt:getCivilianRecords',
            'cortex_mdt:generateStandaloneCivilian',
            'cortex_mdt:registerStandaloneCivilian',
            'cortex_mdt:claimStandaloneCivilian',
            'cortex_mdt:unclaimStandaloneCivilian',
            'cortex_mdt:updateStandaloneCivilian',
            'cortex_mdt:deleteStandaloneCivilian',
            'cortex_mdt:registerStandaloneVehicle',
            'cortex_mdt:deleteStandaloneVehicle',
        },
        storage = 'session',
    })
end
