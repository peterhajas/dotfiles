local P = {}

function P.WikiPath()
    return vim.fn.expand("~") .. "/phajas-wiki"
end

function P.WikiFilePattern()
    return vim.fn.expand("~") .. "/phajas-wiki/*"
end

-- Returns the pretty "file name" for a path
function P.FileName(path)
    local filename = path:match("^.+/([^/]+)$") or path
    filename = filename:gsub("%..*", "")
    return filename
end

return P
