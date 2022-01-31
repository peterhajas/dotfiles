# Variables used below
set ledgerBuild src/ledger_utils/ledger_build.py
set ledgerFile /tmp/peter.ledger

function sync_music -d "Sync Music"
    rsync -avvz ~/Music/peter beacon:/mnt/media/music/
end

function abbrev -d "Install fish abbreviations"
    # dirs
    abbr d cd ~/dotfiles

    # fish
    abbr bu 'brew update && brew upgrade'

    # git
    abbr g git status
    abbr gm git commit
    abbr ga 'git add -p'
    abbr gb 'git branch | fzf -i | xargs git checkout'
    abbr gc git checkout
    abbr gd git diff
    abbr gh git show
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
    abbr vv 'find . | fzf -i | xargs -o vim'

    # vimwikki
    abbr w 'vim -c "VimwikiIndex"'
    abbr ww 'find ~/.vimwiki | fzf -i | xargs -o vim'
    abbr wd 'vim -c "VimwikiMakeDiaryNote"'
    abbr wp 'vimwiki_update'

    # youtube-dl
    abbr y 'ytd "'

    # misc.
    abbr c cd
    abbr ll exa -l

    # util
    ## sync music to lighthouse
    ## listen to current lighthouse stream
    abbr music mpv "http://beacon:3689/stream.mp3"

    ## grabs radio and syncs
    abbr radio '~/Music/peter/_radio/grab.sh && sync_music'

    ## ledger
    abbr l '$ledgerBuild && hledger-web -f $ledgerFile'
    abbr lb '$ledgerBuild && hledger -f $ledgerFile balance'
    abbr lr '$ledgerBuild && hledger -f $ledgerFile register'
    abbr lv '$ledgerBuild && vim $ledgerFile'
    abbr ll '$ledgerBuild && less $ledgerFile'
end
