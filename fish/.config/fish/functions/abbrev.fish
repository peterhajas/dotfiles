function abbrev -d "Install fish abbreviations"
    # dirs
    abbr d cd ~/dotfiles
    # git
    abbr g git
    abbr ga git add
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
    abbr w 'vim -c "VimwikiIndex"'
    abbr ww 'find ~/.vimwiki | fzf | xargs -o vim'
    abbr wd 'vim -c "VimwikiMakeDiaryNote"'
    abbr wp 'vimwiki_update'

    # youtube-dl
    abbr y 'ytd "'

    # misc.
    abbr c cd
    abbr l exa -l
    abbr ll exa -l

    # scratchpad
    ## sync music to lighthouse
    abbr musicsync rsync -avvz ~/Music/peter lighthouse.local:/var/media/music/
end
