function fish_prompt
    # Use saved status from last actual command (defaults to 0)
    set -l last_status $__fish_prompt_last_status
    if test -z "$last_status"
        set last_status 0
    end

    # Username and hostname
    set_color cyan; echo -n (prompt_current_user)
    set_color red; echo -n (prompt_current_hostname)
    set_color normal

    # Color directory based on last command exit status
    if test $last_status -eq 0
        set_color green
    else
        set_color red
    end
    echo -n (echo (prompt_pwd | sed 's/\~\///' | sed 's/\~//'))
    # Only print a space if we're not in ~
    # (~ isn't shown, so we just want the prompt char)
    set working_dir (pwd)
    if test $working_dir != $HOME
        echo -n ' '
    end
    prompt_char

    # Reset status for next prompt (will be overwritten by fish_postexec if command runs)
    set -g __fish_prompt_last_status 0

    # Force block cursor
    printf '\e[2 q'
end
