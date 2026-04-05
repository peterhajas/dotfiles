local M = {}

-- Discover Claude Code skills dynamically from the filesystem
-- Sources:
--   ~/.claude/skills/*/SKILL.md          (user-level skills)
--   .claude/skills/*/SKILL.md            (project-level skills)
--   ~/.claude/plugins/**/skills/*/SKILL.md  (plugin skills)
--   ~/.claude/plugins/**/commands/*.md      (plugin commands)

local function parse_frontmatter(path)
    local f = io.open(path, "r")
    if not f then return nil end
    local first = f:read("*l")
    if not first or not first:match("^%-%-%-") then
        f:close()
        return nil
    end
    local name, description
    for line in f:lines() do
        if line:match("^%-%-%-") then break end
        local k, v = line:match("^(%w[%w_-]*):%s*(.+)$")
        if k == "name" then name = v
        elseif k == "description" then description = v
        end
    end
    f:close()
    return name, description
end

local function glob_files(pattern)
    local results = {}
    local handle = io.popen("find -L " .. pattern .. " 2>/dev/null")
    if handle then
        for line in handle:lines() do
            table.insert(results, line)
        end
        handle:close()
    end
    return results
end

function M.discover_skills()
    local skills = {}
    local seen = {}

    local function add(name, desc)
        if not name or seen[name] then return end
        seen[name] = true
        table.insert(skills, {
            label = "/" .. name,
            documentation = desc or "",
        })
    end

    local home = os.getenv("HOME") or ""

    -- User-level skills: ~/.claude/skills/*/SKILL.md
    for _, path in ipairs(glob_files(home .. "/.claude/skills -maxdepth 2 -name 'SKILL.md'")) do
        local name, desc = parse_frontmatter(path)
        add(name, desc)
    end

    -- Project-level skills: .claude/skills/*/SKILL.md (from cwd)
    local cwd = vim.fn.getcwd()
    for _, path in ipairs(glob_files(cwd .. "/.claude/skills -maxdepth 2 -name 'SKILL.md'")) do
        local name, desc = parse_frontmatter(path)
        add(name, desc)
    end

    -- Plugin skills: ~/.claude/plugins/**/skills/*/SKILL.md
    for _, path in ipairs(glob_files(home .. "/.claude/plugins -name 'SKILL.md' -path '*/skills/*'")) do
        local name, desc = parse_frontmatter(path)
        add(name, desc)
    end

    -- Plugin commands: ~/.claude/plugins/**/commands/*.md
    for _, path in ipairs(glob_files(home .. "/.claude/plugins -name '*.md' -path '*/commands/*'")) do
        local name, desc = parse_frontmatter(path)
        -- For commands, name comes from filename if not in frontmatter
        if not name then
            name = path:match("/([^/]+)%.md$")
        end
        add(name, desc)
    end

    return skills
end

-- Cache skills (refreshed per session or on demand)
M.skills = nil

function M.get_skills()
    if not M.skills then
        M.skills = M.discover_skills()
    end
    return M.skills
end

-- Force refresh (e.g. after installing new plugins)
function M.refresh_skills()
    M.skills = nil
    return M.get_skills()
end

-- Claude tool names worth highlighting
M.tools = {
    "Read", "Write", "Edit", "Bash", "Grep", "Glob", "Agent",
    "Skill", "WebFetch", "WebSearch", "NotebookEdit",
    "TodoWrite", "TodoRead",
    "TaskCreate", "TaskUpdate", "TaskGet", "TaskList", "TaskOutput", "TaskStop",
    "AskUserQuestion",
    "ToolSearch",
}

-- Set up extra highlights for claude_prompt buffers
function M.setup_highlights(buf)
    local ns = vim.api.nvim_create_namespace("claude_prompt")

    local function apply()
        vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)
        local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)

        -- Build skill label set for fast lookup
        local skill_set = {}
        for _, s in ipairs(M.get_skills()) do
            skill_set[s.label] = true
        end

        for i, line in ipairs(lines) do
            local row = i - 1

            -- Highlight /skill references (word boundary: preceded by whitespace or SOL)
            for start_pos, skill_name in line:gmatch("()(/[%w_%-]+)") do
                if skill_set[skill_name] then
                    local col = start_pos - 1
                    if col == 0 or line:sub(col, col):match("[%s%p]") then
                        vim.api.nvim_buf_set_extmark(buf, ns, row, col, {
                            end_col = col + #skill_name,
                            hl_group = "ClaudePromptSkill",
                        })
                    end
                end
            end

            -- Highlight XML-style tags: <tag>, </tag>, <tag attr="val">
            for start_pos, tag in line:gmatch("()(<%/?[%w_:%-]+[^>]->)") do
                local col = start_pos - 1
                vim.api.nvim_buf_set_extmark(buf, ns, row, col, {
                    end_col = col + #tag,
                    hl_group = "ClaudePromptXmlTag",
                })
            end

            -- Highlight tool names (as whole words)
            for _, tool in ipairs(M.tools) do
                local search_start = 1
                while true do
                    local s, e = line:find(tool, search_start, true)
                    if not s then break end
                    local before = s > 1 and line:sub(s - 1, s - 1) or " "
                    local after = e < #line and line:sub(e + 1, e + 1) or " "
                    if not before:match("[%w_]") and not after:match("[%w_]") then
                        vim.api.nvim_buf_set_extmark(buf, ns, row, s - 1, {
                            end_col = e,
                            hl_group = "ClaudePromptTool",
                        })
                    end
                    search_start = e + 1
                end
            end

            -- Highlight {{template_variables}}
            for start_pos, var in line:gmatch("()({{[^}]+}})") do
                local col = start_pos - 1
                vim.api.nvim_buf_set_extmark(buf, ns, row, col, {
                    end_col = col + #var,
                    hl_group = "ClaudePromptVariable",
                })
            end
        end
    end

    apply()
    vim.api.nvim_buf_attach(buf, false, {
        on_lines = function()
            vim.schedule(apply)
        end,
    })
end

-- Define highlight groups (called once)
function M.define_highlight_groups()
    vim.api.nvim_set_hl(0, "ClaudePromptSkill", { fg = "#5599ff", bold = true })
    vim.api.nvim_set_hl(0, "ClaudePromptXmlTag", { fg = "#b07adb" })
    vim.api.nvim_set_hl(0, "ClaudePromptTool", { fg = "#e0a050", bold = true })
    vim.api.nvim_set_hl(0, "ClaudePromptVariable", { fg = "#66bb6a" })
end

-- User command to refresh skills cache
vim.api.nvim_create_user_command("ClaudePromptRefreshSkills", function()
    local skills = M.refresh_skills()
    vim.notify("Claude prompt: discovered " .. #skills .. " skills", vim.log.levels.INFO)
end, {})

return M
