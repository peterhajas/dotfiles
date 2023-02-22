require "util"

local port = 8044

commandToFunction = {
    ["lock"] = function() hs.caffeinate.lockScreen() end,

    ["fullscreen"] = function() hs.window.frontmostWindow():toggleFullScreen() end,
    ["zoom"] = function() hs.window.frontmostWindow():toggleZoom() end,
    ["minimize"] = function() hs.window.frontmostWindow():minimize() end,
    ["close"] = function() hs.window.frontmostWindow():close() end,

    ["quit"] = function() hs.application.frontmostApplication():kill() end,
    ["kill"] = function() hs.application.frontmostApplication():kill() end,
    ["hide"] = function() hs.application.frontmostApplication():hide() end,

    ["up"] = function() hs.eventtap.keyStroke({}, "up") end,
    ["down"] = function() hs.eventtap.keyStroke({}, "down") end,
    ["left"] = function() hs.eventtap.keyStroke({}, "left") end,
    ["right"] = function() hs.eventtap.keyStroke({}, "right") end,
    ["pageup"] = function() hs.eventtap.keyStroke({}, "pageup") end,
    ["pagedown"] = function() hs.eventtap.keyStroke({}, "pagedown") end,
    ["space"] = function() hs.eventtap.keyStroke({}, "space") end,
    ["return"] = function() hs.eventtap.keyStroke({}, "return") end,
}

-- Returns true if parsed correctly, false otherwise
function parseHTTPCommand(cmd)
    local func = commandToFunction[cmd]
    if func ~= nil then
        func()
        return true
    end
    hs.application.open(cmd)
    return true
end

server = hs.httpserver.new()
:setPort(port)
:setCallback(function(requestType, path, headers, contents)
    local body = "OK"
    local responseCode = 200
    local additionalHeaders = {}

    command = path:sub(2)
    if parseHTTPCommand(command) == false then
        body = "FAIL"
        responseCode = 400
    end

    return body, responseCode, additionalHeaders
end)
:start()

dbg(server)

function printHomeAssistantYAML(host)
    out = "\n"
    out = out .. "rest_command:\n"
    for name, _ in pairs(commandToFunction) do
        out = out .. "  " .. "hammerspoon_" .. name .. ":\n"
        out = out .. "    url: \"" .. host .. ":" .. port .. "/" .. name .. "\"\n"
        out = out .. "    method: GET\n"
    end
    print(out)
end
