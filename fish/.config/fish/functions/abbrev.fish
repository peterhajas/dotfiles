# Variables used below
set ledgerBuild ~/src/ledger_utils/ledger_build.py
set ledgerFile /tmp/peter.ledger

function sync_music -d "Sync Music"
    rsync -avvz --delete ~/Music/peter beacon:/mnt/media/music/
end

function abbrev -d "Install fish abbreviations"
    # fish
    abbr bu 'yabai --stop-service && brew update && brew upgrade && yabai --start-service'

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
    abbr vv 'nvim -c "lua require(\'telescope.builtin\').find_files({hidden = true, no_ignore = false, find_command = {\'fd\', \'--type\', \'f\', \'--hidden\', \'--exclude\', \'.git\'}})"'

    # zellij
    abbr za "zellij attach --create"
    abbr zc "zellij attach --create (basename (pwd))"

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

    ## kanata
    abbr kanata_1 "sudo '/Library/Application Support/org.pqrs/Karabiner-DriverKit-VirtualHIDDevice/Applications/Karabiner-VirtualHIDDevice-Daemon.app/Contents/MacOS/Karabiner-VirtualHIDDevice-Daemon'"
    abbr kanata_2 "sudo kanata --cfg ~/.config/kanata/config.kanata"

    ## sketchybar
    abbr sr "brew services restart sketchybar"

    ## pass
    abbr p pass

    ## wiki
    abbr w "cd ~/phajas-wiki"
    abbr ww "tw ~/phajas-wiki/phajas-wiki.html "
    abbr we "tw ~/phajas-wiki/phajas-wiki.html ls | fzf | xargs -I {} tw ~/phajas-wiki/phajas-wiki.html edit '{}'"
end
