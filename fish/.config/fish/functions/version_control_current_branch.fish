function version_control_current_branch
    version_control_repo_type | read repo_type
    
    switch $repo_type
        case git
            git branch |grep "* " | awk '{print substr($0, 3)}'
        case svn
            # No idea if this works
            svn info | sed -n "/URL:/s/.*\///p" | read branch
        case hg
            hg branch | read branch
        end

    echo -n $branch
end
