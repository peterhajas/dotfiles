function version_control_repo_type
    pwd | read CURRENT_DIRECTORY

    while test -d ~
        echo $CURRENT_DIRECTORY | wc -c | read CURRENT_DIRECTORY_LENGTH

        if test 2 -eq $CURRENT_DIRECTORY_LENGTH
            echo -n 'none'
            return
        else if test -e $CURRENT_DIRECTORY/.git
            echo -n git
            return
        else if test -d $CURRENT_DIRECTORY/.svn
            echo -n svn
            return
        else if test -d $CURRENT_DIRECTORY/.hg
            echo -n hg
            return
        end

        dirname $CURRENT_DIRECTORY | read CURRENT_DIRECTORY
    end
end
