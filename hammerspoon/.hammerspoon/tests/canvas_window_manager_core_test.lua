package.path = package.path
    .. ";./?.lua"
    .. ";./tests/?.lua"

local window_manager = require("canvas_window_manager")

local function assertTrue(value, message)
    if not value then
        error(message or "expected true")
    end
end

local function assertFalse(value, message)
    if value then
        error(message or "expected false")
    end
end

local function assertEqual(actual, expected, message)
    if actual ~= expected then
        error((message or "values differ") .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
    end
end

local function assertRectClose(actual, expected, message)
    if not window_manager.rectEquals(actual, expected) then
        error((message or "rects differ")
            .. ": expected {x=" .. expected.x .. ", y=" .. expected.y .. ", w=" .. expected.w .. ", h=" .. expected.h
            .. "}, got {x=" .. actual.x .. ", y=" .. actual.y .. ", w=" .. actual.w .. ", h=" .. actual.h .. "}")
    end
end

local function runTest(name, fn)
    fn()
    io.write("ok - " .. name .. "\n")
end

runTest("keeps visible windows at physical positions with zero camera", function()
    local state = window_manager.newCore()
    state:setViewport({x = 0, y = 0, w = 1600, h = 900})
    state:setWindowFromPhysicalFrame("alpha", {x = 120, y = 80, w = 800, h = 600})

    local placement = state:getPlacements().alpha
    assertFalse(placement.parked)
    assertRectClose(placement.frame, {x = 120, y = 80, w = 800, h = 600})
end)

runTest("horizontal pan shifts x only and leaves y fixed", function()
    local state = window_manager.newCore()
    state:setViewport({x = 0, y = 0, w = 1600, h = 900})
    state:setWindowFromPhysicalFrame("alpha", {x = 120, y = 80, w = 500, h = 400})

    state:beginPan({x = 400, y = 300})
    state:updatePan({x = 460, y = 340})
    state:endPan()

    local camera = state:getCamera()
    assertEqual(camera.x, -60, "camera x")
    assertEqual(camera.y, 0, "camera y")

    local placement = state:getPlacements().alpha
    assertRectClose(placement.frame, {x = 180, y = 80, w = 500, h = 400})
end)

runTest("manual window move updates canvas position under non-zero camera", function()
    local state = window_manager.newCore()
    state:setViewport({x = 0, y = 0, w = 1600, h = 900})
    state:setWindowFromPhysicalFrame("alpha", {x = 100, y = 100, w = 400, h = 300})

    state:beginPan({x = 300, y = 300})
    state:updatePan({x = 500, y = 300})
    state:endPan()

    local beforeMove = state:getPlacements().alpha
    assertRectClose(beforeMove.frame, {x = 300, y = 100, w = 400, h = 300})

    state:setWindowFromPhysicalFrame("alpha", {x = 900, y = 250, w = 400, h = 300})
    local afterMove = state:getPlacements().alpha
    assertRectClose(afterMove.frame, {x = 900, y = 250, w = 400, h = 300})
    assertRectClose(afterMove.canvasFrame, {x = 700, y = 250, w = 400, h = 300})
end)

runTest("far away windows clamp to the edge while preserving hidden x", function()
    local state = window_manager.newCore({activationMargin = 100})
    state:setViewport({x = 0, y = 0, w = 1600, h = 900})
    state:setWindowFromPhysicalFrame("alpha", {x = 100, y = 100, w = 500, h = 400})

    state:beginPan({x = 0, y = 0})
    state:updatePan({x = -2200, y = -1600})
    state:endPan()

    local placement = state:getPlacements().alpha
    assertTrue(placement.parked)
    assertEqual(placement.parkingQuadrant, "west")
    assertRectClose(placement.frame, {x = -460, y = 100, w = 500, h = 400})
    assertEqual(placement.hiddenX, -1640)
end)

runTest("multiple offscreen windows clamp without strip jumping", function()
    local state = window_manager.newCore({activationMargin = 100, parkingStride = 60, parkingColumns = 2})
    state:setViewport({x = 0, y = 0, w = 1600, h = 900})
    state:setWindowFromPhysicalFrame("alpha", {x = 10, y = 10, w = 300, h = 200})
    state:setWindowFromPhysicalFrame("beta", {x = 20, y = 20, w = 300, h = 200})
    state:setWindowFromPhysicalFrame("gamma", {x = 30, y = 30, w = 300, h = 200})

    state:beginPan({x = 0, y = 0})
    state:updatePan({x = 1800, y = 1200})
    state:endPan()

    local placements = state:getPlacements()
    assertEqual(placements.alpha.parkingQuadrant, "east")
    assertRectClose(placements.alpha.frame, {x = 1560, y = 10, w = 300, h = 200})
    assertRectClose(placements.beta.frame, {x = 1560, y = 20, w = 300, h = 200})
    assertRectClose(placements.gamma.frame, {x = 1560, y = 30, w = 300, h = 200})
    assertEqual(placements.alpha.hiddenX, 250)
    assertEqual(placements.beta.hiddenX, 260)
    assertEqual(placements.gamma.hiddenX, 270)
end)

runTest("vertical drift alone does not park a window", function()
    local state = window_manager.newCore({activationMargin = 100})
    state:setViewport({x = 0, y = 0, w = 1600, h = 900})
    state:setWindowFromPhysicalFrame("alpha", {x = 200, y = -300, w = 400, h = 300})

    local placement = state:getPlacements().alpha
    assertFalse(placement.parked)
    assertRectClose(placement.frame, {x = 200, y = -300, w = 400, h = 300})
end)

runTest("windows return from parking once the camera comes back", function()
    local state = window_manager.newCore({activationMargin = 100})
    state:setViewport({x = 0, y = 0, w = 1600, h = 900})
    state:setWindowFromPhysicalFrame("alpha", {x = 200, y = 200, w = 400, h = 300})

    state:beginPan({x = 0, y = 0})
    state:updatePan({x = -2500, y = 0})
    state:endPan()

    assertTrue(state:getPlacements().alpha.parked)

    state:beginPan({x = 0, y = 0})
    state:updatePan({x = 2500, y = 0})
    state:endPan()

    local placement = state:getPlacements().alpha
    assertFalse(placement.parked)
    assertRectClose(placement.frame, {x = 200, y = 200, w = 400, h = 300})
end)

runTest("release keeps hidden canvas distance after edge clamp", function()
    local state = window_manager.newCore({activationMargin = 100})
    state:setViewport({x = 0, y = 0, w = 1600, h = 900})
    state:setWindowFromPhysicalFrame("alpha", {x = 200, y = 200, w = 400, h = 300})

    state:beginPan({x = 0, y = 0})
    state:updatePan({x = 2500, y = 0})
    state:endPan()

    local afterRelease = state:getPlacements().alpha
    assertRectClose(afterRelease.frame, {x = 1560, y = 200, w = 400, h = 300})
    assertEqual(afterRelease.hiddenX, 1140)
    assertRectClose(afterRelease.canvasFrame, {x = 200, y = 200, w = 400, h = 300})
end)

io.write("canvas_window_manager_core tests passed\n")
