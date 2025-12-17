-- TiddlyWiki sidebar implementation
-- Neo-tree/nvim-tree style file explorer for tiddlers

local M = {}
local tw_wrapper = require("tw.tw_wrapper")
local buffer_manager = require("tw.buffer")

-- Sidebar state
local sidebar_state = {
  bufnr = nil,
  winid = nil,
  is_open = false,
  width = 30,
  position = 'left',
  group_by_tags = true,
  show_tag_count = true,
  current_filter = nil,
  expanded_tags = {},  -- Track which tag groups are expanded
  -- Map line numbers to tiddler names or tag names
  line_map = {},
}

-- Configuration
M.config = {
  width = 30,
  position = 'left',
  group_by_tags = true,
  show_tag_count = true,
  auto_refresh = true,
}

-- Helper: Get unique tags from all tiddlers
local function get_all_tags()
  -- Get all tiddler names
  local tiddler_names = tw_wrapper.list()

  -- Extract all tags
  local tag_set = {}
  for _, tiddler_name in ipairs(tiddler_names) do
    local tiddler = tw_wrapper.get_tiddler_object(tiddler_name)
    if tiddler and tiddler.tags then
      local tag_list = type(tiddler.tags) == "table" and tiddler.tags or {tiddler.tags}
      for _, tag in ipairs(tag_list) do
        if type(tag) == "string" and tag ~= "" then
          tag_set[tag] = true
        end
      end
    end
  end

  -- Convert to sorted list
  local tags = {}
  for tag, _ in pairs(tag_set) do
    table.insert(tags, tag)
  end
  table.sort(tags)

  return tags
end

-- Helper: Get tiddlers for a specific tag
local function get_tiddlers_by_tag(tag)
  local results = tw_wrapper.filter(string.format('[tag[%s]]', tag))
  table.sort(results)
  return results
end

-- Helper: Get untagged tiddlers
local function get_untagged_tiddlers()
  local results = tw_wrapper.filter('[!has[tags]]')
  table.sort(results)
  return results
end

-- Helper: Get all tiddlers (for flat view)
local function get_all_tiddlers()
  if sidebar_state.current_filter then
    return tw_wrapper.filter(sidebar_state.current_filter)
  else
    return tw_wrapper.list()
  end
end

