local lsp = require("lsp-zero")

require("mason").setup()
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

