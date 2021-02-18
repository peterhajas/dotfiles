require "streamdeck_buttons.button_images"
require 'home_assistant'
require 'util'

local lastHomeAssistantState = nil
local lastHomeAssistantUpdateTime = 0

local function updateHomeAssistantStateIfNecessary()
    local now = hs.timer.absoluteTime()
    -- in ms
    local elapsed = (now - lastHomeAssistantUpdateTime) * 0.000001
    if elapsed > 1000 then
        lastHomeAssistantUpdateTime = hs.timer.absoluteTime()
        lastHomeAssistantState = homeAssistantRun('GET', 'states')
    end
end

local function currentStateForEntity(entityID)
    for index, state in pairs(lastHomeAssistantState) do
        if state['entity_id'] == entityID then
            return state
        end
    end
    return nil
end

function homeAssistant()
    return {
        ['name'] = 'Home Assistant',
        ['image'] = streamdeck_imageFromText("􀎟"),
        ['children'] = function()
            updateHomeAssistantStateIfNecessary()
            children = { }
            for index, state in pairs(lastHomeAssistantState) do
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
                            updateHomeAssistantStateIfNecessary()
                            local stateNow = currentStateForEntity(entityID)
                            local options = {
                                ['fontSize'] = 20,
                                ['textColor'] = hs.drawing.color.white,
                                ['backgroundColor'] = hs.drawing.color.black
                            }
                            if entityType == 'light' then
                                options['textColor'] = hs.drawing.color.lists()['Apple']['Yellow']
                            end
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
                            local parameters = { ['entity_id'] = entityID }
                            local method = 'POST'
                            local endpoint = 'services/light/toggle'

                            if entityType == 'switch' then
                                endpoint = 'services/switch/toggle'
                            elseif entityType == 'scene' then
                                endpoint = 'services/scene/turn_on'
                            elseif entityType == 'script' then
                                endpoint = 'services/script/turn_on'
                            end

                            homeAssistantRun(method, endpoint, parameters)
                        end,
                        ['updateInterval'] = 1
                    })
                end
            end
            return children
        end,
    }
end
