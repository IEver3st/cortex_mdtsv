return function(ctx)
    ctx.registerPage('roster', {
        callbacks = {
            'cortex_mdt:getRoster',
            'cortex_mdt:updateOfficerAdmin',
            'cortex_mdt:searchOfficers',
        },
        durable = { 'callsign', 'avatar' },
    })
end
