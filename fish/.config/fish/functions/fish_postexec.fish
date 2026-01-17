function fish_postexec --on-event fish_postexec
    # Save the exit status from the command that just executed
    # This is used by fish_prompt to color the directory
    set -g __fish_prompt_last_status $status
end
