require "streamdeck.util.ha_mdi_icon"
require 'home_assistant'
require 'util'

local function currentStateForEntity(entityID)
    return homeAssistantRun('GET', 'states/' .. entityID) or { }
end

-- Returns a button corresponding to a HomeAssistant entity ID
function homeAssistantEntity(entityID)
    return {
        ['name'] = 'HA/' .. entityID,
        ['stateProvider'] = function()
            local stateNow = currentStateForEntity(entityID)
            -- Nix the last_updated value - we will check other states
            stateNow['last_updated'] = nil
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

            endpoint = 'services/homeassistant/toggle'

            homeAssistantRun(method, endpoint, parameters)
        end,
        ['updateInterval'] = 5
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
            local homeAssistantState = homeAssistantRun('GET', 'states') or { }
            local children = { }

            for index, state in pairs(homeAssistantState) do
                local entityID = state['entity_id']
                local name = state['attributes']['friendly_name']
                if name == nil then
                    name = entityID
                end
                local entityType = typeForID(entityID)
                local includedEntityTypes = { 'light', 'switch', 'scene', 'script', 'group', 'person', 'cover', 'media_player' }
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
