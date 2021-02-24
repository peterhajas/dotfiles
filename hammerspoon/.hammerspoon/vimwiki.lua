require "hyper"
require "util"
require "terminal"

-- Path to our vimwiki
local vimwikiPath = "/Users/phajas/.vimwiki"


-- Completion callback for the chooser
local function chooserComplete(result)
    -- Result is nil if we escaped out
    if result == nil then return end

    -- Check if we should open a file
    local filePathToOpen = result['filePath']
    if filePathToOpen ~= nil then
        runInNewTerminal('vim ' .. filePathToOpen)
    end
end

function showVimwikiMenu()
    -- Find all the vimwiki files
    local command = "find " .. vimwikiPath .. " |grep .md"
    local allFilesNewlineSeparated = hs.execute(command)
    local allFilePaths = split(allFilesNewlineSeparated, '\n')

    -- Make our choices for files
    local choices = { }

    for index, filePath in pairs(allFilePaths) do
        -- For the text, strip the vimwiki path
        local title = string.gsub(filePath, vimwikiPath .. '/', "")

        -- Grab the file contents
        local lines = linesInFile(filePath)
        local subText = ""
        for j, line in pairs(lines) do
            subText = subText .. ' ' .. line
        end

        subText = string.gsub(subText, "  ", " ")
        subText = title .. subText

        table.insert(choices,
        {
            ["text"] = title,
            ["subText"] = subText,
            ["filePath"] = filePath
        })
    end

    local chooser = hs.chooser.new(chooserComplete)
        :searchSubText(true)
        :choices(choices)

    chooser:show()
end

-- Bind hyper-space
hs.hotkey.bind(hyper, 'space', function()
    showVimwikiMenu()
end)
