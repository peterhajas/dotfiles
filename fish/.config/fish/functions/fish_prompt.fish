function fish_prompt
    # Print the status if non-zero
    # (thanks James!)
    if test $status -gt 0
        set_color yellow; echo -n "$status " 
    end
    set_color cyan; echo -n (prompt_current_user)
    set_color red; echo -n (prompt_current_hostname)
    set_color normal
    set_color green; echo -n (echo (prompt_pwd | sed 's/\~\///' | sed 's/\~//'))
    # Only print a space if we're not in ~
    # (~ isn't shown, so we just want the prompt char)
    pwd | read working_dir
    if test $working_dir != $HOME
        echo -n ' '
    end
    prompt_char
end
