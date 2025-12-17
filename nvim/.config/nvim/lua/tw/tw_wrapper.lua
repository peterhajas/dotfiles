-- Wrapper functions for tw CLI commands

local M = {}

-- Config will be set by init.lua
M.config = {
  wiki_path = nil,
  tw_binary = nil,
}

-- Cache for all tiddlers loaded via json --all
-- Structure: { wiki_path -> { mtime, tiddlers = {} } }
local _wiki_cache = {}

-- Cache for MIME type to filetype mapping
local _filetype_mapping_cache = nil

-- Load MIME type to filetype mapping from tw filetype-map
local function load_filetype_mapping()
  if _filetype_mapping_cache then
    return _filetype_mapping_cache
  end

  local tw_binary = M.config.tw_binary or "tw"
  local cmd = tw_binary .. " filetype-map"
  local output = vim.fn.system(cmd)

  if vim.v.shell_error ~= 0 then
    vim.notify("Failed to load filetype mapping: " .. output, vim.log.levels.WARN)
    -- Return empty table as fallback
    _filetype_mapping_cache = {}
    return _filetype_mapping_cache
  end

  -- Parse JSON
  local ok, mapping = pcall(vim.json.decode, output)
  if not ok or type(mapping) ~= "table" then
    vim.notify("Failed to parse filetype mapping JSON", vim.log.levels.WARN)
    _filetype_mapping_cache = {}
    return _filetype_mapping_cache
  end

  _filetype_mapping_cache = mapping
  return _filetype_mapping_cache
end

-- Get Neovim filetype from tiddler's MIME type
-- Returns: filetype string, defaults to 'markdown' if not found
local function get_filetype_from_mime(mime_type)
  if not mime_type or mime_type == "" then
    return 'markdown'  -- Default for TiddlyWiki content
  end

  local mapping = load_filetype_mapping()
  return mapping[mime_type] or 'markdown'
end

-- Get file modification time
local function get_file_mtime(filepath)
  local stat = vim.loop.fs_stat(filepath)
  if stat then
    return stat.mtime.sec
  end
  return nil
end

-- Load all tiddlers from cache or via json --all
local function load_all_tiddlers_cached(wiki_path)
  -- Check if we have a valid cache
  local cached = _wiki_cache[wiki_path]
  local current_mtime = get_file_mtime(wiki_path)

  if cached and cached.mtime == current_mtime then
    -- Cache is valid!
    return cached.tiddlers
  end

  -- Cache miss or stale - load all tiddlers via json --all
  local cmd = string.format("TIDDLYWIKI_WIKI_PATH=%s %s json --all",
    vim.fn.shellescape(wiki_path),
    M.config.tw_binary or "tw")

  local output = vim.fn.system(cmd)

  if vim.v.shell_error ~= 0 then
    vim.notify("Failed to load wiki: " .. output, vim.log.levels.ERROR)
    return {}
  end

  -- Parse JSON
  local ok, tiddlers = pcall(vim.json.decode, output)
  if not ok or type(tiddlers) ~= "table" then
    vim.notify("Failed to parse wiki JSON", vim.log.levels.ERROR)
    return {}
  end

  -- Update cache
  _wiki_cache[wiki_path] = {
    mtime = current_mtime,
    tiddlers = tiddlers
  }

  return tiddlers
end

-- Invalidate cache for a wiki (call after writes)
local function invalidate_cache(wiki_path)
  _wiki_cache[wiki_path] = nil
end

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
  local wiki_path = M.config.wiki_path or vim.env.TIDDLYWIKI_WIKI_PATH

  if not wiki_path then
    vim.notify("No wiki path configured", vim.log.levels.ERROR)
    return {}
  end

  -- Use cache to get all tiddlers
  local all_tiddlers = load_all_tiddlers_cached(wiki_path)

  -- Extract just the titles
  local titles = {}
  for _, tiddler in ipairs(all_tiddlers) do
    if tiddler.title then
      table.insert(titles, tiddler.title)
    end
  end

  -- Sort alphabetically (tw ls does this)
  table.sort(titles)

  return titles
end

-- Get tiddler object (raw from cache)
-- Returns the tiddler as a table with all fields
function M.get_tiddler_object(tiddler_name)
  local wiki_path = M.config.wiki_path or vim.env.TIDDLYWIKI_WIKI_PATH

  if not wiki_path then
    vim.notify("No wiki path configured", vim.log.levels.ERROR)
    return nil
  end

  -- Use cache to get the tiddler
  local all_tiddlers = load_all_tiddlers_cached(wiki_path)

  -- Find the tiddler
  for _, tiddler in ipairs(all_tiddlers) do
    if tiddler.title == tiddler_name then
      return tiddler
    end
  end

  return nil
end

