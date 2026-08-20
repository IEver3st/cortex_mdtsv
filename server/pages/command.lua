return function(ctx)
    ctx.registerPage('command', {
        callbacks = {
            'cortex_mdt:getFeatureRecords',
            'cortex_mdt:createFeatureRecord',
            'cortex_mdt:updateFeatureRecord',
            'cortex_mdt:deleteFeatureRecord',
            'cortex_mdt:acknowledgeSop',
            'cortex_mdt:getSopAcknowledgements',
            'cortex_mdt:submitPublicComplaint',
        },
        storage = 'persistent',
    })
end
