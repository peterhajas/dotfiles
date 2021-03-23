function prompt_current_hostname
    echo $SSH_TTY | wc -c | xargs | read SSH_TTY_BYTES
    # Only print the hostname if this is an SSH session
    if test $SSH_TTY_BYTES -gt 1
        echo -n (hostname -s) | read HOSTNAME
        echo -n "$HOSTNAME "
    end
end
