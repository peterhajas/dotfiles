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
                local includedEntityTypes = { 'light', 'switch', 'scene', 'script', 'group' }
                local include = false
                for index, includedEntityType in pairs(includedEntityTypes) do
                    if string.find(entityType, includedEntityType) then
                        include = true
                        break
                    end
                end
                if include then
                    table.insert(children, {
                        ['name'] = 'home_assistant_toggle/' .. entityID,
                        ['imageProvider'] = function()
                            local stateNow = homeAssistantRun('GET', 'states' .. '/' .. entityID)
                            local options = {
                                ['fontSize'] = 20,
                                ['textColor'] = hs.drawing.color.white,
                                ['backgroundColor'] = hs.drawing.color.black
                            }
                            if entityType == 'scene' then
                                options['textColor'] = hs.drawing.color.blue
                            end
                            if entityType == 'group' then
                                options['textColor'] = hs.drawing.color.green
                            end
                            if entityType == 'script' then
                                options['textColor'] = hs.drawing.color.red
                            end
                            if stateNow['state'] == 'on' then
                                local newTextColor = options['backgroundColor']
                                options['backgroundColor'] = options['textColor']
                                options['textColor'] = newTextColor
                            end
                            return streamdeck_imageFromText(buttonText, options)
                        end,
                        ['pressUp'] = function()
                            if entityType == 'light' then
                                homeAssistantRun('POST', 'services/light/toggle', { ['entity_id'] = entityID })
                            elseif entityType == 'switch' then
                                homeAssistantRun('POST', 'services/switch/toggle', { ['entity_id'] = entityID })
                            elseif entityType == 'scene' then
                                homeAssistantRun('POST', 'services/scene/turn_on', { ['entity_id'] = entityID })
                            elseif entityType == 'script' then
                                homeAssistantRun('POST', "services/script/turn_on", { ['entity_id'] = entityID })
                            else
                                homeAssistantRun('POST', 'services/light/toggle', { ['entity_id'] = entityID })
                            end
                        end
                    })
                end
            end
            return children
        end,
    }
end
