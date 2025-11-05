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

-- Create tiddler picker
function M.tiddlers(opts)
  opts = opts or {}
  opts.initial_mode = opts.initial_mode or "normal"

  -- Get list of tiddlers
  local tiddlers = tw_wrapper.list()

  if #tiddlers == 0 then
    vim.notify("No tiddlers found", vim.log.levels.WARN)
    return
  end

  -- Schedule entering insert mode after a delay to avoid character leak
  vim.defer_fn(function()
    vim.cmd("startinsert")
  end, 200)

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

          -- Set filetype for syntax highlighting
          vim.api.nvim_buf_set_option(self.state.bufnr, "filetype", "markdown")
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

      -- Keep default mappings
      return true
    end,
  }):find()
end

-- Create content search picker (grep)
function M.grep(opts)
  opts = opts or {}
  opts.initial_mode = opts.initial_mode or "normal"

  -- Schedule entering insert mode after a delay to avoid character leak
  vim.defer_fn(function()
    vim.cmd("startinsert")
  end, 200)

  pickers.new(opts, {
    prompt_title = "Search Tiddler Content",
    finder = finders.new_dynamic({
      fn = function(prompt)
        if not prompt or prompt == "" then
          return {}
        end

        -- Search tiddler content
        local results = tw_wrapper.grep(prompt, {
          case_sensitive = false,
          include_system = false,
        })

        -- Format results for telescope
        local formatted = {}
        for _, result in ipairs(results) do
          table.insert(formatted, {
            display = string.format("%s:%d: %s",
              result.tiddler,
              result.line_number,
              result.line:gsub("^%s+", "")),  -- trim leading whitespace
            ordinal = result.tiddler .. " " .. result.line,
            tiddler = result.tiddler,
            line_number = result.line_number,
            line = result.line,
          })
        end

        return formatted
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

          -- Set filetype for syntax highlighting
          vim.api.nvim_buf_set_option(self.state.bufnr, "filetype", "markdown")

          -- Try to jump to the matching line
          if entry.value.line_number then
            vim.api.nvim_win_set_cursor(self.state.winid, {entry.value.line_number, 0})
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

return M
