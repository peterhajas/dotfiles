function version_control_repo_type
    if test -d ./.git
        echo -n  git
    else if test -d ./.svn
        echo -n  svn
    else if test -d ./.hg
        echo -n  hg
    else
        echo -n  ''
    end
end
