local ok, snacks = pcall(require, "snacks")
if not ok then
    return
end

snacks.setup({
    dashboard = {
        enabled = true,
        sections = {
            { section = "header" },
            { section = "keys", gap = 1, padding = 1 },
            {
                icon = " ",
                title = "Recent Files (cwd)",
                section = "recent_files",
                cwd = true,
                indent = 2,
                padding = 1,
                filter = function(file)
                    if file:match("/%.git/") then
                        return false
                    end
                    return vim.loop.fs_stat(file) ~= nil
                end,
            },
            { section = "startup" },
            {
                section = "terminal",
                cmd = "pokemon-colorscripts -r --no-title; sleep .1",
                random = 10,
                pane = 2,
                indent = 4,
                height = 30,
                padding = 1,
            },
        },
    },
})
