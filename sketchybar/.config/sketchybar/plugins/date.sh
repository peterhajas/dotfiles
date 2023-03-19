WEEKDAY=$(date | awk '{ print toupper($1) }')
DATE=$(date '+%Y-%m-%d')
sketchybar --set $NAME label="$WEEKDAY $DATE"
