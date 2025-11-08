-- Makes an Owntone API url
function owntoneAPIURL(server, port, endpoint)
    return server .. ":" .. port .. "/api/" .. endpoint
end

-- Returns the Owntone contents by GET'ing the endpoint
function owntoneGet(server, port, endpoint)
    local url = owntoneAPIURL(server, port, endpoint)
    local success, status, body, headers = pcall(hs.http.get, url)
    if not success or not body then
        return {}
    end
    local success, result = pcall(hs.json.decode, body)
    if not success then
        return {}
    end
    return result
end

-- Returns the Owntone contents by PUT'ing the endpoint
function owntonePut(server, port, endpoint)
    local url = owntoneAPIURL(server, port, endpoint)
    local success, status, body, headers = pcall(hs.http.doRequest, url, 'PUT')
    if not success or not body then
        return nil
    end

    if string.len(body) > 0 then
        local success, result = pcall(hs.json.decode, body)
        if not success then
            return nil
        end
        return result
    end
end

