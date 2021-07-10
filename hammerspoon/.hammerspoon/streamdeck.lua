require "streamdeck_buttons.button_images"
require "streamdeck_buttons.initial_buttons"
require "streamdeck_buttons.nonce"
require "streamdeck_buttons.buttons"

require "profile"
require "util"

local streamdeckLogger = hs.logger.new('streamdeck', 'debug')

-- Variables for tracking Streamdeck state
-- The current streamdeck (or `nil` if none is connected)
local currentDeck = nil
-- Whether or not the machine is asleep
local asleep = false

-- The currently visible button state
-- Keys:
-- - 'buttons' - the buttons
-- - 'name' - the name
-- - 'scrollOffset' - the scroll offset, which may wrap around, in rows
local currentButtonState = { }

-- The stack of button states behind this one
-- This is an array
local buttonStateStack = { }

-- Currently active update timers
local currentUpdateTimers = { }

-- Returns all the button states managed by the system
function allButtonStates()
    local allStates = cloneTable(buttonStateStack)
    table.insert(allStates, 1, currentButtonState)
    return allStates
end

-- Returns the currently visible buttons
function currentlyVisibleButtons()
    profileStart('streamDeckVisible')
    local providedButtons = (currentButtonState['buttons'] or { })

    local currentButtons = cloneTable(providedButtons)
    local effectiveScrollAmount = currentButtonState['scrollOffset'] or 0
    columns, rows = currentDeck:buttonLayout()
    if effectiveScrollAmount > 0 then
        for i = 1,effectiveScrollAmount,1 do
            -- Drop columns-1 buttons
            for j = 1,columns-1,1 do
                table.remove(currentButtons, 1)
            end
        end
    end

    local totalButtons = columns * rows

    -- If we have a pushed button state, then add a back button
    if tableLength(buttonStateStack) > 1 then
        local closeButton = {
            ['image'] = streamdeck_imageFromText('􀯶'),
            ['onClick'] = function()
                popButtonState()
            end
        }
        table.insert(currentButtons, 1, closeButton)
    end

    -- Pad with nonces
    while tableLength(currentButtons) < totalButtons do
        table.insert(currentButtons, nonceButton())
    end

    -- If we need to scroll, then insert buttons at the right indices
    -- This should be the far left, under the top left button
    if tableLength(providedButtons) > totalButtons then
        local scrollUp = {
            ['image'] = streamdeck_imageFromText('􀃾'),
            ['onClick'] = function()
                scrollBy(-1)
            end,
            ['onLongPress'] = function()
                scrollToTop()
            end
        }
        local scrollDown = {
            ['image'] = streamdeck_imageFromText('􀄀'),
            ['onClick'] = function()
                scrollBy(1)
            end
        }
        -- Add scroll up, scroll down, and a nonce to pad
        table.insert(currentButtons, columns + 1, scrollUp)
        table.insert(currentButtons, columns * 2 + 1, scrollDown)
        table.insert(currentButtons, columns * 3 + 1, nonceButton())
    end

    -- Remove until we're at the desired length
    while tableLength(currentButtons) > totalButtons do
        table.remove(currentButtons)
    end

    profileStop('streamDeckVisible')

    return currentButtons
end

local function contextForIndex(i)
    columns, rows = currentDeck:buttonLayout()

    local deckSize = {
        ['w'] = columns,
        ['h'] = rows,
    }
    local locationIndex = i - 1
    local location = {
        ['x'] = locationIndex % columns,
        ['y'] = math.floor(locationIndex / columns),
    }

    local context = {
        ['location'] = location,
        ['size'] = deckSize,
        ['isPressed'] = false,
    }

    return context
end

-- Updates the button at the StreamDeck index `i`.
local function updateStreamdeckButton(i, pressed)
    -- No StreamDeck? No update
    if currentDeck == nil then return end
    local button = currentlyVisibleButtons()[i]

    local context = contextForIndex(i)
    if pressed ~= nil then
        context['isPressed'] = pressed
    end

    updateButton(button, context)

    if button ~= nil then
        local image = button['_lastImage']
        if image ~= nil then
            currentDeck:setButtonImage(i, image)
        end
    end
end

-- Disables all timers for all buttons
local function disableTimers()
    for i, timer in pairs(currentUpdateTimers) do
        stopTimer(timer)
    end
    currentUpdateTimers = { }

    for i, state in pairs(allButtonStates()) do
        for index, button in pairs(state['buttons'] or {}) do
            stopTimer(button['_holdTimer'])
            button['_holdTimer'] = nil
        end
    end
end

