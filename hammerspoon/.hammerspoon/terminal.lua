local function findYabaiPath()
    local candidates = {}
    local result = hs.execute("command -v yabai 2>/dev/null", true)
    if result ~= nil then
        result = result:gsub("%s+$", "")
        if result ~= "" then
            table.insert(candidates, result)
        end
    end

    table.insert(candidates, "/opt/homebrew/bin/yabai")
    table.insert(candidates, "/usr/local/bin/yabai")

    for _, path in ipairs(candidates) do
        if hs.fs.attributes(path, "mode") ~= nil then
            return path
        end
    end

    return nil
end

local function windowIsFloating(yabaiPath, windowId)
    local ok, output = pcall(hs.execute, string.format("%s -m query --windows --window %s 2>/dev/null", yabaiPath, tostring(windowId)), true)
    if not ok or output == nil or output == "" then
        return nil
    end

    local decoded = hs.json.decode(output)
    if decoded == nil then
        return nil
    end

    return decoded["is-floating"]
end

local function toggleFloat(yabaiPath, windowId)
    pcall(hs.execute, string.format("%s -m window %s --toggle float 2>/dev/null", yabaiPath, tostring(windowId)), true)
end

local function floatAndCenterWindow(win, options)
    if win == nil then
        return
    end
    if next(options) == nil then
        return
    end
    local app = win:application()
    if app == nil or app:bundleID() ~= "com.mitchellh.ghostty" then
        return
    end

    local size = options["size"] or {w = 960, h = 540}
    local screenFrame = win:screen():frame()
    local targetFrame = {
        w = size["w"] or 960,
        h = size["h"] or 540,
    }
    local position = options["position"] or "center"
    if position == "top-right" then
        local margin = 12
        targetFrame.x = screenFrame.x + screenFrame.w - targetFrame.w - margin
        targetFrame.y = screenFrame.y + margin
    else
        targetFrame.x = screenFrame.x + (screenFrame.w - targetFrame.w) / 2
        targetFrame.y = screenFrame.y + (screenFrame.h - targetFrame.h) / 2
    end

    local function applyFrame()
        win:setFrame(targetFrame, 0)
    end

    if options["float"] == true then
        local yabaiPath = findYabaiPath()
        local windowId = win:id()
        if yabaiPath and windowId then
            local floating = windowIsFloating(yabaiPath, windowId)
            if floating == false then
                toggleFloat(yabaiPath, windowId)
                hs.timer.doAfter(0.05, applyFrame)
                return
            end
        end
    end
    applyFrame()
end

function runInNewTerminal(command, exitAfterwards, options)
    local opts = options or {}
    local effectiveCommand = command
    if exitAfterwards == true then
        effectiveCommand = command .. " && exit"
    end

    hs.application.open("com.mitchellh.ghostty")
    hs.eventtap.keyStroke({"cmd"}, "n")
    hs.eventtap.keyStrokes(effectiveCommand)
    hs.eventtap.keyStroke({}, "return")

    -- Give the new terminal a moment to appear, then float and size it if requested.
    hs.timer.doAfter(0.1, function()
        local win = hs.window.frontmostWindow()
        floatAndCenterWindow(win, opts)
    end)
end
