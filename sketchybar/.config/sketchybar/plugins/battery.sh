TIME=$(pmset -g batt | tail -n 1 | awk '{ print $5 }' | sed "s/:/h/") # minus "m"
PERCENT=$(pmset -g batt | tail -n 1 | awk '{ print $3 }' | sed "s/;//")

sketchybar --set $NAME label="$TIME/$PERCENT"
