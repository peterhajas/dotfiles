function prompt_current_hostname
    # Only print the hostname if this is an SSH session
    if test -n "$SSH_CONNECTION"
        echo -n (hostname -s) | read HOSTNAME
        echo -n "$HOSTNAME "
    end
end
