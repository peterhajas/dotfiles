function abbrev -d "Install fish abbreviations"
    # git
    abbr g git
    abbr gc git checkout
    abbr gl git log
    abbr leaderboard git shortlog -sn
    
    # vim
    abbr v vim

    # misc.
    abbr l ls -lah
    abbr c cd
end
