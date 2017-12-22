-- peterhajas's Hammerspoon config file
-- Originally written Jan 4, 2015

-- vim:fdm=marker

require "hyper"
require "vim_movement"
require "app_shortcuts"
require "footpedals"
require "preferred_screen"
require "media_control"
require "volume_control"
require "brightness_control"
require "grid"

-- Global 'doc' variable that I can use inside of the Hammerspoon {{{

doc = hs.doc

-- }}}
-- Global 'inspectThing' function for inspecting objects {{{

function inspectThing(thing)
    return hs.inspect.inspect(thing)
end

-- }}}
-- Finding all running GUI apps {{{

function allRunningApps()
    local allApps = hs.application.runningApplications()
    local allRunningApps = {}

    for idx,app in pairs(allApps) do
        -- Ignore Hammerspoon
        if app:mainWindow() ~= nil and app:title() ~= "Hammerspoon" then
            table.insert(allRunningApps, app)
        end
    end

    return allRunningApps
end

-- }}}
-- Notifying {{{

function notifySoftly(notificationString)
    hs.alert.show(notificationString)
end

function notify(notificationString)
    local notification = hs.notify.new()
    notification:title(notificationString)
    notification:send()
end

function notifyUrgently(notificationString)
    hs.messages.iMessage("peterhajas@gmail.com", notificationString)
    local messagesApp = hs.appfinder.appFromName("Messages")
    if messagesApp then
        messagesApp:hide()
    end
end

hs.urlevent.bind("notifySoftly", function(eventName, params)
    local text = params["text"]
    if text then
        notifySoftly(text)
    end
end)

hs.urlevent.bind("notify", function(eventName, params)
    local text = params["text"]
    if text then
        notify(text)
    end
end)

hs.urlevent.bind("notifyUrgently", function(eventName, params)
    local text = params["text"]
    if text then
        notifyUrgently(text)
    end
end)

-- }}}
-- Mission Control and Launchpad {{{

-- Hyper-3 for Mission Control

hs.hotkey.bind(hyper, "3", function()
    hs.application.launchOrFocus("Mission Control")
end)

-- Hyper-4 for Launchpad

hs.hotkey.bind(hyper, "4", function()
    hs.application.launchOrFocus("Launchpad")
end)

-- }}}
-- Easy Locking {{{

-- Hyper-Delete to lock the machine

hs.hotkey.bind(hyper, "delete", function()
    hs.caffeinate.startScreensaver()
end)

-- }}}
-- Other Shortcuts {{{

-- Hyper-escape to toggle the Hammerspoon console

hs.hotkey.bind(hyper, "escape", function()
    hs.toggleConsole()
end)

-- Shift-escape to ~

hs.hotkey.bind({"shift"}, "escape", function()
    hs.eventtap.keyStroke({"shift"}, "`")
end)

-- Command-escape to cmd-`

hs.hotkey.bind({"cmd"}, "escape", function()
    hs.eventtap.keyStroke({"cmd"}, "`")
end)

-- }}}
-- Window Geometry {{{

function windowPaddingForScreen (screen)
    return 0
end

-- }}}
-- Window Sanitizing {{{

function sanitizeWindowPosition (window, frame)
    local windowScreen = window:screen()
    local windowPadding = windowPaddingForScreen(windowScreen)

    local screenFrame = windowScreen:frame()

    local minimumWindowX = screenFrame.x + windowPadding
    local minimumWindowY = screenFrame.y + windowPadding

    local maximumWindowX = (screenFrame.x + screenFrame.w) - (frame.w + windowPadding)
    local maximumWindowY = (screenFrame.y + screenFrame.h) - (frame.h + windowPadding)

    frame.x = math.max(frame.x, minimumWindowX)
    frame.y = math.max(frame.y, minimumWindowY)

    frame.x = math.min(frame.x, maximumWindowX)
    frame.y = math.min(frame.y, maximumWindowY)

    return frame
end

function sanitizeWindowSize (window, frame)
    local windowScreen = window:screen()
    local windowPadding = windowPaddingForScreen(windowScreen)

    local screenFrame = windowScreen:frame()

    local maximumWidth = screenFrame.w - (2 * windowPadding)
    local maximumHeight = screenFrame.h - (2 * windowPadding)

    frame.w = math.min(frame.w, maximumWidth)
    frame.h = math.min(frame.h, maximumHeight)

    return frame
end

function sanitizeWindowFrame (window, frame)
    frame = sanitizeWindowSize(window, frame)
    frame = sanitizeWindowPosition(window, frame)

    return frame
end

-- }}}
-- Window Movement {{{

function moveWindowInDirection (window,direction)
    local newWindowFrame = window:frame()
    oldWindowPosition = hs.geometry.point(newWindowFrame.x, newWindowFrame.y)

    local padding = windowPaddingForScreen(window:screen())

    local dimensionMultiplier = 0.5

    newWindowFrame.x = newWindowFrame.x + (newWindowFrame.w * direction.w * dimensionMultiplier)
    newWindowFrame.y = newWindowFrame.y + (newWindowFrame.h * direction.h * dimensionMultiplier)

    if newWindowFrame.x ~= oldWindowPosition.x then newWindowFrame.x = newWindowFrame.x + padding * direction.w end
    if newWindowFrame.y ~= oldWindowPosition.y then newWindowFrame.y = newWindowFrame.y + padding * direction.h end

    newWindowFrame = sanitizeWindowFrame(window, newWindowFrame)

    window:setFrame(newWindowFrame, 0)
end

function moveForegroundWindowInDirection (direction)
    local window = hs.window.focusedWindow()
    moveWindowInDirection(window, direction)
end

-- }}}
-- Window Resizing {{{

function amountToResizeForWindow (window, amount)
    local screen = window:screen()
    local minimumWindowWidth = 400

    if amount == 1 then amount = minimumWindowWidth end
    if amount == -1 then amount = -1 * minimumWindowWidth end
    if amount == 0 then amount = 0 end

    return amount
end

function resizeWindowByAmount (window, amount)
    local newWindowFrame = window:frame()

    oldWindowSize = hs.geometry.size(newWindowFrame.w, newWindowFrame.h)

    local amountW = amountToResizeForWindow(window, amount.w)
    local amountH = amountToResizeForWindow(window, amount.h)

    newWindowFrame.w = newWindowFrame.w + amountW
    newWindowFrame.h = newWindowFrame.h + amountH

    diffW = newWindowFrame.w - oldWindowSize.w
    diffH = newWindowFrame.h - oldWindowSize.h

    newWindowFrame.x = newWindowFrame.x - (diffW / 2)
    newWindowFrame.y = newWindowFrame.y - (diffH / 2)

    newWindowFrame = sanitizeWindowFrame(window, newWindowFrame)

    window:setFrame(newWindowFrame, 0)
end

function resizeForegroundWindowByAmount (amount)
    local window = hs.window.focusedWindow()
    resizeWindowByAmount(window, amount)
end

-- }}}
-- Window Movement Keys {{{

-- Bind hyper-H to move window to the left
hs.hotkey.bind(hyper, "h", function()
    moveForegroundWindowInDirection(hs.geometry.size(-1,0))
end)

-- Bind hyper-L to move window to the right

hs.hotkey.bind(hyper, "l", function()
    moveForegroundWindowInDirection(hs.geometry.size(1,0))
end)

-- Bind hyper-K to move window up

hs.hotkey.bind(hyper, "k", function()
    moveForegroundWindowInDirection(hs.geometry.size(0,-1))
end)

-- Bind hyper-J to move window down

hs.hotkey.bind(hyper, "j", function()
    moveForegroundWindowInDirection(hs.geometry.size(0,1))
end)

-- Bind hyper-T to move window to the "next" screen

hs.hotkey.bind(hyper, "T", function()
    local win = hs.window.focusedWindow()
    local windowScreen = win:screen()
    
    local newWindowScreen = windowScreen:next()
    win:moveToScreen(newWindowScreen, 0)
end)

-- }}}
-- Window Resizing Keys {{{

-- Bind hyper-Y to resize window width smaller

hs.hotkey.bind(hyper, "Y", function()
    resizeForegroundWindowByAmount(hs.geometry.size(-1, 0))
end)

-- Bind hyper-O to resize window width larger

hs.hotkey.bind(hyper, "O", function()
    resizeForegroundWindowByAmount(hs.geometry.size(1, 0))
end)

-- Bind hyper-I to resize window height larger

hs.hotkey.bind(hyper, "I", function()
    resizeForegroundWindowByAmount(hs.geometry.size(0, 1))
end)

-- Bind hyper-U to resize window height smaller

hs.hotkey.bind(hyper, "U", function()
    resizeForegroundWindowByAmount(hs.geometry.size(0, -1))
end)

-- }}}
-- Screen Watching {{{
-- Watch screen change notifications, and reload the config when the screen
-- configuration changes

function handleScreenEvent()
    reload_config()
end

screenWatcher = hs.screen.watcher.new(handleScreenEvent)
screenWatcher:start()

-- }}}
-- Reloading {{{
-- I can reload the config when this file changes. From:
-- http://www.hammerspoon.org/go/#fancyreload
function reload_config(files)
    screenWatcher:stop()
    hs.reload()
end

hs.pathwatcher.new(os.getenv("HOME") .. "/.hammerspoon/", reload_config):start()
hs.alert.show("hs ready", 1)

-- }}}

