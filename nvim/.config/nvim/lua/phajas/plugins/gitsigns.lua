local gitsigns = require("gitsigns")
gitsigns.setup {
    signs = {
        add          = { text = '|' },
        change       = { text = '|' },
        delete       = { text = '|' },
        topdelete    = { text = '|' },
        changedelete = { text = '|' },
        untracked    = { text = '|' },
    },
}

-- Next and previous git hunks, unimpaired-style
-- This uses `vim.schedule` because I was noticing some refresh issues without
-- that setting
vim.keymap.set('n', ']g', function()
    if vim.wo.diff then return ']c' end
    vim.schedule(function() gitsigns.next_hunk() end)
    return '<Ignore>'
end, { expr = true, desc = "Next git hunk" })

vim.keymap.set('n', '[g', function()
    if vim.wo.diff then return '[c' end
    vim.schedule(function() gitsigns.prev_hunk() end)
    return '<Ignore>'
end, { expr = true, desc = "Previous git hunk" })

