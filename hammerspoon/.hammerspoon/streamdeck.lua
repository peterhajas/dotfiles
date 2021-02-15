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
require "streamdeck_buttons.weather"
require "streamdeck_buttons.app_switcher"
require "streamdeck_buttons.window_switcher"
require "streamdeck_buttons.animation_demo"
require "streamdeck_buttons.home_assistant"

require "profile"
require "util"

local streamdeckLogger = hs.logger.new('streamdeck', 'debug')

-- Variables for tracking Streamdeck state
-- The current streamdeck (or `nil` if none is connected)
local currentDeck = nil
-- Whether or not the machine is asleep
local asleep = false

-- The currently visible buttons
local buttons = { }

-- The stack of button states behind this one
-- This is an array
local buttonStack = { }

local function updateButton(i, pressed)
    -- No StreamDeck? No update
    if currentDeck == nil then return end

    profileStart('streamdeckButtonUpdate_' .. i)

    local button = buttons[i]
    if button ~= nil then
        local isStatic = button['image'] ~= nil
        if isStatic then
            -- hs.alert("STATIC: updating image for " .. i, 4)

            currentDeck:setButtonImage(i, button['image'])
        else
            -- hs.alert("DYNAMIC: updating image for " .. i, 4)

            -- Otherwise, call the provider
            local image = button['imageProvider'](pressed)
            button['_cachedImage'] = image
            if image ~= nil then
                currentDeck:setButtonImage(i, image)
            end
        end
    else
        -- Just do a dinky little sign-of-life
        local color = hs.drawing.color.black
        if pressed then
            color = hs.drawing.color.lists()['Apple']['Orange']
        end
        currentDeck:setButtonColor(i, color)
        return
    end

    profileStop('streamdeckButtonUpdate_' .. i)
end

-- Buttons are defined as tables, with some values:
-- 'image': the image
-- 'imageProvider': the function returning the image
-- 'pressDown': the function to perform on press down
-- 'pressUp': the function to perform on press up
-- 'updateInterval': the desired update interval (if any) in seconds
-- 'name': the name of the button
-- 'children': function returning child buttons, which will be pushed

-- Internal values:
-- '_timer': the timer that is updating this button
-- '_cachedImage': cached image for this button

-- Initial Button Definitions
buttons = {
    weatherButton(),
    calendarPeekButton(),
    peekButtonFor('com.reederapp.5.macOS'),
    lockButton,
    audioDeviceButton(false),
    audioDeviceButton(true),
    itunesPreviousButton(),
    itunesNextButton(),
    officeToggle,
    appSwitcher(),
    windowSwitcher(),
    homeAssistant(),
}

-- Disables all timers for all buttons
local function disableTimers()
    for index, button in pairs(buttons) do
        local currentTimer = button['_timer']
        if currentTimer ~= nil then
            currentTimer:stop()
        end
        button['_timer'] = nil
    end
end

-- Updates all timers for all buttons
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

-- Updates all buttons
local function updateButtons()
    profileStart('streamdeckButtonUpdate_all')
    columns, rows = currentDeck:buttonLayout()
    for i=1,columns*rows+1,1 do
        updateButton(i, false)
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

-- Pushes `newState` onto the stack of buttons
function pushButtonState(newState)
    -- Push current buttons back 
    buttonStack[#buttonStack+1] = buttons
    -- Empty the buttons and update
    disableTimers()
    buttons = { }
    updateButtons()
    -- Replace
    buttons = newState
    -- Update
    updateButtons()
    updateTimers()
end

-- Pops back to the last button state
function popButtonState()
    -- Don't pop back past the first state
    if #buttonStack == 0 then
        return
    end

    -- Grab new state
    newState = buttonStack[#buttonStack]
    -- Remove from stack
    buttonStack[#buttonStack] = nil
    -- Empty the buttons and update
    disableTimers()
    buttons = { }
    updateButtons()
    -- Replace
    buttons = newState
    -- Update
    if currentDeck ~= nil then
        updateButtons()
        updateTimers()
    end
end

-- Returns a buttonState for pushing pushButton's children onto the stack
local function buttonStateForPushedButton(pushedButton)
    local state = pushedButton['children']
    if state == nil then return nil end
    state = state()

    -- Add a back button
    local closeButton = {
        ['image'] = streamdeck_imageFromText('􀁲'),
        ['pressUp'] = function()
            popButtonState()
        end
    }
    table.insert(state, 1, closeButton)

    return state
end

-- Button callback from hs.streamdeck
local function streamdeck_button(deck, buttonID, pressed)
    -- Don't allow commands while the machine is asleep / locked
    if asleep then
        return
    end

    -- Grab the button
    local buttonForID = buttons[buttonID]
    if buttonForID == nil then
        updateButton(buttonID, pressed)
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
        local pushedState = buttonStateForPushedButton(buttonForID)
        if pushedState ~= nil then
            pushButtonState(pushedState)
        else
            updateButton(buttonID, false)
        end
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
