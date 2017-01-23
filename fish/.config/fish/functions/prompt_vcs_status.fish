# echos text representing the status of the vcs system currently in use
function prompt_vcs_status
    version_control_repo_type | read repo_type
    
    switch $repo_type
        case git
            git diff --name-only --cached | wc -l | read STAGED
            git ls-files -m --exclude-standard | wc -l | read UNSTAGED
            git ls-files -o --exclude-standard | wc -l | read UNTRACKED
            # Staged: +
            # Unstaged: !
            # Untracked: ?
            # We want these to go in decreasing orders of urgency,
            # so staged -> untracked -> unstaged
            if test $STAGED -gt 0
                echo -n "+"
                return
            end
            if test $UNTRACKED -gt 0
                echo -n "?"
                return
            end
            if test $UNSTAGED -gt 0
                echo -n "!"
                return
            end
            echo -n ""
        end
end
