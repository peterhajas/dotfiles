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

-- Debug print
function dbg(string)
    local debugLogger = hs.logger.new('debug', 'debug')
    debugLogger:i(hs.inspect(string))
end
