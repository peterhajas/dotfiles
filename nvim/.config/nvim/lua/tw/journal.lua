-- Journal navigation and management for TiddlyWiki

local M = {}
local tw_wrapper = require("tw.tw_wrapper")
local buffer_manager = require("tw.buffer")

-- Cache for journal title format
local _journal_format_cache = nil

-- Cache for last known date (for auto-switch)
local _last_date = nil

-- Timer handle for auto-switch
local _timer = nil

-- Get the journal title format from wiki config
-- Returns format string like "YYYY-0MM-0DD"
local function get_journal_title_format()
  if _journal_format_cache then
    return _journal_format_cache
  end

  local format = tw_wrapper.get_field("$:/config/NewJournal/Title", "text")
  if not format then
    -- Default format if not configured
    format = "YYYY-0MM-0DD"
  else
    -- Trim whitespace/newlines
    format = vim.trim(format)
  end

  _journal_format_cache = format
  return format
end

-- Convert TiddlyWiki date format to os.date format
-- Mapping: YYYY → %Y, 0MM → %m, 0DD → %d, MM → %-m, DD → %-d
local function render_tiddlywiki_date(format, timestamp)
  timestamp = timestamp or os.time()

  -- Convert TiddlyWiki tokens to os.date tokens
  local converted = format
  converted = converted:gsub("YYYY", "%%Y")
  converted = converted:gsub("0MM", "%%m")
  converted = converted:gsub("0DD", "%%d")
  -- Handle non-zero-padded (must come after zero-padded)
  converted = converted:gsub("MM", "%%-m")
  converted = converted:gsub("DD", "%%-d")

  return os.date(converted, timestamp)
end

-- Get today's journal title
function M.get_today_journal_title()
  local format = get_journal_title_format()
  return render_tiddlywiki_date(format, os.time())
end

-- Check if a tiddler name matches the journal pattern
function M.is_journal_tiddler(tiddler_name)
  local format = get_journal_title_format()

  -- Build regex pattern from format
  local pattern = format
  pattern = pattern:gsub("YYYY", "%%d%%d%%d%%d")
  pattern = pattern:gsub("0MM", "%%d%%d")
  pattern = pattern:gsub("0DD", "%%d%%d")
  pattern = pattern:gsub("MM", "%%d+")
  pattern = pattern:gsub("DD", "%%d+")
  -- Escape special regex chars that might be in format (like -)
  pattern = "^" .. pattern .. "$"

  return tiddler_name:match(pattern) ~= nil
end

-- Ensure journal tiddler has "Journal" tag
function M.ensure_journal_exists(title)
  local tags = tw_wrapper.get_field(title, "tags")

  if not tags or tags == "" or vim.trim(tags) == "" then
    -- No tags, set to "Journal"
    tags = "Journal"
  else
    tags = vim.trim(tags)
    -- Check if "Journal" tag already exists (plain or bracketed)
    if not tags:match("(^| )Journal( |$)") and not tags:match("%[%[Journal%]%]") then
      -- Append Journal tag
      tags = tags .. " Journal"
    end
  end

  tw_wrapper.set_field(title, "tags", tags)
end

-- Open today's journal
function M.open_today()
  local title = M.get_today_journal_title()
  M.ensure_journal_exists(title)
  buffer_manager.open(title)
end

-- Check if journal tiddler is empty (no text content)
function M.is_journal_empty(tiddler_name)
  local text = tw_wrapper.get_field(tiddler_name, "text")

  if not text or text == "" then
    return true
  end

  -- Check if only whitespace
  return vim.trim(text) == ""
end

-- Timer callback: check if date changed and switch to new journal
local function check_and_switch()
  local ok, err = pcall(function()
    -- Get current buffer info
    local bufnr = vim.api.nvim_get_current_buf()
    local bufname = vim.api.nvim_buf_get_name(bufnr)
    local tiddler_name = bufname:match("^tw://(.+)$")

    -- Only operate on tw buffers
    if not tiddler_name then
      return
    end

    -- Only operate on journal tiddlers
    if not M.is_journal_tiddler(tiddler_name) then
      return
    end

    -- Check if date has changed
    local today = M.get_today_journal_title()
    if not _last_date then
      _last_date = today
      return
    end

    if _last_date == today then
      -- Date hasn't changed yet
      return
    end

    -- Date has changed!
    _last_date = today

    -- Don't switch if buffer has unsaved changes
    if vim.bo[bufnr].modified then
      return
    end

    -- Don't switch if old journal has content
    if not M.is_journal_empty(tiddler_name) then
      return
    end

    -- All checks passed - switch to today's journal
    vim.notify("Date changed, switching to today's journal: " .. today, vim.log.levels.INFO)
    M.open_today()
  end)

  if not ok then
    vim.notify("Journal auto-switch error: " .. tostring(err), vim.log.levels.WARN)
  end
end

-- Setup auto-switch timer (checks every minute)
function M.setup_auto_switch()
  -- Stop existing timer if running
  if _timer then
    vim.fn.timer_stop(_timer)
  end

  -- Initialize last date
  _last_date = M.get_today_journal_title()

  -- Start timer: check every 60 seconds (60000ms)
  _timer = vim.fn.timer_start(60000, check_and_switch, { ["repeat"] = -1 })
end

-- Stop auto-switch timer
function M.stop_auto_switch()
  if _timer then
    vim.fn.timer_stop(_timer)
    _timer = nil
  end
end

return M
