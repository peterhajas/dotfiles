function prompt_vcs_info
    version_control_repo_type | read repo_type
    
    if test $repo_type != 'none'
        set_color red; echo -n (prompt_vcs_char)
        echo -n ' '
        set_color yellow; echo -n (version_control_current_branch)
    end
end
