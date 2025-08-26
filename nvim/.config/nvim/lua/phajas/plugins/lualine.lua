require('lualine').setup {
    options = {
        -- turn off icons everywhere
        icons_enabled = false,
        component_separators = { left = ' ', right = ' '},
        section_separators = { left = '', right = ''},
        theme = "auto",
    },
    sections = {
        lualine_a = {'mode'},
        lualine_b = {'branch', 'diff', 'diagnostics'},
        lualine_c = {{'filename', path = 1}},
        lualine_x = {},
        lualine_y = {'progress'},
        lualine_z = {
            'location',
            function()
                local dap = require('dap')
                local session = dap.session()
                if session then
                    return 'DEBUG'
                end
                return ''
            end,
        }
    },
    inactive_sections = {
        lualine_a = {},
        lualine_b = {},
        lualine_c = {{'filename', path = 1}},
        lualine_x = {},
        lualine_y = {},
        lualine_z = {'location'}
    },
    extensions = {
        'fugitive',
        'fzf',
        'oil',
    }
}
