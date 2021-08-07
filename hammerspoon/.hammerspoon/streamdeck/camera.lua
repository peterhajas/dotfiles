require 'home_assistant'

-- These require a special payload - not totally sure why

camera1Button = {
    ['name'] = 'Camera 1',
    ['image'] = streamdeck_imageFromText('􀍊 1', { ['fontSize'] = 45 }),
    ['onClick'] = function()
        homeAssistantRun('POST', 'events/dash_cam_1', { [''] = '' })
    end
}

camera2Button = {
    ['name'] = 'Camera 2',
    ['image'] = streamdeck_imageFromText('􀍊 2', { ['fontSize'] = 45 }),
    ['onClick'] = function()
        homeAssistantRun('POST', 'events/dash_cam_2', { [''] = '' })
    end
}

dashClose = {
    ['name'] = 'DashClose',
    ['image'] = streamdeck_imageFromText('DX', { ['fontSize'] = 45 }),
    ['onClick'] = function()
        homeAssistantRun('POST', 'events/dash_close', { [''] = '' })
    end
}
