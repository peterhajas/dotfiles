local strip_tiler = {}

local manager = nil
strip_tiler.debugLogging = false

local function copyRect(rect)
    return {
        x = rect.x,
        y = rect.y,
        w = rect.w,
        h = rect.h,
    }
end

local function clamp(value, minimum, maximum)
    if value < minimum then
        return minimum
    end

    if value > maximum then
        return maximum
    end

    return value
end

local function approxEqual(a, b)
    return math.abs(a - b) < 0.5
end

local function rectEquals(left, right)
    if left == nil or right == nil then
        return false
    end

    return approxEqual(left.x, right.x)
        and approxEqual(left.y, right.y)
        and approxEqual(left.w, right.w)
        and approxEqual(left.h, right.h)
end

local StripCore = {}
StripCore.__index = StripCore

function StripCore.new(config)
    local instance = {
        cameraX = 0,
        viewport = nil,
        panPoint = nil,
        stripOriginX = 0,
        order = {},
        windows = {},
        config = {
            cornerReveal = 40,
            minimumWidth = 220,
            resizeAnchorTolerance = 8,
        },
    }

    if config ~= nil then
        for key, value in pairs(config) do
            instance.config[key] = value
        end
    end

    return setmetatable(instance, StripCore)
end

function StripCore:setViewport(rect)
    self.viewport = rect and copyRect(rect) or nil
end

function StripCore:getCamera()
    return {x = self.cameraX, y = 0}
end

function StripCore:beginPan(point)
    self.panPoint = {x = point.x, y = point.y}
end

function StripCore:updatePan(point)
    if self.panPoint == nil then
        self:beginPan(point)
        return false
    end

    local deltaX = point.x - self.panPoint.x
    self.cameraX = self.cameraX - deltaX
    self.panPoint = {x = point.x, y = point.y}
    return not approxEqual(deltaX, 0)
end

function StripCore:endPan()
    self.panPoint = nil
end

function StripCore:_ensureWindow(id, frame)
    local window = self.windows[id]
    if window == nil then
        window = {
            id = id,
            width = frame.w,
        }
        self.windows[id] = window
        table.insert(self.order, id)
    end

    if window.width == nil then
        window.width = frame.w
    end

    return window
end

function StripCore:setWindowFromPhysicalFrame(id, frame)
    local window = self:_ensureWindow(id, frame)
    if window.width == nil then
        window.width = frame.w
    end
end

function StripCore:removeWindow(id)
    self.windows[id] = nil
    for index, orderedId in ipairs(self.order) do
        if orderedId == id then
            table.remove(self.order, index)
            break
        end
    end
end

function StripCore:_windowIndex(id)
    for index, orderedId in ipairs(self.order) do
        if orderedId == id then
            return index
        end
    end

    return nil
end

function StripCore:_canvasFrameForIndex(targetIndex)
    local x = self.stripOriginX

    for index, id in ipairs(self.order) do
        local window = self.windows[id]
        if window ~= nil then
            if index == targetIndex then
                return {
                    x = x,
                    y = self.viewport.y,
                    w = window.width,
                    h = self.viewport.h,
                }
            end
            x = x + window.width
        end
    end

    return nil
end

function StripCore:_constrainedFrame(canvasFrame)
    local reveal = self.config.cornerReveal
    local minX = self.viewport.x - canvasFrame.w + reveal
    local maxX = self.viewport.x + self.viewport.w - reveal
    local frameX = clamp(canvasFrame.x - self.cameraX, minX, maxX)

    return {
        x = frameX,
        y = self.viewport.y,
        w = canvasFrame.w,
        h = self.viewport.h,
    }, (canvasFrame.x - self.cameraX) - frameX
end

function StripCore:getPlacements()
    local placements = {}

    if self.viewport == nil then
        return placements
    end

    for index, id in ipairs(self.order) do
        local canvasFrame = self:_canvasFrameForIndex(index)
        local frame, hiddenX = self:_constrainedFrame(canvasFrame)
        local quadrant = nil

        if hiddenX < 0 then
            quadrant = "west"
        elseif hiddenX > 0 then
            quadrant = "east"
        end

        placements[id] = {
            id = id,
            canvasFrame = canvasFrame,
            frame = frame,
            hiddenX = hiddenX,
            parked = not approxEqual(hiddenX, 0),
            parkingQuadrant = quadrant,
        }
    end

    return placements
end

function StripCore:ensureVisible(id)
    if self.viewport == nil then
        return false
    end

    local index = self:_windowIndex(id)
    if index == nil then
        return false
    end

    local canvasFrame = self:_canvasFrameForIndex(index)
    local targetX = canvasFrame.x - self.cameraX
    local viewportLeft = self.viewport.x
    local viewportRight = self.viewport.x + self.viewport.w
    local nextCameraX = self.cameraX

    if targetX < viewportLeft then
        nextCameraX = canvasFrame.x - viewportLeft
    elseif (targetX + canvasFrame.w) > viewportRight then
        nextCameraX = canvasFrame.x + canvasFrame.w - viewportRight
    end

    if approxEqual(nextCameraX, self.cameraX) then
        return false
    end

    self.cameraX = nextCameraX
    return true
