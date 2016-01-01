hs.alert('hi')
local mouseMovedEventTap = hs.eventtap.new({hs.eventtap.event.types.mouseMoved}, function(event)
    hs.alert('event!')
    local properties = event:properties()
    local desc = hs.inspect.inspect(properties)
    hs.alert(desc)
end)

mouseMovedEventTap:start()
