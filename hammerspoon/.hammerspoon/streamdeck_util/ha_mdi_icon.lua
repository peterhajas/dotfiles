require "streamdeck_buttons.button_images"
require 'util'
require "colors"

local mdiNameToUnicodeMapping = nil
local function loadMDIJSONFileIfNecessary()
    if mdiNameToUnicodeMapping == nil then
        local path = '/Users/phajas/.hammerspoon/streamdeck_util/mdi.json'
        mdiNameToUnicodeMapping = hs.json.read(path)
    end
end

function mdiUnicodeCodepoint(name)
    loadMDIJSONFileIfNecessary()
    if mdiNameToUnicodeMapping == nil then
        return nil
    end
    return mdiNameToUnicodeMapping[name]
end

local function entityIDFor(entityDictionary)
    local entityID = entityDictionary['entity_id']
    return entityID
end

-- A type ('switch', 'light', etc.) for the entity
local function typeFor(entityDictionary)
    local entityID = entityIDFor(entityDictionary)
    local entityType = split(entityID, '.')[1]
    return entityType
end

local function fallbackColorFor(entityDictionary)
    -- If we have a color set, let's use that
    local entityColor = entityDictionary['attributes']['rgb_color']
    local brightness = entityDictionary['attributes']['brightness'] or 255.0
    brightness = brightness  / 255.0
    if entityColor ~= nil then
        entityColor['red'] = entityColor[1] / 255.0
        entityColor['green'] = entityColor[2] / 255.0
        entityColor['blue'] = entityColor[3] / 255.0
        entityColor['alpha'] = brightness
        return entityColor
    end

    local entityType = typeFor(entityDictionary)
    
    if entityType == 'light' then
        return systemYellowColor
    end
    if entityType == 'scene' then
        return systemBlueColor
    end
    if entityType == 'group' then
        return systemGreenColor
    end
    if entityType == 'script' then
        return systemRedColor
    end

    return hs.drawing.color.white
end

local function colorSetFor(entityDictionary, key, fallback)
    local color = entityDictionary['attributes'][key]
    if color ~= nil then
        if string.find(color, '#') then
            return { ['hex'] = color }
        else
            local x11Color = hs.drawing.color.lists()['x11'][color]
            if x11Color ~= nil then
                return x11Color
            end
        end
    end
    return fallback
end

local function textColorFor(entityDictionary)
    return colorSetFor(entityDictionary, 'text_color', fallbackColorFor(entityDictionary))
end

local function iconColorFor(entityDictionary)
    return colorSetFor(entityDictionary, 'icon_color', fallbackColorFor(entityDictionary))
end

local function backgroundColorFor(entityDictionary)
    return colorSetFor(entityDictionary, 'background_color', hs.drawing.color.black)
end

local function titleFor(entityDictionary)
    local name = entityDictionary['attributes']['friendly_name']
    if name == nil then
        local entityID = entityIDFor(entityDictionary)
        name = entityID
    end
    local entityType = typeFor(entityDictionary)
    if entityType == 'person' then
        local location = entityDictionary['state']
        location = location:gsub('_', ' ')
        name = location
    end
    return name
end

local glyphHeight = 64
local textHeight = 38

function homeAssistantEntityIcon(entityDictionary)
    -- If the entity has a picture, then let's grab that
    local entityPictureAttribute = entityDictionary['attributes']['entity_picture']
    local entityPicture = nil
    if entityPictureAttribute ~= nil then
        local entityPictureURL = homeAssistantURL(entityPictureAttribute)
        entityPicture = hs.image.imageFromURL(entityPictureURL)
    end
    local mdiName = entityDictionary['attributes']['icon']
    if mdiName == nil or not string.find(mdiName, 'mdi:') then
        -- Fallback icon
        local entityType = typeFor(entityDictionary)
        if entityType == 'light' then
            mdiName = 'mdi:floor-lamp'
        elseif entityType == 'scene' then
            mdiName = 'mdi:palette'
        elseif entityType == 'group' then
            mdiName = 'mdi:dots-vertical'
        elseif entityType == 'script' then
            mdiName = 'mdi:script-text'
        else
            mdiName = 'mdi:dots-vertical'
        end
    end

    options = { }
    local textColor = textColorFor(entityDictionary)
    local iconColor = iconColorFor(entityDictionary)
    local backgroundColor = backgroundColorFor(entityDictionary)

    -- Flip if we're on
    if entityDictionary['state'] == 'on' then
        local newTextColor = backgroundColor
        backgroundColor = textColor
        textColor = newTextColor
        iconColor = newTextColor
    end

    local elements = { }

    -- Background color
    table.insert(elements, {
        action = "fill",
        frame = { x = 0, y = 0, w = buttonWidth, h = buttonHeight },
        fillColor = backgroundColor,
        type = "rectangle",
    })

    -- Image
    local imageFrame = { x = 0, y = 0, w = buttonWidth, h = glyphHeight }
    if entityPicture ~= nil then
        table.insert(elements, {
            type = "image",
            frame = { x = 0, y = 0, w = buttonWidth, h = buttonHeight },
            image = entityPicture,
            imageScaling = 'scaleToFit',
        })
    else
        -- Find the MDI glyph
        -- Shave off the 'mdi:'
        local iconName = string.sub(mdiName, 5)
        local codepoint = mdiUnicodeCodepoint(iconName)

        if codepoint ~= nil then
            local integer = tonumber(codepoint, 16)
            local mdi = utf8.char(integer)
            table.insert(elements, {
                type = "text",
                frame = imageFrame,
                text = hs.styledtext.new(mdi, {
                    font = { name = 'MaterialDesignIcons', size = 50 },
                    paragraphStyle = { alignment = "center" },
                    color = iconColor,
                }),
            })
        else
            table.insert(elements, {
                type = "text",
                frame = imageFrame,
                text = hs.styledtext.new('•', {
                    font = { name = '.AppleSystemUIFont', size = 50 },
                    paragraphStyle = { alignment = "center" },
                    color = iconColor,
                }),
            })
        end
    end

    -- Name
    table.insert(elements, {
        frame = { x = 0, y = buttonHeight - textHeight, w = buttonWidth, h = textHeight },
        text = hs.styledtext.new(titleFor(entityDictionary), {
            font = { name = '.AppleSystemUIFont', size = 15 },
            paragraphStyle = { alignment = "center" },
            color = textColor,
        }),
        type = "text",
    })

    return streamdeck_imageWithCanvasContents(elements)
end
