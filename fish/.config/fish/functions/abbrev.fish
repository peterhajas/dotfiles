# Variables used below
set ledgerBuild ~/src/ledger_utils/ledger_build.py
set ledgerFile /tmp/peter.ledger

function sync_music -d "Sync Music"
    rsync -avvz --delete ~/Music/peter beacon:/mnt/media/music/
end

function abbrev -d "Install fish abbreviations"
    # fish
    abbr bu 'yabai --stop-service && brew update && brew upgrade && yabai --start-service'

    # bat
    abbr cat bat

    # cd
    abbr c cd

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
    abbr gac 'git commit -a -m "autocommit" && git push'
    abbr leaderboard git shortlog -sn
    
    # vim
    abbr vv 'find . | fzf -i | xargs -o nvim'

    # youtube-dl
    abbr y 'ytd "'

    # util
    ## sync music to lighthouse
    ## listen to current lighthouse stream
    abbr music mpv "http://beacon:3689/stream.mp3"

    ## grabs radio and syncs
    abbr radio '~/Music/peter/_radio/grab.sh && sync_music'

    ## ledger
    abbr ledg 'open "http://127.0.0.1:5000" && $ledgerBuild && hledger-web -f $ledgerFile --serve'
    abbr ledgb '$ledgerBuild && hledger -f $ledgerFile balance'
    abbr ledgr '$ledgerBuild && hledger -f $ledgerFile register'
    abbr ledgv '$ledgerBuild && nvim $ledgerFile'
    abbr ledgl '$ledgerBuild && less $ledgerFile'
    abbr ledgd '$ledgerBuild && rsync /tmp/peter.ledger beacon:services/hledger/data/hledger.journal'

    ## yabai
    abbr yr "yabai --stop-service && yabai --start-service && skhd --stop-service && skhd --start-service"

    ## sketchybar
    abbr sr "brew services restart sketchybar"

    ## ansible
    abbr ap "find /Users/phajas/dotfiles |grep yml | grep -v undodir | grep -v plugged | fzf | xargs ansible-playbook"

    ## pass
    abbr p pass

    ## bookmarks
    for line in (cat ~/.phajas/bookmarks)
        set abb_name (echo $line | awk '{print $1}')
        set abb_path (echo $line | awk '{print $2}')
        abbr $abb_name $abb_path
    end
end
