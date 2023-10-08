# first is empty
# last is 0 to give keyboard similarity
SPACENAMES=('' 'main' 'term' 'comm' 'rss' 'ha' 'fmf' 'watch' '8' '9' '0')
SPACENAME="${SPACENAMES[$SID]}"
SPACEAPPS=$(yabai -m query --windows --space 1 | jq -r ".[] | .app" | uniq) #plh-evil: to be fixed up
UNREADCOUNT=$(yabai -m query --windows --space $SID | jq -r ".[] | .app" | sort | uniq | xargs -L1 lsappinfo info -only StatusLabel -app |grep label | awk '{split($0,a,"StatusLabel"); label=a[2]; print label }' | cut -c 3- | sed 's/=/:/' | jq -r ".label" | awk ' $0 > 0 { print "*"; }')
sketchybar --set $NAME label="$SPACENAME$UNREADCOUNT"
sketchybar --set $NAME background.drawing=$SELECTED
sketchybar --set $NAME label.highlight=$SELECTED
