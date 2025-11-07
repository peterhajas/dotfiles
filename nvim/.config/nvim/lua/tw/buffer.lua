-- Buffer management for tiddler editing

local M = {}
local tw_wrapper = require("tw.tw_wrapper")

-- Map buffer numbers to tiddler names
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
  vim.api.nvim_buf_set_option(bufnr, "buftype", "acwrite")

  -- Set filetype based on tiddler's type field
  local filetype = tw_wrapper.get_tiddler_filetype(tiddler_name)
  vim.api.nvim_buf_set_option(bufnr, "filetype", filetype)

  -- Store mapping
  buffer_map[bufnr] = tiddler_name

  -- Split content into lines and set buffer content
  local lines = vim.split(content, "\n", { plain = true })
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)

  -- Mark buffer as not modified
  vim.api.nvim_buf_set_option(bufnr, "modified", false)

  -- Switch to the buffer
  vim.api.nvim_set_current_buf(bufnr)

  vim.notify("Opened: " .. tiddler_name, vim.log.levels.INFO)
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

  -- Get buffer content
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local content = table.concat(lines, "\n")

  -- Save via tw replace
  local success = tw_wrapper.replace(tiddler_name, content)

  if success then
    -- Mark buffer as saved
    vim.api.nvim_buf_set_option(bufnr, "modified", false)
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
