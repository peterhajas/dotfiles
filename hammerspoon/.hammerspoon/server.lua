require "util"

server = hs.httpserver.new()
:setPort(8044)
:setCallback(function(requestType, path, headers, contents)
    dbg(path)
    dbg(headers)
    dbg(contents)

    -- Check for our commands
    if path == '/lock' then
        hs.caffeinate.lockScreen()
    end

    local body = "OK"
    local responseCode = 200
    local additionalHeaders = {}

    return body, responseCode, additionalHeaders
end)
:start()

dbg(server)
