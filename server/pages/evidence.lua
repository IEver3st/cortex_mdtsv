return function(ctx)
    ctx.registerPage('evidence', {
        callbacks = {
            'cortex_mdt:getEvidence',
            'cortex_mdt:getEvidenceRecord',
            'cortex_mdt:createEvidence',
            'cortex_mdt:updateEvidence',
            'cortex_mdt:transferEvidence',
            'cortex_mdt:addAttachment',
            'cortex_mdt:removeAttachment',
        },
        storage = 'mode',
    })
end
