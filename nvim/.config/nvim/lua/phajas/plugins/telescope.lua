local builtin = require('telescope.builtin')
local make_entry = require('telescope.make_entry')

require('telescope').setup({
    defaults = {
        color_devicons = true,
    }
})

require('telescope').load_extension('fzf')

-- Build a map of relative file paths to git porcelain status codes.
local function git_status_map(cwd)
    local git_root = vim.fn.systemlist({ "git", "-C", cwd, "rev-parse", "--show-toplevel" })[1]
    if vim.v.shell_error ~= 0 or not git_root or git_root == "" then
        return {}
    end

    local prefix = vim.fn.systemlist({ "git", "-C", cwd, "rev-parse", "--show-prefix" })[1] or ""
    if vim.v.shell_error ~= 0 then
        prefix = ""
    end
    local status_lines = vim.fn.systemlist({
        "git",
        "-C",
        cwd,
        "status",
        "--porcelain=v1",
        "--untracked-files=all",
    })
    if vim.v.shell_error ~= 0 then
        return {}
    end
    local status_map = {}

    for _, line in ipairs(status_lines) do
        local status = line:sub(1, 2)
        local path = vim.trim(line:sub(4))
        if path:find(" -> ") then
            path = path:match(" -> (.+)$") or path
        end
        if prefix ~= "" and path:sub(1, #prefix) == prefix then
            path = path:sub(#prefix + 1)
        end
        status_map[path] = status
    end

    return status_map
end

-- Normalize Telescope highlight specs to a consistent { {start, finish}, group } format.
local function normalize_highlights(hl)
    if type(hl) ~= "table" then
        return nil
    end
    local normalized = {}
    for _, item in ipairs(hl) do
        if type(item) == "table" then
            if type(item[1]) == "table" and type(item[2]) == "string" then
                table.insert(normalized, { { item[1][1], item[1][2] }, item[2] })
            elseif type(item[1]) == "number" and type(item[2]) == "number" and type(item[3]) == "string" then
                table.insert(normalized, { { item[1], item[2] }, item[3] })
            end
        end
    end
    if #normalized == 0 then
        return nil
    end
    return normalized
end

-- Pick a highlight group for a git status prefix (favor Fugitive, then GitSigns, then Diff*).
local function fugitive_status_hl(status)
    local function pick(groups, fallback)
        for _, group in ipairs(groups) do
            if vim.fn.hlexists(group) == 1 then
                return group
            end
        end
        return fallback
    end

    if status == "??" then
        return pick({ "FugitiveUntracked", "GitSignsUntracked", "DiffAdd" }, "TelescopeResultsComment")
    end
    if status:find("U") then
        return pick({ "FugitiveUnmerged", "GitSignsConflict", "DiffText" }, "TelescopeResultsComment")
    end
    if status:find("A") then
        return pick({ "FugitiveAdded", "GitSignsAdd", "DiffAdd" }, "TelescopeResultsComment")
    end
    if status:find("D") then
        return pick({ "FugitiveDeleted", "GitSignsDelete", "DiffDelete" }, "TelescopeResultsComment")
    end
    if status:find("R") or status:find("C") then
        return pick({ "FugitiveRenamed", "GitSignsChange", "DiffChange" }, "TelescopeResultsComment")
    end
    if status:find("M") then
        return pick({ "FugitiveModified", "GitSignsChange", "DiffChange" }, "TelescopeResultsComment")
    end
    return "TelescopeResultsComment"
end

-- Find files and prepend git status while preserving Telescope devicon highlights.
local function find_files_with_git_status()
    local cwd = vim.fn.getcwd()
    local status_map = git_status_map(cwd)
    local entry_maker = make_entry.gen_from_file({ cwd = cwd })

    builtin.find_files({
        hidden = true,
        no_ignore = false,
        find_command = { "fd", "--type", "f", "--hidden", "--exclude", ".git" },
        entry_maker = function(line)
            local entry = entry_maker(line)
            if not entry then
                return nil
            end
            local rel_path = entry.path or entry.value or line

            if entry.cwd and rel_path:sub(1, #entry.cwd + 1) == entry.cwd .. "/" then
                rel_path = rel_path:sub(#entry.cwd + 2)
            end

            local status = status_map[rel_path] or "  "
            local status_hl = fugitive_status_hl(status)
            entry.ordinal = rel_path
            local orig_display = entry.display
            entry.display = function(e)
                if type(orig_display) == "function" then
                    local ok, display, hl = pcall(orig_display, e)
                    if not ok then
                        return string.format("%2s %s", status, rel_path)
                    end
                    local prefix = string.format("%2s ", status)
                    local display_str = type(display) == "string" and display or tostring(display)
                    local normalized = normalize_highlights(hl)
                    if not normalized then
                        return prefix .. display_str
                    end
                    local shifted = { { { 0, #prefix }, status_hl } }
                    for _, h in ipairs(normalized) do
                        local start_pos = h[1][1]
                        local end_pos = h[1][2]
                        local group = h[2]
                        if start_pos and end_pos and group then
                            table.insert(shifted, { { start_pos + #prefix, end_pos + #prefix }, group })
                        end
                    end
                    return prefix .. display_str, shifted
                end
                return string.format("%2s %s", status, orig_display or rel_path)
            end
            return entry
        end,
    })
end

vim.keymap.set('n', '<leader>pf', find_files_with_git_status, {})
vim.keymap.set('n', '<leader>pg', find_files_with_git_status, {})
vim.keymap.set('n', '<leader>ps', function()
    builtin.live_grep({
        additional_args = function(args)
            return vim.list_extend(args, {"--hidden", "--glob", "!.git"})
        end
    })
end)
vim.keymap.set('n', '<leader>pS', function()
    builtin.grep_string({ shorten_path = true, word_match = "-w", only_sort_text = true, search = "" })
end)

vim.keymap.set('n', '<leader>gB', builtin.git_branches, {})

vim.keymap.set('n', 'gd', function()
    builtin.lsp_definitions()
end)

vim.keymap.set('n', '<leader>fb', function()
    builtin.buffers()
end)

-- Unfortunately, both of these are subject to:
-- https://github.com/nvim-telescope/telescope.nvim/issues/2195
vim.keymap.set('n', '<leader>fs', builtin.lsp_document_symbols, { desc = "LSP document symbols" })
vim.keymap.set('n', '<leader>fS', builtin.lsp_workspace_symbols, { desc = "LSP workspace symbols" })
