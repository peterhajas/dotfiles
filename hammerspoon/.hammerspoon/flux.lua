-- F.lux Functionality Module
-- Provides automatic screen color temperature adjustment based on time of day

local flux = {}
local fluxStateKey = "flux.lastEnabled"
local fluxLocationKey = "flux.lastLocation"

-- Private helper functions

local function whitepointForHavingScreenTint(hasScreenTint)
    local whitepoint = { }
    if hasScreenTint then
        -- I copied these values from hs.screen:getGamma() while running f.lux

        whitepoint['blue'] = 0.5240478515625
        whitepoint['green'] = 0.76902770996094
        -- More intense warm tint for nighttime
        -- whitepoint['blue'] = whitepoint['blue']/2
        -- whitepoint['green'] = whitepoint['green']/2
        whitepoint['red'] = 1
    else
        whitepoint['blue'] = 1
        whitepoint['green'] = 1
        whitepoint['red'] = 1
    end

    return whitepoint
end

local function blackpointForHavingScreenTint(hasScreenTint)
    local blackpoint = { }
    blackpoint['alpha'] = 1
    blackpoint['blue'] = 0
    blackpoint['green'] = 0
    blackpoint['red'] = 0

    return blackpoint
end

-- Our override flux setting, if any
-- Optional boolean
local overrideFluxSetting = nil
local lastKnownLocation = hs.settings.get(fluxLocationKey)
local lastKnownFluxEnabled = hs.settings.get(fluxStateKey)
if type(lastKnownFluxEnabled) ~= "boolean" then
    lastKnownFluxEnabled = nil
end

local function fluxShouldBeEnabledForLocation(location)
    if location == nil then
        return nil
    end
    local latitude = location['latitude']
    local longitude = location['longitude']
    if latitude == nil or longitude == nil then
        return nil
    end
    local now = os.time()

    local sunriseTime = hs.location.sunrise(latitude, longitude, -7)
    local sunsetTime = hs.location.sunset(latitude, longitude, -7)

    local nowDay = os.date("*t").day
    local sunriseDay = os.date("*t", sunriseTime).day
    local sunsetDay = os.date("*t", sunsetTime).day

    local sunHasRisenToday
    local sunHasSetToday

    if type(sunriseTime) == 'string' and sunriseTime == 'N/R' then
        sunHasRisenToday = false
    else
        sunHasRisenToday = ((now > sunriseTime) and (nowDay == sunriseDay))
    end

    if type(sunsetTime) == 'string' and sunsetTime == 'N/S' then
        sunHasSetToday = false
    else
        sunHasSetToday = ((now > sunsetTime) and (nowDay == sunsetDay))
    end

    local shouldBeEnabled = false

    -- If the sun has risen but has not set, disable the screen tint

    if sunHasRisenToday and not sunHasSetToday then shouldBeEnabled = false end

    -- If the sun has risen and has set, enable the screen tint

    if sunHasRisenToday and sunHasSetToday then shouldBeEnabled = true end

    -- If the sun has not yet risen, enable the screen tint

    if not sunHasRisenToday then shouldBeEnabled = true end

    return shouldBeEnabled
end

local function fallbackFluxEnabled()
    if type(lastKnownFluxEnabled) == "boolean" then
        return lastKnownFluxEnabled
    end
    -- Reasonable fallback until location callbacks arrive.
    local hour = tonumber(os.date("%H")) or 12
    return (hour < 7 or hour >= 19)
end

local function shouldHaveFluxEnabled()
    if overrideFluxSetting == nil then
        local computed = fluxShouldBeEnabledForLocation(lastKnownLocation)
        if computed == nil then
            return fallbackFluxEnabled()
        end
        lastKnownFluxEnabled = computed
        hs.settings.set(fluxStateKey, computed)
        return computed
    end

    return overrideFluxSetting
end

-- Updates the flux setting to `shouldBeEnabled`
local function updateFluxinessEnabled(shouldBeEnabled)
    -- Determine the gamma to set on our displays

    local whitepoint = whitepointForHavingScreenTint(shouldBeEnabled)
    local blackpoint = blackpointForHavingScreenTint(shouldBeEnabled)
    
    local screens = hs.screen.allScreens()

    for i,screen in next,screens do
        local screenGamma = screen:getGamma()
        screen:setGamma(whitepoint, blackpoint)
    end
end

local function updateFluxiness()
    updateFluxinessEnabled(shouldHaveFluxEnabled())
end

local function fluxSignificantTimeDidChange()
    overrideFluxSetting = nil
    updateFluxiness()
end

-- Function for flux toggle setting

local function fluxAdvance()
    local onNow = shouldHaveFluxEnabled()
    -- Determine new state
    if overrideFluxSetting == nil then
        overrideFluxSetting = not onNow
    elseif overrideFluxSetting == true then
        overrideFluxSetting = false
    else
        overrideFluxSetting = nil
    end

    local overrideNewStateName = "?"
    if overrideFluxSetting == true then
        overrideNewStateName = "TO ON"
    elseif overrideFluxSetting == false then
        overrideNewStateName = "TO OFF"
    else
        overrideNewStateName = "<nil>"
    end

    hs.alert("flux override " .. overrideNewStateName)

    updateFluxiness()
end

-- Module state
local fluxScreenWatcher = nil
local fluxTimer = nil
local locationObserver = nil

-- Public API

-- Initialize the flux module
function flux.init()
    -- Set up screen watcher to update when screens change.
    -- Delay the re-apply so a freshly-connected display has finished
    -- settling before we push gamma (otherwise macOS overwrites it).
    fluxScreenWatcher = hs.screen.watcher.new(function()
        updateFluxiness()
        hs.timer.doAfter(2, updateFluxiness)
    end)
    fluxScreenWatcher:start()

    -- Set up location observer to update when location changes
    locationObserver = hs.location.new()
    locationObserver:callback(function(obj, msg, data)
        if msg == "didUpdateLocations" then
            if type(data) == "table" and #data > 0 and type(data[1]) == "table" then
                lastKnownLocation = data[1]
            elseif type(data) == "table" and data["latitude"] ~= nil then
                lastKnownLocation = data
            end
            if lastKnownLocation ~= nil then
                hs.settings.set(fluxLocationKey, lastKnownLocation)
            end
            updateFluxiness()
        elseif msg == "didChangeAuthorizationStatus" then
            updateFluxiness()
        end
    end)
    locationObserver:startTracking()

    -- Set up a timer to check flux status every 5 minutes (300 seconds)
    fluxTimer = hs.timer.doEvery(300, function()
        updateFluxiness()
    end)

    -- Apply initial flux settings
    updateFluxiness()
end

-- Toggle flux override setting
function flux.advance()
    fluxAdvance()
end

-- Reset flux on significant time changes (e.g., after sleep/wake)
function flux.significantTimeDidChange()
    fluxSignificantTimeDidChange()
end

-- Manually update flux (useful for external triggers)
function flux.update()
    updateFluxiness()
end

return flux
