-- Palette-driven colorscheme (generated).

local state_file = vim.fn.expand("~/.config/colorscheme/current")
local last_state_mtime = 0
local last_variant_name = nil

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

local function readColorschemeFamily()
    -- Read the colorscheme state file and return the family name
    local f = io.open(state_file, "r")
    if not f then
        return nil
    end
    local content = f:read("*a")
    f:close()

    -- Parse JSON (simple parsing for our specific format)
    local family = content:match('"family"%s*:%s*"([^"]+)"')
    return family
end

local function getVariantForFamily(family, flavor)
    -- Map family + flavor to specific variant name
    -- These mappings come from palette.toml families section
    local families = {
        modus = {
            light = "modus_operandi",
            dark = "modus_vivendi"
        },
        catppuccin = {
            light = "catppuccin_latte",
            dark = "catppuccin_frappe"
        }
    }

    local f = families[family]
    if f then
        return f[flavor]
    end

    return nil
end

local function hasColorschemeStateChanged()
    -- Check if the colorscheme state file has been modified
    local stat = vim.loop.fs_stat(state_file)
    if stat then
        local mtime = stat.mtime.sec
        if mtime ~= last_state_mtime then
            last_state_mtime = mtime
            local new_family = readColorschemeFamily()
            if new_family ~= last_variant_name then  -- Reuse variable for family
                last_variant_name = new_family
                return true
            end
        end
    end
    return false
end

local function setIndentScopeHighlight()
    vim.api.nvim_set_hl(0, 'MiniIndentscopeSymbol', { link = 'Comment' })
end

local function applyTheme()
    -- Get macOS appearance (light or dark)
    local flavor = detectMacOSAppearance()

    -- Get family from state file (or default to modus)
    local family = readColorschemeFamily() or "modus"

    -- Combine family + flavor to get specific variant
    local variant = getVariantForFamily(family, flavor)

    if variant then
        vim.g.phajas_palette_variant = variant
    else
        -- Fallback if mapping fails
        vim.g.phajas_palette_variant = nil
    end

    -- Set background based on macOS appearance
    vim.opt.background = flavor

    pcall(vim.cmd, [[colorscheme phajas_palette]])

    -- Set indent scope color to match comments (must be after colorscheme)
    setIndentScopeHighlight()
end

local bundleID = os.getenv("__CFBundleIdentifier")
-- if bundleID == nil or
--    bundleID ~= "com.apple.Terminal" then
   applyTheme()

   -- Set up a timer to check for appearance and colorscheme changes every 3 seconds
   -- This allows the theme to update when macOS dark mode is toggled or colorscheme changes
   local timer = vim.loop.new_timer()
   timer:start(3000, 3000, vim.schedule_wrap(function()
       local current_bg = vim.opt.background:get()
       local new_appearance = detectMacOSAppearance()
       local state_changed = hasColorschemeStateChanged()

       if current_bg ~= new_appearance or state_changed then
           applyTheme()
           if state_changed then
               vim.notify("Colorscheme family changed", vim.log.levels.INFO)
           end
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
