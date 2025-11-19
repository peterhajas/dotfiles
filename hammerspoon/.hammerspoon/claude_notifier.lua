-- claude_notifier.lua
-- Visual overlay indicator for when Claude is waiting for input

local M = {}

-- Configuration
M.config = {
    enabled = true,
    waitingColor = {red = 1.0, green = 0, blue = 0, alpha = 0.3},      -- Red = waiting for input
    processingColor = {red = 0, green = 1.0, blue = 0, alpha = 0.3},   -- Green = processing
    terminalApp = "Ghostty",
    borderWidth = 0,  -- 0 = filled overlay, >0 = border only
    hideWhenFocused = true,  -- Hide overlays when terminal window is focused
    debugMode = true  -- Start with debug mode on
}

-- State
local state = {
    claudeState = "unknown",   -- "waiting" or "processing"
    overlay = nil,             -- hs.canvas overlay
    windowWatcher = nil,       -- hs.window.filter watcher
    appWatcher = nil,          -- hs.application.watcher
    currentWindow = nil,       -- hs.window for terminal
    isFocused = false,
    claudePaneId = nil         -- ID of the pane (for future use)
}

-- Debug logging
local function log(message)
    if M.config.debugMode then
        print("[claude_notifier] " .. message)
    end
end

-- Public API functions called by hooks

function M.onClaudeReady(paneId)
    log("onClaudeReady() called - Claude is waiting for input")
    if paneId and paneId ~= "" then
        state.claudePaneId = paneId
        log("Pane ID: " .. paneId)
    end

    -- Store the currently focused terminal window as the Claude window
    local app = hs.application.get(M.config.terminalApp)
    if app then
        state.currentWindow = app:focusedWindow()
        if state.currentWindow then
            log("Stored Claude window ID: " .. state.currentWindow:id())
        end
    end

    state.claudeState = "waiting"
    M.updateOverlay()
end

function M.onClaudeProcessing(paneId)
    log("onClaudeProcessing() called - Claude is processing")
    if paneId and paneId ~= "" then
        state.claudePaneId = paneId
        log("Pane ID: " .. paneId)
    end

    -- Store the currently focused terminal window as the Claude window
    local app = hs.application.get(M.config.terminalApp)
    if app then
        state.currentWindow = app:focusedWindow()
        if state.currentWindow then
            log("Stored Claude window ID: " .. state.currentWindow:id())
        end
    end

    state.claudeState = "processing"
    M.updateOverlay()
end

-- Core overlay management

function M.updateOverlay()
    log("updateOverlay() called, state=" .. state.claudeState)

    -- Check if terminal window is focused
    if M.config.hideWhenFocused then
        local claudeWindow = M.getTerminalWindow()
        if claudeWindow then
            local focusedWindow = hs.window.focusedWindow()
            if focusedWindow and claudeWindow:id() == focusedWindow:id() then
                log("Claude's terminal window is focused, hiding overlay")
                M.hideOverlay()
                return
            end
        end
    end

    -- Get pane bounds
    local bounds = M.getPaneBounds()
    if not bounds then
        log("No pane bounds available, hiding overlay")
        M.hideOverlay()
        return
    end

    -- Show overlay with appropriate color
    if state.claudeState == "waiting" or state.claudeState == "processing" then
        M.showOverlay(bounds, state.claudeState)
    else
        M.hideOverlay()
    end
end

