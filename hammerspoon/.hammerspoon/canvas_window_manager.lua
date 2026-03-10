local window_manager = {}

local manager = nil
window_manager.debugLogging = false

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

local function inflateRect(rect, amount)
    return {
        x = rect.x - amount,
        y = rect.y - amount,
        w = rect.w + (amount * 2),
        h = rect.h + (amount * 2),
    }
end

local function rectIntersects(a, b)
    return a.x < (b.x + b.w)
        and (a.x + a.w) > b.x
        and a.y < (b.y + b.h)
        and (a.y + a.h) > b.y
end

local function rectIntersectsHorizontally(a, b)
    return a.x < (b.x + b.w)
        and (a.x + a.w) > b.x
end

local function rectCenter(rect)
    return {
        x = rect.x + (rect.w / 2),
        y = rect.y + (rect.h / 2),
    }
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

local CanvasCore = {}
CanvasCore.__index = CanvasCore

function CanvasCore.new(config)
    local instance = {
        camera = {x = 0, y = 0},
        viewport = nil,
        panPoint = nil,
        nextOrder = 1,
        windows = {},
        config = {
            activationMargin = 280,
            cornerReveal = 40,
            parkingStride = 56,
            parkingColumns = 3,
        },
    }

    if config ~= nil then
        for key, value in pairs(config) do
            instance.config[key] = value
        end
    end

    return setmetatable(instance, CanvasCore)
end

function CanvasCore:setViewport(rect)
    if rect == nil then
        self.viewport = nil
        return
    end

    self.viewport = copyRect(rect)
end

function CanvasCore:getCamera()
    return {
        x = self.camera.x,
        y = self.camera.y,
    }
end

function CanvasCore:beginPan(point)
    self.panPoint = {
        x = point.x,
        y = point.y,
    }
end

function CanvasCore:updatePan(point)
    if self.panPoint == nil then
        self:beginPan(point)
        return false
    end

    local deltaX = point.x - self.panPoint.x

    self.camera.x = self.camera.x - deltaX

    self.panPoint = {
        x = point.x,
        y = point.y,
    }

    return not approxEqual(deltaX, 0)
end

function CanvasCore:endPan()
    self.panPoint = nil
end

function CanvasCore:_windowRecord(id)
    local window = self.windows[id]
    if window == nil then
        window = {
            id = id,
            canvasFrame = nil,
            order = self.nextOrder,
        }
        self.windows[id] = window
        self.nextOrder = self.nextOrder + 1
    end
    return window
end

function CanvasCore:setWindowFromPhysicalFrame(id, frame)
    local window = self:_windowRecord(id)
    window.canvasFrame = {
        x = frame.x + self.camera.x,
        y = frame.y,
        w = frame.w,
        h = frame.h,
    }
end

function CanvasCore:removeWindow(id)
    self.windows[id] = nil
end

function CanvasCore:_targetFrame(window)
    return {
        x = window.canvasFrame.x - self.camera.x,
        y = window.canvasFrame.y,
        w = window.canvasFrame.w,
        h = window.canvasFrame.h,
    }
end

function CanvasCore:_constrainedFrame(targetFrame)
    local reveal = self.config.cornerReveal
    local frame = copyRect(targetFrame)
    local viewport = self.viewport
    local minX = viewport.x - frame.w + reveal
    local maxX = viewport.x + viewport.w - reveal

    frame.x = clamp(targetFrame.x, minX, maxX)
    frame.y = targetFrame.y

    return frame, targetFrame.x - frame.x
end

function CanvasCore:_parkingFrame(targetFrame, slotIndex, quadrant)
    local stride = self.config.parkingStride
    local frame = copyRect(targetFrame)
    local slotOffset = slotIndex * stride
    local viewport = self.viewport

    if quadrant == "west" then
        frame.x = viewport.x - frame.w + self.config.cornerReveal + slotOffset
    else
        frame.x = viewport.x + viewport.w - self.config.cornerReveal - slotOffset
    end

    frame.y = targetFrame.y

    return frame
end

function CanvasCore:getPlacements()
    local placements = {}
    local windows = {}

    for _, window in pairs(self.windows) do
        if window.canvasFrame ~= nil then
            table.insert(windows, window)
        end
    end

    table.sort(windows, function(left, right)
        return left.order < right.order
    end)

    for _, window in ipairs(windows) do
        local targetFrame = self:_targetFrame(window)
        local frame, hiddenX = self:_constrainedFrame(targetFrame)
        local parked = not approxEqual(hiddenX, 0)
        local quadrant = nil

        if hiddenX < 0 then
            quadrant = "west"
        elseif hiddenX > 0 then
            quadrant = "east"
        end

        placements[window.id] = {
            id = window.id,
            canvasFrame = copyRect(window.canvasFrame),
            targetFrame = targetFrame,
            frame = frame,
            hiddenX = hiddenX,
            parked = parked,
            parkingQuadrant = quadrant,
        }
    end

    return placements
