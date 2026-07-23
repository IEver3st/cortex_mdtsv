return function(ctx)
    ctx.registerPage('dashboard', {
        callbacks = {
            'cortex_mdt:getDashboard',
            'cortex_mdt:sendDashboardChat',
            'cortex_mdt:getAnnouncements',
            'cortex_mdt:createAnnouncement',
            'cortex_mdt:deleteAnnouncement',
        },
        durable = { 'announcements', 'motd', 'quotes' },
    })
end
