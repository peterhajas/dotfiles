-- Makes an Owntone API url
function owntoneAPIURL(server, port, endpoint)
    return server .. ":" .. port .. "/api/" .. endpoint
end

-- Returns the Owntone contents by GET'ing the endpoint
function owntoneGet(server, port, endpoint)
    local url = owntoneAPIURL(server, port, endpoint)
    status, body, headers = hs.http.get(url)
    return hs.json.decode(body)
end

-- Returns the Owntone contents by PUT'ing the endpoint
function owntonePut(server, port, endpoint)
    local url = owntoneAPIURL(server, port, endpoint)
    status, body, headers = hs.http.doRequest(url, 'PUT')

    if string.len(body) > 0 then
        return hs.json.decode(body)
    end
end

