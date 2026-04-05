require "util"

local port = 8044
local secretHeaderName = "X-Hammerspoon-Secret"
local sharedSecretTiddler = "Hammerspoon Server Shared Secret"
local wikiPath = os.getenv("HOME") .. "/phajas-wiki/phajas-wiki.html"
local twBinary = os.getenv("HOME") .. "/dotfiles/tiddlywiki/bin/tw"

local function trim(value)
    if value == nil then
        return nil
    end
    return tostring(value):match("^%s*(.-)%s*$")
end

local function shellQuote(value)
    return "'" .. tostring(value):gsub("'", "'\\''") .. "'"
end

local function wikiGetText(title)
    local command = shellQuote(twBinary) .. " " .. shellQuote(wikiPath) .. " get " .. shellQuote(title) .. " text"
    local output, success = hs.execute(command, true)
    if not success then
        return nil
    end
    return trim(output)
end

local function getHeaderValue(headers, targetName)
    local wanted = string.lower(targetName)
    for name, value in pairs(headers or {}) do
        if string.lower(tostring(name)) == wanted then
            return tostring(value)
        end
    end
    return nil
end

local function commandUsesGet(command)
    return command == "widgets"
end

local commandToFunction = {
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
    ["shortcuts"] = function(args)
        local input = args["input"]
        if input == nil then
            input = ""
        end

        local function applescript_escape(str)
            if str == nil then return "" end
            str = str:gsub("\\", "\\\\")
            str = str:gsub("\"", "\\\"")
            return str
        end

        local shortcutName = args["name"]
        if shortcutName == nil or shortcutName == "" then
            error("missing shortcut name")
        end

        local escaped_name = applescript_escape(shortcutName)
        local escaped_input = applescript_escape(input)

        local applescript = 'tell application "Shortcuts Events" to run shortcut "' .. escaped_name .. '" with input "' .. escaped_input .. '"'
        local success, output, rawTable = hs.osascript.applescript(applescript)

        local result = nil
        if success then
            if type(output) == "string" then
                result = output
            elseif type(output) == "table" then
                if output[1] ~= nil then
                    result = tostring(output[1])
                else
                    result = hs.json.encode(output)
                end
            else
                result = tostring(output)
            end
        else
            error(tostring(rawTable))
        end

        return result
    end,
    ["tw_glance"] = function(args, body)
        local bodyTable = hs.json.decode(body or "")
        if type(bodyTable) ~= "table" then
            error("invalid JSON body")
        end

        local tiddler = bodyTable["tiddler"]
        if tiddler ~= nil then
            SendGlanceToTiddler(tiddler)
        end
    end,
    ["widgets"] = function()
        local out = { }
        local app = hs.application.find("Notification Center")
        if app == nil then
            return hs.json.encode(out)
        end

        local appWindows = app:allWindows()
        table.sort(appWindows, function(a, b)
            local aX = a:frame().x
            local bX = b:frame().x
            local aY = a:frame().y
            local bY = b:frame().y
            if aX ~= bX then
                return aX < bX
            end
            if aY ~= bY then
                return aY < bY
            end
            return aX + aY < bX + bY
        end)
        for _, window in pairs(appWindows) do
            if window:frame().w == 180 then
                local snap = window:snapshot(true)
                if snap ~= nil then
                    table.insert(out, {
                        ["image"] = snap:encodeAsURLString(),
                    })
                end
            end
        end
        return hs.json.encode(out)
    end,
}

local function parseArguments(cmd)
    local components = split(cmd, "?")
    local command = components[1]
    local arguments = {}

    if components[2] ~= nil then
        local args = url_decode(components[2])
        local argElements = split(args, "&")
        for _, value in pairs(argElements) do
            local eqPos = value:find("=")
            if eqPos then
                local argName = value:sub(1, eqPos - 1)
                local argValue = value:sub(eqPos + 1)
                arguments[argName] = argValue
            end
        end
    end

    return command, arguments
end

local function logCommand(cmd, success)
    local components = split(cmd, "?")
    local command = components[1]
    if command ~= "widgets" then
        local outSuccessDescription = "false"
        if success then
            outSuccessDescription = "true"
        end
        dbg("ran " .. cmd .. " successfully " .. outSuccessDescription)
    end
end

local function parseHTTPCommand(requestType, cmd, headers, contents)
    local command, arguments = parseArguments(cmd)
    if command == nil or command == "" then
        return false, "Missing command", 404
    end

    local func = commandToFunction[command]
    if func == nil then
        return false, "Unknown command", 404
    end

    local sharedSecret = wikiGetText(sharedSecretTiddler)
    if sharedSecret == nil or sharedSecret == "" then
        dbg("server shared secret missing")
        return false, "Server secret unavailable", 503
    end

    local providedSecret = getHeaderValue(headers, secretHeaderName)
    if providedSecret ~= sharedSecret then
        return false, "Unauthorized", 401
    end

    local expectedMethod = commandUsesGet(command) and "GET" or "POST"
    if requestType ~= expectedMethod then
        return false, "Method Not Allowed", 405
    end

    local ok, output = pcall(func, arguments, contents)
    logCommand(cmd, ok)
    if not ok then
        dbg("server error for " .. cmd .. ": " .. tostring(output))
        return false, "An error occurred", 500
    end

    if output == nil then
        output = ""
    end
    return true, output, 200
end

local corsHeaders = {
    ["Access-Control-Allow-Origin"] = "*",
    ["Access-Control-Allow-Methods"] = "GET, POST, OPTIONS",
    ["Access-Control-Allow-Headers"] = secretHeaderName .. ", X-Requested-With",
}

server = hs.httpserver.new(false, false)
:setInterface("localhost")
:setPort(port)
:setCallback(function(requestType, path, headers, contents)
    if requestType == "OPTIONS" then
        return "", 204, corsHeaders
    end

    local command = path:sub(2)
    local success, output, statusCode = parseHTTPCommand(requestType, command, headers, contents)
    return output, statusCode, corsHeaders
end)
:start()

function printHomeAssistantYAML(host)
    local out = "\n"
    out = out .. "rest_command:\n"
    for name, _ in pairs(commandToFunction) do
        out = out .. "  hammerspoon_" .. name .. ":\n"
        out = out .. "    url: \"" .. host .. ":" .. port .. "/" .. name .. "\"\n"
        out = out .. "    method: " .. (commandUsesGet(name) and "GET" or "POST") .. "\n"
    end
    print(out)
end
