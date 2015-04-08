require 'itunes'

-- Application Watching

-- Our global app watcher which will watch for app changes

function handleAppEvent(name, event, app)
    if name == 'iTunes' then updateiTunesTrackDisplay() end
end

appWatcher = hs.application.watcher.new(handleAppEvent)
appWatcher:start()