-- Updates button update timers for all buttons
local function updateTimers()
    disableTimers()
    if asleep or currentDeck == nil then
        return
    end

    for index, button in pairs(currentlyVisibleButtons()) do
        local desiredUpdateInterval = button['updateInterval']
        if desiredUpdateInterval ~= nil then
            local timer = updateTimerForButton(button, function()
                updateStreamdeckButton(index)
            end)
            table.insert(currentUpdateTimers, timer)
        end
    end
end

-- Updates all buttons
local function updateStreamdeckButtons()
    -- No StreamDeck? No update
    if currentDeck == nil then return end

    profileStart('streamdeckButtonUpdate_all')
    columns, rows = currentDeck:buttonLayout()
    for i=1,columns*rows+1,1 do
        updateStreamdeckButton(i)
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
    updateStreamdeckButtons()
end

function streamdeck_updateButton(matching)
    if currentDeck == nil then return end
    for index, button in pairs(currentlyVisibleButtons()) do
        title = button['name']
        if title ~= nil then
            if string.match(title, matching) then
                updateStreamdeckButton(index)
            end
        end
    end
end

-- Pushes `newState` onto the stack of buttons
function pushButtonState(newState)
    -- Push current buttons back 
    buttonStateStack[#buttonStateStack+1] = currentButtonState
    -- Empty the buttons
    currentButtonState = { }
    -- Replace
    currentButtonState = newState
    -- Update
    updateStreamdeckButtons()
    updateTimers()
end

-- Pops back to the last button state
function popButtonState()
    -- Don't pop back past the first state
    if #buttonStateStack == 0 then
        return
    end

    -- Grab new state
    newState = buttonStateStack[#buttonStateStack]
    -- Remove from stack
    buttonStateStack[#buttonStateStack] = nil
    -- Empty the buttons
    currentButtonState = { }
    -- Replace
    currentButtonState = newState
    -- Update
    if currentDeck ~= nil then
        updateStreamdeckButtons()
        updateTimers()
    end
end

function scrollToTop()
    currentButtonState['scrollOffset'] = 0
    updateStreamdeckButtons()
end

function scrollBy(amount)
    local currentScrollAmount = currentButtonState['scrollOffset'] or 0
    currentScrollAmount = currentScrollAmount + amount
    currentScrollAmount = math.max(0, currentScrollAmount)
    currentButtonState['scrollOffset'] = currentScrollAmount
    updateStreamdeckButtons()
end

-- Returns a buttonState for pushing pushButton's children onto the stack
local function buttonStateForPushedButton(pushedButton)
    local children = pushedButton['children']
    if children == nil then return nil end

    columns, rows = currentDeck:buttonLayout()
    local deckSize = {
        ['w'] = columns,
        ['h'] = rows,
    }
    local context = {
        ['size'] = deckSize,
    }

    children = children(context)

    local outState = {
        ['name'] = pushedButton['name'],
        ['buttons'] = children
    }

    return outState
end

-- Button callback from hs.streamdeck
local function streamdeck_button(deck, buttonID, pressed)
    -- Don't allow commands while the machine is asleep / locked
    if asleep then
        return
    end

    -- Grab the button
    local buttonForID = currentlyVisibleButtons()[buttonID]
    if buttonForID == nil then
        updateStreamdeckButton(buttonID, pressed)
        return
    end

    local context = contextForIndex(buttonID)

    -- Grab its actions
    local click = buttonForID['onClick'] or function() end
    local hold = buttonForID['onLongPress'] or function() end

    -- Dispatch
    if pressed then
        updateStreamdeckButton(buttonID, true)
        buttonForID['_holdTimer'] = hs.timer.new(0.3, function()
            hold(true)
            buttonForID['_isHolding'] = true
            stopTimer(buttonForID['_holdTimer'])
        end)
        buttonForID['_holdTimer']:start()
    else
        updateStreamdeckButton(buttonID, false)
        if buttonForID['_isHolding'] ~= nil then
            hold(false)
        else
            click(context)

            local pushedState = buttonStateForPushedButton(buttonForID)
            if pushedState ~= nil then
                pushButtonState(pushedState)
            end
        end

        stopTimer(buttonForID['_holdTimer'])
        buttonForID['_isHolding'] = nil
    end
end

local function streamdeck_discovery(connected, deck)
    profileStart('streamdeckDiscovery')
    if connected then
        currentDeck = deck
        deck:buttonCallback(streamdeck_button)
        deck:reset()

        updateStreamdeckButtons()
        updateTimers()

        buttonStateStack = { }
        pushButtonState(initialButtonState)
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
