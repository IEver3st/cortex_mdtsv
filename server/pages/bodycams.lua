return function(ctx)
    ctx.registerPage('bodycams', {
        callbacks = {
            'cortex_mdt:getBodycams',
            'cortex_mdt:viewBodycam',
            'cortex_mdt:getLiveFeeds',
            'cortex_mdt:viewLiveFeed',
            'cortex_mdt:stopCameraView',
            'cortex_mdt:setBodycamAudio',
        },
        storage = 'live',
    })
end
