local min_keyword_length = 2

require('blink.cmp').setup({
    keymap = {
        preset = 'default',
        ['<Down>'] = { 'select_next', 'fallback' },
        ['<Up>'] = { 'select_prev', 'fallback' },
        ['<C-f>'] = { 'scroll_documentation_down', 'fallback' },
        ['<C-b>'] = { 'scroll_documentation_up', 'fallback' },
        ['<Esc>'] = { 'hide', 'fallback' },
        ['<C-y>'] = { 'accept', 'fallback' },
        ['<Tab>'] = { 'select_next', 'fallback' },
        ['<S-Tab>'] = { 'select_prev', 'fallback' },
    },

    appearance = {
        use_nvim_cmp_as_default = true,
        nerd_font_variant = 'mono'
    },

    sources = {
        default = { 'lsp', 'path', 'snippets', 'buffer' },
        providers = {
            buffer = {
                min_keyword_length = min_keyword_length,
            },
            path = {
                min_keyword_length = min_keyword_length,
            },
            snippets = {
                min_keyword_length = min_keyword_length,
            },
        },
    },

    completion = {
        accept = {
            auto_brackets = {
                enabled = true,
            },
        },
        menu = {
            border = 'rounded',
            draw = {
                columns = { { "label", "label_description", gap = 1 }, { "kind_icon", "kind" } },
            },
        },
        documentation = {
            auto_show = true,
            auto_show_delay_ms = 500,
            window = {
                border = 'rounded',
            },
        },
        ghost_text = {
            enabled = true,
        },
    },

    snippets = {
        preset = 'luasnip',
        expand = function(snippet) require('luasnip').lsp_expand(snippet) end,
        active = function(filter)
            if filter and filter.direction then
                return require('luasnip').jumpable(filter.direction)
            end
            return require('luasnip').in_snippet()
        end,
        jump = function(direction) require('luasnip').jump(direction) end,
    },

    signature = {
        enabled = true,
        window = {
            border = 'rounded',
        },
    },
})
