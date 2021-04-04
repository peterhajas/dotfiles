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

-- Returns a button corresponding to a HomeAssistant entity ID
function homeAssistantEntity(entityID)
    return {
        ['name'] = 'HA/' .. entityID,
        ['stateProvider'] = function()
            updateHomeAssistantStateIfNecessary()
            local stateNow = currentStateForEntity(entityID)
            return stateNow
        end,
        ['imageProvider'] = function(context)
            local state = context['state']
            return homeAssistantEntityIcon(state)
        end,
        ['onClick'] = function()
            local parameters = { ['entity_id'] = entityID }
            local method = 'POST'
            local endpoint = 'services/light/toggle'
            local entityType = typeForID(entityID)

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
    }
end

-- Returns the general HomeAssistant button
function homeAssistant()
    local bundleID = 'io.robbie.HomeAssistant'
    return {
        ['name'] = 'Home Assistant',
        ['image'] = hs.image.imageFromAppBundle(bundleID),
        ['onLongPress'] = function()
            hs.application.open(bundleID)
        end,
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
                local entityType = typeForID(entityID)
                local includedEntityTypes = { 'light', 'switch', 'scene', 'script', 'group', 'person' }
                local include = false
                for index, includedEntityType in pairs(includedEntityTypes) do
                    if string.find(entityType, includedEntityType) then
                        include = true
                        break
                    end
                end
                if include then
                    table.insert(children, homeAssistantEntity(entityID))
                end
            end
            return children
        end,
    }
end
