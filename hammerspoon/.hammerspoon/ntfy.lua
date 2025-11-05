-- ntfy.lua - Hammerspoon module for relaying ntfy notifications
-- Subscribes to ntfy topics and displays them as macOS notifications

local ntfy = {}

-- Active subscriptions
local subscriptions = {}

-- Keep references to active notifications to prevent GC
local activeNotifications = {}

-- Parse a single JSON line from the stream
local function parseJSONLine(line)
    if line == nil or line == "" then
        return nil
    end

    local success, result = pcall(function()
        return hs.json.decode(line)
    end)

    if success then
        return result
    else
        print("ntfy: Failed to parse JSON: " .. tostring(result))
        return nil
    end
end

-- Handle a ntfy message event
local function handleMessage(msg, config)
    -- Only process actual messages, not keepalives or open events
    if msg.event ~= "message" then
        return
    end

    -- Build the title
    local title = msg.title or "ntfy"
    if config.title_prefix then
        title = config.title_prefix .. title
    end

    -- Create the notification with callback for click actions
    local notification = hs.notify.new(function(notif)
        -- Handle click action if there's a click URL
        if msg.click then
            hs.urlevent.openURL(msg.click)
        end
    end)

    notification:title(title)

    -- Never auto-withdraw - stay until manually dismissed
    notification:withdrawAfter(0)

    -- Set subtitle to topic if available
    if msg.topic then
        notification:subTitle(msg.topic)
    end

    -- Set the message body
    if msg.message then
        notification:informativeText(msg.message)
    end

    -- Set custom icon if provided
    if config.icon then
        if type(config.icon) == "string" then
            -- If it's a string, treat it as a file path
            local image = hs.image.imageFromPath(config.icon)
            if image then
                notification:setIdImage(image)
            end
        else
            -- Assume it's already an hs.image object
            notification:setIdImage(config.icon)
        end
    end

    -- Send the notification (silent, no sound)
    notification:send()

    -- Store notification to prevent garbage collection
    table.insert(activeNotifications, notification)

    -- Clean up old notifications (keep last 50)
    if #activeNotifications > 50 then
        table.remove(activeNotifications, 1)
    end
end

-- Subscribe to a ntfy topic
function ntfy.subscribe(config)
    -- Validate required parameters
    if not config.topic then
        hs.alert.show("ntfy: topic is required")
        return nil
    end

    -- Set defaults
    local server = config.server or "https://ntfy.sh"
    local topic = config.topic

    -- Build the URL
    local url = server .. "/" .. topic .. "/json"

    -- Add auth if provided
    local headers = {}
    if config.auth then
        local base64Auth = hs.base64.encode(config.auth)
        headers["Authorization"] = "Basic " .. base64Auth
    end

    print("ntfy: Subscribing to " .. url)

    -- Buffer for incomplete JSON lines
    local buffer = ""

    -- Build curl command arguments
    local curlArgs = {"-N", "-s"}  -- -N disables buffering, -s is silent

    -- Add auth header if provided
    if config.auth then
        local base64Auth = hs.base64.encode(config.auth)
        table.insert(curlArgs, "-H")
        table.insert(curlArgs, "Authorization: Basic " .. base64Auth)
    end

    table.insert(curlArgs, url)

    -- Create streaming task using curl
    local task = hs.task.new("/usr/bin/curl", function(exitCode, stdOut, stdErr)
        -- This callback is called when the task terminates
        print("ntfy: Task terminated for topic '" .. topic .. "' (exit code: " .. tostring(exitCode) .. ")")
        if stdErr and stdErr ~= "" then
            print("ntfy: stderr: " .. stdErr)
        end

        -- Remove from subscriptions
        subscriptions[topic] = nil

        -- Optionally reconnect after a delay
        if config.auto_reconnect ~= false then
            hs.timer.doAfter(5, function()
                print("ntfy: Reconnecting to topic '" .. topic .. "'")
                ntfy.subscribe(config)
            end)
        end
    end, function(task, stdOut, stdErr)
        -- This streaming callback receives data as it arrives
        if stdOut and stdOut ~= "" then
            buffer = buffer .. stdOut

            -- Process complete lines (ending with newline)
            while true do
                local newlinePos = buffer:find("\n")
                if not newlinePos then
                    break
                end

                local line = buffer:sub(1, newlinePos - 1)
                buffer = buffer:sub(newlinePos + 1)

                -- Parse and handle the JSON message
                local msg = parseJSONLine(line)
                if msg then
                    handleMessage(msg, config)
                end
            end
        end

        return true  -- Continue receiving data
    end, curlArgs)

    -- Start the task
    task:start()

    -- Store the subscription
    subscriptions[topic] = {
        task = task,
        config = config
    }

    return subscriptions[topic]
end

-- Unsubscribe from a topic
function ntfy.unsubscribe(topic)
    local sub = subscriptions[topic]
    if sub and sub.task then
        -- Terminate the task
        sub.task:terminate()
        subscriptions[topic] = nil
        print("ntfy: Unsubscribed from topic '" .. topic .. "'")
        return true
    end
    return false
end

-- Unsubscribe from all topics
function ntfy.unsubscribeAll()
    for topic, _ in pairs(subscriptions) do
        ntfy.unsubscribe(topic)
    end
end

-- Get list of active subscriptions
function ntfy.listSubscriptions()
    local topics = {}
    for topic, _ in pairs(subscriptions) do
        table.insert(topics, topic)
    end
    return topics
end

return ntfy
