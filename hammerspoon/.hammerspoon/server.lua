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
    ["shortcuts"] = function(args) hs.execute("shortcuts run \"" .. args["name"] .. "\"") end,
    ["tw_publish"] = function() hs.execute("~/bin/tiddlywiki_public", true) end,
    ["tw_glance"] = function(args, body)
        bodyTable = hs.json.decode(body)
        local tiddler = bodyTable["tiddler"]
        if tiddler ~= nil then
            SendGlanceToTiddler(tiddler)
        end
    end,
}

-- Returns true if parsed correctly, false otherwise
function parseHTTPCommand(cmd, headers, contents)
    local components = split(cmd, "?")
    local command = components[1]
    arguments = {}
    if components[2] ~= nil then
        local args = components[2]
        args = url_decode(args)
        local argElements = split(args, "&")
        for _, v in pairs(argElements) do
            argName = split(v, "=")[1]
            argValue = split(v, "=")[2]
            arguments[argName] = argValue
        end
    end
    local func = commandToFunction[command]
    if func ~= nil then
        local output = func(arguments, contents)
        if output ~= nil then
            return true, output
        else
            return true, ""
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
    success, output = parseHTTPCommand(command, headers, contents)
    if success == false then
        return "An error occurred", 400, additionalHeaders
    end

    return output, 200, additionalHeaders
end)
:start()

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
