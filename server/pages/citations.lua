return function(ctx)
    ctx.registerPage('citations', {
        callbacks = {
            'cortex_mdt:issueCitation',
            'cortex_mdt:getMyCitations',
            'cortex_mdt:getCitation',
            'cortex_mdt:markCitationViewed',
        },
        storage = 'mode',
    })
end
