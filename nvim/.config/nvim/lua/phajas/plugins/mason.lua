local lspconfig = require('lspconfig')
local cmp_nvim_lsp = require('cmp_nvim_lsp')

-- Configure LSP capabilities for nvim-cmp
local capabilities = cmp_nvim_lsp.default_capabilities()

-- LSP keymaps and autocommands - only your custom ones, telescope handles gd/gr
local function on_attach(_, bufnr)
    local opts = { buffer = bufnr, remap = false }

    vim.keymap.set("n", "K", function() vim.lsp.buf.hover() end, opts)
    vim.keymap.set("n", "<leader>vws", function() vim.lsp.buf.workspace_symbol() end, opts)
    vim.keymap.set("n", "<leader>vd", function() vim.diagnostic.open_float() end, opts)
    vim.keymap.set("n", "[d", function() vim.diagnostic.jump({ count = -1 }) end, opts)
    vim.keymap.set("n", "]d", function() vim.diagnostic.jump({ count = 1 }) end, opts)
    vim.keymap.set("n", "<leader>ca", function() vim.lsp.buf.code_action() end, opts)
    vim.keymap.set("n", "<leader>gu", function() vim.lsp.buf.references() end, opts)
    vim.keymap.set("n", "<leader>rr", function() vim.lsp.buf.rename() end, opts)
    vim.keymap.set("i", "<C-h>", function() vim.lsp.buf.signature_help() end, opts)
    vim.keymap.set("n", "<leader>lf", vim.lsp.buf.format)
end

require("mason").setup()

local mason_lspconfig = require('mason-lspconfig')

mason_lspconfig.setup({
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
})

-- Set up all installed servers since mason-lspconfig handlers don't auto-run for pre-installed servers
local installed_servers = mason_lspconfig.get_installed_servers()

for _, server_name in ipairs(installed_servers) do
    if server_name == "lua_ls" then
        lspconfig.lua_ls.setup({
            capabilities = capabilities,
            on_attach = on_attach,
        })
    else
        lspconfig[server_name].setup({
            capabilities = capabilities,
            on_attach = on_attach,
        })
    end
end
