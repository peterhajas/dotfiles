function prompt_current_user
    echo -n (whoami) | read USER
    # Print if we're not me
    if test $USER != phajas
        echo -n "$USER "
    end
end