end

function StripCore:applyResize(id, frame, previousFrame)
    if self.viewport == nil then
        return false
    end

    local index = self:_windowIndex(id)
    if index == nil then
        self:setWindowFromPhysicalFrame(id, frame)
        return true
    end

    local window = self.windows[id]
    local oldWidth = window.width
    local newWidth = math.max(self.config.minimumWidth, frame.w)
    local deltaWidth = newWidth - oldWidth

    if approxEqual(deltaWidth, 0) then
        return false
    end

    local movedLeft = frame.x - previousFrame.x
    local movedRight = (frame.x + frame.w) - (previousFrame.x + previousFrame.w)
    local tolerance = self.config.resizeAnchorTolerance
    local balancedEdges = math.abs(math.abs(movedLeft) - math.abs(movedRight)) <= tolerance

    if balancedEdges and movedLeft * movedRight <= 0 then
        self.stripOriginX = self.stripOriginX - (deltaWidth / 2)
    elseif math.abs(movedLeft) > math.abs(movedRight) then
        self.stripOriginX = self.stripOriginX - deltaWidth
    end

    window.width = newWidth
    return true
end

function StripCore:debugState()
    return {
        camera = self:getCamera(),
        stripOriginX = self.stripOriginX,
        order = self.order,
        windows = self:getPlacements(),
    }
end

local function unionFrames(frames)
    local union = nil

    for _, frame in ipairs(frames) do
        if union == nil then
            union = copyRect(frame)
        else
            local minX = math.min(union.x, frame.x)
            local minY = math.min(union.y, frame.y)
            local maxX = math.max(union.x + union.w, frame.x + frame.w)
            local maxY = math.max(union.y + union.h, frame.y + frame.h)
            union.x = minX
            union.y = minY
            union.w = maxX - minX
            union.h = maxY - minY
        end
    end

    return union
end

local function currentViewport()
    local primary = hs.screen.primaryScreen()
    if primary == nil then
        return nil
    end

    return primary:fullFrame()
end

local function log(message)
    print("canvas_window_manager_strips: " .. message)
end

local function debugLog(message)
    if strip_tiler.debugLogging then
        log(message)
    end
end

local function readFile(path)
    local handle = io.open(path, "r")
    if handle == nil then
        return nil
    end

    local content = handle:read("*a")
    handle:close()
    return content
end

local function regexMatcher(pattern)
    if pattern == "^Screen ?Sharing$" then
        return function(value)
            return value == "Screen Sharing" or value == "ScreenSharing"
        end
    end

    if pattern == "\\.[eE][xX][eE]$" then
        return function(value)
            return value ~= nil and value:lower():match("%.exe$") ~= nil
        end
    end

    local exact = pattern:match("^%^(.*)%$$")
    if exact ~= nil and exact:find("[%[%]%(%)%?%+%*]", 1) == nil then
        exact = exact:gsub("\\", "")
        return function(value)
            return value == exact
        end
    end

    return function(value)
        return value ~= nil and value == pattern
    end
end

local function loadManageOffRules(path)
    local content = readFile(path)
    local rules = {app = {}, title = {}}

    if content == nil then
        return rules
    end

    for line in content:gmatch("[^\r\n]+") do
        if line:find("manage=off", 1, true) ~= nil then
            local appPattern = line:match('app="([^"]+)"')
            local titlePattern = line:match('title="([^"]+)"')

            if appPattern ~= nil then
                table.insert(rules.app, regexMatcher(appPattern))
            end

            if titlePattern ~= nil then
                table.insert(rules.title, regexMatcher(titlePattern))
            end
        end
    end

    return rules
end

local function matchesAny(matchers, value)
    for _, matcher in ipairs(matchers) do
        if matcher(value) then
            return true
        end
    end

    return false
end

local function geometryRect(rect)
    return hs.geometry.rect(rect.x, rect.y, rect.w, rect.h)
end

local function shouldManageWindow(win, rules)
    if win == nil or win:id() == nil then
        return false
    end

    if not win:isStandard() or not win:isVisible() or win:isMinimized() or win:isFullScreen() then
        return false
    end

    local app = win:application()
    local appName = app and app:name() or nil
    if appName == "Hammerspoon" then
        return false
    end

    local primary = hs.screen.primaryScreen()
    local screen = win:screen()
    if primary == nil or screen == nil or screen:id() ~= primary:id() then
        return false
    end

    if matchesAny(rules.app, appName) then
        return false
    end

    if matchesAny(rules.title, win:title() or "") then
        return false
    end

    return true
