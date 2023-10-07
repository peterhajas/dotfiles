require("blame_line").setup {
    show_in_visual = false,
    show_in_insert = false,
    prefix = "",
    template = "<author>, <author-time>: <summary>",
    date = {
        relative = false,
        format = "%y-%m-%d",
    }
}

