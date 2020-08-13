function abbrev -d "Install fish abbreviations"
    # git
    abbr g git
    abbr gb 'git branch | fzf | xargs git checkout'
    abbr gc git checkout
    abbr gl git log
    abbr gp git push
    abbr gs git status
    abbr gd git diff
    abbr leaderboard git shortlog -sn
    
    # vim
    abbr vv 'find . | fzf | xargs -o vim'

    # vimwikki
    abbr vw 'vim -c "VimwikiIndex"'
    abbr vd 'vim -c "VimwikiMakeDiaryNote"'
    abbr vp 'vimwiki_pull && vimwiki_push'

    # misc.
    abbr c cd
    abbr l ls -lah
end