end

local function managedWindowsSnapshot(state)
    local windows = {}
    for _, win in ipairs(hs.window.allWindows()) do
        if shouldManageWindow(win, state.manageOffRules) then
            windows[win:id()] = win
        end
    end
    return windows
end

local function clearPendingMove(state, id)
    state.pendingMoves[id] = nil
end

local function setWindowFrame(state, id, win, frame)
    local currentFrame = state.appliedFrames[id]
    if currentFrame == nil then
        currentFrame = win:frame()
        state.appliedFrames[id] = copyRect(currentFrame)
    end

    if rectEquals(currentFrame, frame)
        or (math.abs(currentFrame.x - frame.x) < state.movementThreshold
            and approxEqual(currentFrame.y, frame.y)
            and approxEqual(currentFrame.w, frame.w)
            and approxEqual(currentFrame.h, frame.h)) then
        clearPendingMove(state, id)
        return
    end

    state.pendingMoves[id] = copyRect(frame)
    state.appliedFrames[id] = copyRect(frame)
    win:setFrame(geometryRect(frame))
end

local function requestLayout(state)
    state.layoutDirty = true
end

local applyLayout

local function currentPlacementForWindow(state, id)
    return state.core:getPlacements()[id]
end

applyLayout = function(state)
    if not state.layoutDirty then
        return
    end

    local placements = state.core:getPlacements()
    state.layoutDirty = false

    for id, win in pairs(state.windowsById) do
        local placement = placements[id]
        if placement ~= nil then
            local currentFrame = state.appliedFrames[id]
            if placement.parked and currentFrame ~= nil and rectEquals(currentFrame, placement.frame) then
                goto continue
            end

            setWindowFrame(state, id, win, placement.frame)
        end

        ::continue::
    end
end

local function syncManagedWindows(state)
    local windows = managedWindowsSnapshot(state)
    state.windowsById = windows

    for id, win in pairs(windows) do
        if state.core.windows[id] == nil then
            state.core:setWindowFromPhysicalFrame(id, win:frame())
        end

        if state.appliedFrames[id] == nil then
            state.appliedFrames[id] = copyRect(win:frame())
        end
    end

    for id, _ in pairs(state.core.windows) do
        if windows[id] == nil then
            state.core:removeWindow(id)
            state.appliedFrames[id] = nil
            clearPendingMove(state, id)
        end
    end
end

local function refreshWorld(state)
    local viewport = currentViewport()
    if viewport == nil then
        return
    end

    state.core:setViewport(viewport)
    syncManagedWindows(state)
    requestLayout(state)
    applyLayout(state)
end

local function handleManagedWindowMoved(state, win)
    local id = win:id()
    if id == nil then
        return
    end

    local pendingFrame = state.pendingMoves[id]
    local frame = win:frame()

    if pendingFrame ~= nil and rectEquals(frame, pendingFrame) then
        clearPendingMove(state, id)
        state.appliedFrames[id] = copyRect(frame)
        return
    end

    if state.core.windows[id] == nil then
        state.core:setWindowFromPhysicalFrame(id, frame)
    end

    state.appliedFrames[id] = copyRect(frame)
    requestLayout(state)
end

local function handleManagedWindowResized(state, win)
    local id = win:id()
    if id == nil then
        return
    end

    local frame = win:frame()
    local pendingFrame = state.pendingMoves[id]

    if pendingFrame ~= nil and rectEquals(frame, pendingFrame) then
        clearPendingMove(state, id)
        state.appliedFrames[id] = copyRect(frame)
        return
    end

    if state.core.windows[id] == nil then
        state.core:setWindowFromPhysicalFrame(id, frame)
    end

    local placement = currentPlacementForWindow(state, id)
    local previousFrame = placement and placement.frame or state.appliedFrames[id]
    state.appliedFrames[id] = copyRect(frame)

    if previousFrame ~= nil then
        if state.core:applyResize(id, frame, previousFrame) then
            debugLog("resized " .. tostring(id) .. " to width=" .. tostring(frame.w))
        end
    end

    requestLayout(state)
    applyLayout(state)
end

local function handleManagedWindowFocused(state, win)
    local id = win:id()
    if id == nil then
        return
    end

    if state.core:ensureVisible(id) then
        requestLayout(state)
        applyLayout(state)
    end
end

local function panModifiersPressed(state)
    local modifiers = hs.eventtap.checkKeyboardModifiers()
    for modifierName, required in pairs(state.panModifiers) do
        if required and modifiers[modifierName] ~= true then
            return false
        end
    end

    return true
end

