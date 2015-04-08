-- Battery Watching

-- Our global battery watcher which will watch for battery events

function handleBatteryEvent()
    local isDraining = true

    if hs.battery.powerSource() == 'AC Power' then isDraining = false end
    if hs.battery.powerSource() == nil then isDraining = false end

    local isLow = isDraining and (hs.battery.percentage() < 10)

    if isLow then
        appWatcher:stop()
        timer:stop()
    else
        appWatcher:start()
        timer:start()
    end
end

batteryWatcher = hs.battery.watcher.new(handleBatteryEvent)
batteryWatcher:start()

