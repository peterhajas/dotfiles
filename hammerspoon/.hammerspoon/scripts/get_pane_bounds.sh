#!/bin/bash
# get_pane_bounds.sh
# Calculate the absolute screen coordinates for the current Zellij pane

# Debug mode: set to 1 to enable logging
DEBUG=${DEBUG:-0}

debug_log() {
    if [ "$DEBUG" -eq 1 ]; then
        echo "[DEBUG] $*" >&2
    fi
}

# Get the current pane ID from environment
PANE_ID="${ZELLIJ_PANE_ID}"

if [ -z "$PANE_ID" ]; then
    echo '{"error": "Not running in Zellij (ZELLIJ_PANE_ID not set)"}' >&2
    exit 1
fi

debug_log "Current pane ID: $PANE_ID"

# For now, we'll use a simpler approach:
# 1. Get the terminal window bounds using AppleScript/Hammerspoon
# 2. Parse the Zellij layout to find our pane's position
# 3. Calculate absolute coordinates

# This is a simplified version that will need enhancement
# For now, let's call back to Hammerspoon to get the window bounds

# Use Hammerspoon to get the terminal window bounds and calculate pane position
/usr/local/bin/hs -c "
local app = hs.application.get('Ghostty')
if not app then
    print('{\"error\": \"Ghostty not running\"}')
    os.exit(1)
end

local window = app:mainWindow()
if not window then
    print('{\"error\": \"No Ghostty window found\"}')
    os.exit(1)
end

local frame = window:frame()

-- TODO: Parse Zellij layout and calculate pane position
-- For now, return the full window bounds as a starting point
local result = {
    x = frame.x,
    y = frame.y,
    w = frame.w,
    h = frame.h,
    pane_id = '$PANE_ID'
}

print(hs.json.encode(result))
"
