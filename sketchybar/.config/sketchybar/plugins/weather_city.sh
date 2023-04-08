CITY=$(echo $NAME | sed "s/weather.details.//")
WEATHER=$(curl --silent "wttr.in/$CITY?u&format=%l:+%t+%C+%p")
sketchybar --set $NAME label="$WEATHER"
