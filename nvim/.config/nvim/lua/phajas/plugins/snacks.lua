local snacks = require("snacks")

snacks.setup({
    dashboard = {
        enabled = true,
        sections = {
            { section = "header" },
            {
                section = "terminal",
                cmd = {
                    "sh",
                    "-lc",
                    "if command -v pokemon-colorscripts >/dev/null 2>&1; then out=\"$(pokemon-colorscripts -r)\"; name=\"$(printf '%s\\n' \"$out\" | sed -n '1p')\"; printf '%s\\n' \"$out\" | sed '1d'; printf '\\n%s\\n' \"$name\"; else printf 'pokemon-colorscripts missing in PATH\\nPATH=%s\\n' \"$PATH\"; fi; sleep .1",
                },
                random = 10,
                ttl = 0,
                indent = 2,
                height = 14,
                padding = 1,
            },
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
        },
    },
})
