require "streamdeck_buttons.button_images"
require "streamdeck_buttons.audio_devices"
require "streamdeck_buttons.itunes"
require "streamdeck_buttons.terminal"
require "streamdeck_buttons.peek"
require "streamdeck_buttons.url"
require "streamdeck_buttons.lock"

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
    profileStart('streamdeckButtonUpdate_all')
    for index, button in pairs(buttons) do
        updateButton(index, false)
    end
    profileStop('streamdeckButtonUpdate_all')
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
        deck:buttonCallback(streamdeck_button)

        -- columns, rows = deck:buttonLayout()
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
