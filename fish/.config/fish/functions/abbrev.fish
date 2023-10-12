# Variables used below
set ledgerBuild ~/src/ledger_utils/ledger_build.py
set ledgerFile /tmp/peter.ledger

function sync_music -d "Sync Music"
    rsync -avvz ~/Music/peter beacon:/mnt/media/music/
end

function abbrev -d "Install fish abbreviations"
    # dirs
    abbr d cd ~/dotfiles
    abbr m cd ~/metrics

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
    abbr gac 'git commit -a -m "autocommit" && git push'
    abbr leaderboard git shortlog -sn
    
    # vim
    abbr vv 'find . | fzf -i | xargs -o nvim'

    # vimwikki
    abbr w 'nvim -c "VimwikiIndex"'
    abbr ww 'find -H ~/.vimwiki | fzf -i | xargs -o nvim'
    abbr wd 'nvim -c "VimwikiMakeDiaryNote"'

    ## todo
    abbr tj 'vimwiki_gtd $vimwiki_projects_path'

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
    abbr l 'open "http://127.0.0.1:5000" && $ledgerBuild && hledger-web -f $ledgerFile --serve'
    abbr lb '$ledgerBuild && hledger -f $ledgerFile balance'
    abbr lr '$ledgerBuild && hledger -f $ledgerFile register'
    abbr lv '$ledgerBuild && nvim $ledgerFile'
    abbr ll '$ledgerBuild && less $ledgerFile'
    abbr ld '$ledgerBuild && rsync /tmp/peter.ledger beacon:services/hledger/data/hledger.journal'

    ## yabai
    abbr yr "yabai --stop-service && yabai --start-service && skhd --stop-service && skhd --start-service"

    ## sketchybar
    abbr sr "brew services restart sketchybar"

    ## ansible
    abbr ap "find /Users/phajas/dotfiles |grep yml | grep -v undodir | grep -v plugged | fzf | xargs ansible-playbook"

    ## logseq
    abbr b "cd ~/brain"

    ## pass
    abbr p pass

    ## bookmarks
    for line in (cat ~/.phajas/bookmarks)
        set abb_name (echo $line | awk '{print $1}')
        set abb_path (echo $line | awk '{print $2}')
        abbr $abb_name $abb_path
    end
end
