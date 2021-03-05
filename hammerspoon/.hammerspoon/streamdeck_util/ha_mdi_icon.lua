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
    if mdiNameToUnicodeMapping == nil then
        return nil
    end
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
        return hs.drawing.color.lists()['System']['systemYellowColor']
    end
    if entityType == 'scene' then
        return hs.drawing.color.lists()['System']['systemBlueColor']
    end
    if entityType == 'group' then
        return hs.drawing.color.lists()['System']['systemGreenColor']
    end
    if entityType == 'script' then
        return hs.drawing.color.lists()['System']['systemRedColor']
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
        mdiName = 'mdi:dots-vertical'
    end

    options = { }
    textColor = colorFor(entityDictionary)
    backgroundColor = hs.drawing.color.black

    -- Flip if we're on
    if entityDictionary['state'] == 'on' then
        local newTextColor = backgroundColor
        backgroundColor = textColor
        textColor = newTextColor
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
            frame = imageFrame,
            image = entityPicture,
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
                    color = textColor,
                }),
            })
        else
            table.insert(elements, {
                type = "text",
                frame = imageFrame,
                text = hs.styledtext.new('•', {
                    font = { name = '.AppleSystemUIFont', size = 50 },
                    paragraphStyle = { alignment = "center" },
                    color = textColor,
                }),
            })
        end
    end

    -- Name
    table.insert(elements, {
        frame = { x = 0, y = buttonHeight - textHeight, w = buttonWidth, h = textHeight },
        text = hs.styledtext.new(nameFor(entityDictionary), {
            font = { name = '.AppleSystemUIFont', size = 15 },
            paragraphStyle = { alignment = "center" },
            color = textColor,
        }),
        type = "text",
    })

    return streamdeck_imageWithCanvasContents(elements)
end
