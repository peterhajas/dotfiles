-- Palette-driven colorscheme (generated).

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

local function setIndentScopeHighlight()
    vim.api.nvim_set_hl(0, 'MiniIndentscopeSymbol', { link = 'Comment' })
end

local function applyTheme()
    -- Explicitly set background based on macOS appearance
    -- This helps when running inside Zellij/tmux where OSC 11 queries don't work
    vim.opt.background = detectMacOSAppearance()

    pcall(vim.cmd, [[colorscheme phajas_palette]])

    -- Set indent scope color to match comments (must be after colorscheme)
    setIndentScopeHighlight()
end

local bundleID = os.getenv("__CFBundleIdentifier")
-- if bundleID == nil or
--    bundleID ~= "com.apple.Terminal" then
   applyTheme()

   -- Set up a timer to check for appearance changes every 3 seconds
   -- This allows the theme to update when macOS dark mode is toggled
   local timer = vim.loop.new_timer()
   timer:start(3000, 3000, vim.schedule_wrap(function()
       local current_bg = vim.opt.background:get()
       local new_appearance = detectMacOSAppearance()
       if current_bg ~= new_appearance then
           applyTheme()
       end
   end))

   -- Set up autocommand to reapply indent scope highlight after any colorscheme change
   vim.api.nvim_create_autocmd("ColorScheme", {
       pattern = "*",
       callback = function()
           setIndentScopeHighlight()
       end,
   })
-- end