end

function CanvasCore:debugState()
    local snapshot = {
        camera = self:getCamera(),
        viewport = self.viewport and copyRect(self.viewport) or nil,
        windows = {},
    }

    for id, placement in pairs(self:getPlacements()) do
        snapshot.windows[id] = {
            parked = placement.parked,
            parkingQuadrant = placement.parkingQuadrant,
            frame = copyRect(placement.frame),
            canvasFrame = copyRect(placement.canvasFrame),
            hiddenX = placement.hiddenX,
        }
    end

    return snapshot
end

local function geometryRect(rect)
    return hs.geometry.rect(rect.x, rect.y, rect.w, rect.h)
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
    local frames = {}
    for _, screen in ipairs(hs.screen.allScreens()) do
        table.insert(frames, screen:fullFrame())
    end
    return unionFrames(frames)
end

local function isManagedWindow(win)
    if win == nil or win:id() == nil then
        return false
    end

    if not win:isStandard() then
        return false
    end

    if not win:isVisible() then
        return false
    end

    if win:isMinimized() then
        return false
    end

    if win:isFullScreen() then
        return false
    end

    local app = win:application()
    if app ~= nil and app:name() == "Hammerspoon" then
        return false
    end

    return true
end

local function managedWindowsSnapshot()
    local windows = {}
    for _, win in ipairs(hs.window.allWindows()) do
        if isManagedWindow(win) then
            windows[win:id()] = win
        end
    end
    return windows
end

local function log(message)
    print("canvas_window_manager: " .. message)
end

local function debugLog(message)
    if window_manager.debugLogging then
        log(message)
    end
end

local function nowSeconds()
    return hs.timer.absoluteTime() / 1000000000
end

local function modifiersSummary(modifiers)
    return "cmd=" .. tostring(modifiers.cmd == true)
        .. " alt=" .. tostring(modifiers.alt == true)
        .. " ctrl=" .. tostring(modifiers.ctrl == true)
        .. " shift=" .. tostring(modifiers.shift == true)
        .. " fn=" .. tostring(modifiers.fn == true)
end

local function panModifiersPressed(state)
    local modifiers = hs.eventtap.checkKeyboardModifiers()
    for modifierName, required in pairs(state.panModifiers) do
        if required and modifiers[modifierName] ~= true then
            return false, modifiers
        end
    end

    return true, modifiers
end

local applyLayout

local function requestLayout(state)
    state.layoutDirty = true
end

local function updatePanFromLocation(state, location)
    if state.core:updatePan(location) then
        requestLayout(state)
        debugLog("cmd pan drag x=" .. math.floor(location.x) .. " y=" .. math.floor(location.y))
    end
end

local function beginPan(state, location, modifiers)
    if state.activePanButton == nil then
        state.lastPointerLocation = copyRect({x = location.x, y = location.y, w = 0, h = 0})
        state.lastMotionAt = nowSeconds()
        state.core:beginPan(location)
        state.activePanButton = "cmd"
        debugLog("cmd pan begin x=" .. math.floor(location.x) .. " y=" .. math.floor(location.y) .. " " .. modifiersSummary(modifiers))
    end
end

local function endPan(state)
    if state.activePanButton ~= nil then
        debugLog("cmd pan end")
        state.core:endPan()
        state.activePanButton = nil
        state.lastPointerLocation = nil
    end
end

local function refreshPanFromModifierState(state)
    local pressed, modifiers = panModifiersPressed(state)
    local location = hs.mouse.absolutePosition()
    local now = nowSeconds()

    if state.activePanButton ~= nil and state.lastPointerLocation ~= nil then
        if not (approxEqual(location.x, state.lastPointerLocation.x) and approxEqual(location.y, state.lastPointerLocation.y)) then
            state.lastMotionAt = now
            state.lastPointerLocation = {x = location.x, y = location.y, w = 0, h = 0}
            updatePanFromLocation(state, location)
            return true
        end
    end

    if not pressed then
        if state.activePanButton == nil then
            return false
        end

        endPan(state)
        return false
    end

    if state.activePanButton == nil then
        beginPan(state, location, modifiers)
        return true
    end

    state.lastPointerLocation = {x = location.x, y = location.y, w = 0, h = 0}
    state.lastMotionAt = now
    updatePanFromLocation(state, location)
    return true
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
        or (math.abs(currentFrame.x - frame.x) < state.movementThreshold and approxEqual(currentFrame.y, frame.y)
            and approxEqual(currentFrame.w, frame.w) and approxEqual(currentFrame.h, frame.h)) then
        clearPendingMove(state, id)
        return
    end

    state.pendingMoves[id] = copyRect(frame)
    state.appliedFrames[id] = copyRect(frame)
    win:setFrame(geometryRect(frame))
end

local function shouldSkipClampedUpdate(state, placement)
    if placement == nil or not placement.parked then
        return false
    end

    local currentFrame = state.appliedFrames[placement.id]
    if currentFrame == nil then
        return false
    end

    return rectEquals(currentFrame, placement.frame)
