-- File preview plugin
-- Uses xdg-open to preview current buffer's file
-- Works cross-platform: xdg-open on Linux, custom wrapper on macOS

local M = {}

local function preview_file(background)
    local filepath = vim.api.nvim_buf_get_name(0)
    if filepath == '' then
        vim.notify('No file in buffer', vim.log.levels.WARN)
        return
    end

    -- Save if modified
    if vim.bo.modified then
        vim.cmd('write')
    end

    -- Use xdg-open (works on Linux, macOS has wrapper in PATH)
    local cmd = background and { 'xdg-open', '-g', filepath } or { 'xdg-open', filepath }
    vim.fn.jobstart(cmd, { detach = true })
end

local function preview_current_buffer()
    preview_file(false)
end

local function preview_continuous()
    preview_file(true)
end

vim.keymap.set('n', '<leader>p', preview_continuous, { desc = 'Preview file (background, reusable)' })
vim.api.nvim_create_user_command('Preview', preview_continuous, {})

return M
