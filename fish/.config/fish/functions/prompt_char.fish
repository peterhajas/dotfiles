function prompt_char
    version_control_repo_type | read REPO_TYPE
    echo -n "F5A623" | read PROMPT_COLOR
    echo -n "99CC99" | read PROMPT_GREEN
    echo -n "F2777A" | read PROMPT_RED
    echo -n "6699CC" | read PROMPT_BLUE
    # If we're in a VCS, print some info
    if test $REPO_TYPE != (echo -n 'none')
        # Current branch
        echo -n (prompt_vcs_info)
        echo -n ' '

        # Find the status of the current VCS
        echo -n (prompt_vcs_status) | read VCS_STATUS
        echo $VCS_STATUS | wc -c | read VCS_STATUS_LENGTH
        # If there is a status, pick a color for it
        if test $VCS_STATUS_LENGTH -gt 1
            switch $VCS_STATUS
                # Staged -> Green
                case "+"
                    echo -n $PROMPT_GREEN | read PROMPT_COLOR
                # Untracked -> Blue
                case "?"
                    echo -n $PROMPT_BLUE | read PROMPT_COLOR
                # Unstaged -> Red
                case "!"
                    echo -n $PROMPT_RED | read PROMPT_COLOR
                end
        end

        # Now that we (might) have a custom color, set it and print the prompt character
        set_color $PROMPT_COLOR --bold
        echo -n (prompt_vcs_char)
    else
        # Print the regular prompt character
        set_color $PROMPT_COLOR --bold
        echo -n '▶'
    end
    set_color normal
    echo -n ' '
end
