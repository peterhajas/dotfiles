require("phajas.set")
require("phajas.lazy")
require("phajas.remap")
require("phajas.globals")
require("phajas.plugins.theme")

-- Local helpers that don't need to block startup
vim.api.nvim_create_autocmd("User", {
    pattern = "VeryLazy",
    callback = function()
        require("phajas.plugins.preview")
    end,
})
