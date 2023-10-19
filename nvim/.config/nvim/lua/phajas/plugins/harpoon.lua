local mark = require("harpoon.mark")
local ui = require("harpoon.ui")

vim.keymap.set("n", "<leader>a", mark.add_file)
vim.keymap.set("n", "<leader>A", ui.toggle_quick_menu)
-- plh-evil: we need some better bindings for these that don't overlap
-- vim.keymap.set("n", "<leader>j", function() ui.nav_file(1) end)
-- vim.keymap.set("n", "<leader>j", function() ui.nav_file(2) end)
-- vim.keymap.set("n", "<leader>k", function() ui.nav_file(3) end)
-- vim.keymap.set("n", "<leader>l", function() ui.nav_file(4) end)

require("telescope").load_extension('harpoon')

