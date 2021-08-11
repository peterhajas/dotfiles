soundboardDirectory = "~/sounds"

function allSoundPaths()
    local command = "find " .. soundboardDirectory .. " |grep .mp3"
    local allSoundsNewlineSeparated = hs.execute(command)
    local allFiles = split(allSoundsNewlineSeparated, '\n')
    return allFiles
end

function buttonForSoundPath(soundPath)
    local pathElements = split(soundPath, '/')
    local name = pathElements[tableLength(pathElements)]
    name = split(name, ".mp3")
    return {
        ['name'] = "Soundboard" .. soundPath,
        ['image'] = streamdeck_imageFromText(name, { ['fontSize'] = 24 } ),
        ['onClick'] = function()
            local sound = hs.sound.getByFile(soundPath)
            sound:play()
        end
    }
end

function soundboardButton()
    return {
        ['name'] = "Soundboard",
        ['image'] = streamdeck_imageFromText("􀫀"),
        ['children'] = function()
            local children = {}
            for index, soundPath in pairs(allSoundPaths()) do
                table.insert(children, buttonForSoundPath(soundPath))
            end
            return children
        end,
    }
end