-- Get the Neovim filetype for a tiddler based on its 'type' field
-- Returns: filetype string, defaults to 'markdown'
function M.get_tiddler_filetype(tiddler_name)
  local tiddler = M.get_tiddler_object(tiddler_name)
  if not tiddler then
    return 'markdown'
  end

  return get_filetype_from_mime(tiddler.type)
end

-- Get tiddler content (raw tw cat output)
function M.get(tiddler_name)
  local tiddler = M.get_tiddler_object(tiddler_name)

  if not tiddler then
    vim.notify("Tiddler not found: " .. tiddler_name, vim.log.levels.ERROR)
    return nil
  end

  -- Format as tw cat output (title: value\nfield: value\n\ntext)
  local lines = {}
  table.insert(lines, "title: " .. tiddler.title)

  -- Add other fields (sorted, excluding text and title)
  local fields = {}
  for key, value in pairs(tiddler) do
    if key ~= "title" and key ~= "text" then
      table.insert(fields, key)
    end
  end
  table.sort(fields)

  for _, key in ipairs(fields) do
    table.insert(lines, key .. ": " .. tostring(tiddler[key]))
  end

  -- Add text after blank line
  if tiddler.text then
    table.insert(lines, "")
    table.insert(lines, tiddler.text)
  end

  return table.concat(lines, "\n")
end

-- Replace tiddler content (content must be in tw cat format with title: field)
function M.replace(tiddler_name, content)
  local wiki_path = M.config.wiki_path or vim.env.TIDDLYWIKI_WIKI_PATH
  local cmd = build_tw_cmd("replace")

  -- Pass content via stdin
  local output = vim.fn.system(cmd, content)

  if vim.v.shell_error ~= 0 then
    vim.notify("Failed to save tiddler: " .. output, vim.log.levels.ERROR)
    return false
  end

  -- Invalidate cache after successful write
  invalidate_cache(wiki_path)
  return true
end

-- Delete tiddler
function M.delete(tiddler_name)
  local wiki_path = M.config.wiki_path or vim.env.TIDDLYWIKI_WIKI_PATH
  local cmd = build_tw_cmd(string.format("rm %s", vim.fn.shellescape(tiddler_name)))
  local output = vim.fn.system(cmd)

  if vim.v.shell_error ~= 0 then
    vim.notify("Failed to delete tiddler: " .. output, vim.log.levels.ERROR)
    return false
  end

  -- Invalidate cache after successful write
  invalidate_cache(wiki_path)
  return true
end

-- Create new tiddler
function M.create(tiddler_name, content)
  local wiki_path = M.config.wiki_path or vim.env.TIDDLYWIKI_WIKI_PATH
  local cmd = build_tw_cmd(string.format("touch %s", vim.fn.shellescape(tiddler_name)))
  local output = vim.fn.system(cmd, content or "")

  if vim.v.shell_error ~= 0 then
    vim.notify("Failed to create tiddler: " .. output, vim.log.levels.ERROR)
    return false
  end

  -- Invalidate cache after successful write
  invalidate_cache(wiki_path)
  return true
end

-- Append text to tiddler
function M.append(tiddler_name, text)
  local wiki_path = M.config.wiki_path or vim.env.TIDDLYWIKI_WIKI_PATH
  local cmd = build_tw_cmd(string.format("append %s", vim.fn.shellescape(tiddler_name)))
  local output = vim.fn.system(cmd, text)

  if vim.v.shell_error ~= 0 then
    vim.notify("Failed to append to tiddler: " .. output, vim.log.levels.ERROR)
    return false
  end

  -- Invalidate cache after successful write
  invalidate_cache(wiki_path)
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
  local wiki_path = M.config.wiki_path or vim.env.TIDDLYWIKI_WIKI_PATH
  local cmd = build_tw_cmd(string.format("set %s %s %s",
    vim.fn.shellescape(tiddler_name),
    vim.fn.shellescape(field),
    vim.fn.shellescape(value)))
  local output = vim.fn.system(cmd)

  if vim.v.shell_error ~= 0 then
    vim.notify("Failed to set field: " .. output, vim.log.levels.ERROR)
    return false
  end

  -- Invalidate cache after successful write
  invalidate_cache(wiki_path)
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

-- Filter tiddlers by filter expression
-- Returns table of tiddler names matching the filter
function M.filter(filter_expr)
  local cmd = build_tw_cmd(string.format("filter %s", vim.fn.shellescape(filter_expr)))
  local output = vim.fn.system(cmd)

  if vim.v.shell_error ~= 0 then
    vim.notify("Filter error: " .. output, vim.log.levels.ERROR)
    return {}
  end

  -- Parse output (one result per line)
  local results = {}
  for line in output:gmatch("[^\r\n]+") do
    local trimmed = line:match("^%s*(.-)%s*$")  -- Trim whitespace
    if trimmed ~= "" then
      table.insert(results, trimmed)
    end
  end

  return results
end

return M
