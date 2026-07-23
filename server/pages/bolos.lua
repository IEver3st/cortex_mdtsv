return function(ctx)
    ctx.registerPage('bolos', {
        callbacks = {
            'cortex_mdt:getBolos',
            'cortex_mdt:createBolo',
            'cortex_mdt:updateBoloStatus',
        },
        storage = 'mode',
    })
end
