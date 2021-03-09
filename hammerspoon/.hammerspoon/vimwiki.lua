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

-- The choices for our todos
local todoChoices = { }

-- The current choices
local currentChoices = { }

-- The mode we're in
-- Possible values:
-- nil - normal (file choosing / menu mode)
-- "todo" - todo picking mode
local mode = nil

-- Some regexes for todos:
local outstandingPattern = '%- %[ %]'
local donePattern = '%- %[X%]'

-- Applies extra choices based on mode
local function applyExtraChoices(inChoices)
    local choices = cloneTable(inChoices)
    local beginningCommands = { }
    local endCommands = { }

    -- Add in extras
    if mode == nil then
        beginningCommands =
        {
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
            {
                ["text"] = "To-Do Triage",
                ["subText"] = "Look through outstanding to-dos",
                ["command"] = "showToDos"
            }
        }

        endCommands = {
            {
                ["text"] = "Open Diary",
                ["subText"] = "Opens today's diary",
                ["command"] = "diaryNote"
            },
        }
    end

    if mode ~= nil then
        table.insert(endCommands, {
            ["text"] = "Back",
            ["subText"] = "Go back",
            ["command"] = "clearMode"
        })
    end

    for i, command in pairs(beginningCommands) do
        table.insert(choices, i, command)
    end

    for i, command in pairs(endCommands) do
        table.insert(choices, command)
    end

    return choices
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
    local stringToWrite = string
    -- Add a newline if we're appending
    if fileExists(diaryPath()) then
        stringToWrite = ' \n' .. string
    end
    local diary = openDiary()
    diary:write(stringToWrite)
    diary:close()
end

-- Updates choices
local function updateChoices(query)
    if query ~= nil then
        query = string.lower(query)
    end

    local effectiveChoices = fileChoices
    if mode == 'todo' then
        effectiveChoices = todoChoices
    end

    local newChoices = { }
    -- See if any of our choices contain the query, split by spaces
    for i, choice in pairs(effectiveChoices) do
        if query ~= nil then
            local choiceSearchString = string.lower(choice['subText'] .. choice['text'])
            -- Make sure we match the query first
            for j, queryElement in pairs(split(query, ' ')) do
                if not string.find(choiceSearchString, queryElement) then
                    goto continue
                end
            end
        end

        table.insert(newChoices, choice)

        ::continue::
    end

    -- Sort our choices
    table.sort(newChoices, function(a, b)
        local aOutstanding = a['outstanding']
        local bOutstanding = b['outstanding']
        
        -- Prefer outstanding ToDos
        if aOutstanding and not bOutstanding then
            return true
        end
        if bOutstanding and not aOutstanding then
            return false
        end

        local aIsDiaryEntry = string.find(a['filePath'], 'diary')
        local bIsDiaryEntry = string.find(b['filePath'], 'diary')

        -- If they're both diary entries, sort them in descending date order
        if aIsDiaryEntry and bIsDiaryEntry then
            return b['filePath'] < a['filePath']
        end

        return a['filePath'] < b['filePath']
    end)

    newChoices = applyExtraChoices(newChoices)

    chooser:choices(newChoices)
    currentChoices = newChoices
end

local function openTerminalTo(choice)
    local filePathToOpen = choice['filePath']
    if filePathToOpen ~= nil then
        runInNewTerminal('vim ' .. filePathToOpen, true)
    end
end

-- The callback for shift-selection / right-clicking
local function alternateSelectionCallback(choice)
    openTerminalTo(choice)
end

local function rightClickCallback(index)
    local choice = currentChoices[index]
    alternateSelectionCallback(choice)
end

-- Completion callback for the chooser
local function chooserComplete(result)
    local query = chooser:query()
    -- Result is nil if we escaped out
    if result == nil then return end

    local modifiers = hs.eventtap.checkKeyboardModifiers()
    local hasShift = modifiers['shift'] ~= nil
    if hasShift then
        alternateSelectionCallback(result)
    end

    local filePathToOpen = result['filePath']
    local command = result['command']

    -- Check if we should open a file
    if command == nil then
        openTerminalTo(result)
    end

    -- Check if we should run a command
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
    if command == "showToDos" then
        mode = "todo"
        updateChoices()
        chooser:show()
    end
    if command == "clearMode" then
        mode = nil
        updateChoices()
        chooser:show()
    end
    if command == "todoToggle" then
        -- Grab the line
        local lineNum = result['lineNum']
        local lines = linesInFile(filePathToOpen)
        local line = lines[lineNum]
        if result['outstanding'] then
            line = string.gsub(line, outstandingPattern, '- [X]')
        else
            line = string.gsub(line, donePattern, '- [ ]')
        end
        lines[lineNum] = line
        writeLinesToFile(filePathToOpen, lines)
    end
end

-- The query callback
local function queryCallback(query)
    updateChoices(query)
end

function showVimwikiMenu()
    -- Clear mode
    mode = nil

    -- Nix the found choices
    for k,v in pairs(fileChoices) do fileChoices[k]=nil end
    for k,v in pairs(todoChoices) do todoChoices[k]=nil end

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

            -- Build our todo choice for this line
            if string.find(line, outstandingPattern) or string.find(line, donePattern) then
                local isOutstanding = string.find(line, outstandingPattern) ~= nil

                todoChoiceLine = line
                todoChoiceLine = string.gsub(todoChoiceLine, '  ', '')
                todoChoiceLine = string.gsub(todoChoiceLine, outstandingPattern, '')
                todoChoiceLine = string.gsub(todoChoiceLine, donePattern, '')

                if isOutstanding then
                    todoChoiceLine = '􀓔' .. todoChoiceLine
                else
                    todoChoiceLine = '􀃳' .. todoChoiceLine
                end
                
                table.insert(todoChoices,
                {
                    ["text"] = todoChoiceLine,
                    ["subText"] = title,
                    ["filePath"] = filePath,
                    ["lineNum"] = j,
                    ["command"] = "todoToggle",
                    ["outstanding"] = isOutstanding,
                })
            end
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
        :rightClickCallback(rightClickCallback)
        :searchSubText(true)
        :choices(fileChoices)

    chooser:show()
end

-- Bind hyper-space
hs.hotkey.bind(hyper, 'space', function()
    showVimwikiMenu()
end)
