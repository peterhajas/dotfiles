-- Telescope picker for tiddlers

local M = {}

local pickers = require("telescope.pickers")
local finders = require("telescope.finders")
local conf = require("telescope.config").values
local actions = require("telescope.actions")
local action_state = require("telescope.actions.state")
local previewers = require("telescope.previewers")

local tw_wrapper = require("tw.tw_wrapper")
local buffer_manager = require("tw.buffer")

-- Helper function to create new tiddler from search prompt
local function create_tiddler_from_prompt(prompt_bufnr)
  local prompt = action_state.get_current_line()

  -- Trim whitespace
  prompt = vim.trim(prompt)

  -- Validate prompt is not empty
  if prompt == "" then
    vim.notify("Enter a tiddler name", vim.log.levels.WARN)
    return
  end

  -- Close picker
  actions.close(prompt_bufnr)

  -- Create and open new tiddler
  buffer_manager.new(prompt)
end

-- Create tiddler picker
function M.tiddlers(opts)
  opts = opts or {}

  -- Get list of tiddlers
  local tiddlers = tw_wrapper.list()

  if #tiddlers == 0 then
    vim.notify("No tiddlers found", vim.log.levels.WARN)
    return
  end

  pickers.new(opts, {
    prompt_title = "Tiddlers",
    finder = finders.new_table({
      results = tiddlers,
    }),
    sorter = conf.generic_sorter(opts),
    previewer = previewers.new_buffer_previewer({
      title = "Tiddler Preview",
      define_preview = function(self, entry, status)
        -- Get tiddler content
        local content = tw_wrapper.get(entry.value)

        if content then
          -- Split into lines and display in preview
          local lines = vim.split(content, "\n", { plain = true })
          vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, lines)

          -- Set filetype to tiddlywiki for custom syntax highlighting
          vim.api.nvim_buf_set_option(self.state.bufnr, "filetype", "tiddlywiki")
        end
      end,
    }),
    attach_mappings = function(prompt_bufnr, map)
      -- Default action: open tiddler or create if no results
      actions.select_default:replace(function()
        local current_picker = action_state.get_current_picker(prompt_bufnr)

        -- Check if there are any results
        if current_picker.manager:num_results() == 0 then
          -- No results - create new tiddler with prompt as name
          create_tiddler_from_prompt(prompt_bufnr)
        else
          -- Results exist - open selected tiddler
          actions.close(prompt_bufnr)
          local selection = action_state.get_selected_entry()
          if selection then
            buffer_manager.open(selection.value)
          end
        end
      end)

      -- Custom action: delete tiddler (Ctrl-d)
      map("i", "<C-d>", function()
        local selection = action_state.get_selected_entry()
        if selection then
          local tiddler_name = selection.value

          -- Confirm deletion
          actions.close(prompt_bufnr)
          local confirm = vim.fn.confirm("Delete tiddler: " .. tiddler_name .. "?", "&Yes\n&No", 2)

          if confirm == 1 then
            local success = tw_wrapper.delete(tiddler_name)
            if success then
              vim.notify("Deleted: " .. tiddler_name, vim.log.levels.INFO)
              -- Reopen picker
              M.tiddlers(opts)
            end
          else
            -- Reopen picker if cancelled
            M.tiddlers(opts)
          end
        end
      end)

      -- Custom action: create new tiddler (Ctrl-n)
      map("i", "<C-n>", function()
        create_tiddler_from_prompt(prompt_bufnr)
      end)

      -- Keep default mappings
      return true
    end,
  }):find()
end

