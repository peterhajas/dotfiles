-- Configure LSP capabilities for blink.cmp
local capabilities = require('blink.cmp').get_lsp_capabilities()

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

-- Global defaults applied to every LSP
vim.lsp.config('*', {
    capabilities = capabilities,
    on_attach = on_attach,
})

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
    handlers = {
        -- Default handler for all servers
        function(server_name)
            vim.lsp.enable(server_name)
        end,
    },
})

-- Swift LSP (sourcekit-lsp is not managed by Mason on macOS, so set it up directly)
local sourcekit_cmd = nil
if vim.fn.executable("sourcekit-lsp") == 1 then
    sourcekit_cmd = { "sourcekit-lsp" }
elseif vim.fn.executable("xcrun") == 1 then
    local sourcekit_path = vim.fn.systemlist({ "xcrun", "-f", "sourcekit-lsp" })[1]
    if vim.v.shell_error == 0 and sourcekit_path and sourcekit_path ~= "" then
        sourcekit_cmd = { "xcrun", "sourcekit-lsp" }
    end
end

if sourcekit_cmd then
    vim.lsp.config('sourcekit', {
        cmd = sourcekit_cmd,
        root_markers = { "Package.swift", ".git" },
    })
    vim.lsp.enable('sourcekit')
else
    vim.notify("sourcekit-lsp not found. Install Xcode command line tools or Swift toolchain for Swift LSP.", vim.log.levels.WARN)
end
