local dap = require('dap')
local dapui = require('dapui')

-- Set up DAP UI
dapui.setup()
require("nvim-dap-virtual-text").setup()

-- Auto-open/close DAP UI
dap.listeners.after.event_initialized["dapui_config"] = function()
    dapui.open()
end
dap.listeners.before.event_terminated["dapui_config"] = function()
    dapui.close()
end
dap.listeners.before.event_exited["dapui_config"] = function()
    dapui.close()
end

-- MARK: Keymaps
vim.keymap.set('n', '<leader>dc', function() dap.continue() end, { desc = 'Debug: Start/Continue' })
vim.keymap.set('n', '<leader>dj', function() dap.step_over() end, { desc = 'Debug: Step Over' })
vim.keymap.set('n', '<leader>dJ', function() dap.step_into() end, { desc = 'Debug: Step Into' })
vim.keymap.set('n', '<leader>dk', function() dap.step_out() end, { desc = 'Debug: Step Out' })
vim.keymap.set('n', '<leader>db', function() dap.toggle_breakpoint() end, { desc = 'Debug: Toggle Breakpoint' })
vim.keymap.set('n', '<leader>dB', function()
    dap.set_breakpoint(vim.fn.input('Breakpoint condition: '))
end, { desc = 'Debug: Set Conditional Breakpoint' })
vim.keymap.set('n', '<leader>dr', function() dap.repl.open() end, { desc = 'Debug: Open REPL' })
vim.keymap.set('n', '<leader>dl', function() dap.run_last() end, { desc = 'Debug: Run Last' })

