local function fugitive_blame()
  local file = vim.api.nvim_buf_get_name(0)
  if file == "" then
    vim.notify("Git blame: no file for current buffer", vim.log.levels.WARN)
    return
  end
  if vim.fn.executable("git") == 0 then
    vim.notify("Git blame: git is not installed", vim.log.levels.ERROR)
    return
  end

  local dir = vim.fn.fnamemodify(file, ":h")
  local root = vim.fn.systemlist("git -C " .. vim.fn.shellescape(dir) .. " rev-parse --show-toplevel")[1]
  if vim.v.shell_error ~= 0 or root == nil or root == "" then
    vim.notify("Git blame: file is not in a git repository", vim.log.levels.WARN)
    return
  end
  root = root:gsub("/$", "")
  local abs = vim.fn.fnamemodify(file, ":p")
  local rel = abs
  if abs:sub(1, #root) == root then
    rel = abs:sub(#root + 2)
  end

  vim.fn.system("git -C " .. vim.fn.shellescape(root) .. " ls-files --error-unmatch -- " .. vim.fn.shellescape(rel))
  if vim.v.shell_error ~= 0 then
    vim.notify("Git blame: file is untracked", vim.log.levels.WARN)
    return
  end

  vim.cmd("G blame --date=short")
end

vim.keymap.set("n", "<leader>gb", fugitive_blame)
vim.keymap.set("n", "<leader>ga", ":G add %<CR>")
vim.keymap.set("n", "<leader>gm", ":G commit<CR>")
vim.keymap.set("n", "<leader>gps", ":G push origin HEAD<CR>")
vim.keymap.set("n", "<leader>gpS", ":G push<CR>")
vim.keymap.set("n", "<leader>gpl", ":G pull<CR>")
vim.keymap.set("n", "<leader>gd", ":Gdiffsplit<CR>")
vim.keymap.set("n", "<leader>gl", ":G log<CR>")

local function is_fugitive_status_buf(bufnr)
  if vim.bo[bufnr].filetype ~= "fugitive" then
    return false
  end

  local name = vim.api.nvim_buf_get_name(bufnr)
  -- Status buffers look like fugitive://<repo>/.git//
  return name:match("^fugitive://") and name:match("/%.git//$")
end

local function open_fugitive_status()
  vim.cmd.Git()
  vim.schedule(function()
    if is_fugitive_status_buf(0) then
      vim.cmd("silent keepalt edit")
      vim.cmd("redraw")
    end
  end)
end

vim.keymap.set("n", "<leader>gs", open_fugitive_status)

local function refresh_fugitive_status(bufnr)
  local target = bufnr or 0
  if not vim.api.nvim_buf_is_valid(target) then
    return false
  end
  if not is_fugitive_status_buf(target) then
    return false
  end

  vim.api.nvim_buf_call(target, function()
    if vim.api.nvim_buf_get_name(0) == "" then
      return false
    end
    vim.cmd("silent keepalt edit")
    return true
  end)

  return true
end

vim.api.nvim_create_autocmd({ "FocusGained", "BufWritePost" }, {
  group = vim.api.nvim_create_augroup("phajas-fugitive-refresh-live", { clear = true }),
  callback = function()
    vim.schedule(function()
      refresh_fugitive_status(0)
    end)
  end,
})
