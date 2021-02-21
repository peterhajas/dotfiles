require "streamdeck_buttons.button_images"
require 'util'

local mdiNameToUnicodeMapping = nil
local function loadMDIJSONFileIfNecessary()
    if mdiNameToUnicodeMapping == nil then
        local path = '/Users/phajas/.hammerspoon/streamdeck_util/mdi.json'
        mdiNameToUnicodeMapping = hs.json.read(path)
    end
end

function mdiUnicodeCodepoint(name)
    loadMDIJSONFileIfNecessary()
    return mdiNameToUnicodeMapping[name]
end

local function entityIDFor(entityDictionary)
    local entityID = entityDictionary['entity_id']
    return entityID
end

local function colorFor(entityDictionary)
    -- If we have a color set, let's use that
    local entityColor = entityDictionary['attributes']['rgb_color']
    if entityColor ~= nil then
        entityColor['red'] = entityColor[1] / 255.0
        entityColor['green'] = entityColor[2] / 255.0
        entityColor['blue'] = entityColor[3] / 255.0
        return entityColor
    end
    
    local entityID = entityIDFor(entityDictionary)
    local entityType = split(entityID, '.')[1]
    if entityType == 'light' then
        return hs.drawing.color.lists()['Apple']['Yellow']
    end
    if entityType == 'scene' then
        return hs.drawing.color.blue
    end
    if entityType == 'group' then
        return hs.drawing.color.green
    end
    if entityType == 'script' then
        return hs.drawing.color.red
    end

    return hs.drawing.color.white
end

local function nameFor(entityDictionary)
    local entityID = entityIDFor(entityDictionary)
    local name = entityDictionary['attributes']['friendly_name']
    if name == nil then
        name = entityID
    end
    return name
end

local sharedHACanvas = hs.canvas.new{ w = buttonWidth, h = buttonHeight }
local glyphHeight = 64
local textHeight = 38

function homeAssistantEntityIcon(entityDictionary)
    local mdiName = entityDictionary['attributes']['icon']
    if mdiName == nil or not string.find(mdiName, 'mdi:') then
        -- Fallback icon
        mdiName = 'mdi:dots-vertical'
    end

    -- Find the MDI glyph
    -- Shave off the 'mdi:'
    local iconName = string.sub(mdiName, 5)
    local codepoint = mdiUnicodeCodepoint(iconName)
    local integer = tonumber(codepoint, 16)
    local mdi = utf8.char(integer)

    options = { }
    font = 'MaterialDesignIcons'
    textColor = colorFor(entityDictionary)
    backgroundColor = hs.drawing.color.black

    -- Flip if we're on
    if entityDictionary['state'] == 'on' then
        local newTextColor = backgroundColor
        backgroundColor = textColor
        textColor = newTextColor
    end

    -- Background color
    sharedHACanvas[1] = {
        action = "fill",
        frame = { x = 0, y = 0, w = buttonWidth, h = buttonHeight },
        fillColor = backgroundColor,
        type = "rectangle",
    }

    -- Glyph
    sharedHACanvas[2] = {
        frame = { x = 0, y = 0, w = buttonWidth, h = glyphHeight },
        text = hs.styledtext.new(mdi, {
            font = { name = 'MaterialDesignIcons', size = 50 },
            paragraphStyle = { alignment = "center" },
            color = textColor,
        }),
        type = "text",
    }

    -- Name
    sharedHACanvas[3] = {
        frame = { x = 0, y = buttonHeight - textHeight, w = buttonWidth, h = textHeight },
        text = hs.styledtext.new(nameFor(entityDictionary), {
            font = { name = '.AppleSystemUIFont', size = 15 },
            paragraphStyle = { alignment = "center" },
            color = textColor,
        }),
        type = "text",
    }

    return sharedHACanvas:imageFromCanvas()
end
