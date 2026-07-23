return function(ctx)
    ctx.registerPage('dispatch', {
        callbacks = {
            'cortex_mdt:getDispatch',
            'cortex_mdt:attachDispatchCall',
            'cortex_mdt:detachDispatchCall',
            'cortex_mdt:updateDispatchCall',
            'cortex_mdt:code4DispatchCall',
        },
        storage = 'session',
    })
end
