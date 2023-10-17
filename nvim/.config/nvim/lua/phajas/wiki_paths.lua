local P = {}

function P.WikiPath()
    return vim.fn.expand("~") .. "/phajas-wiki"
end

function P.WikiFilePattern()
    return vim.fn.expand("~") .. "/phajas-wiki/*"
end

return P
