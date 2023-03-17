sketchybar --set $NAME label="$(yabai -m query --windows --window | jq --raw-output '.title')"
