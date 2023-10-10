local cmp = require('cmp')

local min_keyword_length = 5

cmp.setup({
    select = {
        behavior = cmp.SelectBehavior.Select
    },
    window = {
        completion = cmp.config.window.bordered(),
        documentation = cmp.config.window.bordered(),
    },
    mapping = cmp.mapping.preset.insert({
        ['<down>'] = cmp.mapping.select_next_item(),
        ['<up>'] = cmp.mapping.select_prev_item(),
        ['<C-f>'] = cmp.mapping.scroll_docs(4),
        ['<C-b>'] = cmp.mapping.scroll_docs(-4),
        ['<esc>'] = cmp.mapping.close(),
        ['<right>'] = cmp.mapping.confirm {
            behavior = cmp.ConfirmBehavior.Insert,
            select = true,
        },
        ["<Tab>"] = function(fallback) -- also trying out tab here. Sorry TJ.
            if cmp.visible() then
                cmp.select_next_item()
            else
                fallback()
            end
        end,
        ["<S-Tab>"] = function (fallback)
            if cmp.visible() then
                cmp.select_prev_item()
            else
                fallback()
            end
        end,
    }),
    sources = {
        { name = "nvim_lua" },
        { name = "nvim_lsp" },
        { name = "buffer", keyword_length = min_keyword_length },
        { name = "path", keyword_length = min_keyword_length },
        { name = "luasnip" },
    },
    snippet = {
        expand = function(args)
            require("luasnip").lsp_expand(args.body)
        end,
    },
    formatting = {
        -- plh-evil: LSP kind?
    },
    experimental = {
        native_menu = false,
        ghost_text = true,
    }
})
