-- Buffer management for tiddler editing

local M = {}
local tw_wrapper = require("tw.tw_wrapper")

-- Map buffer numbers to tiddler names and original modified values
local buffer_map = {}

-- Generate buffer name for a tiddler
local function get_buffer_name(tiddler_name)
  return "tw://" .. tiddler_name
end

-- Extract tiddler name from buffer name
local function get_tiddler_name(bufname)
  return bufname:match("^tw://(.+)$")
end

-- Open a tiddler in a buffer
function M.open(tiddler_name)
  -- Check if buffer already exists
  local bufname = get_buffer_name(tiddler_name)
  local existing_buf = vim.fn.bufnr(bufname)

  if existing_buf ~= -1 then
    -- Buffer exists, just switch to it
    vim.api.nvim_set_current_buf(existing_buf)
    return
  end

  -- Get tiddler content
  local content = tw_wrapper.get(tiddler_name)
  if not content then
    return
  end

  -- Create new buffer
  local bufnr = vim.api.nvim_create_buf(true, false)

  -- Set buffer name
  vim.api.nvim_buf_set_name(bufnr, bufname)

  -- Set buffer type to acwrite (autocmd-writable)
  vim.bo[bufnr].buftype = "acwrite"

  -- Set filetype based on tiddler's MIME type (defaults to tiddlywiki)
  local ft = tw_wrapper.get_tiddler_filetype(tiddler_name)
  vim.bo[bufnr].filetype = ft

  -- Store mapping and original modified value for save-time comparison
  local tiddler_obj = tw_wrapper.get_tiddler_object(tiddler_name)
  local original_modified = tiddler_obj and tiddler_obj.modified or nil
  buffer_map[bufnr] = { name = tiddler_name, original_modified = original_modified }

  -- Split content into lines and set buffer content
  local lines = vim.split(content, "\n", { plain = true })
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)

  -- Mark buffer as not modified
  vim.bo[bufnr].modified = false

  -- Switch to the buffer
  vim.api.nvim_set_current_buf(bufnr)

  -- Disable line numbers and gutters
  vim.opt_local.number = false
  vim.opt_local.relativenumber = false
  vim.opt_local.signcolumn = "no"
  vim.opt_local.foldcolumn = "0"
end

-- Strip the modified field from frontmatter if unchanged from original,
-- so tw replace will auto-generate a new timestamp.
local function strip_unchanged_modified(content, original_modified)
  if not original_modified then
    return content
  end

  local lines = vim.split(content, "\n", { plain = true })
  local result = {}
  local in_frontmatter = true

  for _, line in ipairs(lines) do
    if in_frontmatter then
      if line:match("^%s*$") or not line:find(":") then
        in_frontmatter = false
        table.insert(result, line)
      elseif line:match("^modified:%s*(.+)$") then
        local value = line:match("^modified:%s*(.+)$")
        if value == original_modified then
          -- unchanged — skip this line so replace auto-generates
        else
          -- user deliberately changed it — keep it
          table.insert(result, line)
        end
      else
        table.insert(result, line)
      end
    else
      table.insert(result, line)
    end
  end

  return table.concat(result, "\n")
end

-- Save a tiddler buffer
function M.save(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()

  -- Get tiddler name from buffer
  local bufname = vim.api.nvim_buf_get_name(bufnr)
  local tiddler_name = get_tiddler_name(bufname)

  if not tiddler_name then
    vim.notify("Not a tiddler buffer", vim.log.levels.ERROR)
    return false
  end

  local buf_info = buffer_map[bufnr]

  -- Get buffer content
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local content = table.concat(lines, "\n")

  -- Strip unchanged modified field so tw replace auto-generates a new timestamp
  if buf_info and buf_info.original_modified then
    content = strip_unchanged_modified(content, buf_info.original_modified)
  end

  -- If the entire buffer is blank, treat save as delete.
  if vim.trim(content) == "" then
    local success = tw_wrapper.delete(tiddler_name)
    if success then
      vim.api.nvim_buf_delete(bufnr, { force = true })
      vim.notify("Deleted: " .. tiddler_name, vim.log.levels.INFO)
      return true
    end
    return false
  end

  -- Save via tw replace
  local success = tw_wrapper.replace(tiddler_name, content)

  if success then
    -- Update stored original_modified so subsequent saves also get fresh timestamps
    if buf_info then
      local updated = tw_wrapper.get_tiddler_object(tiddler_name)
      buf_info.original_modified = updated and updated.modified or nil
    end
    -- Mark buffer as saved
    vim.bo[bufnr].modified = false
    vim.notify("Saved: " .. tiddler_name, vim.log.levels.INFO)
    return true
  end

  return false
end

-- Create a new tiddler
function M.new(tiddler_name)
  -- Create with empty content
  local success = tw_wrapper.create(tiddler_name, "")

  if not success then
    return
  end

  -- Open the new tiddler
  M.open(tiddler_name)
end

-- Delete current tiddler buffer
function M.delete_current()
  local bufnr = vim.api.nvim_get_current_buf()
  local bufname = vim.api.nvim_buf_get_name(bufnr)
  local tiddler_name = get_tiddler_name(bufname)

  if not tiddler_name then
    vim.notify("Not a tiddler buffer", vim.log.levels.ERROR)
    return
  end

  -- Confirm deletion
  local confirm = vim.fn.confirm("Delete tiddler: " .. tiddler_name .. "?", "&Yes\n&No", 2)
  if confirm ~= 1 then
    return
  end

  -- Delete tiddler
  local success = tw_wrapper.delete(tiddler_name)

  if success then
    -- Close buffer
    vim.api.nvim_buf_delete(bufnr, { force = true })
    vim.notify("Deleted: " .. tiddler_name, vim.log.levels.INFO)
  end
end

-- Setup autocmd for saving
function M.setup()
  -- Create autocmd for BufWriteCmd on tw:// buffers
  vim.api.nvim_create_autocmd("BufWriteCmd", {
    pattern = "tw://*",
    callback = function(args)
      M.save(args.buf)
    end,
    group = vim.api.nvim_create_augroup("TiddlerBuffer", { clear = true }),
  })
end

return M
