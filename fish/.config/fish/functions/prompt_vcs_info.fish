function prompt_vcs_info
    version_control_repo_type | read repo_type
    
    if test $repo_type != 'none'
        echo -n (version_control_current_branch)
    end
end
