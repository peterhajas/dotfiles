require "streamdeck_buttons.button_images"
require 'home_assistant'
require 'util'

function homeAssistant()
    return {
        ['image'] = streamdeck_imageFromText("􀎟"),
        ['children'] = function()
            allStates = homeAssistantRun('GET', 'states')
            children = { }
            for index, state in pairs(allStates) do
                local entityID = state['entity_id']
                local name = state['attributes']['friendly_name']
                if name == nil then
                    name = entityID
                end
                local entityType = split(entityID, '.')[1]
                local buttonText = name .. '\n(' .. entityType .. ')'
                if string.find(entityID, 'light.') or string.find(entityID, 'switch.') or string.find(entityID, 'scene') then
                    table.insert(children, {
                        ['name'] = 'home_assistant_toggle/' .. entityID,
                        ['imageProvider'] = function()
                            local stateNow = homeAssistantRun('GET', 'states' .. '/' .. entityID)
                            local options = {
                                ['fontSize'] = 20,
                            }
                            if entityType == 'scene' then
                                options['textColor'] = hs.drawing.color.blue
                            end
                            if stateNow['state'] == 'on' then
                                options['backgroundColor'] = hs.drawing.color.white
                                options['textColor'] = hs.drawing.color.black
                            end
                            return streamdeck_imageFromText(buttonText, options)
                        end,
                        ['pressUp'] = function()
                             if string.find(entityID, 'light.') then
                                homeAssistantRun('POST', 'services/light/toggle', { ['entity_id'] = entityID })
                             elseif string.find(entityID, 'switch.') then
                                homeAssistantRun('POST', 'services/switch/toggle', { ['entity_id'] = entityID })
                             elseif string.find(entityID, 'scene.') then
                                homeAssistantRun('POST', 'services/scene/turn_on', { ['entity_id'] = entityID })
                             end
                        end
                    })
                end
            end
            return children
        end,
    }
end
