return function(ctx)
    ctx.registerPage('leaderboard', {
        callbacks = {
            'cortex_mdt:getLeaderboard',
        },
        storage = 'audit',
    })
end
