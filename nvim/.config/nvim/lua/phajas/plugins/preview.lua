-- File preview plugin
-- Uses xdg-open to preview current buffer's file
-- <leader>p toggles auto-preview mode (refreshes on save)

local M = {}

-- Track buffers with preview mode enabled
local preview_buffers = {}

local function run_preview(bufnr)
    local filepath = vim.api.nvim_buf_get_name(bufnr)
    if filepath == '' then return end
    vim.fn.jobstart({ 'xdg-open', '-g', filepath }, { detach = true })
end

local function enable_preview(bufnr)
    if preview_buffers[bufnr] then return end

    -- Create autocmd for this buffer
    local group = vim.api.nvim_create_augroup('Preview_' .. bufnr, { clear = true })
    vim.api.nvim_create_autocmd('BufWritePost', {
        group = group,
        buffer = bufnr,
        callback = function()
            run_preview(bufnr)
        end,
    })

    preview_buffers[bufnr] = group
end

local function disable_preview(bufnr)
    local group = preview_buffers[bufnr]
    if not group then return end

    vim.api.nvim_del_augroup_by_id(group)
    preview_buffers[bufnr] = nil
end

local function toggle_preview()
    local bufnr = vim.api.nvim_get_current_buf()
    local filepath = vim.api.nvim_buf_get_name(bufnr)

    if filepath == '' then
        vim.notify('No file in buffer', vim.log.levels.WARN)
        return
    end

    if preview_buffers[bufnr] then
        disable_preview(bufnr)
        vim.notify('Preview off', vim.log.levels.INFO)
    else
        -- Save and open initial preview
        if vim.bo.modified then
            vim.cmd('write')
        end
        run_preview(bufnr)
        enable_preview(bufnr)
        vim.notify('Preview on (auto-refresh on save)', vim.log.levels.INFO)
    end
end

-- Clean up when buffer is deleted
vim.api.nvim_create_autocmd('BufDelete', {
    callback = function(args)
        disable_preview(args.buf)
    end,
})

vim.keymap.set('n', '<leader>p', toggle_preview, { desc = 'Toggle preview mode' })
vim.api.nvim_create_user_command('Preview', toggle_preview, {})

return M
