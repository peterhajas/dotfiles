function fish_prompt
    set_color purple; echo -n (prompt_current_hostname)
    echo -n ' '
    set_color green; echo -n (prompt_pwd)
    echo -n ' '
    echo (prompt_vcs_info)
    set_color cyan; echo -n (prompt_current_user)
    set_color F5A623 --bold; echo -n ' '; echo -n (prompt_vcs_char)
    set_color normal
    set_color F5A623; echo -n (prompt_vcs_status)
    set_color normal
    echo -n ' '
end
