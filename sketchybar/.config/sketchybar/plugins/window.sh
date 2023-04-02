sketchybar --set $NAME label="$(yabai -m query --windows --window | jq --raw-output '.title' | awk '{ if (length($0) > 64) { print substr($0, 1, 64) "..." } else { print $0 } }')"
