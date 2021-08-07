require "streamdeck.peek"
function appSwitcher()
    return {
        ['name'] = "App Switcher",
        ['image'] = streamdeck_imageFromText("􀮖"),
        ['children'] = function()
            local out = { }
            for index, app in pairs(hs.application.runningApplications()) do
                local bundleID = app:bundleID()
                if bundleID == nil then goto continue end
                local path = app:path()
                -- Strip out apps we don't want to pick from
                if path == nil then goto continue end
                if string.find(path, '/System/Library') then goto continue end
                if string.find(path, 'appex') then goto continue end
                if string.find(path, 'XPCServices') then goto continue end
                appButton = peekButtonFor(app:bundleID())
                out[#out+1] = appButton
                ::continue::
            end
            return out
        end
    }
end
