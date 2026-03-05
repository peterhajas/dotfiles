local M = {}

local hyper = require "hyper"
local chooser = require "choose"
require "terminal"

local function trim(value)
    if value == nil then
        return ""
    end
    return value:match("^%s*(.-)%s*$")
end

local function shellQuote(value)
    return "'" .. tostring(value):gsub("'", "'\\''") .. "'"
end

local function splitLines(text)
    local lines = {}
    if text == nil or text == "" then
        return lines
    end
    for line in text:gmatch("[^\r\n]+") do
        table.insert(lines, line)
    end
    return lines
end

M.config = {
    wiki_path = os.getenv("TW_NVALT_WIKI_PATH") or (os.getenv("HOME") .. "/phajas-wiki/phajas-wiki.html"),
    tw_binary = os.getenv("HOME") .. "/dotfiles/tiddlywiki/bin/tw",
    cache_ttl_seconds = 45,
    hide_system_tiddlers = true,
    inbox_tiddler = "Inbox",
    journal_title_format = os.getenv("TW_JOURNAL_TITLE_FORMAT") or "YYYY-0MM-0DD",
}

local _cache = {
    titles = {},
    loaded_at = 0,
}

local SPECIAL_PREFIX = "[Special] "

local function buildTwCommand(args)
    return shellQuote(M.config.tw_binary) .. " " .. shellQuote(M.config.wiki_path) .. " " .. args
end

local function twExecute(args)
    local command = buildTwCommand(args)
    local output, ok = hs.execute(command, true)
    if not ok then
        hs.alert.show("TiddlyWiki command failed")
        return nil
    end
    return output or ""
end

local function titleExists(titles, candidate)
    for _, title in ipairs(titles) do
        if title == candidate then
            return true
        end
    end
    return false
end

local function removeTitleFromCache(title)
    for i, existing in ipairs(_cache.titles) do
        if existing == title then
            table.remove(_cache.titles, i)
            break
        end
    end
end

function M.loadTitles(force)
    local now = os.time()
    if not force and #_cache.titles > 0 and (now - _cache.loaded_at) < M.config.cache_ttl_seconds then
        return _cache.titles
    end

    local output = twExecute("ls")
    if output == nil then
        return {}
    end

    local titles = {}
    for _, line in ipairs(splitLines(output)) do
        local title = trim(line)
        if title ~= "" then
            if not M.config.hide_system_tiddlers or not title:match("^%$:/") then
                table.insert(titles, title)
            end
        end
    end

    _cache.titles = titles
    _cache.loaded_at = now
    return titles
end

function M.openInEditor(title)
    local command = string.format(
        "EDITOR=nvim %s edit %s",
        buildTwCommand(""),
        shellQuote(title)
    )
    runInNewTerminal(command, false, {
        float = true,
        size = { w = 1200, h = 800 },
    })
end

function M.createTiddler(title)
    local output = twExecute("touch " .. shellQuote(title))
    if output == nil then
        return false
    end
    if not titleExists(_cache.titles, title) then
        table.insert(_cache.titles, title)
        table.sort(_cache.titles)
    end
    return true
end

function M.deleteTiddler(title)
    local output = twExecute("rm " .. shellQuote(title))
    if output == nil then
        return false
    end
    removeTitleFromCache(title)
    return true
end

local function renderTiddlywikiDate(format, timestamp)
    local converted = format
    converted = converted:gsub("YYYY", "%%Y")
    converted = converted:gsub("0MM", "%%m")
    converted = converted:gsub("0DD", "%%d")
    converted = converted:gsub("MM", "%%-m")
    converted = converted:gsub("DD", "%%-d")
    return os.date(converted, timestamp or os.time())
end

function M.todayJournalTitle()
    return renderTiddlywikiDate(M.config.journal_title_format, os.time())
end

local function ensureTiddlerExists(title)
    if not titleExists(_cache.titles, title) then
        return M.createTiddler(title)
    end
    return true
end

local function promptAndAppendTo(title, promptTitle)
    local button, text = hs.dialog.textPrompt(
        promptTitle,
        "Append to " .. title,
        "",
        "Append",
        "Cancel"
    )

    if button ~= "Append" then
        return
    end

    local content = trim(text)
    if content == "" then
        return
    end

    if not ensureTiddlerExists(title) then
        return
    end

    local stamp = os.date("%Y-%m-%d %H:%M")
    local entry = "\n* " .. stamp .. " " .. content
    local output = twExecute("append " .. shellQuote(title) .. " " .. shellQuote(entry))
    if output == nil then
        return
    end

    hs.alert.show("Appended to " .. title)
end

local function buildSpecialActions()
    local todayTitle = M.todayJournalTitle()
    local actions = {}

    actions[SPECIAL_PREFIX .. "Open Today's Journal (" .. todayTitle .. ")"] = function()
        if ensureTiddlerExists(todayTitle) then
            M.openInEditor(todayTitle)
        end
    end

    actions[SPECIAL_PREFIX .. "Append to Today's Journal (" .. todayTitle .. ")"] = function()
        promptAndAppendTo(todayTitle, "Today Journal")
    end

    actions[SPECIAL_PREFIX .. "Open Inbox (" .. M.config.inbox_tiddler .. ")"] = function()
        if ensureTiddlerExists(M.config.inbox_tiddler) then
            M.openInEditor(M.config.inbox_tiddler)
        end
    end

    actions[SPECIAL_PREFIX .. "Append to Inbox (" .. M.config.inbox_tiddler .. ")"] = function()
        promptAndAppendTo(M.config.inbox_tiddler, "Inbox")
    end

    return actions
end

function M.quickOpen()
    local titles = M.loadTitles(false)
    local specialActions = buildSpecialActions()
    local choices = {}

    for label, _ in pairs(specialActions) do
        table.insert(choices, label)
    end
    table.sort(choices)

    for _, title in ipairs(titles) do
        table.insert(choices, title)
    end

    chooser.showWithOptions(choices, function(selected)
        if selected == nil then
            return
        end

        local title = trim(selected)
        if title == "" then
            return
        end

        local specialAction = specialActions[title]
        if specialAction then
            specialAction()
            return
        end

        if not titleExists(titles, title) then
            local ok = M.createTiddler(title)
            if not ok then
                return
            end
        end

        M.openInEditor(title)
    end, {
        allowFreeform = true,
        allowDelete = true,
        onDelete = function(title)
            if title:sub(1, #SPECIAL_PREFIX) == SPECIAL_PREFIX then
                hs.alert.show("Special entries cannot be deleted")
                return
            end
            local confirm = hs.dialog.blockAlert(
                "Delete Tiddler",
                "Delete \"" .. title .. "\"?",
                "Delete",
                "Cancel"
            )
            if confirm ~= "Delete" and confirm ~= 1000 then
                return
            end

            if M.deleteTiddler(title) then
                hs.alert.show("Deleted: " .. title)
            end
        end,
        placeholder = "Search/create tiddlers, Enter=open/create, Ctrl-D=delete",
    })
end

function M.init()
    hs.hotkey.bind(hyper.key, "space", function()
        M.quickOpen()
    end)
end

return M
