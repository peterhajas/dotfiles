-- claude_status.lua
-- Hammerspoon module for displaying Claude session status in a floating UI

local M = {}

-- Configuration
M.config = {
    enabled = true,
    width = 196,  -- Match tiddlywiki sidebar width
    maxHeight = 200,
    margin = 12,
    sessionTimeout = 300,  -- 5 minutes in seconds
    cleanupInterval = 60,  -- Run cleanup every 60 seconds
}

-- State
local state = {
    sessions = {},  -- session_id -> session_state
    webview = nil,
    cleanupTimer = nil,
    positionWatcher = nil,
    sessionWatcher = nil,  -- Filesystem watcher for sessions
    permissionWatcher = nil,  -- Filesystem watcher for permissions
    eventHandlersInitialized = false,
    debounceTimer = nil,  -- Debounce filesystem events
    lastStateHash = nil,  -- Track state changes
}

-- Filesystem paths
local STATE_DIR = os.getenv("HOME") .. "/.claude-state"
local SESSION_DIR = STATE_DIR .. "/sessions"
local PERMISSION_DIR = STATE_DIR .. "/permissions"

-- Utility functions

local function log(message)
    print("[claude_status] " .. message)
end

local function shortenPath(path)
    if not path then return "" end
    local home = os.getenv("HOME")
    if home and path:sub(1, #home) == home then
        return "~" .. path:sub(#home + 1)
    end
    return path
end

local function escapeHtml(text)
    if not text then return "" end
    text = tostring(text)
    text = text:gsub("&", "&amp;")
    text = text:gsub("<", "&lt;")
    text = text:gsub(">", "&gt;")
    text = text:gsub('"', "&quot;")
    text = text:gsub("'", "&#39;")
    return text
end

local function parseHammerspoonUrl(url)
    -- Parse hammerspoon://event_name?param1=value1&param2=value2
    local event_name = url:match("hammerspoon://([^?]+)")
    if not event_name then return nil, {} end

    local params = {}
    local query = url:match("%?(.+)")
    if query then
        for key, value in query:gmatch("([^&=]+)=([^&=]+)") do
            params[key] = hs.http.urlDecode(value)
        end
    end

    return event_name, params
end

local function findIPhoneMirroringWindow()
    -- Find the iPhone Mirroring window if it exists
    local wins = hs.window.allWindows()
    for _, win in ipairs(wins) do
        local app = win:application()
        if app and app:name() == "iPhone Mirroring" then
            return win
        end
    end
    return nil
end

-- Load HTML template

local htmlTemplate = nil

local function loadHTMLTemplate()
    if htmlTemplate then
        return htmlTemplate
    end

    local templatePath = hs.configdir .. "/claude_status.html"
    local file = io.open(templatePath, "r")
    if not file then
        log("ERROR: Could not load HTML template from: " .. templatePath)
        return nil
    end

    htmlTemplate = file:read("*all")
    file:close()
    log("Loaded HTML template from: " .. templatePath)
    return htmlTemplate
end

-- Generate HTML for the webview

local function generateHTML()
    local template = loadHTMLTemplate()
    if not template then
        return "<html><body style='background: #000; color: #fff; padding: 20px;'>ERROR: Could not load HTML template</body></html>"
    end

    local sessionsList = {}
    for _, session in pairs(state.sessions) do
        table.insert(sessionsList, session)
    end

    -- Sort by last_update (most recent first)
    table.sort(sessionsList, function(a, b)
        return a.last_update > b.last_update
    end)

    -- Generate Claude mascots HTML
    local mascotsHTML = {}

    if #sessionsList == 0 then
        table.insert(mascotsHTML, [[
            <div class="empty-state">
                <div class="claude-icon-empty">👾</div>
                <div class="empty-text">No active Claude sessions</div>
            </div>
        ]])
    else
        table.insert(mascotsHTML, '<div class="claude-container">')

        for _, session in ipairs(sessionsList) do
            local mascot = {}

            -- Claude mascot container with random animation offsets
            table.insert(mascot, string.format(
                '<div class="claude-mascot" data-status="%s" data-session-id="%s" style="--offset-x: %dpx; --offset-y: %dpx;">',
                escapeHtml(session.status),
                escapeHtml(session.session_id),
                session.offset_x or 0,
                session.offset_y or 0
            ))

            -- Claude icon with random hue
            table.insert(mascot, string.format(
                '<div class="claude-icon" style="--hue: %ddeg;">👾</div>',
                session.hue or 0
            ))

            -- Tooltip
            table.insert(mascot, '<div class="claude-tooltip">')
            table.insert(mascot, string.format(
                '<div class="tooltip-path">%s</div>',
                escapeHtml(session.display_path)
            ))
            table.insert(mascot, string.format(
                '<div class="tooltip-status">%s</div>',
                escapeHtml(session.status_text)
            ))

            if session.current_tool then
                table.insert(mascot, string.format(
                    '<div class="tooltip-tool">Tool: %s</div>',
                    escapeHtml(session.current_tool)
                ))
            end

            table.insert(mascot, '</div>')

            -- Permission modal (only if permission_request exists)
            if session.permission_request then
                local perm = session.permission_request
                table.insert(mascot, '<div class="permission-modal">')
                table.insert(mascot, string.format(
                    '<div class="permission-text">%s</div>',
                    escapeHtml(perm.description or perm.tool_name)
                ))
                table.insert(mascot, '<div class="permission-buttons">')
                table.insert(mascot, string.format(
                    '<button class="approve-btn" onclick="approve(\'%s\')">✓ Approve</button>',
                    perm.request_id
                ))
                table.insert(mascot, string.format(
                    '<button class="deny-btn" onclick="deny(\'%s\')">✗ Deny</button>',
                    perm.request_id
                ))
                table.insert(mascot, '</div>')
                table.insert(mascot, '</div>')
            end

            table.insert(mascot, '</div>')

            table.insert(mascotsHTML, table.concat(mascot))
        end

        table.insert(mascotsHTML, '</div>')
    end

    -- Replace placeholder and all demo content with generated mascots
    local mascotsContent = table.concat(mascotsHTML, "\n")

    -- Escape % characters in replacement string (% has special meaning in gsub replacement)
    -- Each % needs to become %% (so we replace % with %%)
    mascotsContent = mascotsContent:gsub("%%", "%%%%")

    -- Replace from placeholder to end of body (removes demo content)
    local html = template:gsub("<!%-%- SESSIONS_PLACEHOLDER %-%->.-</script>", mascotsContent .. "\n\n    <script>")

    return html
end

-- Webview management

local function createWebview()
    if state.webview then
        state.webview:delete()
        state.webview = nil
    end

    -- Always use primary screen (main display)
    local mainScreen = hs.screen.primaryScreen()
    local screenFrame = mainScreen:frame()

    -- Default position: bottom-right corner
    local x = screenFrame.x + screenFrame.w - M.config.width
    local y = screenFrame.y + screenFrame.h - M.config.maxHeight

    -- Check if iPhone Mirroring window exists and adjust position
    local iphoneWin = findIPhoneMirroringWindow()
    if iphoneWin then
        local iphoneFrame = iphoneWin:frame()
        -- Only dodge if window has valid dimensions (not 0x0)
        if iphoneFrame.w > 0 and iphoneFrame.h > 0 then
            -- Position above iPhone Mirroring window with a small gap
            local gap = 12
            y = iphoneFrame.y - M.config.maxHeight - gap
            -- Keep same right alignment
            x = screenFrame.x + screenFrame.w - M.config.width
            log(string.format("iPhone Mirroring detected at y=%d, positioning above at y=%d", iphoneFrame.y, y))
        end
    end

    state.webview = hs.webview.new({
        x = x,
        y = y,
        w = M.config.width,
        h = M.config.maxHeight
    })
        :windowStyle({})
        :level(hs.drawing.windowLevels.floating)
        :allowTextEntry(true)
        :behavior(hs.drawing.windowBehaviors.stationary)  -- Only on one space, main display
        :transparent(true)  -- Properly translucent like tiddlywiki.lua
        :navigationCallback(function(action, webview, navID, err)
            -- Only intercept willNavigate actions
            if action ~= "willNavigate" then
                return true
            end

            local url = err  -- err parameter contains the URL in this case
            log("Navigation attempt to: " .. tostring(url))

            -- Check if it's a hammerspoon:// URL
            if url and url:match("^hammerspoon://") then
                local event_name, params = parseHammerspoonUrl(url)

                if event_name == "claude_approve" and params.request_id then
                    M.approvePermission(params.request_id)
                elseif event_name == "claude_deny" and params.request_id then
                    M.denyPermission(params.request_id)
                else
                    log("WARNING: Unknown hammerspoon URL: " .. url)
                end

                -- Block the navigation
                return false
            end

            -- Allow other navigation
            return true
        end)
        :html(generateHTML())

    -- Only show if we have sessions
    if next(state.sessions) ~= nil then
        state.webview:show()
    end

    log("Webview created on primary screen at " .. x .. "," .. y)
end

local function updateWebviewPosition()
    -- Update webview position without recreating it
    if not state.webview then
        return
    end

    local mainScreen = hs.screen.primaryScreen()
    local screenFrame = mainScreen:frame()

    -- Default position: bottom-right corner
    local x = screenFrame.x + screenFrame.w - M.config.width
    local y = screenFrame.y + screenFrame.h - M.config.maxHeight

    -- Check if iPhone Mirroring window exists and adjust position
    local iphoneWin = findIPhoneMirroringWindow()
    if iphoneWin then
        local iphoneFrame = iphoneWin:frame()
        -- Only dodge if window has valid dimensions (not 0x0)
        if iphoneFrame.w > 0 and iphoneFrame.h > 0 then
            -- Position above iPhone Mirroring window with a small gap
            local gap = 12
            y = iphoneFrame.y - M.config.maxHeight - gap
        end
    end

    -- Get current position
    local currentFrame = state.webview:frame()

    -- Only update if position changed
    if currentFrame.x ~= x or currentFrame.y ~= y then
        state.webview:frame({
            x = x,
            y = y,
            w = M.config.width,
            h = M.config.maxHeight
        })
        log(string.format("Updated position to %d,%d", x, y))
    end
end

function M.refreshUI()
    if not state.webview then
        createWebview()
    else
        state.webview:html(generateHTML())

        -- Show/hide based on whether we have sessions
        if next(state.sessions) == nil then
            state.webview:hide()
        else
            state.webview:show()
        end
    end
end

-- Random color/animation generation

local function randomHue()
    -- Generate random hue rotation (0-360 degrees)
    math.randomseed(os.time() + os.clock() * 1000000)
    return math.random(0, 360)
end

local function randomOffset()
    -- Generate random animation offset (-10 to 10)
    return math.random(-10, 10)
end

-- Session management

function M.updateSession(data)
    local session_id = data.session_id
    if not session_id then
        log("ERROR: updateSession called without session_id")
        return
    end

    -- Get or create session
    local session = state.sessions[session_id]
    if not session then
        session = {
            session_id = session_id,
            status = "unknown",
            color = "#888888",
            status_text = "Unknown",
            last_update = os.time(),
            hue = randomHue(),  -- Random color for this Claude
            offset_x = randomOffset(),  -- Random horizontal drift
            offset_y = randomOffset(),  -- Random vertical drift
        }
        state.sessions[session_id] = session
        log("Created new session: " .. session_id)
    end

    -- Update fields
    if data.cwd then
        session.cwd = data.cwd
        session.display_path = shortenPath(data.cwd)
    end

    if data.status then
        session.status = data.status
    end

    if data.status_text then
        session.status_text = data.status_text
    end

    if data.color then
        session.color = data.color
    end

    if data.current_tool ~= nil then
        session.current_tool = data.current_tool
    end

    if data.permission_request ~= nil then
        session.permission_request = data.permission_request
    end

    session.last_update = os.time()

    log(string.format("Updated session %s: %s", session_id, session.status_text))

    M.refreshUI()
end

function M.removeSession(sessionId)
    if state.sessions[sessionId] then
        -- First set to "removing" status to trigger fade-out animation
        state.sessions[sessionId].status = "removing"
        state.sessions[sessionId].status_text = "Done"
        M.refreshUI()

        -- Actually remove after fade-out animation completes (500ms)
        hs.timer.doAfter(0.6, function()
            state.sessions[sessionId] = nil
            log("Removed session: " .. sessionId)
            M.refreshUI()
        end)
    end
end

-- Event handlers

function M.handleEvent(eventType, data)
    log(string.format("handleEvent: %s", eventType))

    if eventType == "update_session" then
        M.updateSession(data)
    elseif eventType == "remove_session" then
        M.removeSession(data.session_id)
    elseif eventType == "permission_request" then
        M.updateSession(data)
    else
        log("WARNING: Unknown event type: " .. eventType)
    end
end

-- Filesystem state loading

function M.loadStateFromFilesystem()
    -- Read all session JSON files
    local sessions = {}
    local handle = io.popen("ls '" .. SESSION_DIR .. "'/*.json 2>/dev/null")
    if handle then
        local files = handle:read("*a")
        handle:close()

        for filename in files:gmatch("[^\r\n]+") do
            local file = io.open(filename, "r")
            if file then
                local content = file:read("*all")
                file:close()

                local ok, session = pcall(hs.json.decode, content)
                if ok and session and session.session_id then
                    sessions[session.session_id] = session
                end
            end
        end
    end

    -- Read pending permission requests and attach to sessions
    handle = io.popen("ls '" .. PERMISSION_DIR .. "/pending'/*.json 2>/dev/null")
    if handle then
        local files = handle:read("*a")
        handle:close()

        for filename in files:gmatch("[^\r\n]+") do
            local file = io.open(filename, "r")
            if file then
                local content = file:read("*all")
                file:close()

                local ok, permission = pcall(hs.json.decode, content)
                if ok and permission and permission.session_id then
                    if sessions[permission.session_id] then
                        sessions[permission.session_id].permission_request = {
                            request_id = permission.request_id,
                            tool_name = permission.tool_name,
                            description = permission.description
                        }
                    end
                end
            end
        end
    end

    -- Calculate state hash to detect actual changes
    local stateJson = hs.json.encode(sessions)
    local newHash = hs.hash.SHA256(stateJson)

    -- Only update if state actually changed
    if newHash ~= state.lastStateHash then
        log("State changed, updating UI")
        state.sessions = sessions
        state.lastStateHash = newHash
        return true  -- State changed
    end

    return false  -- No change
end

-- Debounced state loader
local function debouncedLoadState()
    if state.debounceTimer then
        state.debounceTimer:stop()
    end

    state.debounceTimer = hs.timer.doAfter(0.1, function()
        local changed = M.loadStateFromFilesystem()
        if changed then
            M.refreshUI()
        end
    end)
end

-- Permission handling

function M.approvePermission(requestId)
    log("Approving permission: " .. requestId)

    -- Clear permission request from UI immediately
    for _, session in pairs(state.sessions) do
        if session.permission_request and session.permission_request.request_id == requestId then
            session.permission_request = nil
            session.status = "processing"
            session.status_text = "Approved, processing..."
            session.color = "#FF8C00"
            break
        end
    end
    M.refreshUI()

    -- Touch approval file (hook is polling for this)
    local approvalFile = PERMISSION_DIR .. "/approved/" .. requestId
    local file = io.open(approvalFile, "w")
    if file then
        file:write("")
        file:close()
        log("Wrote approval to: " .. approvalFile)
    else
        log("ERROR: Could not write approval file: " .. approvalFile)
    end

    -- Remove pending file immediately
    local pendingFile = PERMISSION_DIR .. "/pending/" .. requestId .. ".json"
    os.execute("rm -f '" .. pendingFile .. "'")
end

function M.denyPermission(requestId)
    log("Denying permission: " .. requestId)

    -- Clear permission request from UI immediately
    for _, session in pairs(state.sessions) do
        if session.permission_request and session.permission_request.request_id == requestId then
            session.permission_request = nil
            session.status = "idle"
            session.status_text = "Denied"
            session.color = "#E74C3C"
            break
        end
    end
    M.refreshUI()

    -- Touch denial file (hook is polling for this)
    local denialFile = PERMISSION_DIR .. "/denied/" .. requestId
    local file = io.open(denialFile, "w")
    if file then
        file:write("")
        file:close()
        log("Wrote denial to: " .. denialFile)
    else
        log("ERROR: Could not write denial file: " .. denialFile)
    end

    -- Remove pending file immediately
    local pendingFile = PERMISSION_DIR .. "/pending/" .. requestId .. ".json"
    os.execute("rm -f '" .. pendingFile .. "'")
end

-- Cleanup

function M.cleanupStale()
    local now = os.time()
    local toRemove = {}

    for session_id, session in pairs(state.sessions) do
        if now - session.last_update > M.config.sessionTimeout and session.status ~= "removing" then
            table.insert(toRemove, session_id)
        end
    end

    if #toRemove > 0 then
        log(string.format("Cleaning up %d stale session(s)", #toRemove))
        for _, session_id in ipairs(toRemove) do
            M.removeSession(session_id)
        end
    end
end

-- Initialization

local function initializeEventHandlers()
    if state.eventHandlersInitialized then
        return
    end

    hs.urlevent.bind("claude_approve", function(eventName, params)
        if params.request_id then
            M.approvePermission(params.request_id)
        end
    end)

    hs.urlevent.bind("claude_deny", function(eventName, params)
        if params.request_id then
            M.denyPermission(params.request_id)
        end
    end)

    state.eventHandlersInitialized = true
    log("Event handlers initialized")
end

function M.init()
    log("Initializing claude_status module")

    if not M.config.enabled then
        log("Module disabled in config")
        return
    end

    -- Clean up any orphaned permission files from previous crashes
    os.execute("rm -f /tmp/claude-perm-*.json 2>/dev/null")

    -- Initialize event handlers (for URL callbacks)
    initializeEventHandlers()

    -- Load initial state from filesystem
    M.loadStateFromFilesystem()

    -- Create webview
    createWebview()

    -- Start filesystem watchers with debouncing
    state.sessionWatcher = hs.pathwatcher.new(SESSION_DIR, function(files)
        debouncedLoadState()
    end)
    state.sessionWatcher:start()
    log("Started session watcher")

    state.permissionWatcher = hs.pathwatcher.new(PERMISSION_DIR .. "/pending", function(files)
        debouncedLoadState()
    end)
    state.permissionWatcher:start()
    log("Started permission watcher")

    -- Start cleanup timer
    state.cleanupTimer = hs.timer.doEvery(M.config.cleanupInterval, M.cleanupStale)

    -- Start position watcher (check every 2 seconds for iPhone Mirroring window)
    state.positionWatcher = hs.timer.doEvery(2, updateWebviewPosition)

    log("claude_status module initialized")
end

-- Test functions

function M.test()
    log("Running test with sample data")

    -- Test processing session
    M.handleEvent('update_session', {
        session_id = 'test-1',
        cwd = '/Users/phajas/dotfiles',
        status = 'processing',
        status_text = 'Processing your request...',
        color = '#FF8C00',
        current_tool = nil
    })

    -- Test running tool
    M.handleEvent('update_session', {
        session_id = 'test-2',
        cwd = '/Users/phajas/projects/webapp',
        status = 'running_tool',
        status_text = 'Running tool...',
        color = '#4A90E2',
        current_tool = 'Bash'
    })

    -- Test permission request
    M.handleEvent('permission_request', {
        session_id = 'test-3',
        cwd = '/Users/phajas/Documents',
        status = 'waiting_permission',
        status_text = 'Needs permission',
        color = '#E74C3C',
        permission_request = {
            request_id = 'test-req-123',
            tool_name = 'Bash',
            description = 'rm -rf node_modules'
        }
    })

    log("Test complete - check the floating UI")
end

function M.clearAll()
    state.sessions = {}
    M.refreshUI()
    log("Cleared all sessions")
end

function M.debugHTML()
    local html = generateHTML()
    print("=== Generated HTML (first 500 chars) ===")
    print(html:sub(1, 500))
    print("...")
    print("=== Session count:", #(function() local t = {}; for k in pairs(state.sessions) do table.insert(t, k) end; return t end)(), "===")
    for id, sess in pairs(state.sessions) do
        print("  ", id, ":", sess.status_text)
    end

    -- Write to file
    local f = io.open("/tmp/generated-claude-ui.html", "w")
    if f then
        f:write(html)
        f:close()
        print("Wrote full HTML to /tmp/generated-claude-ui.html")
    end
end

return M