-- Create content search picker (grep)
function M.grep(opts)
  opts = opts or {}

  -- Build cache of tiddler content using the wrapper's internal cache
  -- This is now FAST because tw_wrapper caches json --all results!
  local tiddlers = tw_wrapper.list()
  local cache = {}

  for _, tiddler_name in ipairs(tiddlers) do
    -- Skip system tiddlers
    if not tiddler_name:match("^%$/") then
      local content = tw_wrapper.get(tiddler_name)
      if content then
        local lines = vim.split(content, "\n", { plain = true })
        cache[tiddler_name] = lines
      end
    end
  end

  pickers.new(opts, {
    prompt_title = "Search Tiddler Content",
    finder = finders.new_dynamic({
      fn = function(prompt)
        if not prompt or prompt == "" then
          return {}
        end

        -- Search cached content (fast!)
        local results = {}
        local search_pattern = prompt:lower()

        for tiddler_name, lines in pairs(cache) do
          for line_num, line in ipairs(lines) do
            local search_line = line:lower()
            local start_pos = search_line:find(search_pattern, 1, true)

            if start_pos then
              table.insert(results, {
                display = string.format("%s:%d: %s",
                  tiddler_name,
                  line_num,
                  line:gsub("^%s+", "")),  -- trim leading whitespace
                ordinal = tiddler_name .. " " .. line,
                tiddler = tiddler_name,
                line_number = line_num,
                line = line,
              })
            end
          end
        end

        return results
      end,
      entry_maker = function(entry)
        return {
          value = entry,
          display = entry.display,
          ordinal = entry.ordinal,
        }
      end,
    }),
    sorter = conf.generic_sorter(opts),
    previewer = previewers.new_buffer_previewer({
      title = "Tiddler Preview",
      define_preview = function(self, entry, status)
        if not entry or not entry.value then
          return
        end

        -- Get tiddler content
        local content = tw_wrapper.get(entry.value.tiddler)

        if content then
          -- Split into lines and display in preview
          local lines = vim.split(content, "\n", { plain = true })
          vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, lines)

          -- Set filetype to tiddlywiki for custom syntax highlighting
          vim.api.nvim_buf_set_option(self.state.bufnr, "filetype", "tiddlywiki")

          -- Try to jump to the matching line
          if entry.value.line_number then
            local line_num = entry.value.line_number
            local total_lines = #lines

            -- Only set cursor if line number is valid
            if line_num > 0 and line_num <= total_lines then
              vim.schedule(function()
                pcall(vim.api.nvim_win_set_cursor, self.state.winid, {line_num, 0})
              end)
            end
          end
        end
      end,
    }),
    attach_mappings = function(prompt_bufnr, map)
      -- Default action: open tiddler at matching line
      actions.select_default:replace(function()
        actions.close(prompt_bufnr)
        local selection = action_state.get_selected_entry()
        if selection and selection.value then
          buffer_manager.open(selection.value.tiddler)

          -- Jump to the line after buffer opens
          vim.schedule(function()
            local line_num = selection.value.line_number
            if line_num then
              vim.api.nvim_win_set_cursor(0, {line_num, 0})
              vim.cmd("normal! zz")  -- Center the line
            end
          end)
        end
      end)

      -- Keep default mappings
      return true
    end,
  }):find()
end

-- Create filter picker (generic TiddlyWiki filter expressions)
function M.filter_picker(opts)
  opts = opts or {}
  local filter_expr = opts.filter_expr

  -- If no filter expression, prompt for one
  if not filter_expr then
    filter_expr = vim.fn.input("Filter expression: ")
    if filter_expr == "" then
      vim.notify("No filter expression provided", vim.log.levels.WARN)
      return
    end
  end

  -- Get filtered tiddlers
  local tiddlers = tw_wrapper.filter(filter_expr)

  if #tiddlers == 0 then
    vim.notify("No tiddlers match filter: " .. filter_expr, vim.log.levels.WARN)
    return
  end

  pickers.new(opts, {
    prompt_title = "Filtered Tiddlers: " .. filter_expr,
    finder = finders.new_table({
      results = tiddlers,
    }),
    sorter = conf.generic_sorter(opts),
    previewer = previewers.new_buffer_previewer({
      title = "Tiddler Preview",
      define_preview = function(self, entry, status)
        -- Get tiddler content
        local content = tw_wrapper.get(entry.value)

        if content then
          -- Split into lines and display in preview
          local lines = vim.split(content, "\n", { plain = true })
          vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, lines)

          -- Set filetype to tiddlywiki for custom syntax highlighting
          vim.api.nvim_buf_set_option(self.state.bufnr, "filetype", "tiddlywiki")
        end
      end,
    }),
    attach_mappings = function(prompt_bufnr, map)
      -- Default action: open tiddler
      actions.select_default:replace(function()
        actions.close(prompt_bufnr)
        local selection = action_state.get_selected_entry()
        if selection then
          buffer_manager.open(selection.value)
        end
      end)

      -- Keep default mappings
      return true
    end,
  }):find()
end

return M
