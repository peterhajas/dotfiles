local palette = require("phajas.colors.palette")

local function select_variant()
    for name, variant in pairs(palette.variants or {}) do
        if variant.flavor == vim.o.background then
            return variant
        end
    end
    if palette.default_variant and palette.variants then
        return palette.variants[palette.default_variant]
    end
end

local function build_theme()
    local variant = select_variant() or {}
    local c = vim.deepcopy(variant.extended or {})
    local ansi = variant.ansi or {}

    local function pick(...)
        for i = 1, select("#", ...) do
            local v = select(i, ...)
            if v then return v end
        end
    end

    -- Derive accents from the current palette data
    c.accent = pick(c.accent, c.blue_warmer, c.blue, ansi[5], variant.foreground)
    c.accent_dark = pick(c.accent_dark, c.blue_intense, ansi[13], c.accent)
    c.green = pick(c.green, c.green_warmer, ansi[3], c.accent)
    c.red = pick(c.red, c.red_warmer, ansi[2], c.accent)
    c.yellow = pick(c.yellow, c.yellow_warmer, ansi[4], c.accent)
    c.magenta = pick(c.magenta, c.magenta_warmer, ansi[6], c.accent)

    local fg_active = pick(c.fg_status_line_active, c.fg_main, variant.foreground)
    local bg_active = pick(c.bg_status_line_active, c.bg_main, variant.background)
    local fg_inactive = pick(c.fg_status_line_inactive, c.fg_dim, fg_active)
    local bg_inactive = pick(c.bg_status_line_inactive, c.bg_dim, variant.background)
    local section_bg = pick(c.bg_dim, bg_active, variant.background)

    local function mode_section(color)
        return { a = { fg = bg_active, bg = color, gui = "bold" },
                 b = { fg = fg_active, bg = section_bg },
                 c = { fg = fg_active, bg = bg_active } }
    end

    return {
        normal  = mode_section(c.accent),
        insert  = mode_section(c.green),
        visual  = mode_section(c.magenta),
        replace = mode_section(c.red),
        command = mode_section(c.yellow),
        inactive = {
            a = { fg = fg_inactive, bg = bg_inactive, gui = "bold" },
            b = { fg = fg_inactive, bg = bg_inactive },
            c = { fg = fg_inactive, bg = bg_inactive },
        },
    }
end

require('lualine').setup {
    options = {
        icons_enabled = true,
        theme = build_theme(),
    },
    sections = {
        lualine_a = {'mode'},
        lualine_b = {'branch', 'diff', 'diagnostics'},
        lualine_c = {{'filename', path = 1}},
        lualine_x = {
            -- Word/character count for markdown and tiddlywiki files
            function()
                local ft = vim.bo.filetype
                if ft == 'markdown' or ft == 'tiddlywiki' then
                    local words = vim.fn.wordcount()
                    return string.format('%dw %dc', words.words, words.chars)
                end
                return ''
            end,
        },
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
        'mason',
        'nvim-dap-ui',
        'nvim-tree',
        'oil',
    }
}