function M.showOverlay(bounds, claudeState)
    -- Delete old overlay if it exists
    if state.overlay then
        state.overlay:delete()
        state.overlay = nil
    end

    log(string.format("showOverlay called with bounds: x=%.0f, y=%.0f, w=%.0f, h=%.0f, state=%s",
        bounds.x, bounds.y, bounds.w, bounds.h, claudeState))

    -- Choose color based on state
    local color
    if claudeState == "waiting" then
        color = M.config.waitingColor
    elseif claudeState == "processing" then
        color = M.config.processingColor
    else
        color = M.config.waitingColor  -- Default to waiting color
    end

    -- Write detailed log to file for debugging
    local logFile = io.open("/tmp/claude_overlay_debug.log", "a")
    if logFile then
        logFile:write(string.format("[%s] Creating %s overlay at x=%.0f, y=%.0f, w=%.0f, h=%.0f\n",
            os.date("%Y-%m-%d %H:%M:%S"), claudeState, bounds.x, bounds.y, bounds.w, bounds.h))
        logFile:close()
    end

    -- Create new canvas
    state.overlay = hs.canvas.new({
        x = bounds.x,
        y = bounds.y,
        w = bounds.w,
        h = bounds.h
    })

    -- Configure overlay appearance
    if M.config.borderWidth > 0 then
        -- Border mode
        state.overlay[1] = {
            type = "rectangle",
            action = "stroke",
            strokeColor = color,
            strokeWidth = M.config.borderWidth,
            roundedRectRadii = {xRadius = 5, yRadius = 5}
        }
    else
        -- Fill mode
        state.overlay[1] = {
            type = "rectangle",
            action = "fill",
            fillColor = color,
            roundedRectRadii = {xRadius = 5, yRadius = 5}
        }
    end

    -- Configure window behavior
    state.overlay:behavior(hs.canvas.windowBehaviors.canJoinAllSpaces)
    state.overlay:level(hs.canvas.windowLevels.overlay)
    state.overlay:clickActivating(false)

    -- Show the overlay
    state.overlay:show()

    -- Verify it's actually showing
    local frame = state.overlay:frame()
    log(string.format("Overlay frame after show(): x=%.0f, y=%.0f, w=%.0f, h=%.0f",
        frame.x, frame.y, frame.w, frame.h))
    log("Overlay isShowing: " .. tostring(state.overlay:isShowing()))

    -- Write verification to file
    if logFile then
        logFile = io.open("/tmp/claude_overlay_debug.log", "a")
        logFile:write(string.format("[%s] Overlay isShowing: %s, frame: x=%.0f, y=%.0f, w=%.0f, h=%.0f\n",
            os.date("%Y-%m-%d %H:%M:%S"), tostring(state.overlay:isShowing()),
            frame.x, frame.y, frame.w, frame.h))
        logFile:close()
    end
end

function M.hideOverlay()
    if state.overlay then
        state.overlay:delete()
        state.overlay = nil
        log("Overlay deleted")
    end
end

-- Pane bounds calculation

function M.getTerminalWindow()
    -- Use the stored window if we have one
    if state.currentWindow and state.currentWindow:isStandard() then
        log("Using stored Claude window")
        return state.currentWindow
    end

    -- Fallback to main window
    local app = hs.application.get(M.config.terminalApp)
    if not app then
        log("Terminal app not running: " .. M.config.terminalApp)
        return nil
    end

    local window = app:mainWindow()
    if not window then
        log("No main window found for terminal")
        return nil
    end

    log("Using main window as fallback")
    return window
end

function M.getPaneBounds()
    -- Get the terminal window
    local window = M.getTerminalWindow()
    if not window then
        return nil
    end

    local frame = window:frame()
    log(string.format("Terminal window frame: x=%.0f, y=%.0f, w=%.0f, h=%.0f",
        frame.x, frame.y, frame.w, frame.h))

    -- Use the stored pane ID from the hook
    local paneId = state.claudePaneId
    if not paneId then
        log("WARNING: No pane ID available yet - will parse layout but can't verify pane ID")
        -- Continue anyway and use focus detection
    else
        log("Using pane ID: " .. tostring(paneId))
    end

    -- Get Zellij layout information
    local layoutOutput, status = hs.execute("zellij action dump-layout", true)
    if not status then
        log("Failed to get Zellij layout")
        return {x = frame.x, y = frame.y, w = frame.w, h = frame.h}
    end

    log("Got layout output, parsing...")

    -- Parse the layout to find pane position
    local bounds = M.parseZellijLayout(layoutOutput, paneId, frame)

    return bounds
end

