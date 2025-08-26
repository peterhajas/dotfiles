require('lualine').setup {
    options = {
        -- turn off icons everywhere
        icons_enabled = false,
        component_separators = { left = ' ', right = ' '},
        section_separators = { left = ' ', right = ' '},
        theme = "auto",
    },
    extensions = {
        'fugitive',
        'fzf',
        'oil',
    }
}
