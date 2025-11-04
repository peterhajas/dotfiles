-- peterhajas's Hammerspoon config file
-- Originally written Jan 4, 2015

-- vim:fdm=marker

-- Clear the console
hs.console.clearConsole()

-- Start profiling
require("profile")

hs.alert.show("hs...")

profileStart('imports')
profileStart('configTotal')

require "util"

require("hs.ipc")
hs.ipc.cliInstall()

local hyper = require "hyper"
local vim_movement = require "vim_movement"
local footpedals = require "footpedals"
require "volume_control"
require "darkmode"
require "audio_output"
require "choose"
require "streamdeck"
require "link_replace"
require "youtubedl"
require "server"
local flux = require "flux"
require "tiddlywiki"
require "iphone_mirroring"

profileStop('imports')
profileStart('globals')
-- Global 'doc' variable that I can use inside of the Hammerspoon {{{

doc = hs.doc

-- }}}
-- Global 'inspectThing' function for inspecting objects {{{

function inspectThing(thing)
    return hs.inspect.inspect(thing)
end

-- }}}
-- Global variables {{{
hs.window.animationDuration = 0.0
caffeinateWatcher = nil
pasteboardWatcher = nil
-- }}}
profileStop('globals')
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
-- Easy Locking {{{

-- Hyper-Delete to lock the machine

hs.hotkey.bind(hyper.key, "delete", function()
    hs.caffeinate.startScreensaver()
end)

-- }}}
-- Other Shortcuts {{{

-- Hyper-escape to toggle the Hammerspoon console

hs.hotkey.bind(hyper.key, "escape", function()
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
profileStart('windowCommands')
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
    local screen = window:screen()
    local screenFrame = screen:frame()

    newWindowFrame.x = newWindowFrame.x + (direction.w * screenFrame.w / 10)
    newWindowFrame.y = newWindowFrame.y + (direction.h * screenFrame.h / 4)

    if newWindowFrame.x ~= oldWindowPosition.x then newWindowFrame.x = newWindowFrame.x + padding * direction.w end
    if newWindowFrame.y ~= oldWindowPosition.y then newWindowFrame.y = newWindowFrame.y + padding * direction.h end

    newWindowFrame = sanitizeWindowFrame(window, newWindowFrame)

    window:setFrame(newWindowFrame)
end

function moveForegroundWindowInDirection (direction)
    local window = hs.window.focusedWindow()
    if window == nil then return end
    moveWindowInDirection(window, direction)
end

-- }}}
-- Window Resizing {{{

function amountToResizeForWindow (window, amount, horizontal)
    local screen = window:screen()
    local screenFrame = screen:frame()

    if horizontal == true then minimumWindowDimension = screenFrame.w / 10 end
    if not horizontal then minimumWindowDimension = screenFrame.h / 4 end

    if amount == 1 then amount = minimumWindowDimension end
    if amount == -1 then amount = -1 * minimumWindowDimension end
    if amount == 0 then amount = 0 end

    return amount
end

function resizeWindowByAmount (window, amount)
    local newWindowFrame = window:frame()

    local amountW = amountToResizeForWindow(window, amount.w, true)
    local amountH = amountToResizeForWindow(window, amount.h, false)

    newWindowFrame.w = newWindowFrame.w + amountW
    newWindowFrame.h = newWindowFrame.h + amountH

    newWindowFrame = sanitizeWindowFrame(window, newWindowFrame)

    window:setFrame(newWindowFrame)
end

function resizeForegroundWindowByAmount (amount)
    local window = hs.window.focusedWindow()
    if window == nil then return end
    resizeWindowByAmount(window, amount)
end

-- }}}
profileStop('windowCommands')
profileStart('noises')
-- Noises {{{
-- Just playing for now with this config:
-- https://github.com/trishume/dotfiles/blob/master/hammerspoon/hammerspoon.symlink/init.lua
-- This stuff is wild, and it works!
listener = nil
popclickListening = false
local scrollDownTimer = nil
function popclickHandler(evNum)
  if evNum == 1 then
    scrollDownTimer = hs.timer.doEvery(0.02, function()
      hs.eventtap.scrollWheel({0,-10},{}, "pixel")
      end)
  elseif evNum == 2 then
    if scrollDownTimer then
      scrollDownTimer:stop()
      scrollDownTimer = nil
    end
  elseif evNum == 3 then
    hs.eventtap.scrollWheel({0,250},{}, "pixel")
  end
end

function popclickPlayPause()
  if not popclickListening then
    listener:start()
    hs.alert.show("listening")
  else
    listener:stop()
    hs.alert.show("stopped listening")
  end
  popclickListening = not popclickListening
end
popclickListening = false
local fn = popclickHandler
listener = hs.noises.new(fn)
-- }}}
profileStop('noises')
profileStart('screenChanges')
-- {{{ Screen Changes
--- Watch screen change notifications, and reload certain components when the
--screen configuration changes

function handleScreenEvent()
    flux.update()
end

screenWatcher = hs.screen.watcher.new(handleScreenEvent)
screenWatcher:start()

-- }}}
profileStop('screenChanges')
profileStart('caffeinate')
-- {{{ Caffeinate

function caffeinateCallback(eventType)
    if (eventType == hs.caffeinate.watcher.screensDidSleep) then
    elseif (eventType == hs.caffeinate.watcher.screensDidWake) then
        flux.significantTimeDidChange()
    elseif (eventType == hs.caffeinate.watcher.screensDidLock) then
        streamdeck_sleep()
        -- hs.execute("osascript -e 'tell application \"DisplayLink Manager\" to quit'")
    elseif (eventType == hs.caffeinate.watcher.screensDidUnlock) then
        streamdeck_wake()
        -- hs.application.open("DisplayLink Manager")

    end
end

caffeinateWatcher = hs.caffeinate.watcher.new(caffeinateCallback)
caffeinateWatcher:start()
-- }}}
profileStop('caffeinate')
profileStart('pasteboard')
-- {{{ Pasteboard
pasteboardWatcher = hs.pasteboard.watcher.new(function(contents)
    replacePasteboardLinkIfNecessary(contents)
end)
-- }}}
profileStop('pasteboard')
profileStart('reloading')
-- Reloading {{{
-- I can reload the config when this file changes. From:
-- http://www.hammerspoon.org/go/#fancyreload
function reload_config(files)
    hs.reload()
end

hs.pathwatcher.new(os.getenv("HOME") .. "/.hammerspoon/", reload_config):start()

-- }}}
profileStop('reloading')
-- AXBrowse {{{
local axbrowse = require("axbrowse")
local lastApp
hs.hotkey.bind({"cmd", "alt", "ctrl"}, "b", function()
 local currentApp = hs.axuielement.applicationElement(hs.application.frontmostApplication())
 if currentApp == lastApp then
     axbrowse.browse() -- try to continue from where we left off
 else
     lastApp = currentApp
     axbrowse.browse(currentApp) -- new app, so start over
 end
end)
-- }}}

-- {{ Bootstrapping

-- Flux setup {{{
flux.init()
-- }}}

-- Vim movement setup {{{
vim_movement.init()
-- }}}

-- Footpedals setup {{{
footpedals.init()
-- }}}

hs.alert.show("hs ready!")

profileStop('configTotal')

