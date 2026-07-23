return function(ctx)
    ctx.registerPage('charges', {
        callbacks = {
            'cortex_mdt:getCharges',
            'cortex_mdt:updateCharge',
        },
        durable = { 'charges' },
    })
end
