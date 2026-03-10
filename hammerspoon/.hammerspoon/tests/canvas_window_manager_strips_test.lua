package.path = package.path
    .. ";./?.lua"
    .. ";./tests/?.lua"

local strip_tiler = require("canvas_window_manager_strips")

local function assertTrue(value, message)
    if not value then
        error(message or "expected true")
    end
end

local function assertEqual(actual, expected, message)
    if actual ~= expected then
        error((message or "values differ") .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
    end
end

local function assertRectClose(actual, expected, message)
    if not strip_tiler.rectEquals(actual, expected) then
        error((message or "rects differ")
            .. ": expected {x=" .. expected.x .. ", y=" .. expected.y .. ", w=" .. expected.w .. ", h=" .. expected.h
            .. "}, got {x=" .. actual.x .. ", y=" .. actual.y .. ", w=" .. actual.w .. ", h=" .. actual.h .. "}")
    end
end

local function runTest(name, fn)
    fn()
    io.write("ok - " .. name .. "\n")
end

runTest("lays out windows as full-height horizontal strips", function()
    local state = strip_tiler.newCore()
    state:setViewport({x = 0, y = 0, w = 1600, h = 900})
    state:setWindowFromPhysicalFrame("a", {x = 10, y = 10, w = 300, h = 200})
    state:setWindowFromPhysicalFrame("b", {x = 20, y = 20, w = 500, h = 300})

    local placements = state:getPlacements()
    assertRectClose(placements.a.frame, {x = 0, y = 0, w = 300, h = 900})
    assertRectClose(placements.b.frame, {x = 300, y = 0, w = 500, h = 900})
end)

runTest("horizontal pan moves strip x only", function()
    local state = strip_tiler.newCore()
    state:setViewport({x = 0, y = 0, w = 1600, h = 900})
    state:setWindowFromPhysicalFrame("a", {x = 10, y = 10, w = 300, h = 200})

    state:beginPan({x = 500, y = 400})
    state:updatePan({x = 700, y = 200})
    state:endPan()

    local placements = state:getPlacements()
    assertRectClose(placements.a.frame, {x = 200, y = 0, w = 300, h = 900})
    assertEqual(state:getCamera().x, -200)
    assertEqual(state:getCamera().y, 0)
end)

runTest("right-edge resize grows to the right", function()
    local state = strip_tiler.newCore()
    state:setViewport({x = 0, y = 0, w = 1600, h = 900})
    state:setWindowFromPhysicalFrame("a", {x = 0, y = 0, w = 300, h = 900})
    state:setWindowFromPhysicalFrame("b", {x = 300, y = 0, w = 400, h = 900})
    state:setWindowFromPhysicalFrame("c", {x = 700, y = 0, w = 500, h = 900})

    local placements = state:getPlacements()
    state:applyResize("b", {x = 300, y = 100, w = 550, h = 400}, placements.b.frame)

    local after = state:getPlacements()
    assertRectClose(after.a.frame, {x = 0, y = 0, w = 300, h = 900})
    assertRectClose(after.b.frame, {x = 300, y = 0, w = 550, h = 900})
    assertRectClose(after.c.frame, {x = 850, y = 0, w = 500, h = 900})
end)

runTest("right-edge resize shrinking pulls right neighbors left", function()
    local state = strip_tiler.newCore()
    state:setViewport({x = 0, y = 0, w = 1600, h = 900})
    state:setWindowFromPhysicalFrame("a", {x = 0, y = 0, w = 300, h = 900})
    state:setWindowFromPhysicalFrame("b", {x = 300, y = 0, w = 400, h = 900})
    state:setWindowFromPhysicalFrame("c", {x = 700, y = 0, w = 500, h = 900})

    local placements = state:getPlacements()
    state:applyResize("b", {x = 300, y = 100, w = 250, h = 400}, placements.b.frame)

    local after = state:getPlacements()
    assertRectClose(after.a.frame, {x = 0, y = 0, w = 300, h = 900})
    assertRectClose(after.b.frame, {x = 300, y = 0, w = 250, h = 900})
    assertRectClose(after.c.frame, {x = 550, y = 0, w = 500, h = 900})
end)

runTest("left-edge resize grows to the left", function()
    local state = strip_tiler.newCore()
    state:setViewport({x = 0, y = 0, w = 1600, h = 900})
    state:setWindowFromPhysicalFrame("a", {x = 0, y = 0, w = 300, h = 900})
    state:setWindowFromPhysicalFrame("b", {x = 300, y = 0, w = 400, h = 900})
    state:setWindowFromPhysicalFrame("c", {x = 700, y = 0, w = 500, h = 900})

    local placements = state:getPlacements()
    state:applyResize("b", {x = 150, y = 100, w = 550, h = 400}, placements.b.frame)

    local after = state:getPlacements()
    assertRectClose(after.a.frame, {x = -150, y = 0, w = 300, h = 900})
    assertRectClose(after.b.frame, {x = 150, y = 0, w = 550, h = 900})
    assertRectClose(after.c.frame, {x = 700, y = 0, w = 500, h = 900})
    assertEqual(after.a.parkingQuadrant, nil)
    assertEqual(after.a.hiddenX, 0)
end)

runTest("center resize splits displacement both ways", function()
    local state = strip_tiler.newCore()
    state:setViewport({x = 0, y = 0, w = 1600, h = 900})
    state:setWindowFromPhysicalFrame("a", {x = 0, y = 0, w = 300, h = 900})
    state:setWindowFromPhysicalFrame("b", {x = 300, y = 0, w = 400, h = 900})
    state:setWindowFromPhysicalFrame("c", {x = 700, y = 0, w = 500, h = 900})

    local placements = state:getPlacements()
    state:applyResize("b", {x = 225, y = 100, w = 550, h = 400}, placements.b.frame)

    local after = state:getPlacements()
    assertRectClose(after.a.frame, {x = -75, y = 0, w = 300, h = 900})
    assertRectClose(after.b.frame, {x = 225, y = 0, w = 550, h = 900})
    assertRectClose(after.c.frame, {x = 775, y = 0, w = 500, h = 900})
    assertEqual(after.a.parkingQuadrant, nil)
    assertEqual(after.a.hiddenX, 0)
end)

runTest("offscreen windows clamp but preserve hidden distance", function()
    local state = strip_tiler.newCore()
    state:setViewport({x = 0, y = 0, w = 1600, h = 900})
    state:setWindowFromPhysicalFrame("a", {x = 0, y = 0, w = 1700, h = 900})
    state:setWindowFromPhysicalFrame("b", {x = 800, y = 0, w = 900, h = 900})

    local placements = state:getPlacements()
    assertTrue(placements.b.parked)
    assertEqual(placements.b.parkingQuadrant, "east")
    assertRectClose(placements.b.frame, {x = 1560, y = 0, w = 900, h = 900})
    assertEqual(placements.b.hiddenX, 140)
end)

runTest("focused offscreen window scrolls into view", function()
    local state = strip_tiler.newCore()
    state:setViewport({x = 0, y = 0, w = 1600, h = 900})
    state:setWindowFromPhysicalFrame("a", {x = 0, y = 0, w = 1000, h = 900})
    state:setWindowFromPhysicalFrame("b", {x = 1000, y = 0, w = 1000, h = 900})
    state:setWindowFromPhysicalFrame("c", {x = 2000, y = 0, w = 1000, h = 900})

    local before = state:getPlacements()
    assertTrue(before.c.parked)

    assertTrue(state:ensureVisible("c"))

    local after = state:getPlacements()
    assertRectClose(after.c.frame, {x = 600, y = 0, w = 1000, h = 900})
    assertEqual(after.c.hiddenX, 0)
end)

io.write("canvas_window_manager_strips tests passed\n")
