-- modus theme does not work well for Terminal.app, so only enable it if we're
-- not running in Terminal
--
-- macOS sets this environment variable for apps, so check the bundle ID or
-- enable if it is `nil`

local function detectMacOSAppearance()
    -- Query macOS for the current appearance (light or dark mode)
    local handle = io.popen("defaults read -g AppleInterfaceStyle 2>/dev/null")
    if handle then
        local result = handle:read("*a")
        handle:close()
        -- If the command returns "Dark", we're in dark mode
        if result:match("Dark") then
            return "dark"
        end
    end
    -- Default to light if not dark or if the command failed
    return "light"
end

local function applyModus()
    -- Explicitly set background based on macOS appearance
    -- This helps when running inside Zellij/tmux where OSC 11 queries don't work
    local appearance = detectMacOSAppearance()
    vim.opt.background = appearance
    vim.cmd([[colorscheme modus]])
end

local bundleID = os.getenv("__CFBundleIdentifier")
if bundleID == nil or
   bundleID ~= "com.apple.Terminal" then
   applyModus()

   -- Set up a timer to check for appearance changes every 3 seconds
   -- This allows the theme to update when macOS dark mode is toggled
   local timer = vim.loop.new_timer()
   timer:start(3000, 3000, vim.schedule_wrap(function()
       local current_bg = vim.opt.background:get()
       local new_appearance = detectMacOSAppearance()
       if current_bg ~= new_appearance then
           vim.opt.background = new_appearance
           vim.cmd([[colorscheme modus]])
       end
   end))
end
