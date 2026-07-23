return function(ctx)
    ctx.registerPage('units', {
        callbacks = {
            'cortex_mdt:getUnits',
            'cortex_mdt:updateUnitStatus',
            'cortex_mdt:goOnDuty',
            'cortex_mdt:goOffDuty',
        },
        storage = 'framework',
    })
end
