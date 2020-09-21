function bool_to_number(value)
  return value and 1 or 0
end

local currentDeck = nil
local asleep = false
local buttonUpdateTimer = nil
local buttonUpdateInterval = 10
local buttonWidth = 96
local buttonHeight = 96

function fixupButtonUpdateTimer()
    if asleep or currentDeck == nil then
        buttonUpdateTimer:stop()
    else
        buttonUpdateTimer:start()
    end
end

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
end

-- Returns an image with the specified text, color, and background color
local function streamdeck_imageFromText(text, options)
    local imageCanvas = hs.canvas.new{ w = buttonWidth, h = buttonHeight }
    local options = options or { }
    textColor = options["textColor"] or hs.drawing.color.white
    backgroundColor = options["backgroundColor"] or hs.drawing.color.black
    fontSize = options["fontSize"] or 70

    imageCanvas[1] = {
        action = "fill",
        frame = { x = 0, y = 0, w = buttonWidth, h = buttonHeight },
        fillColor = backgroundColor,
        type = "rectangle",
    }
    imageCanvas[2] = {
        frame = { x = 0, y = 0, w = buttonWidth, h = buttonHeight },
        text = hs.styledtext.new(text, {
            font = { name = ".AppleSystemUIFont", size = fontSize },
            paragraphStyle = { alignment = "center" },
            color = textColor,
        }),
        type = "text",
    }
    return imageCanvas:imageFromCanvas()
end

-- Button Definitions
-- Buttons are defined as tables, with three functions:
-- "image": the function returning the image
-- "pressDown": the function to perform on press down
-- "pressUp": the function to perform on press up

local nonceButton = {}

local function peekButtonFor(bundleID)
    return {
        ["image"] = function (pressed)
            return hs.image.imageFromAppBundle(bundleID)
        end,
        ["pressDown"] = function()
            hs.application.open(bundleID)
        end,
        ["pressUp"] = function()
            local app = hs.application.get(bundleID)
            if app ~= nil then
                app:hide()
            end
        end
    }
end

local function urlButton(url, imageProvider, performAfter)
    return {
        ["image"] = imageProvider, 
        ["pressUp"] = function()
            hs.urlevent.openURL(url)
            performAfter = performAfter or function() end
            hs.timer.doAfter(0.2, function()
                performAfter()
            end)
        end
    }
end

local function terminalButton(commandProvider, imageProvider, performAfter)
    return {
        ["image"] = imageProvider,
        ["pressUp"] = function()
            local command = commandProvider()
            if command == nil then
                return
            end

            hs.application.open("com.apple.Terminal")
            hs.eventtap.keyStroke({"cmd"}, "n")
            hs.eventtap.keyStrokes(command)
            hs.eventtap.keyStroke({}, "return")

            performAfter = performAfter or function() end
            hs.timer.doAfter(0.1, function()
                performAfter()
            end)
        end
    }
end

local weatherButton = urlButton('https://wttr.in', function()
    local output, status, t, rc = hs.execute('curl -s "wttr.in?format=1" | sed "s/+//" | sed "s/F//" | grep -v "Unknow"')
    return streamdeck_imageFromText(output, {['fontSize'] = 40 })
end)

local cpuButton = terminalButton(function() return 'htop' end,
function()
    local output, status, t, rc = hs.execute('cpu.10s.sh', true)
    return streamdeck_imageFromText(output, {['fontSize'] = 40 })
end, function()
    hs.eventtap.keyStrokes("P")
end)

local memoryButton = terminalButton(function() return 'htop' end,
function()
    local output, status, t, rc = hs.execute('memory.10s.sh', true)
    return streamdeck_imageFromText(output, {['fontSize'] = 40 })
end, function()
    hs.eventtap.keyStrokes("M")
end)

local pinboardButton = urlButton('https://pinboard.in/add/', function()
    return streamdeck_imageFromText('􀎧', {['backgroundColor'] = hs.drawing.color.blue})
end,
function()
    hs.eventtap.keyStroke({"cmd"}, "v")
end)

local youtubeDLButton = terminalButton(function()
    -- Grab pasteboard
    local pasteboard = hs.pasteboard.readString()
    if string.find(pasteboard, 'http') then
        local command = "ytd \""..pasteboard.."\""
        return command
    end
    return nil
end, function()
    return streamdeck_imageFromText('􀊚"', {['backgroundColor'] = hs.drawing.color.white, ['textColor'] = hs.drawing.color.red})
end, function()
    hs.eventtap.keyStroke({"ctrl"}, "d")
end)

local lockButton = {
    ['image'] = function()
        return streamdeck_imageFromText('􀎡')
    end,
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
    peekButtonFor('com.reederapp.macOS'),
    lockButton,
}

local function updateButton(i, pressed)
    if currentDeck == nil then return end
    local button = buttons[i]
    local image = button["image"](pressed)
    if image ~= nil then
        currentDeck:setButtonImage(i, image)
    end
end

local function updateButtons()
    for index, button in pairs(buttons) do
        updateButton(index, false)
    end
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
    local pressDown = buttonForID["pressDown"] or function() end
    local pressUp = buttonForID["pressUp"] or function() end

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
end

hs.streamdeck.init(streamdeck_discovery)