function M.parseZellijLayout(layout, paneId, windowFrame)
    log("Parsing Zellij layout to find pane position")

    -- Constants for Zellij UI elements
    local TAB_BAR_HEIGHT = 30
    local STATUS_BAR_HEIGHT = 30
    local BORDER_WIDTH = 1  -- Space between panes

    -- Start with the content area (minus tab and status bars)
    local contentX = windowFrame.x
    local contentY = windowFrame.y + TAB_BAR_HEIGHT
    local contentW = windowFrame.w
    local contentH = windowFrame.h - TAB_BAR_HEIGHT - STATUS_BAR_HEIGHT

    log(string.format("Content area: x=%.0f, y=%.0f, w=%.0f, h=%.0f",
        contentX, contentY, contentW, contentH))

    -- Parse the layout structure to calculate position
    local bounds = M.calculatePaneBounds(layout, contentX, contentY, contentW, contentH)

    if bounds then
        log(string.format("Calculated pane bounds: x=%.0f, y=%.0f, w=%.0f, h=%.0f",
            bounds.x, bounds.y, bounds.w, bounds.h))
        return bounds
    else
        log("Parser returned nil, using full content area")
        return {x = contentX, y = contentY, w = contentW, h = contentH}
    end
end

function M.calculatePaneBounds(layout, x, y, w, h)
    -- Recursively parse the Zellij layout tree to find the focused Claude pane
    log(string.format("calculatePaneBounds at: x=%.0f, y=%.0f, w=%.0f, h=%.0f", x, y, w, h))

    -- First, extract the focused tab
    local focusedTab = layout:match('tab[^{]* focus=true[^{]*{(.-)}\n%s*tab')
    if not focusedTab then
        -- Maybe it's the only tab or the last tab
        focusedTab = layout:match('tab[^{]*{(.+)}%s*}%s*$')
    end

    if not focusedTab then
        log("Could not find focused tab in layout")
        return nil
    end

    log("Found focused tab, parsing pane structure")

    -- Extract the main pane container (skip tab-bar and status-bar panes)
    -- Look for the pane with split_direction (this is the main content pane)
    local splitStart = focusedTab:find('pane split_direction=')
    if not splitStart then
        log("Could not find pane with split_direction")
        return nil
    end

    -- Find the opening brace
    local braceStart = focusedTab:find("{", splitStart)
    if not braceStart then
        log("Could not find opening brace for split pane")
        return nil
    end

    -- Find the matching closing brace
    local braceCount = 1
    local braceEnd = braceStart
    while braceCount > 0 and braceEnd < #focusedTab do
        braceEnd = braceEnd + 1
        local c = focusedTab:sub(braceEnd, braceEnd)
        if c == "{" then
            braceCount = braceCount + 1
        elseif c == "}" then
            braceCount = braceCount - 1
        end
    end

    if braceCount ~= 0 then
        log("Could not find matching closing brace")
        return nil
    end

    local mainPane = focusedTab:sub(splitStart, braceEnd)

    log(string.format("Found main pane container, length %d", #mainPane))

    -- Now parse the pane structure within the main pane
    local result, isFocused = M.parsePane(mainPane, x, y, w, h, 0, nil)
    if result then
        if isFocused then
            log("Using focused Claude pane bounds")
        else
            log("Using unfocused Claude pane bounds (no focused Claude pane found)")
        end
        return result
    end

    -- Fallback
    log("Could not find any Claude pane, using full content area")
    return nil
end

function M.parsePane(paneText, x, y, w, h, depth, foundClaudePaneBounds)
    local indent = string.rep("  ", depth)
    log(indent .. "Parsing pane at depth " .. depth)

    -- Extract just the pane header (first line) to check attributes
    local paneHeader = paneText:match('^pane[^{]*')
    if paneHeader then
        log(indent .. "Header: " .. paneHeader)

        -- Check if THIS specific pane is running Claude
        local hasClaudeCommand = paneHeader:match('command="claude"') ~= nil

        if hasClaudeCommand then
            local hasFocus = paneHeader:match('focus=true') ~= nil

            if hasFocus then
                -- Focused Claude pane - return immediately!
                log(indent .. "✓ Found FOCUSED Claude pane!")
                return {x = x, y = y, w = w, h = h}, true
            else
                -- Unfocused Claude pane - return as fallback
                log(indent .. "✓ Found unfocused Claude pane, returning bounds")
                return {x = x, y = y, w = w, h = h}, false
            end
        end
    end

    -- Check for split direction
    local splitDirection = paneText:match('split_direction="(%w+)"')

    if not splitDirection then
        -- No split, this is a leaf pane
        log(indent .. "Leaf pane (no splits)")
        return nil, false
    end

    log(indent .. "Split direction: " .. splitDirection)

    -- Extract child panes
    -- We need to match balanced braces to get each child pane
    local children = M.extractChildPanes(paneText)

    if #children == 0 then
        log(indent .. "No children found")
        return nil
    end

    log(indent .. "Found " .. #children .. " child panes")

    -- Calculate bounds for each child
    local currentX = x
    local currentY = y

    for i, child in ipairs(children) do
        local sizeStr = child.text:match('size="(%d+)%%"')
        local size = tonumber(sizeStr) or (100 / #children)  -- Default to equal split

        log(indent .. string.format("Child %d: size=%.1f%% (parsed: %s)", i, size, tostring(sizeStr)))

        local childX, childY, childW, childH

        if splitDirection == "vertical" then
            -- Vertical split = side by side
            childW = w * (size / 100)
            childH = h
            childX = currentX
            childY = y
            currentX = currentX + childW
        else
            -- Horizontal split = stacked
            childW = w
            childH = h * (size / 100)
            childX = x
            childY = currentY
            currentY = currentY + childH
        end

        log(indent .. string.format("  -> bounds: x=%.0f, y=%.0f, w=%.0f, h=%.0f",
            childX, childY, childW, childH))

        -- Recursively parse this child
        local result, isFocused = M.parsePane(child.text, childX, childY, childW, childH, depth + 1, foundClaudePaneBounds)
        if result and isFocused then
            -- Found a focused Claude pane, return immediately
            return result, true
        elseif result then
            -- Found an unfocused Claude pane, store as backup
            foundClaudePaneBounds = result
        end
    end

    -- Return the backup Claude pane if we found one
    if foundClaudePaneBounds then
        log(indent .. "Returning unfocused Claude pane as fallback at depth " .. depth)
        return foundClaudePaneBounds, false
    end

    log(indent .. "No Claude pane found at depth " .. depth)
    return nil, false
end

function M.extractChildPanes(text)
    -- Extract ONLY direct child pane blocks (not nested grandchildren)
    local children = {}

    -- Find the opening brace of the parent pane
    local parentBraceStart = text:find("{")
    if not parentBraceStart then
        log("extractChildPanes: No opening brace found")
        return children
    end

    log(string.format("extractChildPanes: Starting from pos %d, text length %d", parentBraceStart, #text))

    local pos = parentBraceStart + 1
    local depth = 0  -- Depth relative to the parent's opening brace
    local foundPanes = 0

    while pos <= #text do
        -- Check if this is a "pane" keyword BEFORE updating depth
        if depth == 0 and text:sub(pos, pos + 3) == "pane" then
            local nextChar = text:sub(pos + 4, pos + 4)
            -- Make sure it's followed by whitespace (not "panes")
            if nextChar:match("%s") then
                -- Found a pane at depth 0 (direct child)
                foundPanes = foundPanes + 1
                log(string.format("extractChildPanes: Found pane #%d at pos %d (depth %d)", foundPanes, pos, depth))
                local paneStart = pos

                -- Find its opening brace
                local braceStart = text:find("{", paneStart)
                if not braceStart then break end

                -- Find the matching closing brace
                local braceCount = 1
                local braceEnd = braceStart

                while braceCount > 0 and braceEnd < #text do
                    braceEnd = braceEnd + 1
                    local c = text:sub(braceEnd, braceEnd)
                    if c == "{" then
                        braceCount = braceCount + 1
                    elseif c == "}" then
                        braceCount = braceCount - 1
                    end
                end

                if braceCount == 0 then
                    local paneText = text:sub(paneStart, braceEnd)

                    -- Skip plugin panes (tab-bar, status-bar) and floating panes
                    if not paneText:match('plugin location=') and
                       not paneText:match('floating_panes') and
                       not paneText:match('^pane%s+size%s*=%s*1%s+borderless') then
                        log(string.format("extractChildPanes: Adding child pane"))
                        table.insert(children, {text = paneText})
                    else
                        log(string.format("extractChildPanes: Skipping pane (plugin or special)"))
                    end

                    pos = braceEnd + 1
                    depth = 0  -- Reset depth after processing this pane
                    goto continue
                end
            end
        end

        -- Update depth based on braces
        local char = text:sub(pos, pos)
        if char == "{" then
            depth = depth + 1
        elseif char == "}" then
            depth = depth - 1
            if depth < 0 then
                -- We've reached the parent's closing brace
                break
            end
        end

        pos = pos + 1
        ::continue::
    end

    log(string.format("extractChildPanes: Returning %d children", #children))
    return children
end

-- Window and focus management

local function onAppEvent(appName, eventType, appObject)
    -- Only care about our terminal app
    if appName ~= M.config.terminalApp then
        return
    end

    if eventType == hs.application.watcher.activated then
        log("Terminal activated (focused)")
        state.isFocused = true
        M.updateOverlay()
    elseif eventType == hs.application.watcher.deactivated then
        log("Terminal deactivated (unfocused)")
        state.isFocused = false
        M.updateOverlay()
    end
end

-- Manual test functions (for testing without using Claude tokens)

function M.testReady()
    log("TEST: Simulating Claude ready state")
    M.onClaudeReady()
end

function M.testProcessing()
    log("TEST: Simulating Claude processing state")
    M.onClaudeProcessing()
end

function M.testShowOverlay()
    log("TEST: Forcing overlay to show")
    local testBounds = {x = 100, y = 100, w = 400, h = 600}
    M.showOverlay(testBounds, "waiting")
end

function M.testBrightOverlay()
    print("Creating VERY VISIBLE overlay for testing...")

    -- Set state to waiting so it persists
    state.claudeState = "waiting"
    state.claudePaneId = "0"

    local app = hs.application.get(M.config.terminalApp)
    if app then
        state.currentWindow = app:focusedWindow()
    end

    local window = M.getTerminalWindow()
    if not window then
        print("No window found")
        return
    end

    local frame = window:frame()
    local bounds = {
        x = frame.x,
        y = frame.y,
        w = frame.w / 2,
        h = frame.h
    }

    -- Create with bright, opaque color
    if state.overlay then
        state.overlay:delete()
    end

    state.overlay = hs.canvas.new(bounds)
    state.overlay[1] = {
        type = "rectangle",
        action = "fill",
        fillColor = {red = 1.0, green = 0, blue = 0, alpha = 0.7},  -- Bright red, mostly opaque
    }

    state.overlay:behavior(hs.canvas.windowBehaviors.canJoinAllSpaces)
    state.overlay:level(hs.canvas.windowLevels.floating)  -- Try floating level
    state.overlay:clickActivating(false)
    state.overlay:show()

    print(string.format("Created BRIGHT RED overlay at x=%.0f, y=%.0f, w=%.0f, h=%.0f",
        bounds.x, bounds.y, bounds.w, bounds.h))
    print("isShowing: " .. tostring(state.overlay:isShowing()))
    print("State set to 'waiting' - overlay should persist when unfocusing")
    print("You should see a bright red overlay covering half the terminal window")
    print("Run claudeNotifier.testHideOverlay() to hide it")
end

function M.testHideOverlay()
    log("TEST: Forcing overlay to hide")
    M.hideOverlay()
end

function M.testToggle()
    if state.claudeState == "waiting" then
        M.testProcessing()
    else
        M.testReady()
    end
end

function M.getState()
    return {
        claudeState = state.claudeState,
        isFocused = state.isFocused,
        overlayVisible = state.overlay ~= nil,
        terminalApp = M.config.terminalApp
    }
end

function M.printState()
    local s = M.getState()
    print("=== Claude Notifier State ===")
    print("Claude state: " .. s.claudeState)
    print("Terminal focused: " .. tostring(s.isFocused))
    print("Overlay visible: " .. tostring(s.overlayVisible))
    print("Terminal app: " .. s.terminalApp)
    print("Pane ID: " .. tostring(state.claudePaneId))
    print("============================")
    return s
end

function M.testLayout()
    print("=== Testing Layout Parser ===")
    local window = M.getTerminalWindow()
    if not window then
        print("ERROR: No terminal window found")
        return
    end

    local frame = window:frame()
    print(string.format("Window: x=%.0f, y=%.0f, w=%.0f, h=%.0f", frame.x, frame.y, frame.w, frame.h))

    local layoutOutput, status = hs.execute("zellij action dump-layout", true)
    if not status then
        print("ERROR: Failed to get layout")
        return
    end

    print("\n--- Raw Layout (first 500 chars) ---")
    print(layoutOutput:sub(1, 500))
    print("\n--- Parsing ---")

    local bounds = M.parseZellijLayout(layoutOutput, state.claudePaneId, frame)
    print(string.format("\n--- Result ---\nPane bounds: x=%.0f, y=%.0f, w=%.0f, h=%.0f",
        bounds.x, bounds.y, bounds.w, bounds.h))
    print("==============================")
    return bounds
end

function M.fullTest()
    print("=== COMPREHENSIVE CLAUDE NOTIFIER TEST ===")
    print("\n1. Testing window detection...")

    local app = hs.application.get(M.config.terminalApp)
    if not app then
        print("  ✗ Terminal app not running: " .. M.config.terminalApp)
        return
    end
    print("  ✓ Terminal app found: " .. M.config.terminalApp)

    local window = app:focusedWindow()
    if not window then
        print("  ✗ No focused terminal window")
        return
    end
    print(string.format("  ✓ Terminal window: %d", window:id()))

    local frame = window:frame()
    print(string.format("  ✓ Window frame: x=%.0f, y=%.0f, w=%.0f, h=%.0f", frame.x, frame.y, frame.w, frame.h))

    print("\n2. Testing pane layout parsing...")
    local layoutOutput = hs.execute("zellij action dump-layout", true)
    if not layoutOutput then
        print("  ✗ Failed to get Zellij layout")
        return
    end
    print("  ✓ Got layout (" .. #layoutOutput .. " chars)")

    local bounds = M.parseZellijLayout(layoutOutput, "0", frame)
    if not bounds then
        print("  ✗ Failed to parse bounds")
        return
    end
    print(string.format("  ✓ Parsed bounds: x=%.0f, y=%.0f, w=%.0f, h=%.0f", bounds.x, bounds.y, bounds.w, bounds.h))

    print("\n3. Testing overlay creation...")
    M.showOverlay(bounds, "waiting")

    if not state.overlay then
        print("  ✗ Overlay not created")
        return
    end
    print("  ✓ Overlay created")
    print("  ✓ isShowing: " .. tostring(state.overlay:isShowing()))

    local overlayFrame = state.overlay:frame()
    print(string.format("  ✓ Overlay frame: x=%.0f, y=%.0f, w=%.0f, h=%.0f",
        overlayFrame.x, overlayFrame.y, overlayFrame.w, overlayFrame.h))

    print("\n4. Checking debug log...")
    os.execute("tail -5 /tmp/claude_overlay_debug.log 2>/dev/null || echo '  (no log file yet)'")

    print("\n5. Testing state...")
    M.printState()

    print("\n=== TEST COMPLETE ===")
    print("The overlay should now be visible on your screen.")
    print("If you don't see it, check /tmp/claude_overlay_debug.log")
    print("\nTo hide: claudeNotifier.testHideOverlay()")
end

-- Initialization

function M.init()
    log("Initializing claude_notifier")

    if not M.config.enabled then
        log("Module disabled in config")
        return
    end

    -- Set up application watcher for focus changes
    state.appWatcher = hs.application.watcher.new(onAppEvent)
    state.appWatcher:start()
    log("Application watcher started")

    log("claude_notifier initialized")
    log("Test commands available:")
    log("  claudeNotifier.testReady() - simulate Claude ready")
    log("  claudeNotifier.testProcessing() - simulate Claude processing")
    log("  claudeNotifier.testToggle() - toggle between states")
    log("  claudeNotifier.testShowOverlay() - force show overlay")
    log("  claudeNotifier.testHideOverlay() - force hide overlay")
    log("  claudeNotifier.printState() - show current state")
end

return M
