function prompt_current_hostname
    echo -n (hostname -s) | read HOSTNAME
    switch $HOSTNAME
        case Poseidon
            echo -n " 🌊 "
            return
        case *
            echo -n $HOSTNAME
        end
end
