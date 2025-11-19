-- Claude Usage Menubar Module
-- Shows Claude API usage in the menu bar

local claude_usage = {}

-- Private state
local menubar = nil
local updateTimer = nil
local currentData = nil  -- Store latest usage data
local SCRIPT_PATH = os.getenv("HOME") .. "/dotfiles/claude/bin/claude_usage"
local UPDATE_INTERVAL = 30  -- 30 seconds

-- Unicode bloom character
local BLOOM = "✻"

-- Parse the usage script output
local function parseUsageOutput(output)
    if not output then return nil end

    -- Parse: "Usage: 44% | Resets: 2am (America/Denver)"
    local percentage = output:match("Usage:%s*(%d+)%%")
    local resetTime = output:match("Resets:%s*(.+)")

    return {
        percentage = percentage and tonumber(percentage) or nil,
        resetTime = resetTime
    }
end

-- Format the menubar text
local function formatMenubarText(data)
    if not data or not data.percentage then
        return BLOOM .. " ?"
    end
    return string.format("%s %d%%", BLOOM, data.percentage)
end

-- Format the tooltip
local function formatTooltip(data)
    if not data or not data.percentage then
        return "Claude usage unavailable"
    end

    local tooltip = string.format("Claude: %d%%", data.percentage)
    if data.resetTime then
        tooltip = tooltip .. string.format("\nResets: %s", data.resetTime)
    end
    return tooltip
end

-- Update the display with styled text
local function updateStyledDisplay(text)
    if menubar then
        local styledText = hs.styledtext.new(text, {
            color = { red = 1.0, green = 0.6, blue = 0.0 },
            font = { name = ".AppleSystemUIFont", size = 0 }
        })
        menubar:setTitle(styledText)
    end
end

-- Generate menu items dynamically
local function generateMenu()
    local menu = {}

    -- Add usage info if available
    if currentData and currentData.percentage then
        table.insert(menu, { title = string.format("Usage: %d%%", currentData.percentage), disabled = true })
        if currentData.resetTime then
            table.insert(menu, { title = string.format("Resets: %s", currentData.resetTime), disabled = true })
        end
        table.insert(menu, { title = "-" })
    end

    table.insert(menu, { title = "Refresh", fn = updateUsage })
    table.insert(menu, { title = "-" })
    table.insert(menu, { title = "Open Claude", fn = function()
        hs.execute("open -a Terminal ~/dotfiles && /opt/homebrew/bin/claude")
    end })

    return menu
end

-- Update the menubar with current usage (runs in background)
local function updateUsage()
    -- Run in background to avoid blocking
    hs.task.new(SCRIPT_PATH, function(exitCode, stdout, stderr)
        if exitCode == 0 then
            local data = parseUsageOutput(stdout)
            currentData = data  -- Store for menu
            if menubar then
                local text = formatMenubarText(data)
                updateStyledDisplay(text)
                menubar:setTooltip(formatTooltip(data))
                menubar:setMenu(generateMenu)  -- Update menu dynamically
            end
        else
            if menubar then
                currentData = nil
                updateStyledDisplay(BLOOM .. " !")
                menubar:setTooltip("Error fetching Claude usage")
                menubar:setMenu(generateMenu)
            end
        end
    end):start()
end

-- Public API

-- Initialize the module
function claude_usage.init()
    -- Create menubar item
    menubar = hs.menubar.new()
    if menubar then
        -- Set orange color
        menubar:setTitle(BLOOM .. " …")

        -- Style with attributed string for orange color
        local styledText = hs.styledtext.new(BLOOM .. " …", {
            color = { red = 1.0, green = 0.6, blue = 0.0 },  -- Orange
            font = { name = ".AppleSystemUIFont", size = 0 }  -- System font
        })
        menubar:setTitle(styledText)

        -- Set menu items (dynamically generated)
        menubar:setMenu(generateMenu)

        -- Do initial update
        updateUsage()

        -- Set up periodic updates (every 30 seconds)
        updateTimer = hs.timer.doEvery(UPDATE_INTERVAL, updateUsage)
    end
end

return claude_usage
