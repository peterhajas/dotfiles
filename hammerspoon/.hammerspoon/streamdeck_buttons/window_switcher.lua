require "streamdeck_buttons.button_images"
function windowSwitcher()
    return {
        ['name'] = "Window Switcher",
        ['image'] = streamdeck_imageFromText("􀏜"),
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
                        local imageCanvas = hs.canvas.new{ w = buttonWidth, h = buttonHeight }
                        imageCanvas[1] = {
                            type = "image",
                            image = snap,
                            imageScaling = "scaleToFill"
                        }
                        imageCanvas[2] = {
                            type = "image",
                            image = icon,
                            frame = { x = 5, y = 5, w = 30, h = 30 }
                        }
                        return imageCanvas:imageFromCanvas()
                    end,
                    ['pressUp'] = function()
                        window:unminimize()
                        window:becomeMain()
                        window:focus()
                        popButtonState()
                    end
                }
                out[#out+1] = appButton
                ::continue::
            end
            return out
        end
    }
end
