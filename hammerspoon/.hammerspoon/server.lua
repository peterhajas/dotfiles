require "util"

local port = 8044
local secretHeaderName = "X-Hammerspoon-Secret"
local sharedSecretTiddler = "Hammerspoon Server Shared Secret"
local wikiPath = os.getenv("HOME") .. "/phajas-wiki/phajas-wiki.html"
local twBinary = os.getenv("HOME") .. "/dotfiles/tiddlywiki/bin/tw"

-- Anti-DNS-rebinding: a Host header outside this set means the request
-- came in through a hostname we don't serve, which is the rebinding
-- attack shape (browser tricked into sending example.com → 127.0.0.1).
local allowedHosts = {
    ["localhost:" .. port] = true,
    ["127.0.0.1:" .. port] = true,
    ["[::1]:" .. port] = true,
}

local function hostIsAllowed(headerValue)
    if headerValue == nil then return false end
    -- Host headers are case-insensitive per RFC and may carry a trailing
    -- dot on the hostname (e.g. "localhost.:8044" — DNS-valid, resolves
    -- to loopback). Normalize before lookup.
    local lowered = string.lower(headerValue)
    lowered = lowered:gsub("%.:", ":")
    return allowedHosts[lowered] == true
end

-- Allowlist of browser Origins permitted to talk to us. The TW HUD is
-- loaded via `hs.webview:html()`, which gives it Origin: null. The
-- secret-header check is still the auth boundary — any page from an
-- allowlisted origin still needs the secret to do anything useful.
local allowedOrigins = {
    ["null"] = true,
}

local function corsHeadersFor(origin)
    -- Echo back the specific origin; never wildcard, since wildcard
    -- would let any page read responses if it ever got past the secret.
    return {
        ["Access-Control-Allow-Origin"] = origin,
        ["Access-Control-Allow-Methods"] = "GET, POST, OPTIONS",
        ["Access-Control-Allow-Headers"] = secretHeaderName,
        ["Access-Control-Max-Age"] = "600",
        ["Vary"] = "Origin",
    }
end

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

-- Cached at load so we don't shell out to `tw` on every request. Rotate
-- by editing the tiddler then `hs.reload()`.
local cachedSecret = wikiGetText(sharedSecretTiddler)
if cachedSecret == "" then cachedSecret = nil end
if cachedSecret == nil then
    dbg("Hammerspoon server: shared secret missing; all requests will be rejected")
end

local function constantTimeEquals(a, b)
    if type(a) ~= "string" or type(b) ~= "string" then return false end
    if #a ~= #b then return false end
    local diff = 0
    for i = 1, #a do
        diff = diff | (string.byte(a, i) ~ string.byte(b, i))
    end
    return diff == 0
end

local function commandUsesGet(command)
    return command == "widgets" or command == "dictation"
end

local commandToFunction = {
    ["lock"] = function() hs.caffeinate.lockScreen() end,

    ["fullscreen"] = function() hs.window.frontmostWindow():toggleFullScreen() end,
    ["zoom"] = function() hs.window.frontmostWindow():toggleZoom() end,
    ["minimize"] = function() hs.window.frontmostWindow():minimize() end,
    ["close"] = function() hs.window.frontmostWindow():close() end,

    ["dictation"] = function() dictation.toggle() end,

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

        -- AppleScript string literals accept \n \r \t but reject raw
        -- newlines, so a bare LF in `name` or `input` would terminate
        -- the literal and allow arbitrary AppleScript injection.
        local function applescript_escape(str)
            if str == nil then return "" end
            str = str:gsub("\\", "\\\\")
            str = str:gsub("\"", "\\\"")
            str = str:gsub("\r", "\\r")
            str = str:gsub("\n", "\\n")
            str = str:gsub("\t", "\\t")
            return str
        end

        local shortcutName = args["name"]
        if shortcutName == nil or shortcutName == "" then
            error("missing shortcut name")
        end
        -- Shortcut names can't contain control characters; refuse rather
        -- than escape so a typo doesn't silently run the wrong shortcut.
        if shortcutName:find("%c") then
            error("shortcut name contains control characters")
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
        -- Decode per-component so a percent-encoded `&` or `=` inside a
        -- value can't smuggle in extra arguments.
        local argElements = split(components[2], "&")
        for _, pair in pairs(argElements) do
            local eqPos = pair:find("=")
            if eqPos then
                local argName = url_decode(pair:sub(1, eqPos - 1))
                local argValue = url_decode(pair:sub(eqPos + 1))
                arguments[argName] = argValue
            end
        end
    end

    return command, arguments
end

local function logCommand(command, success)
    if command == "widgets" then return end
    dbg("ran " .. command .. " successfully " .. (success and "true" or "false"))
end

local function parseHTTPCommand(requestType, cmd, headers, contents)
    -- Authenticate before any command-table lookup so an unauthenticated
    -- caller can't enumerate command names by 404-probing. Host and
    -- Origin validation already ran in the HTTP callback.
    if cachedSecret == nil then
        return false, "Server secret unavailable", 503
    end
    local providedSecret = getHeaderValue(headers, secretHeaderName)
    if not constantTimeEquals(providedSecret or "", cachedSecret) then
        return false, "Unauthorized", 401
    end

    local command, arguments = parseArguments(cmd)
    if command == nil or command == "" then
        return false, "Missing command", 404
    end

    local func = commandToFunction[command]
    if func == nil then
        return false, "Unknown command", 404
    end

    local expectedMethod = commandUsesGet(command) and "GET" or "POST"
    if requestType ~= expectedMethod then
        return false, "Method Not Allowed", 405
    end

    local ok, output = pcall(func, arguments, contents)
    logCommand(command, ok)
    if not ok then
        dbg("server error for " .. command .. ": " .. tostring(output))
        return false, "An error occurred", 500
    end

    if output == nil then
        output = ""
    end
    return true, output, 200
end

server = hs.httpserver.new(false, false)
    :setInterface("localhost")
    :setPort(port)
    :setCallback(function(requestType, path, headers, contents)
        -- Host allowlist kills DNS rebinding even though we bind loopback.
        if not hostIsAllowed(getHeaderValue(headers, "Host")) then
            return "Forbidden", 403, {}
        end

        -- Reject browser callers from origins we don't trust. Non-browser
        -- callers (HA, curl, Stream Deck native HTTP) send no Origin and
        -- fall through.
        local origin = getHeaderValue(headers, "Origin")
        if origin ~= nil and not allowedOrigins[origin] then
            return "Forbidden", 403, {}
        end

        local responseHeaders = {}
        if origin ~= nil then
            responseHeaders = corsHeadersFor(origin)
        end

        -- CORS preflight: tell the browser the real request is allowed
        -- to carry the secret header. The real request still has to
        -- authenticate normally.
        if requestType == "OPTIONS" then
            return "", 204, responseHeaders
        end

        local command = path:sub(2)
        local _, output, statusCode = parseHTTPCommand(requestType, command, headers, contents)
        return output, statusCode, responseHeaders
    end)
server:maxBodySize(64 * 1024)
server:start()

function printHomeAssistantYAML(host)
    local out = "\n"
    out = out .. "rest_command:\n"
    for name, _ in pairs(commandToFunction) do
        out = out .. "  hammerspoon_" .. name .. ":\n"
        out = out .. "    url: \"" .. host .. ":" .. port .. "/" .. name .. "\"\n"
        out = out .. "    method: " .. (commandUsesGet(name) and "GET" or "POST") .. "\n"
        out = out .. "    headers:\n"
        out = out .. "      " .. secretHeaderName .. ": !secret hammerspoon_secret\n"
    end
    print(out)
end