-- Build sidebar content with tag grouping
local function build_grouped_content()
  local lines = {}
  sidebar_state.line_map = {}

  local tags = get_all_tags()

  -- Header
  local title = sidebar_state.current_filter
    and string.format("TiddlyWiki (filtered: %s)", sidebar_state.current_filter)
    or "TiddlyWiki"
  table.insert(lines, title)
  table.insert(lines, string.rep("─", #title))
  sidebar_state.line_map[1] = { type = "header" }
  sidebar_state.line_map[2] = { type = "header" }

  -- Show each tag group
  for _, tag in ipairs(tags) do
    local tiddlers = get_tiddlers_by_tag(tag)
    local is_expanded = sidebar_state.expanded_tags[tag]

    -- Tag header line
    local icon = is_expanded and "▼" or "▶"
    local count_str = M.config.show_tag_count and string.format(" (%d)", #tiddlers) or ""
    local tag_line = string.format("%s [%s]%s", icon, tag, count_str)

    local line_num = #lines + 1
    table.insert(lines, tag_line)
    sidebar_state.line_map[line_num] = { type = "tag", tag = tag, expanded = is_expanded }

    -- Show tiddlers if expanded
    if is_expanded then
      for _, tiddler_name in ipairs(tiddlers) do
        local tiddler_line = string.format("  %s", tiddler_name)
        line_num = #lines + 1
        table.insert(lines, tiddler_line)
        sidebar_state.line_map[line_num] = { type = "tiddler", name = tiddler_name, tag = tag }
      end
    end
  end

  -- Untagged tiddlers
  local untagged = get_untagged_tiddlers()
  if #untagged > 0 then
    local is_expanded = sidebar_state.expanded_tags["[untagged]"]
    local icon = is_expanded and "▼" or "▶"
    local count_str = M.config.show_tag_count and string.format(" (%d)", #untagged) or ""
    local tag_line = string.format("%s [untagged]%s", icon, count_str)

    local line_num = #lines + 1
    table.insert(lines, tag_line)
    sidebar_state.line_map[line_num] = { type = "tag", tag = "[untagged]", expanded = is_expanded }

    if is_expanded then
      for _, tiddler_name in ipairs(untagged) do
        local tiddler_line = string.format("  %s", tiddler_name)
        line_num = #lines + 1
        table.insert(lines, tiddler_line)
        sidebar_state.line_map[line_num] = { type = "tiddler", name = tiddler_name, tag = "[untagged]" }
      end
    end
  end

  return lines
end

-- Build sidebar content without tag grouping (flat list)
local function build_flat_content()
  local lines = {}
  sidebar_state.line_map = {}

  local title = sidebar_state.current_filter
    and string.format("TiddlyWiki (filtered: %s)", sidebar_state.current_filter)
    or "TiddlyWiki"
  table.insert(lines, title)
  table.insert(lines, string.rep("─", #title))
  sidebar_state.line_map[1] = { type = "header" }
  sidebar_state.line_map[2] = { type = "header" }

  local tiddlers = get_all_tiddlers()
  for _, tiddler_name in ipairs(tiddlers) do
    local line_num = #lines + 1
    table.insert(lines, tiddler_name)
    sidebar_state.line_map[line_num] = { type = "tiddler", name = tiddler_name }
  end

  return lines
end

-- Render sidebar content
local function render_sidebar()
  if not sidebar_state.bufnr or not vim.api.nvim_buf_is_valid(sidebar_state.bufnr) then
    return
  end

  -- Build content based on grouping setting
  local lines = M.config.group_by_tags and build_grouped_content() or build_flat_content()

  -- Set buffer content
  vim.api.nvim_buf_set_option(sidebar_state.bufnr, "modifiable", true)
  vim.api.nvim_buf_set_lines(sidebar_state.bufnr, 0, -1, false, lines)
  vim.api.nvim_buf_set_option(sidebar_state.bufnr, "modifiable", false)
end

-- Create sidebar buffer
local function create_sidebar_buffer()
  local bufnr = vim.api.nvim_create_buf(false, true)

  -- Set buffer options
  vim.api.nvim_buf_set_name(bufnr, "TiddlyWiki Sidebar")
  vim.api.nvim_buf_set_option(bufnr, "buftype", "nofile")
  vim.api.nvim_buf_set_option(bufnr, "bufhidden", "hide")
  vim.api.nvim_buf_set_option(bufnr, "buflisted", false)
  vim.api.nvim_buf_set_option(bufnr, "swapfile", false)
  vim.api.nvim_buf_set_option(bufnr, "filetype", "tiddlywiki-sidebar")

  return bufnr
end

-- Setup keybindings for sidebar
local function setup_keybindings(bufnr)
  local opts = { buffer = bufnr, noremap = true, silent = true }

  -- Navigation: open tiddler
  vim.keymap.set("n", "<CR>", function()
    local line_num = vim.fn.line(".")
    local item = sidebar_state.line_map[line_num]

    if not item then
      return
    end

    if item.type == "tiddler" then
      -- Open tiddler in main window
      buffer_manager.open(item.name)
    elseif item.type == "tag" then
      -- Toggle tag expansion
      local tag = item.tag
      sidebar_state.expanded_tags[tag] = not sidebar_state.expanded_tags[tag]
      render_sidebar()
    end
  end, opts)

  -- Open in split
  vim.keymap.set("n", "o", function()
    local line_num = vim.fn.line(".")
    local item = sidebar_state.line_map[line_num]

    if item and item.type == "tiddler" then
      vim.cmd("split")
      buffer_manager.open(item.name)
    end
  end, opts)

  -- Delete tiddler
  vim.keymap.set("n", "d", function()
    local line_num = vim.fn.line(".")
    local item = sidebar_state.line_map[line_num]

    if item and item.type == "tiddler" then
      local confirm = vim.fn.confirm("Delete tiddler: " .. item.name .. "?", "&Yes\n&No", 2)
      if confirm == 1 then
        local success = tw_wrapper.delete(item.name)
        if success then
          vim.notify("Deleted: " .. item.name, vim.log.levels.INFO)
          M.refresh()
        end
      end
    end
  end, opts)

  -- Create new tiddler
  vim.keymap.set("n", "a", function()
    local tiddler_name = vim.fn.input("New tiddler name: ")
    if tiddler_name ~= "" then
      buffer_manager.new(tiddler_name)
      if M.config.auto_refresh then
        M.refresh()
      end
    end
  end, opts)

  -- Refresh sidebar
  vim.keymap.set("n", "r", function()
    M.refresh()
    vim.notify("Sidebar refreshed", vim.log.levels.INFO)
  end, opts)

  -- Filter tiddlers
  vim.keymap.set("n", "f", function()
    local filter_expr = vim.fn.input("Filter expression: ")
    if filter_expr ~= "" then
      sidebar_state.current_filter = filter_expr
      M.refresh()
    end
  end, opts)

  -- Clear filter
  vim.keymap.set("n", "F", function()
    sidebar_state.current_filter = nil
    M.refresh()
    vim.notify("Filter cleared", vim.log.levels.INFO)
  end, opts)

  -- Search tiddlers (interactive filter using Telescope)
  vim.keymap.set("n", "/", function()
    M.close()  -- Close sidebar temporarily
    require("tw.telescope").grep()
  end, opts)

  -- Close sidebar
  vim.keymap.set("n", "q", function()
    M.close()
  end, opts)

  -- Toggle tag grouping
  vim.keymap.set("n", "g", function()
    M.config.group_by_tags = not M.config.group_by_tags
    M.refresh()
    local mode = M.config.group_by_tags and "grouped" or "flat"
    vim.notify("Sidebar view: " .. mode, vim.log.levels.INFO)
  end, opts)

  -- Show help
  vim.keymap.set("n", "?", function()
    local help_text = [[
TiddlyWiki Sidebar Help

Navigation:
  <CR>  - Open tiddler / Toggle tag group
  o     - Open tiddler in split
  j/k   - Move up/down

Actions:
  a     - Create new tiddler
  d     - Delete tiddler
  r     - Refresh sidebar
  f     - Filter tiddlers (TiddlyWiki expression)
  F     - Clear filter
  /     - Search tiddler content (Telescope)

View:
  g     - Toggle tag grouping
  q     - Close sidebar
  ?     - Show this help
]]
    vim.notify(help_text, vim.log.levels.INFO)
  end, opts)
end

-- Open sidebar
function M.open()
  if sidebar_state.is_open then
    -- Already open, just focus it
    if sidebar_state.winid and vim.api.nvim_win_is_valid(sidebar_state.winid) then
      vim.api.nvim_set_current_win(sidebar_state.winid)
    end
    return
  end

  -- Create buffer if needed
  if not sidebar_state.bufnr or not vim.api.nvim_buf_is_valid(sidebar_state.bufnr) then
    sidebar_state.bufnr = create_sidebar_buffer()
    setup_keybindings(sidebar_state.bufnr)
  end

  -- Create window
  local width = M.config.width
  local position = M.config.position

  local win_opts = {
    split = position,
    win = 0,
  }

  vim.cmd(string.format("%s vsplit", position == "right" and "rightbelow" or "leftabove"))
  local winid = vim.api.nvim_get_current_win()

  vim.api.nvim_win_set_buf(winid, sidebar_state.bufnr)
  vim.api.nvim_win_set_width(winid, width)

  -- Window options
  vim.api.nvim_win_set_option(winid, "number", false)
  vim.api.nvim_win_set_option(winid, "relativenumber", false)
  vim.api.nvim_win_set_option(winid, "cursorline", true)
  vim.api.nvim_win_set_option(winid, "winfixwidth", true)

  sidebar_state.winid = winid
  sidebar_state.is_open = true

  -- Render content
  render_sidebar()

  vim.notify("TiddlyWiki sidebar opened", vim.log.levels.INFO)
end

-- Close sidebar
function M.close()
  if not sidebar_state.is_open then
    return
  end

  if sidebar_state.winid and vim.api.nvim_win_is_valid(sidebar_state.winid) then
    vim.api.nvim_win_close(sidebar_state.winid, true)
  end

  sidebar_state.winid = nil
  sidebar_state.is_open = false
end

-- Toggle sidebar
function M.toggle()
  if sidebar_state.is_open then
    M.close()
  else
    M.open()
  end
end

-- Refresh sidebar content
function M.refresh()
  if sidebar_state.is_open then
    render_sidebar()
  end
end

-- Setup function
function M.setup(opts)
  opts = opts or {}

  M.config.width = opts.width or M.config.width
  M.config.position = opts.position or M.config.position
  M.config.group_by_tags = opts.group_by_tags ~= nil and opts.group_by_tags or M.config.group_by_tags
  M.config.show_tag_count = opts.show_tag_count ~= nil and opts.show_tag_count or M.config.show_tag_count
  M.config.auto_refresh = opts.auto_refresh ~= nil and opts.auto_refresh or M.config.auto_refresh
end

return M
