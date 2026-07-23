return function(ctx)
    ctx.registerPage('reports', {
        callbacks = {
            'cortex_mdt:getReports',
            'cortex_mdt:getReport',
            'cortex_mdt:createReport',
            'cortex_mdt:updateReport',
            'cortex_mdt:addReportTimeline',
            'cortex_mdt:addReportEntity',
            'cortex_mdt:removeReportEntity',
        },
        storage = 'mode',
    })
end
