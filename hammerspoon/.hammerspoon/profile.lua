local profileLogger = hs.logger.new('profile', 'debug')
local profileLogStartTimes = { }

-- Starts profiling `name`
function profileStart(name)
    profileLogStartTimes[name] = hs.timer.absoluteTime()
end

-- Stops profiling `name`
function profileStop(name)
    local now = hs.timer.absoluteTime()
    local delta = now - profileLogStartTimes[name]
    local deltaNormalized = delta / 1000000000.0
    local logString = name .. ': ' .. deltaNormalized .. 's'
    profileLogger.i(logString)
end

