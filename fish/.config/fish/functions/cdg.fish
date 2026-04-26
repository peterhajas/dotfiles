function cdg --description "fzf-pick a dir from sessionize sources, cd into it"
    if not type -q sessionize
        return
    end
    set -l dir (sessionize --pick-dir)
    if test -n "$dir" -a -d "$dir"
        cd $dir
    end
    commandline -f repaint
end
