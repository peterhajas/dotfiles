local cmp = require('cmp')

cmp.setup({
    select = {
        behavior = cmp.SelectBehavior.Select
    },
    window = {
        completion = cmp.config.window.bordered(),
        documentation = cmp.config.window.bordered(),
    },
    mapping = cmp.mapping.preset.insert({
        ['j'] = cmp.mapping.select_next_item(),
        ['k'] = cmp.mapping.select_prev_item(),
        ['J'] = cmp.mapping.scroll_docs(4),
        ['K'] = cmp.mapping.scroll_docs(-4),
        ['<left>'] = cmp.mapping.close(),
        ['<right>'] = cmp.mapping.confirm {
            behavior = cmp.ConfirmBehavior.Insert,
            select = true,
        },
    }),
    sources = {
        { name = "nvim_lua" },
        { name = "nvim_lsp" },
        { name = "buffer" , keyword_length = 5},
        { name = "path" },
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