end

local function syncManagedWindows(state)
    local windows = managedWindowsSnapshot()
    state.windowsById = windows

    for id, win in pairs(windows) do
        local existing = state.core.windows[id]
        if existing == nil or existing.canvasFrame == nil then
            state.core:setWindowFromPhysicalFrame(id, win:frame())
        end

        if state.appliedFrames[id] == nil then
            state.appliedFrames[id] = copyRect(win:frame())
        end
    end

    for id, _ in pairs(state.core.windows) do
        if windows[id] == nil then
            state.core:removeWindow(id)
            clearPendingMove(state, id)
            state.appliedFrames[id] = nil
        end
    end
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
            if shouldSkipClampedUpdate(state, placement) then
                goto continue
            end

            setWindowFrame(state, id, win, placement.frame)
        end

        ::continue::
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
    if not isManagedWindow(win) then
        local id = win:id()
        if id ~= nil then
            state.core:removeWindow(id)
            state.windowsById[id] = nil
            clearPendingMove(state, id)
        end
        return
    end

    local id = win:id()
    local frame = win:frame()
    local pendingFrame = state.pendingMoves[id]

    if pendingFrame ~= nil and rectEquals(frame, pendingFrame) then
        clearPendingMove(state, id)
        state.appliedFrames[id] = copyRect(frame)
        return
    end

    state.windowsById[id] = win
    state.appliedFrames[id] = copyRect(frame)
    state.core:setWindowFromPhysicalFrame(id, frame)
    requestLayout(state)
    applyLayout(state)
end

local function handleWindowLifecycle(state)
    refreshWorld(state)
end

local function pollPanFallback(state)
    refreshPanFromModifierState(state)
end

local function modifierFlagsChangedCallback(state)
    local pressed = panModifiersPressed(state)
    if not pressed then
        endPan(state)
    end
    return false
end

local function buildManager(config)
    local state = {
        core = CanvasCore.new(config),
        windowsById = {},
        pendingMoves = {},
        appliedFrames = {},
        activePanButton = nil,
        layoutDirty = false,
        lastMotionAt = 0,
        lastPointerLocation = nil,
        movementThreshold = 2,
        panModifiers = {cmd = true},
        modifierTap = nil,
        renderTimer = nil,
        renderHz = 60,
        screenWatcher = nil,
        pollTimer = nil,
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

    local wf = hs.window.filter.new(function(win)
        return isManagedWindow(win)
    end)

    local lifecycleEvents = {
        hs.window.filter.windowCreated,
        hs.window.filter.windowDestroyed,
        hs.window.filter.windowMinimized,
        hs.window.filter.windowUnminimized,
        hs.window.filter.windowVisible,
        hs.window.filter.windowNotVisible,
        hs.window.filter.windowFullscreened,
        hs.window.filter.windowUnfullscreened,
        hs.window.filter.windowAllowed,
        hs.window.filter.windowRejected,
    }

    wf:subscribe(lifecycleEvents, function()
        handleWindowLifecycle(state)
    end)

    wf:subscribe(hs.window.filter.windowMoved, function(win)
        if win ~= nil then
            handleManagedWindowMoved(state, win)
        end
    end)

    state.windowFilter = wf
    state.screenWatcher = hs.screen.watcher.new(function()
        refreshWorld(state)
    end)
    state.modifierTap = hs.eventtap.new({
        hs.eventtap.event.types.flagsChanged,
    }, function()
        return modifierFlagsChangedCallback(state)
    end)
    state.pollTimer = hs.timer.new(1 / 90, function()
        pollPanFallback(state)
    end)
    state.renderTimer = hs.timer.new(1 / state.renderHz, function()
        applyLayout(state)
    end)

    function state:start()
        self.screenWatcher:start()
        self.modifierTap:start()
        self.pollTimer:start()
        self.renderTimer:start()
        refreshWorld(self)
        log("started")
    end

    function state:stop()
        self.core:endPan()
        self.activePanButton = nil

        if self.pollTimer ~= nil then
            self.pollTimer:stop()
        end

        if self.renderTimer ~= nil then
            self.renderTimer:stop()
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

        self.pendingMoves = {}
        self.appliedFrames = {}
        log("stopped")
    end

    function state:debugState()
        return self.core:debugState()
    end

    return state
end

function window_manager.init(config)
    if manager ~= nil then
        return manager
    end

    manager = buildManager(config)
    manager:start()
    return manager
end

function window_manager.stop()
    if manager == nil then
        return
    end

    manager:stop()
    manager = nil
end

function window_manager.debugState()
    if manager == nil then
        return nil
    end

    return manager:debugState()
end

function window_manager.newCore(config)
    return CanvasCore.new(config)
end

function window_manager.rectEquals(left, right)
    return rectEquals(left, right)
end

function window_manager.setDebugLogging(enabled)
    window_manager.debugLogging = enabled == true
end

return window_manager
