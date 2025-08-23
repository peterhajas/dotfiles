local lsp = require("lsp-zero")
local lua_opts = lsp.nvim_lua_ls()
require('lspconfig').lua_ls.setup(lua_opts)

lsp.preset("recommended")

lsp.on_attach(function(client, bufnr)
    lsp.default_keymaps({buffer = bufnr})

    local opts = {buffer = bufnr, remap=false}
    vim.keymap.set("n", "K", function() vim.lsp.buf.hover() end, opts)
    vim.keymap.set("n", "<leader>vws", function() vim.lsp.buf.workspace_symbol() end, opts)
    vim.keymap.set("n", "<leader>vd", function() vim.diagnostic.open_float() end, opts)
    vim.keymap.set("n", "[d", function() vim.diagnostic.goto_next() end, opts)
    vim.keymap.set("n", "]d", function() vim.diagnostic.goto_prev() end, opts)
    vim.keymap.set("n", "<leader>vca", function() vim.lsp.buf.code_action() end, opts)
    vim.keymap.set("n", "<leader>vrr", function() vim.lsp.buf.references() end, opts)
    vim.keymap.set("n", "<leader>vrn", function() vim.lsp.buf.rename() end, opts)
    vim.keymap.set("i", "<C-h>", function() vim.lsp.buf.signature_help() end, opts)
end)

require('mason-lspconfig').setup({
    ensure_installed = {
        "arduino_language_server",
        "clangd",
        "cssls",
        "docker_compose_language_service",
        "dockerls",
        "gopls",
        "html",
        "intelephense",
        "jedi_language_server",
        "jqls",
        "jsonls",
        "lemminx",
        "lua_ls",
        "marksman",
        "pyright",
        "rust_analyzer",
        "taplo",
        "yamlls",
    },
    handlers = {
        lsp.default_setup,
    },
})

lsp.setup()

