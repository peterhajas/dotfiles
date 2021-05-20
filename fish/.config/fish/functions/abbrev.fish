function abbrev -d "Install fish abbreviations"
    # dirs
    abbr d cd ~/dotfiles
    # git
    abbr g git
    abbr ga git add
    abbr gb 'git branch | fzf | xargs git checkout'
    abbr gc git checkout
    abbr gd git diff
    abbr gi git init
    abbr gl git log
    abbr gpl git pull
    abbr gps git push
    abbr gr git restore
    abbr gre git remote
    abbr gs git status
    abbr gsh git show
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
    abbr ll exa -l

    # util
    ## sync music to lighthouse
    abbr musicsync rsync -avvz ~/Music/peter lighthouse.local:/var/media/music/

    ## ledger
    abbr l 'src/ledger_utils/ledger_build.py && ledger -f ~/.vimwiki/ledger/peter.ledger'
    abbr lb 'src/ledger_utils/ledger_build.py && ledger -f ~/.vimwiki/ledger/peter.ledger balance'
    abbr lr 'src/ledger_utils/ledger_build.py && ledger -f ~/.vimwiki/ledger/peter.ledger register'
    abbr lv 'src/ledger_utils/ledger_build.py && vim ~/.vimwiki/ledger/peter.ledger'
end
