function bool_to_number(value)
  return value and 1 or 0
end

local currentDeck = nil
local asleep = false
local cameraButtonUpdateTimer = nil

function fixupCameraButtonUpdateTimer()
    if asleep or currentDeck == nil then
        cameraButtonUpdateTimer:stop()
    else
        cameraButtonUpdateTimer:start()
    end
end

function streamdeck_sleep()
    asleep = true
    fixupCameraButtonUpdateTimer()
    if currentDeck == nil then return end
    currentDeck:setBrightness(0)
end

function streamdeck_wake()
    asleep = false
    fixupCameraButtonUpdateTimer()
    if currentDeck == nil then return end
    currentDeck:setBrightness(30)
end

cameraButtonUpdateTimer = hs.timer.new(3, function()
    if currentDeck == nil then return end
    currentDeck:setButtonImage(30, hs.image.imageFromURL("http://192.168.0.167/cgi-bin/currentpic.cgi"))
    currentDeck:setButtonImage(31, hs.image.imageFromURL("http://192.168.0.196/cgi-bin/currentpic.cgi"))
end)

local function streamdeck_run_in_terminal(command)
    hs.application.open("com.apple.Terminal")
    hs.eventtap.keyStroke({"cmd"}, "n")
    hs.eventtap.keyStrokes(command)
    hs.eventtap.keyStroke({}, "return")
end

local function streamdeck_button(deck, buttonID, pressed)
    if buttonID == 14 then
        if pressed then
            hs.application.open("com.apple.iCal")
        else
            local app = hs.application'com.apple.iCal'
            if app ~= nil then
                app:hide()
            end
        end
    end
    if buttonID == 15 then
        if pressed then
            hs.application.open("com.reederapp.macOS")
        else
            local app = hs.application'com.reederapp.macOS'
            if app ~= nil then
                app:hide()
            end
        end
    end
    -- Only activate on button-down
    if not pressed then
        return
    end
    -- Don't allow commands while the machine is asleep / locked
    if asleep then
        return
    end

    if buttonID == 1 then
        hs.urlevent.openURL("https://pinboard.in/add/")
        hs.eventtap.keyStroke({"cmd"}, "v")
    end
    if buttonID == 2 then
        -- Grab pasteboard
        local pasteboard = hs.pasteboard.readString()
        local command = "ytd \""..pasteboard.."\""
        streamdeck_run_in_terminal(command)
    end
    if buttonID == 23 then
        hs.caffeinate.lockScreen()
    end
    if buttonID == 30 then
        hs.execute('camera1', true)
    end
    if buttonID == 31 then
        hs.execute('camera2', true)
    end
end

-- Returns an image with the specified text, color, and background color
local function streamdeck_imageFromText(text, textColor, backgroundColor)
    local imageCanvas = hs.canvas.new{ w = 100, h = 100 }
    textColor = textColor or hs.drawing.color.white
    backgroundColor = backgroundColor or hs.drawing.color.black

    imageCanvas[1] = {
        action = "fill",
        frame = { x = 0, y = 0, w = 100, h = 100 },
        fillColor = backgroundColor,
        type = "rectangle",
    }
    imageCanvas[2] = {
        frame = { x = 0, y = 0, w = 100, h = 100 },
        text = hs.styledtext.new(text, {
            font = { name = ".AppleSystemUIFont", size = 70 },
            paragraphStyle = { alignment = "center" },
            color = textColor,
        }),
        type = "text",
    }
    return imageCanvas:imageFromCanvas()
end

local function streamdeck_updateWeatherButton(index, deck)
    local output, status, t, rc = hs.execute('curl -s "wttr.in?format=1" | sed "s/+//" | sed "s/°F//" | grep -v "Unknow"')
    hs.alert(output)
    deck:setButtonImage(index, streamdeck_imageFromText(output))
end

local function streamdeck_discovery(connected, deck)
    if connected then
        currentDeck = deck
        fixupCameraButtonUpdateTimer()
        local waiting = streamdeck_imageFromText("􀍠")

        deck:buttonCallback(streamdeck_button)

        print(deck:buttonLayout())
        for i=1,32 do
            deck:setButtonImage(i, waiting)
        end
        deck:setButtonImage(1, streamdeck_imageFromText("􀎧", nil, hs.drawing.color.blue))
        deck:setButtonImage(2, streamdeck_imageFromText("􀊚", hs.drawing.color.red, hs.drawing.color.white))
        streamdeck_updateWeatherButton(3, deck)
        deck:setButtonImage(9, hs.image.imageFromAppBundle("com.apple.Mail"))
        deck:setButtonImage(10, hs.image.imageFromAppBundle("com.apple.Safari"))
        deck:setButtonImage(11, hs.image.imageFromAppBundle("com.apple.Terminal"))
        deck:setButtonImage(12, hs.image.imageFromAppBundle("com.apple.Notes"))
        deck:setButtonImage(13, hs.image.imageFromAppBundle("com.apple.Reminders"))
        deck:setButtonImage(14, hs.image.imageFromAppBundle("com.apple.iCal"))
        deck:setButtonImage(15, streamdeck_imageFromText("􀖆"))
        deck:setButtonImage(23, streamdeck_imageFromText("􀎡"))
    else
        currentDeck = nil
        fixupCameraButtonUpdateTimer()
    end
    if asleep then
        streamdeck_sleep()
    else
        streamdeck_wake()
    end
end

hs.streamdeck.init(streamdeck_discovery)
