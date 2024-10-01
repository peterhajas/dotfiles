local wezterm = require 'wezterm'
local config = {}
local appearance = wezterm.gui.get_appearance()
local phajasColors = false

-- Config (general)
config.quit_when_all_windows_are_closed = false

config.audible_bell = 'Disabled'

-- Fonts
config.font_size = 16

-- Turn off padding
local padding = 0
config.window_padding = {
  top = padding,
  bottom = padding,
  left = padding,
  right = padding,
}

-- Tab bars
config.use_fancy_tab_bar = false
config.hide_tab_bar_if_only_one_tab = true

config.keys = {
   -- Cmd-K Behavior
  {
    key = 'k',
    mods = 'CMD',
    action = wezterm.action.Multiple {
      wezterm.action.ClearScrollback 'ScrollbackAndViewport',
      wezterm.action.SendKey { key = 'L', mods = 'CTRL' },
    },
  },
}

config.window_decorations = "TITLE|RESIZE|MACOS_FORCE_ENABLE_SHADOW"

-- Colors
if phajasColors then
    config.colors = {
        foreground = '#e6e6dc',
        background = '#1a1a1a',
        cursor_bg = '#d3d0c8',
        ansi = {
            '#1a1a1a',
            '#f2777a',
            '#99cc99',
            '#ffcc66',
            '#6699cc',
            '#cc99cc',
            '#66cccc',
            '#d3d0c8',
        },
        brights = {
            "#747369",
            "#995151",
            "#709970",
            "#997a3d",
            "#517099",
            "#997099",
            "#519999",
            "#cccccc",
        }
    }
    config.colors.selection_fg = config.colors.background
    config.colors.selection_bg = config.colors.brights[8]
    config.colors.cursor_border = config.colors.cursor_bg
else
    if appearance:find 'Dark' then
        config.color_scheme = 'Catppuccin Mocha'
    else
        config.color_scheme = 'Catppuccin Latte'
    end
end

return config

