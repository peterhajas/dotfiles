function version_control_current_branch
    version_control_repo_type | read repo_type

    set branch ""

    switch $repo_type
        case git
            git branch 2>/dev/null | grep "* " | awk '{print substr($0, 3)}' | read branch
        case svn
            # No idea if this works
            svn info 2>/dev/null | sed -n "/URL:/s/.*\///p" | read branch
        case hg
            hg branch 2>/dev/null | read branch
    end

    echo -n $branch
end
