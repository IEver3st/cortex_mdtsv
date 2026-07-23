return function(ctx)
    ctx.registerPage('vehicles', {
        callbacks = {
            'cortex_mdt:searchVehicles',
            'cortex_mdt:getVehicle',
            'cortex_mdt:impoundVehicle',
            'cortex_mdt:releaseImpound',
        },
        storage = 'mode',
    })
end
