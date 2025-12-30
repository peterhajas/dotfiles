-- Import base sub-modules first (these don't depend on button modules)
local button_images = require("streamdeck.button_images")
local buttons_module = require("streamdeck.buttons")

require "profile"
require "util"

-- Module table
local M = {}

-- Re-export utilities as module properties (dot notation - stateless)
M.imageFromText = button_images.imageFromText
M.imageWithCanvasContents = button_images.imageWithCanvasContents
M.buttonWidth = button_images.buttonWidth
M.buttonHeight = button_images.buttonHeight

-- Backward compatibility shim for button modules
-- IMPORTANT: Set this up BEFORE requiring button modules!
_G.streamdeck_imageFromText = M.imageFromText
_G.streamdeck_imageWithCanvasContents = M.imageWithCanvasContents
_G.buttonWidth = M.buttonWidth
_G.buttonHeight = M.buttonHeight

-- Now import button modules (which need the globals above)
local nonce_module = require("streamdeck.nonce")
local initial_buttons = require("streamdeck.initial_buttons")

-- Local aliases for internal use
local imageFromText = M.imageFromText
local imageWithCanvasContents = M.imageWithCanvasContents
local updateButton = buttons_module.updateButton
local updateTimerForButton = buttons_module.updateTimerForButton
local nonceButton = nonce_module.nonceButton
local initialButtonState = initial_buttons.initialButtonState

local streamdeckLogger = hs.logger.new('streamdeck', 'debug')

-- Private state (closure-based encapsulation)
local streamdeckState = {
    currentDeck = nil,
    asleep = false,
    currentButtonState = {},
    buttonStateStack = {},
    currentUpdateTimers = {},
}

-- Returns all the button states managed by the system
local function allButtonStates()
    local allStates = cloneTable(streamdeckState.buttonStateStack)
    table.insert(allStates, 1, streamdeckState.currentButtonState)
    return allStates
end

-- Returns the currently visible buttons
local function currentlyVisibleButtons()
    profileStart('streamDeckVisible')
    local providedButtons = (streamdeckState.currentButtonState['buttons'] or { })

    local currentButtons = cloneTable(providedButtons)
    local effectiveScrollAmount = streamdeckState.currentButtonState['scrollOffset'] or 0
    columns, rows = streamdeckState.currentDeck:buttonLayout()
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
    if tableLength(streamdeckState.buttonStateStack) > 1 then
        local closeButton = {
            ['image'] = imageFromText('􀯶'),
            ['onClick'] = function()
                M:popButtonState()
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
            ['image'] = imageFromText('􀃾'),
            ['onClick'] = function()
                scrollBy(-1)
            end,
            ['onLongPress'] = function()
                scrollToTop()
            end
        }
        local scrollDown = {
            ['image'] = imageFromText('􀄀'),
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
    columns, rows = streamdeckState.currentDeck:buttonLayout()

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
    if streamdeckState.currentDeck == nil then return end
    local button = currentlyVisibleButtons()[i]

    local context = contextForIndex(i)
    if pressed ~= nil then
        context['isPressed'] = pressed
    end

    updateButton(button, context)

    if button ~= nil then
        local image = button['_lastImage']
        if image ~= nil then
            streamdeckState.currentDeck:setButtonImage(i, image)
        end
    end
end

-- Disables all timers for all buttons
local function disableTimers()
    for i, timer in pairs(streamdeckState.currentUpdateTimers) do
        stopTimer(timer)
    end
    streamdeckState.currentUpdateTimers = { }

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
    if streamdeckState.asleep or streamdeckState.currentDeck == nil then
        return
    end

    for index, button in pairs(currentlyVisibleButtons()) do
        local desiredUpdateInterval = button['updateInterval']
        if desiredUpdateInterval ~= nil then
            local timer = updateTimerForButton(button, function()
                updateStreamdeckButton(index)
            end)
            table.insert(streamdeckState.currentUpdateTimers, timer)
        end
    end
end

-- Updates all buttons
local function updateStreamdeckButtons()
    -- No StreamDeck? No update
    if streamdeckState.currentDeck == nil then return end

    profileStart('streamdeckButtonUpdate_all')
    columns, rows = streamdeckState.currentDeck:buttonLayout()
    for i=1,columns*rows+1,1 do
        updateStreamdeckButton(i)
    end
    profileStop('streamdeckButtonUpdate_all')
end

function scrollToTop()
    streamdeckState.currentButtonState['scrollOffset'] = 0
    updateStreamdeckButtons()
end

function scrollBy(amount)
    local currentScrollAmount = streamdeckState.currentButtonState['scrollOffset'] or 0
    currentScrollAmount = currentScrollAmount + amount
    currentScrollAmount = math.max(0, currentScrollAmount)
    streamdeckState.currentButtonState['scrollOffset'] = currentScrollAmount
    updateStreamdeckButtons()
end

-- Returns a buttonState for pushing pushButton's children onto the stack
local function buttonStateForPushedButton(pushedButton)
    local children = pushedButton['children']
    if children == nil then return nil end

    columns, rows = streamdeckState.currentDeck:buttonLayout()
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
    if streamdeckState.asleep then
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
                M:pushButtonState(pushedState)
            end
        end

        stopTimer(buttonForID['_holdTimer'])
        buttonForID['_isHolding'] = nil
    end
end

local function streamdeck_discovery(connected, deck)
    profileStart('streamdeckDiscovery')
    if connected then
        streamdeckState.currentDeck = deck
        deck:buttonCallback(streamdeck_button)
        deck:reset()

        updateStreamdeckButtons()
        updateTimers()

        streamdeckState.buttonStateStack = { }
        M:pushButtonState(initialButtonState)
    else
        streamdeckState.currentDeck = nil
        updateTimers()
    end
    if streamdeckState.asleep then
        M:sleep()
    else
        M:wake()
    end
    profileStop('streamdeckDiscovery')
end

-- Public API methods
function M:init()
    hs.streamdeck.init(streamdeck_discovery)
end

function M:sleep()
    streamdeckState.asleep = true
    updateTimers()
    if streamdeckState.currentDeck == nil then return end
    streamdeckState.currentDeck:setBrightness(0)
end

function M:wake()
    streamdeckState.asleep = false
    updateTimers()
    if streamdeckState.currentDeck == nil then return end
    streamdeckState.currentDeck:setBrightness(30)
    updateStreamdeckButtons()
end

function M:updateButton(matching)
    if streamdeckState.currentDeck == nil then return end
    for index, button in pairs(currentlyVisibleButtons()) do
        local title = button['name']
        if title ~= nil then
            if string.match(title, matching) then
                updateStreamdeckButton(index)
            end
        end
    end
end

-- Pushes `newState` onto the stack of buttons
function M:pushButtonState(newState)
    -- Push current buttons back
    streamdeckState.buttonStateStack[#streamdeckState.buttonStateStack+1] = streamdeckState.currentButtonState
    -- Empty the buttons
    streamdeckState.currentButtonState = { }
    -- Replace
    streamdeckState.currentButtonState = newState
    -- Update
    updateStreamdeckButtons()
    updateTimers()
end

-- Pops back to the last button state
function M:popButtonState()
    -- Don't pop back past the first state
    if #streamdeckState.buttonStateStack == 0 then
        return
    end

    -- Grab new state
    local newState = streamdeckState.buttonStateStack[#streamdeckState.buttonStateStack]
    -- Remove from stack
    streamdeckState.buttonStateStack[#streamdeckState.buttonStateStack] = nil
    -- Empty the buttons
    streamdeckState.currentButtonState = { }
    -- Replace
    streamdeckState.currentButtonState = newState
    -- Update
    if streamdeckState.currentDeck ~= nil then
        updateStreamdeckButtons()
        updateTimers()
    end
end

-- Backward compatibility shim for runtime functions (used in button onClick handlers)
_G.pushButtonState = function(...) return M:pushButtonState(...) end
_G.popButtonState = function(...) return M:popButtonState(...) end

return M
