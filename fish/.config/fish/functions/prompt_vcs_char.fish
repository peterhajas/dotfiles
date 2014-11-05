function prompt_vcs_char
    git branch >/dev/null 2>/dev/null; and echo -n '±'; and return
    hg root >/dev/null 2>/dev/null; and echo -n '☿'; and return
    svn info >/dev/null 2>/dev/null; and echo -n '§'; and return
    return
end
