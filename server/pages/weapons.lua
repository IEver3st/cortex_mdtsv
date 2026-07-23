return function(ctx)
    ctx.registerPage('weapons', {
        callbacks = {
            'cortex_mdt:getWeapons',
            'cortex_mdt:searchWeapons',
            'cortex_mdt:getWeapon',
            'cortex_mdt:getWeaponRecord',
            'cortex_mdt:getWeaponAnalytics',
            'cortex_mdt:createWeapon',
            'cortex_mdt:updateWeapon',
            'cortex_mdt:transferWeapon',
        },
        storage = 'mode',
    })
end
