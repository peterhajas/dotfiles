-- peterhajas's Hammerspoon config file
-- Originally written Jan 4, 2015

-- vim:fdm=marker

-- Hyper Key {{{

local hyper = {"ctrl", "alt", "shift"}

-- }}}
-- Global 'doc' variable that I can use inside of the Hammerspoon {{{

doc = hs.doc.fromJSONFile(hs.docstrings_json_file)

-- }}}
-- Global 'inspectThing' function for inspecting objects {{{

function inspectThing(thing)
    return hs.inspect.inspect(thing)
end

-- }}}
-- {{{ Updating Status Items

function updateStatusItemWithName(items, name)
    textObject = items[name][3]
    bgObject = items[name][4]

    updateFunc = items[name][2]

    newText = ""

    if updateFunc ~= nil then newText = updateFunc() end

    if string.len(newText) == 0 then
        bgObject:hide()
    else
        bgObject:show()
        bgObject:orderBelow(textObject)
    end

    textObject:setText(newText)
end

-- }}}
-- {{{ Left / Right Status Items
--
local leftStatusItems = {}
local rightStatusItems = {}

-- }}}
-- Status Convenience Methods {{{

function percentStringWithLeadingZeroForPercent(percent)
    percent = math.floor(percent)
    percentString = tostring(percent)

    -- Ugly hack - how does one do leading zeroes?

    if string.len(percent) > 2 then
        return percentString
    else
        return "0" .. percentString
    end
end

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
-- Color Manipulation {{{

function HSVtoRGB (hsv_color)
    local h = hsv_color['hue']
    local s = hsv_color['saturation']
    local v = hsv_color['value']
    local r, g, b, i, f, p, q, t;
    i = math.floor(h * 6);
    f = h * 6 - i;
    p = v * (1 - s);
    q = v * (1 - f * s);
    t = v * (1 - (1 - f) * s);
    if i == 0 then r = v; g = t; b = p end
    if i == 1 then r = q; g = v; b = p end
    if i == 2 then r = p; g = v; b = t end
    if i == 3 then r = p; g = q; b = v end
    if i == 4 then r = t; g = p; b = v end
    if i == 5 then r = v; g = p; b = q end
    local color = {}
    color['red'] = r
    color['green'] = g
    color['blue'] = b
    color['alpha'] = 1.0

    return color
end

-- }}}
-- Decoration Colors {{{

function decorationColorHSV()
    nameForColor = 'Computer'

    ok, result = hs.applescript.applescript("set foo to computer name of (system info)")

    if (ok) then
        nameForColor = result
    end

    local color = {}

    local nameLength = string.len(nameForColor)
    local sin = math.sin(nameLength)
    local cos = math.cos(nameLength)

    local h = math.abs(cos)
    local s = math.abs(sin)
    local v = 1.0 - (1.0 / nameLength)

    local color = {}
    color['hue'] = h
    color['saturation'] = s
    color['value'] = v

    return color
end

function altDecorationColorHSV()
    local color = decorationColorHSV()
    color['hue'] = 1.0 - color['hue']
    return color
end

function decorationColor()
    local hsv_color = decorationColorHSV()
    local color = HSVtoRGB(hsv_color)
    return color
end

function altDecorationColor()
    local hsv_color = altDecorationColorHSV()
    local color = HSVtoRGB(hsv_color)
    return color
end

-- }}}
-- Preferred screen {{{

function preferredScreen ()
    return hs.screen.allScreens()[1]
end

-- }}}
-- Decoration Drawing {{{

function proportionOfPreferredScreenDimension(percent)
    return preferredScreen():fullFrame().w * percent
end

function regularDecorationTextSize()
    return 13
end

function regularDecorationHeight()
    return regularDecorationTextSize() * 1.7
end

function regularDecorationPadding()
    return 5
end

function decorationTextColor()
    local statusTextColor = {}
    local color = 1.0
    statusTextColor['red'] = color
    statusTextColor['green'] = color
    statusTextColor['blue'] = color
    statusTextColor['alpha'] = 1.0
    return statusTextColor
end

function decorationBackgroundColor()
    local backgroundColor = {}
    local color = 0.2
    backgroundColor['red'] = color
    backgroundColor['green'] = color
    backgroundColor['blue'] = color
    backgroundColor['alpha'] = 0.85
    return backgroundColor
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
-- Brightness Control {{{

function updateBrightnessStatus()
    text = percentStringWithLeadingZeroForPercent(hs.brightness.get()) .. "☀"
    return text
end

function changeBrightnessInDirection (d)
    local brightnessChangeAmount = 16
    local brightness = hs.brightness.get()

    brightness = brightness + (brightnessChangeAmount * d)

    hs.brightness.set(brightness)

    updateStatusItemWithName(rightStatusItems, "Brightness")
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
-- iTunes Current Track Status Update{{{

function updateiTunesTrackDisplay()
    local statusText = ''
    if hs.appfinder.appFromName('iTunes') and 
        type(hs.itunes.getCurrentTrack()) == 'string' then
        local trackName = hs.itunes.getCurrentTrack()
        local artistName = hs.itunes.getCurrentArtist()
        statusText = trackName .. ' by ' .. artistName
    end

    return statusText
end

-- }}}
-- Media Player Controls {{{

-- Hyper-8 plays/pauses music

hs.hotkey.bind(hyper, "8", function()
    hs.itunes.play()
    updateStatusItemWithName(leftStatusItems, "iTunes")
end)

-- Hyper-0 goes to the next track

hs.hotkey.bind(hyper, "0", function()
    hs.itunes.next()
    updateStatusItemWithName(leftStatusItems, "iTunes")
end)

-- Hyper-9 goes to the previous track

hs.hotkey.bind(hyper, "9", function()
    hs.itunes.previous()
    updateStatusItemWithName(leftStatusItems, "iTunes")
end)

-- }}}
-- Volume Control {{{

-- Number of volume "ticks"

function volumeTicks()
    return 10
end

-- Getting the current volume

function currentVolume()
    ok, result = hs.applescript.applescript("output volume of (get volume settings)")

    volume = -1

    if (ok) then
        volume = tonumber(result)
    end

    return volume
end

-- Volume Status Item

function updateVolumeStatus(volumeStatus)
    text = percentStringWithLeadingZeroForPercent(currentVolume()) .. "☊"
    return text
end

-- Changing volume

function changeVolumeByAmount(amount)
    vol = currentVolume()
    delta = (100 / volumeTicks()) * amount
    newVol = currentVolume() + delta
    newVol = math.floor(newVol)

    local command = "set volume output volume " .. newVol .. " --100%"
    hs.applescript.applescript(command)

    updateStatusItemWithName(rightStatusItems, "Volume")
end

-- Hyper-- for volume down

hs.hotkey.bind(hyper, "-", function()
    changeVolumeByAmount(-1)
end)

-- Hyper-+ for volume up

hs.hotkey.bind(hyper, "=", function()
    changeVolumeByAmount(1)
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
-- Footpedals Key Combos {{{

-- My footpedals map to F9 and F10. We'll use this to make different things
-- happen in different apps

local footpedalKeyCombos = {}

-- Footpedal Key Combos are defined as a table of tables
-- Each entry in the table has the modifiers (if any), the left key pedal press,
-- and the right key pedal press.
--
-- Most apps only have one command per foot. Some, like Mail, require two

footpedalKeyCombos["Mail"]     = { {{"cmd","shift"}, "k", "k"}, {{}, "up", "down"} }
footpedalKeyCombos["Safari"]   = { {{"cmd","shift"}, "[", "]" } }
footpedalKeyCombos["Tweetbot"] = { {{"cmd"}, "[", "]" } }
footpedalKeyCombos["iTunes"]   = { {{"cmd"}, "left", "right" } }
footpedalKeyCombos["Photos"]   = { {{"cmd"}, "left", "right" } }
footpedalKeyCombos["Messages"] = { {{"cmd"}, "[", "]" } }
footpedalKeyCombos["Calendar"] = { {{"cmd"}, "left", "right" } }

-- }}}
-- Sending footpedal key commands {{{

function sendKeyStroke(modifiers, character)
    hs.eventtap.keyStroke(modifiers, character)
end


function runFootpedalCommandsForFoot(commands, foot)
    if commands == nil then return end
    for idx,command in pairs(commands) do
        local modifiers = command[1]
        local key

        if foot == "left" then
            key = command[2]
        else
            key = command[3]
        end

        sendKeyStroke(modifiers, key)
    end
end

hs.hotkey.bind({""}, "f9", function()
    runFootpedalCommandsForFoot(footpedalKeyCombos[frontmostAppName()], "left")
end)

hs.hotkey.bind({""}, "f10", function()
    runFootpedalCommandsForFoot(footpedalKeyCombos[frontmostAppName()], "right")
end)

-- }}}
-- Date Status Update{{{

function dateString()
    return os.date("%a %b %d")
end

function updateStatusDate(date)
    return dateString()
end

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
    local windowPadding = screenFrame.w * 0.001
    windowPadding = math.floor(windowPadding)

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
-- Application Watching {{{

-- Our global app watcher which will watch for app changes

function handleAppEvent(name, event, app)
    if name == 'iTunes' then
        updateStatusItemWithName(leftStatusItems, "iTunes")
    end
end

appWatcher = hs.application.watcher.new(handleAppEvent)
appWatcher:start()

-- }}}
-- Global Update Timer {{{

-- For all sorts of reasons, it's convenient to have a timer that's always
-- running. We'll keep it at a pretty infrequent ten seconds (and terminate it
-- if the battery is too low)

function timerUpdate()
    updateStatusItemWithName(leftStatusItems, "iTunes")
    updateFluxiness()
    updateStatusItemWithName(rightStatusItems, "Date")
end

timer = hs.timer.new(10, timerUpdate)
timer:start()

-- }}}
-- Battery Status {{{

function updateBatteryStatus()
    local string = ""
    local charging = hs.battery.isCharging()

    if charging == nil then return string end

    if charging == true then
        string = "+"
    else 
        string = "-"
    end

    if hs.battery.isCharged() then string = "=" end

    return string .. percentStringWithLeadingZeroForPercent(hs.battery.percentage())

end

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

    updateStatusItemWithName(rightStatusItems, "Battery")
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
-- Desktop Strip {{{

local strip

function buildStrip()
    if strip then strip:delete() end
    local screenForStrip = preferredScreen()
    local stripWidth = proportionOfPreferredScreenDimension(0.15)
    local screenFrame = screenForStrip:fullFrame()
    local longestScreenDimension = math.max(screenFrame.w, screenFrame.h)
    local shortestScreenDimension = math.min(screenFrame.w, screenFrame.h)
    local dimensionDifference = longestScreenDimension - shortestScreenDimension
    local stripStart = hs.geometry.point(dimensionDifference - stripWidth, 0 - stripWidth)
    local stripEnd = hs.geometry.point(screenFrame.w + stripWidth, screenFrame.h + stripWidth)
    strip = hs.drawing.line(stripStart, stripEnd)

    strip = strip:setStrokeWidth(stripWidth)

    strip = strip:setStrokeColor(decorationColor())

    strip:sendToBack():show()
end

buildStrip()

-- }}}
-- Status Item Layout {{{

-- Iterate through tables in a sorted fashion
-- Cribbed from http://stackoverflow.com/questions/15706270/sort-a-table-in-lua

function spairs(t, order)
    -- collect the keys
    local keys = {}
    for k in pairs(t) do keys[#keys+1] = k end

    -- if order function given, sort by it by passing the table and keys a, b,
    -- otherwise just sort the keys 
    if order then
        table.sort(keys, function(a,b) return order(t, a, b) end)
    else
        table.sort(keys)
    end

    -- return the iterator function
    local i = 0
    return function()
        i = i + 1
        if keys[i] then
            return keys[i], t[keys[i]]
        end
    end
end

function addStatusItemsOnSide(items, side)
    local textSize = regularDecorationTextSize()
    local widthPerChar = 8.9
    local height = regularDecorationHeight()
    local y = preferredScreen():fullFrame().h - (height + regularDecorationPadding())
    local margin = regularDecorationPadding()
    local startingX
    local offsetMultiplier

    if side == "left" then
        startingX = 0
        offsetMultiplier = 1
    else
        startingX = hs.screen.mainScreen():frame().w
        offsetMultiplier = -1
    end

    local currentX = startingX + (offsetMultiplier * margin)

    function sortItems(i, a, b)
        local a_ord = i[a][5]
        local b_ord = i[b][5]

        return a_ord > b_ord
    end

    for name, data in spairs(items, sortItems) do
        local drawable = data[3]
        local bg = data[4]

        local text = data[1]

        local width = widthPerChar * string.len(text)

        if side == "right" then
            currentX = currentX - width
        end

        local frame = hs.geometry.rect(currentX,y,width,height)

        if side == "left" then
            currentX = currentX + (offsetMultiplier * (width + margin))
        else
            currentX = currentX + (offsetMultiplier * margin)
        end

        local drawable = hs.drawing.text(frame, text)
        local bg = hs.drawing.rectangle(frame)

        data[3] = drawable
        data[4] = bg

        bg:setFillColor(decorationBackgroundColor())
        bg:show()

        drawable:setTextFont("Menlo")
        drawable:setTextSize(textSize)
        drawable:setTextColor(decorationTextColor())
        drawable:show()

        bg:sendToBack()
        drawable:sendToBack()

        updateStatusItemWithName(items, name)
    end
end

-- }}}
-- Status Items {{{

-- A status item is a table with the following params:
-- Sample text (for sizing) | update func (if any) | nil | nil | order (LTR)
-- Note that the nils will be populated with the text object and background

leftStatusItems["iTunes"] = {"This is a song by this cool artist", updateiTunesTrackDisplay, nil, nil, 1}

rightStatusItems["Battery"] = {"100=", updateBatteryStatus, nil, nil, 1}
rightStatusItems["Brightness"] = {"020B", updateBrightnessStatus, nil, nil, 2}
rightStatusItems["Volume"] = {"050V", updateVolumeStatus, nil, nil, 3}
rightStatusItems["Date"] = {"MMM DD DDD", updateStatusDate, nil, nil, 4}

addStatusItemsOnSide(leftStatusItems, "left")
addStatusItemsOnSide(rightStatusItems, "right")

-- }}}
-- Decoration Z Ordering {{{

function arrangeDecorations()
    strip:sendToBack()
end

arrangeDecorations()

-- }}}
-- Reloading {{{
-- I can reload the config when this file changes. From:
-- http://www.hammerspoon.org/go/#fancyreload
function reload_config(files)
    appWatcher:stop()
    timer:stop()
    batteryWatcher:stop()
    screenWatcher:stop()
    hs.reload()
end

hs.pathwatcher.new(os.getenv("HOME") .. "/.hammerspoon/", reload_config):start()

-- }}}

