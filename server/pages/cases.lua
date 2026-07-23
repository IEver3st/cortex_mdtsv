return function(ctx)
    ctx.registerPage('cases', {
        callbacks = {
            'cortex_mdt:getCases',
            'cortex_mdt:getCase',
            'cortex_mdt:createCase',
            'cortex_mdt:updateCase',
            'cortex_mdt:addCaseLink',
            'cortex_mdt:removeCaseLink',
            'cortex_mdt:addCasePersonnel',
            'cortex_mdt:removeCasePersonnel',
        },
        storage = 'mode',
    })
end
