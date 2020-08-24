function abbrev -d "Install fish abbreviations"
    # git
    abbr g git
    abbr gb 'git branch | fzf | xargs git checkout'
    abbr gc git checkout
    abbr gl git log
    abbr gps git push
    abbr gpl git pull
    abbr gs git status
    abbr gd git diff
    abbr leaderboard git shortlog -sn
    
    # vim
    abbr vv 'find . | fzf | xargs -o vim'

    # vimwikki
    abbr ww 'vim -c "VimwikiIndex"'
    abbr wd 'vim -c "VimwikiMakeDiaryNote"'
    abbr wp 'vimwiki_pull && vimwiki_push'

    # misc.
    abbr c cd
    abbr l exa -l
    abbr ll exa -l
end
