return function(ctx)
    ctx.registerPage('citizens', {
        callbacks = {
            'cortex_mdt:searchCitizens',
            'cortex_mdt:getCitizen',
            'cortex_mdt:updateCitizen',
            'cortex_mdt:updateCitizenLicenses',
        },
        storage = 'mode',
    })
end
