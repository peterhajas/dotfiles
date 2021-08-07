require "shortcuts"

function buttonForShortcut(name)
    local options = {
        ['fontSize'] = 32
    }
    return {
        ['image'] = streamdeck_imageFromText(name, options),
        ['onClick'] = function()
            runShortcut(name)
        end,
        ['onLongPress'] = function()
            viewShortcut(name)
        end,
    }
end

function buttonsForShortcuts(listOfShortcutNames)
    local buttons = { }
    for index, shortcut in pairs(listOfShortcutNames) do
        local button = buttonForShortcut(shortcut)
        table.insert(buttons, button)
    end
    return buttons
end

function buttonForFolder(folderName)
    local options = {
        ['fontSize'] = 32
    }
    return {
        ['image'] = streamdeck_imageFromText(folderName, options),
        ['children'] = function()
            return buttonsForShortcuts(shortcutsInFolder(folderName))
        end
    }
end

function buttonsForFolders(folders)
    local buttons = { }
    for index, folder in pairs(folders) do
        local button = buttonForFolder(folder)
        table.insert(buttons, button)
    end
    return buttons
end

-- Returns the general Shortcuts button
function shortcuts()
    local bundleID = 'com.apple.shortcuts'
    return {
        ['name'] = 'Shortcuts',
        ['image'] = hs.image.imageFromAppBundle(bundleID),
        ['onLongPress'] = function()
            hs.application.open(bundleID)
        end,
        ['children'] = function()
            return buttonsForFolders(shortcutFolders())
        end
    }
end

