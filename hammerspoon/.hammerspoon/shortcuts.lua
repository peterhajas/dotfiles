-- Returns a list of Shortcuts
function allShortcuts()
    local listOfShortcuts = hs.execute("shortcuts list")
    local lines = linesInString(listOfShortcuts)
    return lines
end

-- Returns a list of shortcuts in `folder`
function shortcutsInFolder(folder)
    local command = "shortcuts list --folder-name \"" .. folder .. "\""
    local listOfShortcuts = hs.execute(command)
    local lines = linesInString(listOfShortcuts)
    return lines
end

-- Returns a list of all the shortcut folders present
function shortcutFolders()
    local listOfFolders = hs.execute("shortcuts list --folders")
    local lines = linesInString(listOfFolders)
    return lines
end

-- Returns a list of folder dictionaries, with names and their shortcuts contained
-- [
--     { "name" : "Some Folder Name",
--       "shortcuts" : [ strings of shortcut names ]
--     }
-- ]
function shortcutsByFolder()
    local byFolder = { }
    local folders = shortcutFolders()
    
    for index, folder in pairs(folders) do
        local folderShortcuts = shortcutsInFolder(folder)
        local folderDictionary = {
            ["name"] = folder,
            ["shortcuts"] = folderShortcuts,
        }

        table.insert(byFolder, folderDictionary)
    end

    return byFolder
end

-- Runs the Shortcut with the specified name
function runShortcut(name)
    local command = "shortcuts run " .. name
    hs.execute(command)
end

-- Views the Shortcut with the specified name
function viewShortcut(name)
    local command = "shortcuts view " .. name
    hs.execute(command)
end
