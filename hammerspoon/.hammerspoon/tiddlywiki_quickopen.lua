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
    inbox_tiddler = "Inbox",
    journal_title_format = os.getenv("TW_JOURNAL_TITLE_FORMAT") or "YYYY-0MM-0DD",
}

local _cache = {
    titles = {},
    loaded_at = 0,
}

local SPECIAL_PREFIX = "[Special] "

local function escapeHtml(str)
    if str == nil then
        return ""
    end
    return tostring(str)
        :gsub("&", "&amp;")
        :gsub("<", "&lt;")
        :gsub(">", "&gt;")
        :gsub('"', "&quot;")
end

local function plainPreviewHTML(title, message)
    return [[
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <style>
    body {
      margin: 0;
      padding: 18px;
      background: rgba(20, 20, 30, 0.95);
      color: #d2d8e2;
      font-family: Menlo, Monaco, monospace;
      font-size: 14px;
      line-height: 1.5;
    }
    h1 {
      font-size: 15px;
      margin: 0 0 10px;
      color: #f0f3f8;
    }
    p {
      margin: 0;
      white-space: pre-wrap;
    }
  </style>
</head>
<body>
  <h1>]] .. escapeHtml(title or "Preview") .. [[</h1>
  <p>]] .. escapeHtml(message or "") .. [[</p>
</body>
</html>
]]
end

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

local function isSystemTiddler(title)
    return type(title) == "string" and title:match("^%$:/") ~= nil
end

local function compareTitles(a, b)
    local aIsSystem = isSystemTiddler(a)
    local bIsSystem = isSystemTiddler(b)
    if aIsSystem ~= bIsSystem then
        return not aIsSystem
    end

    local aKey = tostring(a):lower()
    local bKey = tostring(b):lower()
    if aKey == bKey then
        return tostring(a) < tostring(b)
    end
    return aKey < bKey
end

local function removeTitleFromCache(title)
    for i, existing in ipairs(_cache.titles) do
        if existing == title then
            table.remove(_cache.titles, i)
            break
        end
    end
end

local function quickOpenHelpTitle()
    if type(TiddlyWikiQuickOpenHelpTitle) == "function" then
        return TiddlyWikiQuickOpenHelpTitle()
    end
    return "$:/plugins/phajas/hud/QuickOpenPreviewHelp"
end

local function canUseHUDPreview()
    return type(TiddlyWikiBuildHUDHTML) == "function" and type(TiddlyWikiUpdateHUDCurrent) == "function"
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
            table.insert(titles, title)
        end
    end

    table.sort(titles, compareTitles)

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
        table.sort(_cache.titles, compareTitles)
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
    local previewTargets = {}

    local openTodayLabel = SPECIAL_PREFIX .. "Open Today's Journal (" .. todayTitle .. ")"
    actions[openTodayLabel] = function()
        if ensureTiddlerExists(todayTitle) then
            M.openInEditor(todayTitle)
        end
    end
    previewTargets[openTodayLabel] = todayTitle

    local appendTodayLabel = SPECIAL_PREFIX .. "Append to Today's Journal (" .. todayTitle .. ")"
    actions[appendTodayLabel] = function()
        promptAndAppendTo(todayTitle, "Today Journal")
    end
    previewTargets[appendTodayLabel] = todayTitle

    return actions, previewTargets
end

local function buildPreviewRuntimeHTML()
    if not canUseHUDPreview() then
        return nil
    end
    return TiddlyWikiBuildHUDHTML(quickOpenHelpTitle(), "Select a tiddler to preview.")
end

local function setPreviewTarget(previewWebview, targetTitle, helpText)
    if not previewWebview then
        return false
    end
    if not canUseHUDPreview() then
        return false
    end
    return TiddlyWikiUpdateHUDCurrent(previewWebview, targetTitle, helpText)
end

function M.quickOpen()
    local titles = M.loadTitles(false)
    local specialActions, specialPreviewTargets = buildSpecialActions()
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
        enablePreview = true,
        previewPlaceholder = "Select a tiddler to preview",
        onPreviewInit = function(previewWebview)
            local runtimeHTML = buildPreviewRuntimeHTML()
            if runtimeHTML then
                previewWebview:html(runtimeHTML)
                hs.timer.doAfter(0.2, function()
                    setPreviewTarget(previewWebview, quickOpenHelpTitle(), "Select a tiddler to preview.")
                end)
            else
                previewWebview:html(plainPreviewHTML("Preview", "Could not load wiki HTML."))
            end
        end,
        onPreviewEvent = function(previewWebview, selection)
            local text = trim(selection)
            local helpTitle = quickOpenHelpTitle()
            if text == "" then
                return setPreviewTarget(previewWebview, helpTitle, "Type to search, or select an entry.")
            end

            if text:sub(1, #SPECIAL_PREFIX) == SPECIAL_PREFIX then
                local target = specialPreviewTargets[text]
                if target then
                    if titleExists(titles, target) then
                        return setPreviewTarget(previewWebview, target, "")
                    end
                    return setPreviewTarget(previewWebview, helpTitle, "Will create on use: " .. target)
                end
                return setPreviewTarget(previewWebview, helpTitle, "Execute this special action.")
            end

            if not titleExists(titles, text) then
                return setPreviewTarget(previewWebview, helpTitle, "Press Enter to create this new tiddler: " .. text)
            end

            return setPreviewTarget(previewWebview, text, "")
        end,
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
        if chooser.isVisible and chooser.isVisible() then
            chooser.hide()
            return
        end
        M.quickOpen()
    end)
end

return M
