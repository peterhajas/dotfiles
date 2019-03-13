function abbrev -d "Install fish abbreviations"
    # git
    abbr g git
    abbr gb 'git branch | fzf | xargs git checkout'
    abbr gc git checkout
    abbr gl git log
    abbr gp git push
    abbr gs git status
    abbr leaderboard git shortlog -sn
    
    # vim
    abbr v 'find . | fzf | xargs -o vim'

    # misc.
    abbr c cd
    abbr l ls -lah
end
