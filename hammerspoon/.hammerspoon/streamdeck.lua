require "streamdeck_buttons.button_images"
require "streamdeck_buttons.initial_buttons"
require "streamdeck_buttons.nonce"

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

-- Updates the button at the StreamDeck index `i`.
local function updateButton(i, pressed)
    -- No StreamDeck? No update
    if currentDeck == nil then return end

    profileStart('streamdeckButtonUpdate_' .. i)

    local button = currentlyVisibleButtons()[i]
    if button ~= nil then
        local isStatic = button['image'] ~= nil
        local currentState = {}
        if isStatic then
            currentDeck:setButtonImage(i, button['image'])
        else
            local isDirty = false
            local stateProvider = button['stateProvider']
            if stateProvider == nil then
                isDirty = true
            else
                currentState = stateProvider() or { }
                local lastState = button['_lastState'] or { }
                isDirty = not equals(currentState, lastState, false)
                button['_lastState']  = currentState
            end
            if isDirty then
                local context = {
                    ['isPressed'] = pressed,
                    ['state'] = currentState
                }
                local image = button['imageProvider'](context)
                button['_lastImage'] = image
            end
            local image = button['_lastImage']
            if image ~= nil then
                currentDeck:setButtonImage(i, image)
            end
        end
    end

    profileStop('streamdeckButtonUpdate_' .. i)
end

local function stopTimer(timer)
    if timer ~= nil then
        timer:stop()
    end
end

-- Disables all timers for all buttons
local function disableTimers()
    for i, state in pairs(allButtonStates()) do
        for index, button in pairs(state['buttons'] or {}) do
            stopTimer(button['_timer'])
            stopTimer(button['_holdTimer'])
            button['_timer'] = nil
            button['_holdTimer'] = nil
        end
    end
end

-- Updates all timers for all buttons
local function updateTimers()
    disableTimers()
    if asleep or currentDeck == nil then
        return
    end

    for index, button in pairs(currentlyVisibleButtons()) do
        local desiredUpdateInterval = button['updateInterval']
        if desiredUpdateInterval ~= nil then
            local timer = hs.timer.new(desiredUpdateInterval, function()
                updateButton(index)
            end)
            timer:start()
            button['_timer'] = timer
        end
    end
end

-- Updates all buttons
local function updateButtons()
    -- No StreamDeck? No update
    if currentDeck == nil then return end

    profileStart('streamdeckButtonUpdate_all')
    columns, rows = currentDeck:buttonLayout()
    for i=1,columns*rows+1,1 do
        updateButton(i)
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
    if currentDeck == nil then return end
    for index, button in pairs(currentlyVisibleButtons()) do
        title = button['name']
        if title ~= nil then
            if string.match(title, matching) then
                updateButton(index)
            end
        end
    end
end

-- Pushes `newState` onto the stack of buttons
function pushButtonState(newState)
    -- Push current buttons back 
    buttonStateStack[#buttonStateStack+1] = currentButtonState
    -- Empty the buttons and update
    updateTimers()
    currentButtonState = { }
    updateButtons()
    -- Replace
    currentButtonState = newState
    -- Update
    updateButtons()
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
    -- Empty the buttons and update
    updateTimers()
    currentButtonState = { }
    updateButtons()
    -- Replace
    currentButtonState = newState
    -- Update
    if currentDeck ~= nil then
        updateButtons()
        updateTimers()
    end
end

function scrollBy(amount)
    local currentScrollAmount = currentButtonState['scrollOffset'] or 0
    currentScrollAmount = currentScrollAmount + amount
    currentScrollAmount = math.max(0, currentScrollAmount)
    currentButtonState['scrollOffset'] = currentScrollAmount
    updateButtons()
end

-- Returns a buttonState for pushing pushButton's children onto the stack
local function buttonStateForPushedButton(pushedButton)
    local children = pushedButton['children']
    if children == nil then return nil end
    children = children()

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
        updateButton(buttonID, pressed)
        return
    end

    -- Grab its actions
    local click = buttonForID['onClick'] or function() end
    local hold = buttonForID['onLongPress'] or function() end

    -- Dispatch
    if pressed then
        updateButton(buttonID, true)
        buttonForID['_holdTimer'] = hs.timer.new(0.3, function()
            hold(true)
            buttonForID['_isHolding'] = true
            stopTimer(buttonForID['_holdTimer'])
        end)
        buttonForID['_holdTimer']:start()
    else
        updateButton(buttonID, false)
        if buttonForID['_isHolding'] ~= nil then
            hold(false)
        else
            click()

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

        updateButtons()
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
