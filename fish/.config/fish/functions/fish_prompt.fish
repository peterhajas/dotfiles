function fish_prompt
    set_color purple; echo -n (prompt_current_hostname)
    echo -n ' '
    set_color green; echo -n (prompt_pwd)
    echo -n ' '
    echo (prompt_vcs_info)
    set_color cyan; echo -n (prompt_current_user)
    set_color normal; echo ' > '
end
