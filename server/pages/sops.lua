return function(ctx)
    ctx.registerPage('sops', {
        callbacks = {
            'cortex_mdt:getSops',
        },
        durable = { 'pageConfig' },
    })
end
