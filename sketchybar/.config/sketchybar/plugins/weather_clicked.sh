PLUGIN_DIR="$HOME/.config/sketchybar/plugins"

sketchybar -m --set weather popup.drawing=toggle

sketchybar --remove "/weather.details.*/"

CITIES=$(cat ~/brain/pages/data___weather_locations.md | sed 's/- //')

for CITY in $CITIES
do
    NAME="weather.details.$CITY"
    sketchybar --add item $NAME popup.weather
    sketchybar --set $NAME label="$CITY: (loading)"
    sketchybar --set $NAME script="$PLUGIN_DIR/weather_city.sh"
    sketchybar --subscribe $NAME weather_update
done

sketchybar --trigger weather_update
