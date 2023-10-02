-- catppuccin does not work well for Terminal.app, so only enable it if we're
-- not running in Terminal
--
-- macOS sets this environment variable for apps, so check the bundle ID or
-- enable if it is `nil`
local bundleID = os.getenv("__CFBundleIdentifier")
if bundleID == nil or
   bundleID ~= "com.apple.Terminal" then
    require("catppuccin").setup({
        flavour = "mocha",
        integrations = {
            harpoon = true,
            treesitter_context = false,
        }
    })

    vim.cmd.colorscheme "catppuccin"
end
