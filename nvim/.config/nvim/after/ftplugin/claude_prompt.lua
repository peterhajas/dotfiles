-- Filetype plugin for claude_prompt files
-- Extends markdown with Claude-specific highlighting and completion

-- Use markdown treesitter parser for this filetype
vim.treesitter.language.register("markdown", "claude_prompt")

-- Also set up markdown-compatible options
vim.bo.commentstring = "<!-- %s -->"
vim.wo.wrap = true
vim.wo.linebreak = true

-- Set up Claude prompt highlights
local cp = require("phajas.claude_prompt")
cp.define_highlight_groups()
cp.setup_highlights(vim.api.nvim_get_current_buf())

-- Re-define highlights after colorscheme changes
vim.api.nvim_create_autocmd("ColorScheme", {
    buffer = vim.api.nvim_get_current_buf(),
    callback = function()
        cp.define_highlight_groups()
    end,
})
