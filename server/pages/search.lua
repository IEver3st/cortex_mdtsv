return function(ctx)
    ctx.registerPage('search', {
        callbacks = {
            'cortex_mdt:globalSearch',
        },
        storage = 'mode',
    })
end
