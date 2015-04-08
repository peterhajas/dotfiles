-- Global Update Timer

-- For all sorts of reasons, it's convenient to have a timer that's always
-- running. We'll keep it at a pretty infrequent ten seconds (and terminate it
-- if the battery is too low)

function timerUpdate()
    updateiTunesTrackDisplay()
    updateFluxiness()
end

timer = hs.timer.new(10, timerUpdate)
timer:start()

