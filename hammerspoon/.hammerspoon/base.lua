-- Declare a global 'doc' variable that I can use inside of the Hammerspoon
-- console

doc = hs.doc.fromJSONFile(hs.docstrings_json_file)

-- Begin Monitoring for Location Events

local startedMonitoringLocation = hs.location.start()

if startedMonitoringLocation == false then
    hs.alert.show("Unable to determine location - please approve Hammerspoon to access your location")
end

