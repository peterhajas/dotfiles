# first is empty
# last is 0 to give keyboard similarity
SPACENAMES=('' 'main' 'term' 'comm' 'rss' 'ha' 'fmf' 'watch' 'bg' 'sys' 'wiki')
SPACENAME="${SPACENAMES[$SID]}"

# Get unique apps in this space
SPACEAPPS=$(yabai -m query --windows --space $SID | jq -r ".[] | .app" | sort | uniq)

# Build unread info string
UNREADINFO=""
for app in $SPACEAPPS; do
    # Get the unread count for this app (using your working command format)
    count=$(lsappinfo info -app "$app" -only StatusLabel | grep label | awk '{split($0,a,"StatusLabel\"="); label=a[2]; print label }' | sed 's/=/:/' | jq -r ".label" 2>/dev/null)
    
    # Check if count is a valid number > 0
    if [[ "$count" =~ ^[0-9]+$ ]] && [[ "$count" -gt 0 ]]; then
        if [[ -n "$UNREADINFO" ]]; then
            UNREADINFO="$UNREADINFO $app($count)"
        else
            UNREADINFO="$app($count)"
        fi
    fi
done

# Add brackets around unread info
if [[ -n "$UNREADINFO" ]]; then
    UNREADINFO="[$UNREADINFO]"
fi

sketchybar --set $NAME label="$SPACENAME$UNREADINFO"
sketchybar --set $NAME background.drawing=$SELECTED
sketchybar --set $NAME label.highlight=$SELECTED
