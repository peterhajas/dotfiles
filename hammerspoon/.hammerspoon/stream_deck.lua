require "streamdeck_buttons.button_images"
require "streamdeck_buttons.audio_devices"
require "streamdeck_buttons.itunes"

require "profile"

function bool_to_number(value)
  return value and 1 or 0
end

local currentDeck = nil
local asleep = false
local buttonUpdateTimer = nil
local buttonUpdateInterval = 10

function fixupButtonUpdateTimer()
    if asleep or currentDeck == nil then
        buttonUpdateTimer:stop()
    else
        buttonUpdateTimer:start()
    end
end

-- Button Definitions
-- Buttons are defined as tables, with some values
-- 'image': the image
-- 'imageProvider': the function returning the image
-- 'pressDown': the function to perform on press down
-- 'pressUp': the function to perform on press up

local nonceButton = {}

-- Key: bundleID
-- Value: last "press down" nanoseconds
local peekDownTimes = {}
local function peekButtonFor(bundleID)
    return {
        ['image'] = hs.image.imageFromAppBundle(bundleID),
        ['pressDown'] = function()
            peekDownTimes[bundleID] = hs.timer.absoluteTime()
            hs.application.open(bundleID)
        end,
        ['pressUp'] = function()
            local upTime = hs.timer.absoluteTime()
            local downTime = peekDownTimes[bundleID]

            if downTime ~= nil then
                local elapsed = (upTime - downTime) * .000001
                -- If we've held the button down for > 300ms, hide
                if elapsed > 300 then
                    local app = hs.application.get(bundleID)
                    if app ~= nil then
                        app:hide()
                    end
                end
            end
        end
    }
end

local function urlButton(url, button)
    local out = button
    out['pressUp'] =  function()
        hs.urlevent.openURL(url)
        performAfter = performAfter or function() end
        hs.timer.doAfter(0.2, function()
            performAfter()
        end)
    end
    return out
end

local function terminalButton(commandProvider, button)
    local out = button
    out['pressUp'] = function()
        local command = commandProvider()
        if command == nil then
            return
        end

        hs.application.open("com.apple.Terminal")
        hs.eventtap.keyStroke({"cmd"}, "n")
        hs.eventtap.keyStrokes(command)
        hs.eventtap.keyStroke({}, "return")

        performAfter = button['performAfter'] or function() end
        hs.timer.doAfter(0.1, function()
            performAfter()
        end)
    end
    return out
end

local weatherButton = urlButton('https://wttr.in', {
    ['imageProvider'] = function()
        local output, status, t, rc = hs.execute('curl -s "wttr.in?format=1" | sed "s/+//" | sed "s/F//" | grep -v "Unknow"')
        return streamdeck_imageFromText(output, {['fontSize'] = 40 })
    end
})

local cpuButton = terminalButton(function() return 'htop' end, {
    ['imageProvider'] = function()
        local output, status, t, rc = hs.execute('cpu.10s.sh', true)
        return streamdeck_imageFromText(output, {['fontSize'] = 40 })
    end,
    ['performAfter'] = function()
        hs.eventtap.keyStrokes("P")
    end
})

local memoryButton = terminalButton(function() return 'htop' end, {
    ['imageProvider'] = function()
        local output, status, t, rc = hs.execute('memory.10s.sh', true)
        return streamdeck_imageFromText(output, {['fontSize'] = 40 })
    end,
    ['performAfter'] = function()
        hs.eventtap.keyStrokes("M")
    end
})

local pinboardButton = urlButton('https://pinboard.in/add/', {
    ['image'] = streamdeck_imageFromText('􀎧', {['backgroundColor'] = hs.drawing.color.blue}),
    ['pressUp'] = function()
        hs.eventtap.keyStroke({"cmd"}, "v")
    end
})

