return function(ctx)
    ctx.registerPage('settings', {
        callbacks = {
            'cortex_mdt:getSettings',
            'cortex_mdt:updateSetting',
            'cortex_mdt:saveOfficerAvatar',
            'cortex_mdt:fetchLicenseTypes',
            'cortex_mdt:createLicenseType',
            'cortex_mdt:updateLicenseType',
            'cortex_mdt:deleteLicenseType',
        },
        durable = { 'settings', 'announcements', 'callsign', 'avatar', 'licenses', 'pageConfig' },
    })
end
