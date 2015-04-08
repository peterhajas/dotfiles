require 'convenience'

-- Status Geometry

-- When drawing status information, it is useful to have metrics about where to
-- draw

function statusEdgePadding()
    return 10
end

function statusTextSize()
    return 15
end

function statusHeight()
    return statusTextSize() + 4
end

function statusFrameForXAndWidth (x, w)
    local screenFrame = preferredScreen():fullFrame()
    return hs.geometry.rect(x,
                            screenFrame.h - statusHeight() - statusEdgePadding(),
                            w,
                            statusHeight())
end

function statusTextColor()
    local statusTextColor = {}
    statusTextColor['red'] = 1.0
    statusTextColor['green'] = 1.0
    statusTextColor['blue'] = 1.0
    statusTextColor['alpha'] = 0.7
    return statusTextColor
end

