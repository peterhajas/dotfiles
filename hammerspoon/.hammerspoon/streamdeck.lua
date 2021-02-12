require "streamdeck_buttons.button_images"
require "streamdeck_buttons.audio_devices"
require "streamdeck_buttons.itunes"
require "streamdeck_buttons.terminal"
require "streamdeck_buttons.peek"
require "streamdeck_buttons.url"
require "streamdeck_buttons.lock"
require "streamdeck_buttons.clock"
require "streamdeck_buttons.camera"
require "streamdeck_buttons.office_lights"

require "profile"

function bool_to_number(value)
  return value and 1 or 0
end

local currentDeck = nil
local asleep = false
local buttons = { }

local function updateButton(i, pressed)
    -- No StreamDeck? No update
    if currentDeck == nil then return end

    profileStart('streamdeckButtonUpdate_' .. i)

    local button = buttons[i]

    local isStatic = button['image'] ~= nil
    if isStatic then
        -- hs.alert("STATIC: updating image for " .. i, 4)
        currentDeck:setButtonImage(i, button['image'])
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

-- Button Definitions
-- Buttons are defined as tables, with some values:
-- 'image': the image
-- 'imageProvider': the function returning the image
-- 'pressDown': the function to perform on press down
-- 'pressUp': the function to perform on press up
-- 'updateInterval': the desired update interval (if any) in seconds
-- 'name': the name of the button
-- Internal values:
-- '_timer': the timer that is updating this button

buttons = {
    weatherButton,
    calendarPeekButton(),
    peekButtonFor('com.reederapp.5.macOS'),
    lockButton,
    audioDeviceButton(false),
    audioDeviceButton(true),
    itunesPreviousButton(),
    itunesNextButton(),
    officeToggle,
    officeNormal,
    officeMood
}

local function disableTimers()
    for index, button in pairs(buttons) do
        local currentTimer = button['_timer']
        if currentTimer ~= nil then
            currentTimer:stop()
        end
        button['_timer'] = nil
    end
end

local function updateTimers()
    if asleep or currentDeck == nil then
        disableTimers()
    else
        disableTimers()
        for index, button in pairs(buttons) do
            local desiredUpdateInterval = button['updateInterval']
            if desiredUpdateInterval ~= nil then
                local timer = hs.timer.new(desiredUpdateInterval, function()
                    updateButton(index, false)
                end)
                timer:start()
                button['_timer'] = timer
            end
        end
    end
end

local function updateButtons()
    profileStart('streamdeckButtonUpdate_all')
    for index, button in pairs(buttons) do
        updateButton(index, false)
    end
    profileStop('streamdeckButtonUpdate_all')
end

function streamdeck_sleep()
    asleep = true
    updateTimers()
    if currentDeck == nil then return end
    currentDeck:setBrightness(0)
end

function streamdeck_wake()
    asleep = false
    updateTimers()
    if currentDeck == nil then return end
    currentDeck:setBrightness(30)
    updateButtons()
end

function streamdeck_updateButton(matching)
    for index, button in pairs(buttons) do
        title = button['name']
        if title ~= nil then
            if string.match(title, matching) then
                updateButton(index, false)
            end
        end
    end
end

local function streamdeck_button(deck, buttonID, pressed)
    -- Don't allow commands while the machine is asleep / locked
    if asleep then
        return
    end

    -- Grab the button
    local buttonForID = buttons[buttonID]
    -- Guard against invalid buttons
    if buttonForID == nil then
        -- Just do a dinky little sign-of-life
        local color = hs.drawing.color.black
        if pressed then
            color = hs.drawing.color.lists()['Apple']['Orange']
        end
        currentDeck:setButtonColor(buttonID, color)
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
        deck:buttonCallback(streamdeck_button)
        deck:reset()

        -- columns, rows = deck:buttonLayout()
        updateButtons()
        updateTimers()
    else
        currentDeck = nil
        updateTimers()
    end
    if asleep then
        streamdeck_sleep()
    else
        streamdeck_wake()
    end
    profileStop('streamdeckDiscovery')
end

hs.streamdeck.init(streamdeck_discovery)
