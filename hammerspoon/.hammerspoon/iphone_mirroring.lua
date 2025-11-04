-- iPhone Mirroring Module
-- Automatically positions and resizes the iPhone Mirroring window

local iphone_mirroring = {}

-- Private helper functions

local function updateiPhoneMirroringFrame()
    local app = hs.application.find("iPhone Mirroring")
    if app ~= nil then
        local window = app:visibleWindows()[1]
        if window ~= nil then
            local screen = window:screen()
            local screenFrame = screen:fullFrame()

            local mirroringWidth = window:frame().w
            local mirroringHeight = window:frame().h
            local mirroringInset = 7

            local mirroringFrame = hs.geometry.rect(screenFrame.w - mirroringWidth + mirroringInset,
                                                    screenFrame.h - mirroringHeight + mirroringInset,
                                                    mirroringWidth,
                                                    mirroringHeight)
            window:setFrame(mirroringFrame)
        end
    end
end

-- Keeps the mirroring app at the biggest size or smallest size
-- (we post the event twice)
local function phoneMirroringResize(bigger)
    local app = hs.application.find("iPhone Mirroring")
    if app ~= nil then
        local text =  hs.keycodes.map["pad+"]
        if not bigger then
            text =  hs.keycodes.map["pad-"]
        end
        local down = hs.eventtap.event.newKeyEvent({"cmd"}, text, true)
        local up = hs.eventtap.event.newKeyEvent({"cmd"}, text, false)
        down:post(app)
        up:post(app)
        updateiPhoneMirroringFrame()
        down:post(app)
        up:post(app)
        updateiPhoneMirroringFrame()
    end
end

-- Module state
local phoneMirroringAppWatcher = nil
local phoneMirroringScreenWatcher = nil

-- Initialize iPhone mirroring watchers
function iphone_mirroring.init()
    phoneMirroringAppWatcher = hs.application.watcher.new(function(name, type, app)
        if name == "iPhone Mirroring" then
            if type == hs.application.watcher.activated then
                phoneMirroringResize(true)
            elseif type == hs.application.watcher.deactivated then
                phoneMirroringResize(false)
            end
            updateiPhoneMirroringFrame()
        end
    end):start()

    phoneMirroringScreenWatcher = hs.screen.watcher.new(updateiPhoneMirroringFrame):start()

    updateiPhoneMirroringFrame()
end

return iphone_mirroring
