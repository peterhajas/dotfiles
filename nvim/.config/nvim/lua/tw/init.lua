-- TiddlyWiki Telescope Plugin
-- Main entry point

local M = {}

local tw_wrapper = require("tw.tw_wrapper")
local buffer_manager = require("tw.buffer")
local telescope_picker = require("tw.telescope")

-- Setup function
function M.setup(opts)
  opts = opts or {}

  -- Configure tw wrapper
  tw_wrapper.config.wiki_path = opts.wiki_path
  tw_wrapper.config.tw_binary = opts.tw_binary or "tw"

  -- Auto-init wiki if it doesn't exist (and auto_init is true)
  if opts.auto_init and opts.wiki_path then
    local wiki_path = vim.fn.expand(opts.wiki_path)
    if vim.fn.filereadable(wiki_path) == 0 then
      vim.notify("Wiki not found, initializing: " .. wiki_path, vim.log.levels.INFO)
      local tw_binary = opts.tw_binary or "tw"
      local cmd = string.format("%s init %s", tw_binary, vim.fn.shellescape(wiki_path))
      local output = vim.fn.system(cmd)

      if vim.v.shell_error ~= 0 then
        vim.notify("Failed to initialize wiki: " .. output, vim.log.levels.ERROR)
      else
        vim.notify("Wiki initialized successfully", vim.log.levels.INFO)
      end
    end
  end

  -- Setup buffer management
  buffer_manager.setup()

  -- Auto-open wiki files when opening .html files
  if opts.auto_open_wiki_files then
    vim.api.nvim_create_autocmd({"BufReadPost"}, {
      pattern = {"*.html"},
      callback = function(ev)
        local filepath = vim.api.nvim_buf_get_name(ev.buf)

        -- Use tw to detect format (more efficient and centralized)
        local tw_binary = opts.tw_binary or "tw"
        local cmd = string.format("%s %s detect", tw_binary, vim.fn.shellescape(filepath))
        local output = vim.fn.system(cmd)

        if vim.v.shell_error ~= 0 then
          -- Not a TiddlyWiki file (or error occurred)
          return
        end

        local format = vim.trim(output)  -- "modern" or "legacy"

        -- Close the HTML buffer (we don't want to edit raw HTML)
        vim.api.nvim_buf_delete(ev.buf, { force = true })

        -- Reconfigure tw to use this wiki
        tw_wrapper.config.wiki_path = filepath

        -- Launch the picker
        vim.schedule(function()
          vim.notify("Opening TiddlyWiki (" .. format .. "): " .. vim.fn.fnamemodify(filepath, ":t"), vim.log.levels.INFO)
          telescope_picker.tiddlers()
        end)
      end,
    })
  end

  -- Create user commands
  vim.api.nvim_create_user_command("TiddlerEdit", function()
    telescope_picker.tiddlers()
  end, { desc = "Open Telescope tiddler picker" })

  vim.api.nvim_create_user_command("TiddlerNew", function(args)
    local tiddler_name = args.args

    if tiddler_name == "" then
      -- Prompt for name
      tiddler_name = vim.fn.input("Tiddler name: ")
    end

    if tiddler_name ~= "" then
      buffer_manager.new(tiddler_name)
    end
  end, { nargs = "?", desc = "Create new tiddler" })

  vim.api.nvim_create_user_command("TiddlerSave", function()
    buffer_manager.save()
  end, { desc = "Save current tiddler buffer" })

  vim.api.nvim_create_user_command("TiddlerDelete", function()
    buffer_manager.delete_current()
  end, { desc = "Delete current tiddler" })

  vim.api.nvim_create_user_command("TiddlerGrep", function()
    telescope_picker.grep()
  end, { desc = "Search tiddler content" })

  vim.api.nvim_create_user_command("TiddlerAppend", function(args)
    local bufnr = vim.api.nvim_get_current_buf()
    local bufname = vim.api.nvim_buf_get_name(bufnr)
    local tiddler_name = bufname:match("^tw://(.+)$")

    if not tiddler_name then
      vim.notify("Not a tiddler buffer", vim.log.levels.ERROR)
      return
    end

    local text = args.args
    if text == "" then
      text = vim.fn.input("Text to append: ")
    end

    if text ~= "" then
      local success = tw_wrapper.append(tiddler_name, text)
      if success then
        vim.notify("Appended to: " .. tiddler_name, vim.log.levels.INFO)
        -- Reload buffer
        buffer_manager.open(tiddler_name)
      end
    end
  end, { nargs = "?", desc = "Append text to current tiddler" })

  vim.api.nvim_create_user_command("TiddlerSetField", function(args)
    local bufnr = vim.api.nvim_get_current_buf()
    local bufname = vim.api.nvim_buf_get_name(bufnr)
    local tiddler_name = bufname:match("^tw://(.+)$")

    if not tiddler_name then
      vim.notify("Not a tiddler buffer", vim.log.levels.ERROR)
      return
    end

    local parts = vim.split(args.args, " ", { plain = true })
    if #parts < 2 then
      vim.notify("Usage: TiddlerSetField <field> <value>", vim.log.levels.ERROR)
      return
    end

    local field = parts[1]
    local value = table.concat(parts, " ", 2)

    local success = tw_wrapper.set_field(tiddler_name, field, value)
    if success then
      vim.notify("Set " .. field .. " on: " .. tiddler_name, vim.log.levels.INFO)
      -- Reload buffer
      buffer_manager.open(tiddler_name)
    end
  end, { nargs = "+", desc = "Set field on current tiddler" })

  -- Optional: setup keybindings if provided
  if opts.keybindings then
    if opts.keybindings.edit then
      -- Use <Cmd> mapping to avoid timeout delays that cause characters to leak into prompt
      vim.keymap.set("n", opts.keybindings.edit, "<Cmd>TiddlerEdit<CR>", { desc = "Edit tiddler" })
    end

    if opts.keybindings.grep then
      -- Use <Cmd> mapping to avoid timeout delays that cause characters to leak into prompt
      vim.keymap.set("n", opts.keybindings.grep, "<Cmd>TiddlerGrep<CR>", { desc = "Search tiddler content" })
    end
  end
end

-- Expose submodules for advanced usage
M.buffer = buffer_manager
M.telescope = telescope_picker
M.tw = tw_wrapper

return M
