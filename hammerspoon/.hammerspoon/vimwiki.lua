require "hyper"
require "util"
require "terminal"

-- Path to our vimwiki
local vimwikiPath = "/Users/phajas/.vimwiki"

-- Some caches
-- The chooser
local chooser = nil

-- The choices for our files
local fileChoices = { }
local function allChoices()
    return fileChoices
end

local function diaryPath()
    local diaryFilename = os.date('%Y-%m-%d') .. '.md'
    local diaryFullPath = vimwikiPath .. '/diary/' .. diaryFilename
    return diaryFullPath
end

local function openDiary()
    return io.open(diaryPath(), 'a')
end

local function writeToDiary(string)
    -- plh-evil: these diary appends always add an extra newline at
    -- the start...
    local diary = openDiary()
    diary:write('\n' .. string)
    diary:close()
end

-- Completion callback for the chooser
local function chooserComplete(result)
    local query = chooser:query()
    -- Result is nil if we escaped out
    if result == nil then return end

    -- Check if we should open a file
    local filePathToOpen = result['filePath']
    if filePathToOpen ~= nil then
        runInNewTerminal('vim ' .. filePathToOpen, true)
    end

    -- Check if we should run a command
    local command = result['command']
    if command == "addToDiary" then
        writeToDiary(query)
    end
    if command == "addToDo" then
        local toWrite = "- [ ] " .. query
        writeToDiary(toWrite)
    end
    if command == "diaryNote" then
        runInNewTerminal('vim -c VimwikiMakeDiaryNote', true)
    end
end

-- The query callback
local function queryCallback(query)
    query = string.lower(query)
    local newChoices = { }
    -- See if any of our choices contain this query, split by spaces
    for i, choice in pairs(fileChoices) do
        local choiceSearchString = string.lower(choice['subText'])
        -- Make sure we match the query first
        for j, queryElement in pairs(split(query, ' ')) do
            if not string.find(choiceSearchString, queryElement) then
                goto continue
            end
        end

        table.insert(newChoices, choice)

        ::continue::
    end

    -- We've build all our choices for files
    -- Add some commands at the beginning and end

    local beginningCommands = {
        {
            ["text"] = "Add to Diary",
            ["subText"] = "Adds this string to today's Diary",
            ["command"] = "addToDiary"
        },
        {
            ["text"] = "Add To-Do",
            ["subText"] = "Adds this string to today's Diary as a ToDo",
            ["command"] = "addToDo"
        },
    }

    local endCommands = {
        {
            ["text"] = "Open Diary",
            ["subText"] = "Opens today's diary",
            ["command"] = "diaryNote"
        },
    }

    for i, command in pairs(beginningCommands) do
        table.insert(newChoices, i, command)
    end

    for i, command in pairs(endCommands) do
        table.insert(newChoices, command)
    end
    
    chooser:choices(newChoices)

end

function showVimwikiMenu()
    -- Nix the found choices
    for k,v in pairs(fileChoices) do fileChoices[k]=nil end

    -- Find all the vimwiki files
    local command = "find " .. vimwikiPath .. " |grep .md"
    local allFilesNewlineSeparated = hs.execute(command)
    local allFilePaths = split(allFilesNewlineSeparated, '\n')

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

        table.insert(fileChoices,
        {
            ["text"] = title,
            ["subText"] = subText,
            ["filePath"] = filePath
        })
    end

    chooser = hs.chooser.new(chooserComplete)
        :queryChangedCallback(queryCallback)
        :searchSubText(true)
        :choices(allChoices)

    chooser:show()
end

-- Bind hyper-space
hs.hotkey.bind(hyper, 'space', function()
    showVimwikiMenu()
end)
