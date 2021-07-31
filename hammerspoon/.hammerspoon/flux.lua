require "hyper"
require "util"

-- F.lux Functionality {{{

local function whitepointForHavingScreenTint(hasScreenTint)
    local whitepoint = { }
    if hasScreenTint then
        -- I copied these values from hs.screen:getGamma() while running f.lux

        whitepoint['blue'] = 0.5240478515625
        whitepoint['green'] = 0.76902770996094
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

local function fluxShouldBeEnabledForLocation()
    local location = hs.location.get()

    if location == nil then return end
    local latitude = location['latitude']
    local longitude = location['longitude']
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

local function shouldHaveFluxEnabled()
    if overrideFluxSetting == nil then
        return fluxShouldBeEnabledForLocation()
    end

    return overrideFluxSetting
end

-- Updates the flux setting to `shouldBeEnabled`
function updateFluxinessEnabled(shouldBeEnabled)
    -- Determine the gamma to set on our displays

    local whitepoint = whitepointForHavingScreenTint(shouldBeEnabled)
    local blackpoint = blackpointForHavingScreenTint(shouldBeEnabled)
    
    local screens = hs.screen.allScreens()

    for i,screen in next,screens do
        local screenGamma = screen:getGamma()
        
        if (screenGamma['whitepoint'] ~= whitepoint) or (screenGamma['blackpoint'] ~= blackpoint) then
            screen:setGamma(whitepoint, blackpoint)
        end
    end
end

function updateFluxiness()
    updateFluxinessEnabled(shouldHaveFluxEnabled())
end

function fluxSignificantTimeDidChange()
    overrideFluxSetting = nil
    updateFluxiness()
end

-- Bindings for flux toggle setting

hs.hotkey.bind(hyper, "f", function()
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
end)

