local wezterm = require 'wezterm'
local config = {}

config.audible_bell = 'Disabled'
-- Fonts
config.font = wezterm.font 'Menlo'
config.font_size = 16

-- Turn off padding
config.window_padding = {
  top = 0,
  bottom = 0,
  left = 0,
  right = 0,
}
config.use_fancy_tab_bar = false

-- Colors
config.color_scheme = 'Catppuccin Mocha'

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

config.window_decorations = "RESIZE"

return config

