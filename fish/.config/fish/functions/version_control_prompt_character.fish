function version_control_prompt_character
    git branch >/dev/null 2>/dev/null; and echo '±'; and return
    # hg root >/dev/null 2>/dev/null; and echo '☿'; and return
    svn info >/dev/null 2>/dev/null; and echo '§'; and return
    echo '○'
end
