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

    ["tw_publish"] = function() hs.execute("~/bin/tiddlywiki_public", true) end
}

-- Returns true if parsed correctly, false otherwise
function parseHTTPCommand(cmd)
    local func = commandToFunction[cmd]
    if func ~= nil then
        local output = func()
        if output ~= nil then
            return true, output
        else
            return true, "OK"
        end
    end
    hs.application.open(cmd)
    return false, nil
end

server = hs.httpserver.new()
:setPort(port)
:setCallback(function(requestType, path, headers, contents)
    local additionalHeaders = {
        ["Access-Control-Allow-Origin"] = "*"
    }

    command = path:sub(2)
    success, output = parseHTTPCommand(command)
    if success == false then
        return "An error occurred", 400, additionalHeaders
    end

    return output, 200, additionalHeaders
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
