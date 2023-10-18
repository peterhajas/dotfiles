local Navigation = require("phajas.wiki_navigation")
local Paths = require("phajas.wiki_paths")
local Backlinks = require("phajas.wiki_backlinks")
local I = {}

-- Key: Window number
-- Value: Table of Info state about that window
--  visible : bool about whether or not it's currently visible
--  bufno : the buffer showing info for this window
I._visibleInfos = {}
function I._IsInfoVisible(winno)
    return I._visibleInfos[winno] ~= nil and I._visibleInfos[winno].visible == true
end

function I._SetInfoVisible(winno, new)
    if I._visibleInfos[winno] == nil then
        I._visibleInfos[winno] = {}
    end
    I._visibleInfos[winno].visible = new
end

function I._NewInfoBuffer(winno, bufno)
    local infobufno = vim.api.nvim_create_buf(false, true)
    I._visibleInfos[winno].bufno = infobufno

    -- Mark it non-modifiable
    vim.api.nvim_buf_set_option(infobufno, 'modifiable', false)
    -- Register a key command so that when we hit enter, we open that file
    vim.api.nvim_buf_set_keymap(infobufno, 'n', '<CR>', '', {
        callback = function()
            local infoWinno = vim.api.nvim_get_current_win()
            Navigation.OpenFileAtCursor(infoWinno, winno, infobufno)
            -- Switch focus back to the editor
            vim.api.nvim_set_current_win(winno)
        end
    })
    return infobufno
end

function I._UpdateInfoBuffer(infobufno, forPath)
    vim.api.nvim_buf_set_option(infobufno, 'modifiable', true)
    local lines = {}
    table.insert(lines, "# " .. Paths.FileName(forPath))
    table.insert(lines, "")
    table.insert(lines, "## Backlinks:")
    table.insert(lines, "")
    for _, b in ipairs(Backlinks.Backlinks(forPath)) do
        table.insert(lines, Paths.FileName(b))
    end
    vim.api.nvim_buf_set_lines(infobufno, 0, -1, false, lines)
    vim.api.nvim_buf_set_option(infobufno, 'modifiable', false)
end

function I.UpdateInfoBuffer(bufno, winno)
    if I._visibleInfos[winno] ~= nil then
        local infobufno = I._visibleInfos[winno].bufno
        local path = vim.api.nvim_buf_get_name(bufno)
        I._UpdateInfoBuffer(infobufno, path)
    end
end

function I.ShowInfo(bufno, winno)
    I._SetInfoVisible(winno, true)
    if I._visibleInfos[winno].bufno == nil then
        I._visibleInfos[winno].bufno = I._NewInfoBuffer(winno, bufno)
    end
    local infobufno = I._visibleInfos[winno].bufno
    local infoWidth = 40
    vim.api.nvim_command('split')
    vim.api.nvim_command('wincmd L')
    vim.api.nvim_command('buffer ' .. infobufno)
    -- plh-evil: seems to not work to actually resize
    vim.api.nvim_win_set_width(vim.api.nvim_get_current_win(), infoWidth)
    vim.api.nvim_command('wincmd h')

    local path = vim.api.nvim_buf_get_name(bufno)
    I._UpdateInfoBuffer(infobufno, path)
    print("show")
end

function I.HideInfo(bufno, winno)
    I._SetInfoVisible(winno, false)
    if I._visibleInfos[winno].bufno ~= nil then
        vim.api.nvim_command('bdelete ' .. I._visibleInfos[winno].bufno)
    end
    I._visibleInfos[winno] = nil
    print("hide")
end

function I.ToggleInfo(bufno, winno)
    local infoVisible = I._IsInfoVisible(winno)
    if infoVisible then
        I.HideInfo(bufno, winno)
    else
        I.ShowInfo(bufno, winno)
    end
end

return I
