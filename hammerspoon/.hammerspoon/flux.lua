-- F.lux Functionality

function whitepointForHavingScreenTint(hasScreenTint)
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

function blackpointForHavingScreenTint(hasScreenTint)
    local blackpoint = { }
    blackpoint['alpha'] = 1
    blackpoint['blue'] = 0
    blackpoint['green'] = 0
    blackpoint['red'] = 0

    return blackpoint
end

function updateFluxiness()
    local location = hs.location.get()
    local latitude = location['latitude']
    local longitude = location['longitude']
    local timestamp = location['timestamp']

    local sunriseTime = hs.location.sunrise(latitude, longitude, 0)
    local sunsetTime = hs.location.sunset(latitude, longitude, 0)

    local sunHasRisenToday
    local sunHasSetToday

    if type(sunriseTime) == 'string' and sunriseTime == 'N/R' then
        sunHasRisenToday = false
    else
        sunHasRisenToday = timestamp > sunriseTime
    end

    if type(sunsetTime) == 'string' and sunsetTime == 'N/S' then
        sunHasSetToday = false
    else
        sunHasSetToday = timestamp > sunsetTime
    end

    local shouldTintScreen = false

    -- If the sun has risen but has not set, disable the screen tint

    if sunHasRisenToday and not sunHasSetToday then shouldTintScreen = false end

    -- If the sun has risen and has set, enable the screen tint

    if sunHasRisenToday and sunHasSetToday then shouldTintScreen = true end

    -- If the sun has not yet risen, enable the screen tint

    if not sunHasRisenToday then shouldTintScreen = true end

    -- Determine the gamma to set on our displays

    local whitepoint = whitepointForHavingScreenTint(shouldTintScreen)
    local blackpoint = blackpointForHavingScreenTint(shouldTintScreen)
    
    local screens = hs.screen.allScreens()

    for i,screen in next,screens do
        local screenGamma = screen:getGamma()
        
        if (screenGamma['whitepoint'] ~= whitepoint) or (screenGamma['blackpoint'] ~= blackpoint) then
            screen:setGamma(whitepoint, blackpoint)
        end
    end
end

updateFluxiness()
