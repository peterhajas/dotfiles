-- from https://stackoverflow.com/a/7615129
function split(inputstr, sep)
    if sep == nil then
        sep = "%s"
    end
    local t={}
    for str in string.gmatch(inputstr, "([^"..sep.."]+)") do
        table.insert(t, str)
    end
    return t
end

function linesInString(str)
    return split(str, '\n')
end

-- https://stackoverflow.com/questions/2705793/how-to-get-number-of-entries-in-a-lua-table
function tableLength(T)
  local count = 0
  for _ in pairs(T) do count = count + 1 end
  return count
end

-- Converts a boolean to a number
function boolToNumber(value)
  return value and 1 or 0
end

-- Clones a table
function cloneTable(oldTable)
    local newTable = {}
    for k,v in pairs(oldTable) do
        newTable[k] = v
    end
    return newTable
end

-- https://stackoverflow.com/questions/1283388/lua-merge-tables
function mergeTables(t1, t2)
    for k,v in pairs(t2) do
        if type(v) == "table" then
            if type(t1[k] or false) == "table" then
                mergeTables(t1[k] or {}, t2[k] or {})
            else
                t1[k] = v
            end
        else
            t1[k] = v
        end
    end
    return t1
end

-- https://stackoverflow.com/questions/11201262/how-to-read-data-from-a-file-in-lua
-- see if the file exists
function fileExists(file)
    local f = io.open(file, "rb")
    if f then f:close() end
    return f ~= nil
end

-- https://stackoverflow.com/questions/11201262/how-to-read-data-from-a-file-in-lua
-- get all lines from a file, returns an empty 
-- list/table if the file does not exist
function linesInFile(file)
    if not fileExists(file) then return {} end
    lines = {}
    for line in io.lines(file) do 
      lines[#lines + 1] = line
    end
    return lines
end

function writeLinesToFile(file, lines)
    handle = io.open(file, 'w')
    for i, line in pairs(lines) do
        handle:write(line)
        handle:write('\n')
    end
    handle:close()
end

-- https://stackoverflow.com/a/32660766
-- ignore_mt means ignore metatables
function equals(o1, o2, ignore_mt)
    if o1 == o2 then return true end
    local o1Type = type(o1)
    local o2Type = type(o2)
    if o1Type ~= o2Type then return false end
    if o1Type ~= 'table' then return false end

    if not ignore_mt then
        local mt1 = getmetatable(o1)
        if mt1 and mt1.__eq then
            --compare using built in method
            return o1 == o2
        end
    end

    local keySet = {}

    for key1, value1 in pairs(o1) do
        local value2 = o2[key1]
        if value2 == nil or equals(value1, value2, ignore_mt) == false then
            return false
        end
        keySet[key1] = true
    end

    for key2, _ in pairs(o2) do
        if not keySet[key2] then return false end
    end
    return true
end

-- Debug print
function dbg(string)
    -- Note that this may do _nothing_ if this is a 0-length string!
    local debugLogger = hs.logger.new('debug', 'debug')
    debugLogger:i(hs.inspect(string))
end

-- Stops a timer from running
function stopTimer(timer)
    if timer ~= nil then
        timer:stop()
    end
end

