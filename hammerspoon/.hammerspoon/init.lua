-- peterhajas's Hammerspoon config file
-- Originally written Jan 4, 2015

require 'base'

require 'hyper'
require 'hyper_hotkeys'
require 'window_manipulation'

require 'app_shortcuts'
require 'key_remap'
require 'itunes'
require 'flux'

require 'timer'
require 'app_watching'
require 'battery_watching'

-- I can reload the config when this file changes. From:
-- http://www.hammerspoon.org/go/#fancyreload

function reload_config(files)
    destroyiTunesTrackDisplay()
    appWatcher:stop()
    timer:stop()
    batteryWatcher:stop()
    hs.reload()
end
hs.pathwatcher.new(os.getenv("HOME") .. "/.hammerspoon/", reload_config):start()
hs.alert.show("Config loaded")

