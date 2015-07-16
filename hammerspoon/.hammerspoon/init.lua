-- peterhajas's Hammerspoon config file
-- Originally written Jan 4, 2015

-- vim:fdm=marker

-- Hyper Key {{{

local hyper = {"ctrl", "alt", "shift"}

-- }}}
-- Global 'doc' variable that I can use inside of the Hammerspoon {{{

doc = hs.doc.fromJSONFile(hs.docstrings_json_file)

-- }}}
-- Listen for Location Events {{{

local startedMonitoringLocation = hs.location.start()

if startedMonitoringLocation == false then
    hs.alert.show("Unable to determine location - please approve Hammerspoon to access your location")
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
-- Preferred screen {{{

function preferredScreen ()
    return hs.screen.allScreens()[1]
end

-- }}}
-- Frontmost app {{{

function frontmostAppName ()
    return hs.application.frontmostApplication():title()
end

-- }}}
-- App Shortcuts {{{

-- Option-M for Mail

hs.hotkey.bind({"alt"}, "m", function()
    hs.application.launchOrFocus("Mail")
end)

-- Option-A for Messages

hs.hotkey.bind({"alt"}, "a", function()
    hs.application.launchOrFocus("Messages")
end)

-- Option-Tab for Terminal

hs.hotkey.bind({"alt"}, "tab", function()
    hs.application.launchOrFocus("Terminal")
end)

-- Option-T for Textual

hs.hotkey.bind({"alt"}, "t", function()
    hs.application.launchOrFocus("Textual 5")
end)

-- }}}
-- F.lux Functionality {{{

function whitepointForHavingScreenTint(hasScreenTint)
    local whitepoint = { }
    if hasScreenTint then
        -- I copied these values from hs.screen:getGamma() while running f.lux

        whitepoint['blue'] = 0.5240478515625
        whitepoint['green'] = 0.76902770996094
        whitepoint['red'] = 1
    else
        whitepoint['blue'] = 1
        whitepoint['green'] = 1
        whitepoint['red'] = 1
    end

    return whitepoint
end

function blackpointForHavingScreenTint(hasScreenTint)
    local blackpoint = { }
    blackpoint['alpha'] = 1
    blackpoint['blue'] = 0
    blackpoint['green'] = 0
    blackpoint['red'] = 0

    return blackpoint
end

function updateFluxiness()
    local location = hs.location.get()

    if location == nil then return end
    local latitude = location['latitude']
    local longitude = location['longitude']
    local now = os.time()

    local sunriseTime = hs.location.sunrise(latitude, longitude, -7)
    local sunsetTime = hs.location.sunset(latitude, longitude, -7)

    local nowDay = os.date("*t").day
    local sunriseDay = os.date("*t", sunriseTime).day
    local sunsetDay = os.date("*t", sunsetTime).day

    local sunHasRisenToday
    local sunHasSetToday

    if type(sunriseTime) == 'string' and sunriseTime == 'N/R' then
        sunHasRisenToday = false
    else
        sunHasRisenToday = ((now > sunriseTime) and (nowDay == sunriseDay))
    end

    if type(sunsetTime) == 'string' and sunsetTime == 'N/S' then
        sunHasSetToday = false
    else
        sunHasSetToday = ((now > sunsetTime) and (nowDay == sunsetDay))
    end

    local shouldTintScreen = false

    -- If the sun has risen but has not set, disable the screen tint

    if sunHasRisenToday and not sunHasSetToday then shouldTintScreen = false end

    -- If the sun has risen and has set, enable the screen tint

    if sunHasRisenToday and sunHasSetToday then shouldTintScreen = true end

    -- If the sun has not yet risen, enable the screen tint

    if not sunHasRisenToday then shouldTintScreen = true end

    -- Determine the gamma to set on our displays

    local whitepoint = whitepointForHavingScreenTint(shouldTintScreen)
    local blackpoint = blackpointForHavingScreenTint(shouldTintScreen)
    
    local screens = hs.screen.allScreens()

    for i,screen in next,screens do
        local screenGamma = screen:getGamma()
        
        if (screenGamma['whitepoint'] ~= whitepoint) or (screenGamma['blackpoint'] ~= blackpoint) then
            screen:setGamma(whitepoint, blackpoint)
        end
    end
end

updateFluxiness()

-- }}}
-- Status Geometry {{{

-- When drawing status information, it is useful to have metrics about where to
-- draw

function statusEdgePadding()
    return 10
end

function statusTextSize()
    return 15
end

function statusHeight()
    return statusTextSize() + 4
end

function statusFrameForXAndWidth (x, w)
    local screenFrame = preferredScreen():fullFrame()
    return hs.geometry.rect(x,
                            screenFrame.h - statusHeight() - statusEdgePadding(),
                            w,
                            statusHeight())
end

function statusTextColor()
    local statusTextColor = {}
    statusTextColor['red'] = 1.0
    statusTextColor['green'] = 1.0
    statusTextColor['blue'] = 1.0
    statusTextColor['alpha'] = 0.7
    return statusTextColor
end

-- Status Frames

function iTunesStatusFrame()
    local width = 400
    local frame = statusFrameForXAndWidth(statusEdgePadding(), width)
    return frame
end

-- }}}
-- Brightness Control {{{

function changeBrightnessInDirection (d)
    local brightnessChangeAmount = 16
    local brightness = hs.brightness.get()

    brightness = brightness + (brightnessChangeAmount * d)

    hs.brightness.set(brightness)
end

-- Hyper-1 for brightness down

hs.hotkey.bind(hyper, "1", function()
    changeBrightnessInDirection(-1)
end)

-- Hyper-2 for brightness up

hs.hotkey.bind(hyper, "2", function()
    changeBrightnessInDirection(1)
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
-- iTunes Current Track Display {{{

local iTunesStatusText
local iTunesStatusTextBackground

function destroyiTunesTrackDisplay()
    if iTunesStatusText then iTunesStatusText:delete() end
    if iTunesStatusTextBackground then iTunesStatusTextBackground:delete() end
end

function updateiTunesTrackDisplay()
    local statusText = ''
    if hs.appfinder.appFromName('iTunes') and 
        type(hs.itunes.getCurrentTrack()) == 'string' then
        local trackName = hs.itunes.getCurrentTrack()
        local artistName = hs.itunes.getCurrentArtist()
        statusText = trackName .. ' by ' .. artistName
    end

    iTunesStatusText:setText(statusText)
end

function buildiTunesTrackDisplay()
    destroyiTunesTrackDisplay()
    local frame = iTunesStatusFrame()
    iTunesStatusText = hs.drawing.text(frame, '')
    iTunesStatusTextBackground = hs.drawing.rectangle(frame)

    iTunesStatusText:setTextColor(statusTextColor()):setTextSize(statusTextColor):sendToBack():show()
    updateiTunesTrackDisplay()
end

buildiTunesTrackDisplay()

-- }}}
-- Media Player Controls {{{

-- Hyper-8 plays/pauses music

hs.hotkey.bind(hyper, "8", function()
    hs.itunes.play()
    updateiTunesTrackDisplay()
end)

-- Hyper-0 goes to the next track

hs.hotkey.bind(hyper, "0", function()
    hs.itunes.next()
    updateiTunesTrackDisplay()
end)

-- Hyper-9 goes to the previous track

hs.hotkey.bind(hyper, "9", function()
    hs.itunes.previous()
    updateiTunesTrackDisplay()
end)

-- }}}
-- Volume Control {{{

-- Hyper-- for volume down

hs.hotkey.bind(hyper, "-", function()
    hs.applescript.applescript("set volume output volume ((output volume of (get volume settings)) - 10) --100%")
end)

-- Hyper-+ for volume up

hs.hotkey.bind(hyper, "=", function()
    hs.applescript.applescript("set volume output volume ((output volume of (get volume settings)) + 10) --100%")
end)

-- }}}
-- Easy Locking {{{

-- Hyper-Delete to lock the machine

hs.hotkey.bind(hyper, "delete", function()
    hs.caffeinate.startScreensaver()
end)

-- }}}
-- Vim Movement Shortcuts {{{

hs.hotkey.bind({"ctrl"}, "h", function()
    local key = hs.eventtap.event.newKeyEvent({}, "left", true)
    key:post()
end)

hs.hotkey.bind({"ctrl"}, "j", function()
    local key = hs.eventtap.event.newKeyEvent({}, "down", true)
    key:post()
end)

hs.hotkey.bind({"ctrl"}, "k", function()
    local key = hs.eventtap.event.newKeyEvent({}, "up", true)
    key:post()
end)

hs.hotkey.bind({"ctrl"}, "l", function()
    local key = hs.eventtap.event.newKeyEvent({}, "right", true)
    key:post()
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
-- Footpedals {{{

-- My footpedals map to F9 and F10. We'll use this to make different things
-- happen in different apps

function sendKeyStroke(modifiers, character)
    hs.eventtap.keyStroke(modifiers, character)
end

hs.hotkey.bind({""}, "f9", function()
    local appName = frontmostAppName()

    if appName == "Safari" then
        sendKeyStroke({"cmd","shift"}, "[")
    elseif appName == "Mail" then
        sendKeyStroke({"cmd","shift"}, "k")
        sendKeyStroke({}, "up")
    elseif appName == "Messages" then
        sendKeyStroke({"cmd"}, "[")
    elseif appName == "Photos" then
        sendKeyStroke({}, "left")
    end
end)

hs.hotkey.bind({""}, "f10", function()
    local appName = frontmostAppName()

    if appName == "Safari" then
        sendKeyStroke({"cmd","shift"}, "]")
    elseif appName == "Mail" then
        sendKeyStroke({"cmd","shift"}, "k")
        sendKeyStroke({}, "down")
    elseif appName == "Messages" then
        sendKeyStroke({"cmd"}, "]")
    elseif appName == "Photos" then
        sendKeyStroke({}, "right")
    end
end)

-- }}}
-- Window Hints {{{

local hints = hs.hints
hints.hintChars = {'a','s','d','f','j','k','l',';','g','h'}
hints.fontSize = 100

hs.hotkey.bind(hyper, "space", function()
    hints.windowHints()
end)

-- }}}
-- Window Movement {{{

function windowPaddingForScreen (screen)
    local screenFrame = screen:frame()
    local windowPadding = screenFrame.w * 0.005

    return windowPadding
end

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

function moveWindowInDirection (window,direction)
    local newWindowFrame = window:frame()
    oldWindowPosition = hs.geometry.point(newWindowFrame.x, newWindowFrame.y)

    local padding = windowPaddingForScreen(window:screen())

    newWindowFrame.x = newWindowFrame.x + (newWindowFrame.w * direction.w)
    newWindowFrame.y = newWindowFrame.y + (newWindowFrame.h * direction.h)

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
    local minimumWindowWidth = 600

    -- We should allow even multiples of minimumWindowWidth to fit onscreen
    
    numberOfWindowsWide = screen:frame().w / minimumWindowWidth
    numberOfWindowsWide = math.floor(numberOfWindowsWide)

    if amount == 1 then amount = numberOfWindowsWide end
    if amount == -1 then amount = 1 / numberOfWindowsWide end
    if amount == 0 then amount = 1 end

    return amount
end

function resizeWindowByAmount (window, amount)
    local newWindowFrame = window:frame()

    oldWindowSize = hs.geometry.size(newWindowFrame.w, newWindowFrame.h)

    local amountW = amountToResizeForWindow(window, amount.w)
    local amountH = amountToResizeForWindow(window, amount.h)

    newWindowFrame.w = newWindowFrame.w * amountW
    newWindowFrame.h = newWindowFrame.h * amountH

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
    win:moveToScreen(newWindowScreen)
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
-- Application Watching {{{

-- Our global app watcher which will watch for app changes

function handleAppEvent(name, event, app)
    if name == 'iTunes' then updateiTunesTrackDisplay() end
end

appWatcher = hs.application.watcher.new(handleAppEvent)
appWatcher:start()

-- }}}
-- Global Update Timer {{{

-- For all sorts of reasons, it's convenient to have a timer that's always
-- running. We'll keep it at a pretty infrequent ten seconds (and terminate it
-- if the battery is too low)

function timerUpdate()
    updateiTunesTrackDisplay()
    updateFluxiness()
end

timer = hs.timer.new(10, timerUpdate)
timer:start()

-- }}}
-- Battery Watching {{{

-- Our global battery watcher which will watch for battery events

function handleBatteryEvent()
    local isDraining = true

    if hs.battery.powerSource() == 'AC Power' then isDraining = false end
    if hs.battery.powerSource() == nil then isDraining = false end

    local isLow = isDraining and (hs.battery.percentage() < 10)

    if isLow then
        appWatcher:stop()
        timer:stop()
    else
        appWatcher:start()
        timer:start()
    end
end

batteryWatcher = hs.battery.watcher.new(handleBatteryEvent)
batteryWatcher:start()

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
-- Misc. {{{

function decorationColor()
    nameForColor = 'Computer'

    ok, result = hs.applescript.applescript("set foo to computer name of (system info)")

    if (ok) then
        nameForColor = result
    end

    local color = {}

    local nameLength = string.len(nameForColor)
    local sin = math.sin(nameLength)
    local cos = math.cos(nameLength)

    color['red'] = 1.0 - (1.0 / nameLength)
    color['green'] = sin
    color['blue'] = cos
    color['alpha'] = 1.0

    return color
end

local strip

function stripWidthForScreen(screen)
    return screen:fullFrame().w * 0.15
end

function buildStrip()
    if strip then strip:delete() end
    local screenForStrip = preferredScreen()
    local stripWidth = stripWidthForScreen(screenForStrip)
    local screenFrame = screenForStrip:fullFrame()
    local stripStart = hs.geometry.point((screenFrame.w * 0.65) - stripWidth, 0 - stripWidth)
    local stripEndY = screenFrame.w - stripStart.x
    local stripEnd = hs.geometry.point(screenFrame.w + 2 * stripWidth, stripEndY  + 2 * stripWidth)
    strip = hs.drawing.line(stripStart, stripEnd)

    strip = strip:setStrokeWidth(stripWidth)

    strip = strip:setStrokeColor(decorationColor())

    strip:sendToBack():show()
end

buildStrip()

-- }}}
-- Reloading {{{
-- I can reload the config when this file changes. From:
-- http://www.hammerspoon.org/go/#fancyreload
function reload_config(files)
    destroyiTunesTrackDisplay()
    appWatcher:stop()
    timer:stop()
    batteryWatcher:stop()
    screenWatcher:stop()
    hs.reload()
end

hs.pathwatcher.new(os.getenv("HOME") .. "/.hammerspoon/", reload_config):start()
hs.alert.show("Config loaded")

-- }}}

