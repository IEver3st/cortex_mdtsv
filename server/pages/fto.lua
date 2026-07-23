return function(ctx)
    ctx.registerPage('fto', {
        callbacks = {
            'cortex_mdt:getFtoRecords',
            'cortex_mdt:createFtoRecord',
            'cortex_mdt:updateFtoRecord',
        },
        storage = 'session',
    })
end
