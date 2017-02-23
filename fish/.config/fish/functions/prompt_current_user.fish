function prompt_current_user
    echo -n (whoami) | read USER
    if test $USER = phajas
        # It's me! Echo nothing
        echo -n ""
    else
        echo -n $USER
    end
end
