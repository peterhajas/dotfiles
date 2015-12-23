require "preferred_screen"

local color = hs.drawing.color
local crayons = color.lists()['Crayons']

allStatusItems = {
                  {'sh ~/bin/status/frontmost_window.sh', 'left', crayons['Bubblegum']},
                  {'sh ~/bin/status/music.sh', 'center', crayons['Honeydew']},
                  {'sh ~/bin/status/cpu.sh', 'right', crayons['Moss']},
                  {'sh ~/bin/status/memory.sh', 'right', crayons['Nickel']},
                  {'sh ~/bin/status/battery.sh', 'right', crayons['Banana']},
                  {'sh ~/bin/status/date.sh', 'right', crayons['Strawberry']},
                  {'sh ~/bin/status/time.sh', 'right', crayons['Ice']}
                 }

leftStatusItemText = nil
centerStatusItemText = nil
rightStatusItemText = nil
statusBarBackground = nil

function statusItemFont()
    local font = {}
    font['name'] = 'Menlo'
    font['size'] = 14
    return font
end

function styleForStatusItem(statusItem)
    local side = statusItem[2]
    local color = statusItem[3]

    local paragraphStyle = { }
    paragraphStyle['alignment'] = side

    local style = { }
    style['color'] = color
    style['paragraphStyle'] = paragraphStyle
    style['font'] = statusItemFont()

    return style
end

function statusItemString(statusItem)
    local script = statusItem[1]

    scriptText = hs.execute(script)
    style = styleForStatusItem(statusItem)

    text = hs.styledtext.new(scriptText, style)

    return text
end

function statusBarRect()
    local screenFrame = preferredScreenFrame()
    local x = screenFrame.x
    local y = screenFrame.y
    local w = screenFrame.w
    local h = 23
    return hs.geometry.rect(x,y,w,h)
end

function allStatusTextWithTextAppended(statusText, text, item)
    local newStatusText = statusText
    local space = hs.styledtext.new(' ', styleForStatusItem(item))
    newStatusText = newStatusText..space

    newStatusText = newStatusText..text
    return newStatusText
end

function applyStatusBehaviorsToDrawingObject(drawingObject)
    drawingObject:setBehavior(9)
end

function newStatusTextObject()
    local textObject = hs.drawing.text(statusBarRect(), '')
    textObject:show()
    textObject:sendToBack();
    applyStatusBehaviorsToDrawingObject(textObject)

    return textObject
end

function newStatusBarBackground()
    local background = hs.drawing.rectangle(statusBarRect())
    background:setFillColor(crayons['Tungsten'])
    background:show()
    background:sendToBack();
    applyStatusBehaviorsToDrawingObject(background)

    return background
end

function updateStatusItems()
    local leftItems = hs.styledtext.new('')
    local centerItems = hs.styledtext.new('')
    local rightItems = hs.styledtext.new('')

    local numberOfItems = #allStatusItems
    for i = 1,numberOfItems do
        local item = allStatusItems[i]
        local itemText = statusItemString(item)

        if item[2] == 'left' then  leftItems = allStatusTextWithTextAppended(leftItems, itemText, item) end
        if item[2] == 'center' then  centerItems = allStatusTextWithTextAppended(centerItems, itemText, item) end
        if item[2] == 'right' then  rightItems = allStatusTextWithTextAppended(rightItems, itemText, item) end
    end

    leftStatusItemText:setStyledText(leftItems)
    centerStatusItemText:setStyledText(centerItems)
    rightStatusItemText:setStyledText(rightItems)
end

function buildStatusItems()
    if leftStatusItemText ~= nil then
        leftStatusItemText:delete()
        centerStatusItemText:delete()
        rightStatusItemText:delete()
        statusBarBackground:delete()
    end

    statusBarBackground = newStatusBarBackground()
    leftStatusItemText = newStatusTextObject()
    centerStatusItemText = newStatusTextObject()
    rightStatusItemText = newStatusTextObject()

    updateStatusItems()
end

function statusTimerUpdate()
    updateStatusItems()
end

statusTimer = hs.timer.new(5, statusTimerUpdate)
statusTimer:start()

buildStatusItems()

