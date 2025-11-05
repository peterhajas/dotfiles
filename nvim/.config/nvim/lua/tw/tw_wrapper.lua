-- Wrapper functions for tw CLI commands

local M = {}

-- Config will be set by init.lua
M.config = {
  wiki_path = nil,
  tw_binary = nil,
}

-- Build the tw command with proper environment
local function build_tw_cmd(args)
  local wiki_path = M.config.wiki_path or vim.env.TIDDLYWIKI_WIKI_PATH
  local tw_binary = M.config.tw_binary or "tw"

  if not wiki_path then
    error("No wiki path configured. Set TIDDLYWIKI_WIKI_PATH or provide wiki_path in setup()")
  end

  -- Build command: TIDDLYWIKI_WIKI_PATH=... tw ...
  local cmd = string.format("TIDDLYWIKI_WIKI_PATH=%s %s %s",
    vim.fn.shellescape(wiki_path),
    tw_binary,
    args
  )

  return cmd
end

-- List all tiddler names
function M.list()
  local cmd = build_tw_cmd("ls")
  local output = vim.fn.system(cmd)

  if vim.v.shell_error ~= 0 then
    vim.notify("Failed to list tiddlers: " .. output, vim.log.levels.ERROR)
    return {}
  end

  -- Parse output into table of tiddler names
  local tiddlers = {}
  for line in output:gmatch("[^\n]+") do
    if line ~= "" then
      table.insert(tiddlers, line)
    end
  end

  return tiddlers
end

-- Get tiddler content (raw tw cat output)
function M.get(tiddler_name)
  local cmd = build_tw_cmd(string.format("cat %s", vim.fn.shellescape(tiddler_name)))
  local output = vim.fn.system(cmd)

  if vim.v.shell_error ~= 0 then
    vim.notify("Failed to get tiddler: " .. output, vim.log.levels.ERROR)
    return nil
  end

  return output
end

-- Replace tiddler content (content must be in tw cat format with title: field)
function M.replace(tiddler_name, content)
  local cmd = build_tw_cmd("replace")

  -- Pass content via stdin
  local output = vim.fn.system(cmd, content)

  if vim.v.shell_error ~= 0 then
    vim.notify("Failed to save tiddler: " .. output, vim.log.levels.ERROR)
    return false
  end

  return true
end

-- Delete tiddler
function M.delete(tiddler_name)
  local cmd = build_tw_cmd(string.format("rm %s", vim.fn.shellescape(tiddler_name)))
  local output = vim.fn.system(cmd)

  if vim.v.shell_error ~= 0 then
    vim.notify("Failed to delete tiddler: " .. output, vim.log.levels.ERROR)
    return false
  end

  return true
end

-- Create new tiddler
function M.create(tiddler_name, content)
  local cmd = build_tw_cmd(string.format("touch %s", vim.fn.shellescape(tiddler_name)))
  local output = vim.fn.system(cmd, content or "")

  if vim.v.shell_error ~= 0 then
    vim.notify("Failed to create tiddler: " .. output, vim.log.levels.ERROR)
    return false
  end

  return true
end

-- Append text to tiddler
function M.append(tiddler_name, text)
  local cmd = build_tw_cmd(string.format("append %s", vim.fn.shellescape(tiddler_name)))
  local output = vim.fn.system(cmd, text)

  if vim.v.shell_error ~= 0 then
    vim.notify("Failed to append to tiddler: " .. output, vim.log.levels.ERROR)
    return false
  end

  return true
end

-- Get a specific field value from a tiddler
function M.get_field(tiddler_name, field)
  local cmd = build_tw_cmd(string.format("get %s %s",
    vim.fn.shellescape(tiddler_name),
    vim.fn.shellescape(field)))
  local output = vim.fn.system(cmd)

  if vim.v.shell_error ~= 0 then
    vim.notify("Failed to get field: " .. output, vim.log.levels.ERROR)
    return nil
  end

  return output
end

-- Set a field value on a tiddler
function M.set_field(tiddler_name, field, value)
  local cmd = build_tw_cmd(string.format("set %s %s %s",
    vim.fn.shellescape(tiddler_name),
    vim.fn.shellescape(field),
    vim.fn.shellescape(value)))
  local output = vim.fn.system(cmd)

  if vim.v.shell_error ~= 0 then
    vim.notify("Failed to set field: " .. output, vim.log.levels.ERROR)
    return false
  end

  return true
end

-- Get tiddler as JSON
function M.json(tiddler_name)
  local cmd = build_tw_cmd(string.format("json %s", vim.fn.shellescape(tiddler_name)))
  local output = vim.fn.system(cmd)

  if vim.v.shell_error ~= 0 then
    vim.notify("Failed to get JSON: " .. output, vim.log.levels.ERROR)
    return nil
  end

  return output
end

-- Search tiddler content (grep)
-- Returns table of {tiddler_name, line_number, line_content, match_start, match_end}
function M.grep(pattern, opts)
  opts = opts or {}
  local case_sensitive = opts.case_sensitive or false

  -- Get all tiddlers
  local tiddlers = M.list()
  local results = {}

  -- Search pattern in each tiddler
  for _, tiddler_name in ipairs(tiddlers) do
    -- Skip system tiddlers unless explicitly requested
    if not opts.include_system and tiddler_name:match("^%$/") then
      goto continue
    end

    local content = M.get(tiddler_name)
    if content then
      local lines = vim.split(content, "\n", { plain = true })

      for line_num, line in ipairs(lines) do
        local search_line = case_sensitive and line or line:lower()
        local search_pattern = case_sensitive and pattern or pattern:lower()

        local start_pos, end_pos = search_line:find(search_pattern, 1, true)

        if start_pos then
          table.insert(results, {
            tiddler = tiddler_name,
            line_number = line_num,
            line = line,
            match_start = start_pos,
            match_end = end_pos,
          })
        end
      end
    end

    ::continue::
  end

  return results
end

return M
