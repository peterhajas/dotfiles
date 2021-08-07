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
                    ['onClick'] = function()
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
