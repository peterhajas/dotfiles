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
    eventHandlersInitialized = false,
}

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

    local x = screenFrame.x + screenFrame.w - M.config.width - M.config.margin
    local y = screenFrame.y + screenFrame.h - M.config.maxHeight - M.config.margin

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
        :html(generateHTML())

    -- Only show if we have sessions
    if next(state.sessions) ~= nil then
        state.webview:show()
    end

    log("Webview created on primary screen at " .. x .. "," .. y)
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
        state.sessions[sessionId] = nil
        log("Removed session: " .. sessionId)
        M.refreshUI()
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

-- Permission handling

function M.approvePermission(requestId)
    log("Approving permission: " .. requestId)

    local response = {
        decision = "allow",
        timestamp = os.time()
    }

    local filename = "/tmp/claude-perm-" .. requestId .. ".json"
    local file = io.open(filename, "w")
    if file then
        file:write(hs.json.encode(response))
        file:close()
        log("Wrote approval to: " .. filename)
    else
        log("ERROR: Could not write approval file: " .. filename)
    end

    -- Clear permission request from UI
    for _, session in pairs(state.sessions) do
        if session.permission_request and session.permission_request.request_id == requestId then
            session.permission_request = nil
            session.status = "processing"
            session.status_text = "Processing..."
            session.color = "#FF8C00"
            break
        end
    end

    M.refreshUI()
end

function M.denyPermission(requestId)
    log("Denying permission: " .. requestId)

    local response = {
        decision = "deny",
        timestamp = os.time()
    }

    local filename = "/tmp/claude-perm-" .. requestId .. ".json"
    local file = io.open(filename, "w")
    if file then
        file:write(hs.json.encode(response))
        file:close()
        log("Wrote denial to: " .. filename)
    else
        log("ERROR: Could not write denial file: " .. filename)
    end

    -- Clear permission request from UI
    for _, session in pairs(state.sessions) do
        if session.permission_request and session.permission_request.request_id == requestId then
            session.permission_request = nil
            session.status = "processing"
            session.status_text = "Processing..."
            session.color = "#FF8C00"
            break
        end
    end

    M.refreshUI()
end

-- Cleanup

function M.cleanupStale()
    local now = os.time()
    local removed = 0

    for session_id, session in pairs(state.sessions) do
        if now - session.last_update > M.config.sessionTimeout then
            state.sessions[session_id] = nil
            removed = removed + 1
        end
    end

    if removed > 0 then
        log(string.format("Cleaned up %d stale session(s)", removed))
        M.refreshUI()
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

    -- Initialize event handlers
    initializeEventHandlers()

    -- Create webview
    createWebview()

    -- Start cleanup timer
    state.cleanupTimer = hs.timer.doEvery(M.config.cleanupInterval, M.cleanupStale)

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
