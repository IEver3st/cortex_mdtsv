return function(ctx)
    ctx.registerPage('cctv', {
        callbacks = {
            'cortex_mdt:getCameras',
            'cortex_mdt:viewCamera',
            'cortex_mdt:createCamera',
            'cortex_mdt:deleteCamera',
            'cortex_mdt:setCameraOnline',
        },
        storage = 'mode',
    })
end
