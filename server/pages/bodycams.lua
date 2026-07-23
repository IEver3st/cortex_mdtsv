return function(ctx)
    ctx.registerPage('bodycams', {
        callbacks = {
            'cortex_mdt:getBodycams',
            'cortex_mdt:viewBodycam',
            'cortex_mdt:stopBodycam',
            'cortex_mdt:setBodycamAudio',
        },
        storage = 'live',
    })
end
