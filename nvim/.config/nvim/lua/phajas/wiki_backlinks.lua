Paths = require("phajas.wiki_paths")

local B = {}

-- Returns a list of files that point to `path`
function B.Backlinks(path)
    local files = vim.fn.globpath(Paths.WikiPath(), '**/*.md', 1, 1)
    local pattern = '%[%[' .. Paths.FileName(path):lower() .. '%]%]'
    local backlinks = {}
    for _, filepath in pairs(files) do
        if filepath ~= path then
            local file = io.open(filepath, 'r')
            if file then
                for line in file:lines() do
                    local found = false
                    local lowercaseLine = string.lower(line)
                    for _ in lowercaseLine:gmatch(pattern) do
                        table.insert(backlinks, filepath)
                        found = true
                        break
                    end
                    if found then
                        break
                    end
                end

                file:close()
            end
        end
    end
    return backlinks
end

return B
