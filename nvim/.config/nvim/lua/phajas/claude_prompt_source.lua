-- blink.cmp custom source for Claude prompt skill completion
-- Discovers skills dynamically from ~/.claude/skills, plugins, etc.

local source = {}

function source.new(opts, config)
    return setmetatable({ opts = opts or {} }, { __index = source })
end

function source:get_trigger_characters()
    return { "/" }
end

function source:get_completions(context, callback)
    local skills = require("phajas.claude_prompt").get_skills()
    local items = {}
    for _, skill in ipairs(skills) do
        table.insert(items, {
            label = skill.label,
            kind = vim.lsp.protocol.CompletionItemKind.Keyword,
            insertText = skill.label,
            documentation = {
                kind = "plaintext",
                value = skill.documentation,
            },
        })
    end
    callback({
        is_incomplete_forward = false,
        is_incomplete_backward = false,
        items = items,
    })
end

return source
