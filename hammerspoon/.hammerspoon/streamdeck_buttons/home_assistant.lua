require "streamdeck_util.ha_mdi_icon"
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
        ['image'] = hs.image.imageFromAppBundle('io.robbie.HomeAssistant'),
        ['children'] = function()
            updateHomeAssistantStateIfNecessary()
            children = { }
            if lastHomeAssistantState == nil then
                return children
            end

            for index, state in pairs(lastHomeAssistantState) do
                local entityID = state['entity_id']
                local name = state['attributes']['friendly_name']
                if name == nil then
                    name = entityID
                end
                local entityType = split(entityID, '.')[1]
                local buttonText = name .. '\n(' .. entityType .. ')'
                local includedEntityTypes = { 'light', 'switch', 'scene', 'script', 'group', 'person' }
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
                            return homeAssistantEntityIcon(stateNow)
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
