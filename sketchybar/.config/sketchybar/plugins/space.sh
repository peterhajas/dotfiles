# first is empty
SPACENAMES=('' 'main' 'sub' 'comms' 'rss' 'ha')
SPACENAME="${SPACENAMES[$SID]}"
UNREADCOUNT=$(yabai -m query --windows --space $SID | jq -r ".[] | .app" | sort | uniq | xargs -L1 lsappinfo info -only StatusLabel -app |grep label | awk '{split($0,a,"StatusLabel"); label=a[2]; print label }' | cut -c 3- | sed 's/=/:/' | jq -r ".label")
sketchybar --set $NAME label="$SPACENAME $UNREADCOUNT"
sketchybar --set $NAME background.drawing=$SELECTED
sketchybar --set $NAME label.highlight=$SELECTED
