function fish_prompt
    set_color cyan; echo -n (prompt_current_user)
    set_color normal
    echo -n ' '
    set_color green; echo -n (prompt_pwd)
    echo -n ' '
    prompt_char
end