local youtubeDLButton = terminalButton(function()
    -- Grab pasteboard
    local pasteboard = hs.pasteboard.readString()
    if string.find(pasteboard, 'http') then
        local command = "ytd \""..pasteboard.."\""
        return command
    end
    return nil
end, {
    ['image'] = streamdeck_imageFromText('􀊚"', {['backgroundColor'] = hs.drawing.color.white, ['textColor'] = hs.drawing.color.red}),
    ['performAfter'] = function()
        hs.eventtap.keyStroke({"ctrl"}, "d")
    end
})

local lockButton = {
    ['image'] = streamdeck_imageFromText('􀎡'),
    ['pressUp'] = function()
        hs.caffeinate.lockScreen()
    end
}

local buttons = {
    weatherButton,
    cpuButton,
    memoryButton,
    pinboardButton,
    youtubeDLButton,
    peekButtonFor('com.apple.iCal'),
    peekButtonFor('com.reederapp.5.macOS'),
    lockButton,
    audioDeviceButton(false),
    audioDeviceButton(true),
    itunesPreviousButton(),
    itunesPlayPuaseButton(),
    itunesNextButton()
}

function streamdeck_sleep()
    asleep = true
    fixupButtonUpdateTimer()
    if currentDeck == nil then return end
    currentDeck:setBrightness(0)
end

function streamdeck_wake()
    asleep = false
    fixupButtonUpdateTimer()
    if currentDeck == nil then return end
    currentDeck:setBrightness(30)
    for index, button in pairs(buttons) do
        button['_hasAppliedStaticImage'] = nil
    end
end

local function updateButton(i, pressed)
    -- No StreamDeck? No update
    if currentDeck == nil then return end

    profileStart('streamdeckButtonUpdate_' .. i)

    local button = buttons[i]

    -- If we have a static image, then only update if we have to
    local isStatic = button['image'] ~= nil
    if isStatic then
        if button['_hasAppliedStaticImage'] ~= true then
            -- hs.alert("STATIC: updating image for " .. i, 4)
            currentDeck:setButtonImage(i, button['image'])
            button['_hasAppliedStaticImage'] = true
        end
    else
        -- hs.alert("DYNAMIC: updating image for " .. i, 4)

        -- Otherwise, call the provider
        local image = button['imageProvider'](pressed)
        if image ~= nil then
            currentDeck:setButtonImage(i, image)
        end
    end

    profileStop('streamdeckButtonUpdate_' .. i)
end

local function updateButtons()
    for index, button in pairs(buttons) do
        updateButton(index, false)
    end
end

function streamdeck_update()
    updateButtons()
end


buttonUpdateTimer = hs.timer.new(buttonUpdateInterval, function()
    updateButtons()
end)

local function streamdeck_button(deck, buttonID, pressed)
    -- Don't allow commands while the machine is asleep / locked
    if asleep then
        return
    end

    -- Grab the button
    local buttonForID = buttons[buttonID]
    -- Guard against invalid buttons
    if buttonForID == nil then
        return
    end

    -- Grab its actions
    local pressDown = buttonForID['pressDown'] or function() end
    local pressUp = buttonForID['pressUp'] or function() end

    -- Dispatch
    if pressed then
        pressDown()
        updateButton(buttonID, true)
    else
        pressUp()
        updateButton(buttonID, false)
    end
end

local function streamdeck_discovery(connected, deck)
    profileStart('streamdeckDiscovery')
    if connected then
        currentDeck = deck
        fixupButtonUpdateTimer()
        local waiting = streamdeck_imageFromText("􀍠")

        deck:buttonCallback(streamdeck_button)

        columns, rows = deck:buttonLayout()
        for i=1,columns*rows do
            deck:setButtonImage(i, waiting)
        end
        updateButtons()
    else
        currentDeck = nil
        fixupButtonUpdateTimer()
    end
    if asleep then
        streamdeck_sleep()
    else
        streamdeck_wake()
    end
    profileStop('streamdeckDiscovery')
end

hs.streamdeck.init(streamdeck_discovery)
