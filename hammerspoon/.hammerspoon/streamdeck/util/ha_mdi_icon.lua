local mdiNameToUnicodeMapping = nil
local hasLoadedMDIMapping = false
local function loadMDIJSONFileIfNecessary()
    if not hasLoadedMDIMapping then
        local path = '/Users/phajas/.hammerspoon/streamdeck/util/mdi.json'
        mdiNameToUnicodeMapping = hs.json.read(path)
        hasLoadedMDIMapping = true
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

-- A type ('switch', 'light', etc.) for the entityID
function typeForID(entityID)
    local entityType = split(entityID, '.')[1]
    return entityType
end

-- A type ('switch', 'light', etc.) for the entity dictionary
local function typeForDictionary(entityDictionary)
    local entityID = entityIDFor(entityDictionary)
    return typeForID(entityID)
end

local function fallbackColorFor(entityDictionary)
    -- If we have a color set, let's use that
    local entityColor = entityDictionary['attributes']['rgb_color']
    if entityColor ~= nil then
        entityColor['red'] = entityColor[1] / 255.0
        entityColor['green'] = entityColor[2] / 255.0
        entityColor['blue'] = entityColor[3] / 255.0
        return entityColor
    end

    local entityType = typeForDictionary(entityDictionary)
    
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
    if entityType == 'cover' then
        return systemPurpleColor
    end
    if entityType == 'media_player' then
        return systemTealColor
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
    return colorSetFor(entityDictionary, 'background_color', systemBackgroundColor)
end

local function titleFor(entityDictionary)
    local name = entityDictionary['attributes']['friendly_name']
    if name == nil then
        local entityID = entityIDFor(entityDictionary)
        name = entityID
    end
    local entityType = typeForDictionary(entityDictionary)
    if entityType == 'person' then
        local location = entityDictionary['state']
        location = location:gsub('_', ' ')
        name = location
    end
    return name
end

-- Returns a logical fraction for the entity. For example, if it's a light,
-- the brightness
local function fractionFor(entityDictionary)
    local brightness = entityDictionary['attributes']['brightness']
    if brightness ~= nil then
        return brightness / 255.0
    end

    if entityDictionary['state'] == 'on' or
        entityDictionary['state'] == 'open' then
        return 1.0
    end

    return 0.0
end

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
        local entityType = typeForDictionary(entityDictionary)
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

    local textColor = textColorFor(entityDictionary)
    local iconColor = iconColorFor(entityDictionary)
    local backgroundColor = backgroundColorFor(entityDictionary)
    local fraction = fractionFor(entityDictionary)

    local elements = { }

    local strokeWidth = 20
    local contentRect = {
                          x = strokeWidth / 2,
                          y = strokeWidth / 2,
                          w = buttonWidth - strokeWidth,
                          h = buttonHeight - strokeWidth,
                        }

    local textHeight = 36
    local imageHeight = contentRect.h - textHeight

    -- Background color
    table.insert(elements, {
        action = "fill",
        frame = { x = 0, y = 0, w = buttonWidth, h = buttonHeight },
        fillColor = backgroundColor,
        type = "rectangle",
    })

    if fraction > 0 then
        local fractionColor = cloneTable(textColor)
        fractionColor['alpha'] = fraction
        local radius = 8
        -- Fraction / on outline
        table.insert(elements, {
            frame = { x = 0, y = 0, w = buttonWidth, h = buttonHeight },
            strokeColor = fractionColor,
            type = "rectangle",
            action = "stroke",
            strokeJoinStyle = "round",
            roundedRectRadii = { ["xRadius"] = radius, ["yRadius"] = radius },
            strokeWidth = strokeWidth,
        })
    end

    -- Image
    local imageFrame = { x = contentRect.x, y = contentRect.y, w = contentRect.w, h = imageHeight }
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
        local fontSize = 32

        if codepoint ~= nil then
            local integer = tonumber(codepoint, 16)
            local mdi = utf8.char(integer)
            table.insert(elements, {
                type = "text",
                frame = imageFrame,
                text = hs.styledtext.new(mdi, {
                    font = { name = 'MaterialDesignIcons', size = fontSize },
                    paragraphStyle = { alignment = "center" },
                    color = iconColor,
                }),
            })
        else
            table.insert(elements, {
                type = "text",
                frame = imageFrame,
                text = hs.styledtext.new('•', {
                    font = { name = '.AppleSystemUIFont', size = fontSize },
                    paragraphStyle = { alignment = "center" },
                    color = iconColor,
                }),
            })
        end
    end

    -- Name
    local nameY = contentRect.y + contentRect.h - textHeight
    table.insert(elements, {
        frame = { x = contentRect.x, y = nameY, w = contentRect.w, h = textHeight },
        text = hs.styledtext.new(titleFor(entityDictionary), {
            font = { name = '.AppleSystemUIFont', size = 14 },
            paragraphStyle = { alignment = "center" },
            color = textColor,
        }),
        type = "text",
    })

    return streamdeck_imageWithCanvasContents(elements)
end
