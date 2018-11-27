function notify -d "Send a user notification"
    set message $argv[1]
    set intensity $argv[2]
    
    if test $intensity -eq 0
        hammerspoon notifySoftly text $message
    else if test $intensity -eq 1
        hammerspoon notify text $message
    else
        hammerspoon notifyUrgently text $message
    end
end

