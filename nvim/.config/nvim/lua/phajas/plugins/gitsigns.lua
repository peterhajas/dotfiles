local gitsigns = require("gitsigns")
gitsigns.setup {
    signs = {
        add          = { text = 'A' },
        change       = { text = 'M' },
        delete       = { text = 'D' },
        topdelete    = { text = 'D' },
        changedelete = { text = 'D' },
        untracked    = { text = '?' },
    },
    current_line_blame = false,
    current_line_blame_opts = {
        virt_text = true,
        virt_text_pos = "right_align",
    },
    word_diff = false,
    current_line_blame_formatter = '<abbrev_sha> <author> <author_time:%Y-%m-%d> <summary>',
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

