require 'hyper'

-- Window Manipulation

-- Hints

local hints = hs.hints
hints.hintChars = {'a','s','d','f','j','k','l',';','g','h'}
hints.fontSize = 100

hs.hotkey.bind(hyper, "space", function()
    hints.windowHints()
end)

local windowPadding = 15

function adjustForegroundWindowToUnitSize (x,y,w,h)
    local win = hs.window.focusedWindow()
    local windowScreen = win:screen()
    local screenFrame = windowScreen:frame()
    local frame = win:frame()

    frame.x = screenFrame.x + screenFrame.w * x
    frame.y = screenFrame.y + screenFrame.h * y
    frame.w = screenFrame.w * w
    frame.h = screenFrame.h * h

    frame.x = frame.x + windowPadding
    frame.y = frame.y + windowPadding
    frame.w = frame.w - (2 * windowPadding)
    frame.h = frame.h - (2 * windowPadding)

    win:setFrame(frame, 0)
end

-- 50% manipulation

-- Bind hyper-H to move window to the left half of its current screen
hs.hotkey.bind(hyper, "h", function()
    adjustForegroundWindowToUnitSize(0,0,0.5,1)
end)

-- Bind hyper-L to move window to the right half of its current screen

hs.hotkey.bind(hyper, "l", function()
    adjustForegroundWindowToUnitSize(0.5,0.0,0.5,1)
end)

-- Bind hyper-K to move window to the top half of its current screen

hs.hotkey.bind(hyper, "k", function()
    adjustForegroundWindowToUnitSize(0,0,1,0.5)
end)

-- Bind hyper-J to move window to the bottom half of its current screen

hs.hotkey.bind(hyper, "j", function()
    adjustForegroundWindowToUnitSize(0,0.5,1,0.5)
end)

-- Bind hyper-: to move 75% sized window to the center

hs.hotkey.bind(hyper, ";", function()
    adjustForegroundWindowToUnitSize(0.125,0.125,0.75,0.7)
end)

-- 70% manipulation

-- Bind hyper-Y to move window to the left 70% of its current screen

hs.hotkey.bind(hyper, "Y", function()
    adjustForegroundWindowToUnitSize(0,0,0.7,1)
end)

-- Bind hyper-O to move window to the right 70% of its current screen

hs.hotkey.bind(hyper, "O", function()
    adjustForegroundWindowToUnitSize(0.3,0.0,0.7,1)
end)

-- Bind hyper-I to move window to the top 70% of its current screen

hs.hotkey.bind(hyper, "I", function()
    adjustForegroundWindowToUnitSize(0,0,1,0.7)
end)

-- Bind hyper-U to move window to the bottom 70% of its current screen

hs.hotkey.bind(hyper, "U", function()
    adjustForegroundWindowToUnitSize(0,0.3,1,0.7)
end)

-- Bind hyper-P to move 100% sized window to the center

hs.hotkey.bind(hyper, "P", function()
    adjustForegroundWindowToUnitSize(0,0,1,1)
end)

-- 30% manipulation

-- Bind hyper-N to move window to the left 30% of its current screen

hs.hotkey.bind(hyper, "N", function()
    adjustForegroundWindowToUnitSize(0,0,0.3,1)
end)

-- Bind hyper-. to move window to the right 30% of its current screen

hs.hotkey.bind(hyper, ".", function()
    adjustForegroundWindowToUnitSize(0.7,0.0,0.3,1)
end)

-- Bind hyper-, to move window to the top 30% of its current screen

hs.hotkey.bind(hyper, ",", function()
    adjustForegroundWindowToUnitSize(0,0,1,0.3)
end)

-- Bind hyper-M to move window to the bottom 30% of its current screen

hs.hotkey.bind(hyper, "M", function()
    adjustForegroundWindowToUnitSize(0,0.7,1,0.3)
end)

-- Bind hyper-/ to move 50% sized window to the center

hs.hotkey.bind(hyper, "/", function()
    adjustForegroundWindowToUnitSize(0.25,0.25,.5,.5)
end)

-- Bind hyper-T to move window to the "next" screen

hs.hotkey.bind(hyper, "T", function()
    local win = hs.window.focusedWindow()
    local windowScreen = win:screen()
    
    local newWindowScreen = windowScreen:next()
    win:moveToScreen(newWindowScreen)
end)

