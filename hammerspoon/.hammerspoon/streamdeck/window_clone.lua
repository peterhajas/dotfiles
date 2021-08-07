local lastWindowImage = nil
local lastWindowImageTime = 0

local sizeMultiplier = 1.0

local itemWidth = buttonWidth * sizeMultiplier
local itemHeight = buttonHeight * sizeMultiplier

local function updateWindowImageIfNecessary(window, size)
    local now = hs.timer.absoluteTime()
    -- in ms
    local elapsed = (now - lastWindowImageTime) * 0.000001
    if elapsed >= 33 then
        lastWindowImageTime = hs.timer.absoluteTime()
        lastWindowImage = window:snapshot():copy():size(size)
    end
end

-- An individual button in the cloned window panel
local function button(window)
    return {
        ['imageProvider'] = function(context)
            local x = context['location']['x']
            local y = context['location']['y']
            local w = context['size']['w']
            local h = context['size']['h']

            local destinationSize = { ['w'] = w * itemWidth,
                                      ['h'] = h * itemHeight }

            local elements = { }
            table.insert(elements, {
                frame = {
                    x = -1 * x * itemWidth,
                    y = -1 * y * itemHeight,
                    w = destinationSize['w'],
                    h = destinationSize['h']
                },
                type = 'image',
                image = lastWindowImage,
            })

            local resized = streamdeck_imageWithCanvasContents(elements)

            if x == context['size']['w'] - 1 and
               y == context['size']['h'] - 1 then
                updateWindowImageIfNecessary(window, destinationSize)
            end

            return resized
        end,
        ['onClick'] = function()
            -- A bit of a hack, but pop twice to go back to the menun above the
            -- clone button
            popButtonState()
            popButtonState()
        end,
        ['updateInterval'] = 0.033
    }
end

-- A button that lets you "zoom in" on a window
function windowClone()
    return {
        ['name'] = "Window Zoom",
        ['image'] = streamdeck_imageFromText("􀊫"),
        ['children'] = function()
            local out = { }
            for index, window in pairs(hs.window.allWindows()) do
                local app = window:application()
                if app == nil then goto continue end
                local bundleID = app:bundleID()
                if bundleID == nil then goto continue end
                appButton = {
                    ['imageProvider'] = function()
                        local snap = window:snapshot()
                        local icon = hs.image.imageFromAppBundle(bundleID)
                        local elements = {}
                        table.insert(elements, {
                            type = "image",
                            image = snap,
                            imageScaling = "shrinkToFit"
                        })
                        table.insert(elements, {
                            type = "image",
                            image = icon,
                            frame = { x = 5, y = 5, w = 30, h = 30 }
                        })
                        return streamdeck_imageWithCanvasContents(elements)
                    end,
                    ['children'] = function(context)
                        return panelChildren(context, button(window))
                    end,
                }
                out[#out+1] = appButton
                ::continue::
            end
            return out
        end
    }
end