local function refreshPan(state)
    local location = hs.mouse.absolutePosition()

    if not panModifiersPressed(state) then
        if state.activePan then
            state.core:endPan()
            state.activePan = false
        end
        return
    end

    if not state.activePan then
        state.activePan = true
        state.core:beginPan(location)
        return
    end

    if state.core:updatePan(location) then
        requestLayout(state)
    end
end

local function buildManager(config)
    local yabaiRulesPath = "/Users/phajas/dotfiles/yabai/.config/yabai/yabairc"
    if config ~= nil and config.yabaiRulesPath ~= nil then
        yabaiRulesPath = config.yabaiRulesPath
    end

    local state = {
        core = StripCore.new(config),
        manageOffRules = loadManageOffRules(yabaiRulesPath),
        windowsById = {},
        pendingMoves = {},
        appliedFrames = {},
        activePan = false,
        layoutDirty = false,
        movementThreshold = 2,
        panModifiers = {cmd = true},
        modifierTap = nil,
        pollTimer = nil,
        reconcileTimer = nil,
        renderTimer = nil,
        renderHz = 60,
        screenWatcher = nil,
        windowFilter = nil,
    }

    if config ~= nil and config.panModifiers ~= nil then
        state.panModifiers = config.panModifiers
    end

    if config ~= nil and config.movementThreshold ~= nil then
        state.movementThreshold = config.movementThreshold
    end

    if config ~= nil and config.renderHz ~= nil then
        state.renderHz = config.renderHz
    end

    local wf = hs.window.filter.new(false)
    wf:subscribe({
        hs.window.filter.windowCreated,
        hs.window.filter.windowDestroyed,
        hs.window.filter.windowVisible,
        hs.window.filter.windowNotVisible,
        hs.window.filter.windowMinimized,
        hs.window.filter.windowUnminimized,
        hs.window.filter.windowFullscreened,
        hs.window.filter.windowUnfullscreened,
        hs.window.filter.windowAllowed,
        hs.window.filter.windowRejected,
    }, function()
        refreshWorld(state)
    end)
    wf:subscribe(hs.window.filter.windowMoved, function(win)
        if win ~= nil and shouldManageWindow(win, state.manageOffRules) then
            local id = win:id()
            local frame = win:frame()
            local previousFrame = id and state.appliedFrames[id] or nil

            if previousFrame ~= nil and (not approxEqual(frame.w, previousFrame.w) or not approxEqual(frame.h, previousFrame.h)) then
                handleManagedWindowResized(state, win)
            else
                handleManagedWindowMoved(state, win)
            end
        end
    end)
    wf:subscribe(hs.window.filter.windowFocused, function(win)
        if win ~= nil and shouldManageWindow(win, state.manageOffRules) then
            handleManagedWindowFocused(state, win)
        end
    end)

    state.windowFilter = wf
    state.screenWatcher = hs.screen.watcher.new(function()
        refreshWorld(state)
    end)
    state.modifierTap = hs.eventtap.new({hs.eventtap.event.types.flagsChanged}, function()
        if not panModifiersPressed(state) and state.activePan then
            state.core:endPan()
            state.activePan = false
        end
        return false
    end)
    state.pollTimer = hs.timer.new(1 / 90, function()
        refreshPan(state)
    end)
    state.renderTimer = hs.timer.new(1 / state.renderHz, function()
        applyLayout(state)
    end)
    state.reconcileTimer = hs.timer.new(0.75, function()
        refreshWorld(state)
    end)

    function state:start()
        self.screenWatcher:start()
        self.modifierTap:start()
        self.pollTimer:start()
        self.renderTimer:start()
        self.reconcileTimer:start()
        refreshWorld(self)
        log("started")
    end

    function state:stop()
        if self.renderTimer ~= nil then
            self.renderTimer:stop()
        end
        if self.reconcileTimer ~= nil then
            self.reconcileTimer:stop()
        end
        if self.pollTimer ~= nil then
            self.pollTimer:stop()
        end
        if self.modifierTap ~= nil then
            self.modifierTap:stop()
        end
        if self.screenWatcher ~= nil then
            self.screenWatcher:stop()
        end
        if self.windowFilter ~= nil then
            self.windowFilter:unsubscribeAll()
        end
        log("stopped")
    end

    function state:debugState()
        return self.core:debugState()
    end

    return state
end

function strip_tiler.init(config)
    if manager ~= nil then
        return manager
    end

    manager = buildManager(config)
    manager:start()
    return manager
end

function strip_tiler.stop()
    if manager == nil then
        return
    end

    manager:stop()
    manager = nil
end

function strip_tiler.debugState()
    if manager == nil then
        return nil
    end

    return manager:debugState()
end

function strip_tiler.newCore(config)
    return StripCore.new(config)
end

function strip_tiler.rectEquals(left, right)
    return rectEquals(left, right)
end

return strip_tiler
