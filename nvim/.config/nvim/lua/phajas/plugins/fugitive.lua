vim.keymap.set("n", "<leader>gs", vim.cmd.Git)

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
