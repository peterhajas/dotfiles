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

-- Returns the file path with this name, or `nil` if none exists
function P.FilePath(name)
    local files = vim.fn.globpath(Paths.WikiPath(), '**/' .. name .. ".md", 1, 1)

    if not files or #files == 0 then
        return nil
    end

    return files[1]
end

return P
