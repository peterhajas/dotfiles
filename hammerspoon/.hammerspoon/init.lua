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
local darkmode = require "darkmode"
local audio_output = require "audio_output"
local chooser = require "choose"
local link_replace = require "link_replace"
local youtubedl = require "youtubedl"
local flux = require "flux"
local iphone_mirroring = require "iphone_mirroring"
require "streamdeck"
require "server"
require "tiddlywiki"

profileStop('imports')
profileStart('globals')

-- Global 'doc' variable that I can use inside of the Hammerspoon
doc = hs.doc

-- Global 'ntfy' module for easy CLI access
ntfy = require "ntfy"

-- Global 'inspectThing' function for inspecting objects
function inspectThing(thing)
    return hs.inspect.inspect(thing)
end

-- Global variables
hs.window.animationDuration = 0.0
caffeinateWatcher = nil
pasteboardWatcher = nil

profileStop('globals')

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

-- Easy Locking - Hyper-Delete to lock the machine
hs.hotkey.bind(hyper.key, "delete", function()
    hs.caffeinate.startScreensaver()
end)

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

-- Pasteboard
pasteboardWatcher = hs.pasteboard.watcher.new(function(contents)
    link_replace.replacePasteboardLinkIfNecessary(contents)
end)

profileStop('pasteboard')
profileStart('reloading')

-- Reloading
-- I can reload the config when this file changes. From:
-- http://www.hammerspoon.org/go/#fancyreload
function reload_config(files)
    hs.reload()
end

hs.pathwatcher.new(os.getenv("HOME") .. "/.hammerspoon/", reload_config):start()

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

-- Bootstrapping

flux.init()
vim_movement.init()
footpedals.init()
darkmode.init()
audio_output.init()
youtubedl.init()
iphone_mirroring.init()

hs.alert.show("hs ready!")

profileStop('configTotal')

