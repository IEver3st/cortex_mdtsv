return function(ctx)
    ctx.registerPage('sops', {
        callbacks = {
            'cortex_mdt:getSops',
            'cortex_mdt:getFeatureRecords',
            'cortex_mdt:acknowledgeSop',
            'cortex_mdt:getSopAcknowledgements',
        },
        durable = { 'pageConfig' },
    })
end
