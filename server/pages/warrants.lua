return function(ctx)
    ctx.registerPage('warrants', {
        callbacks = {
            'cortex_mdt:getWarrants',
            'cortex_mdt:createWarrant',
            'cortex_mdt:updateWarrantStatus',
        },
        storage = 'mode',
    })
end
