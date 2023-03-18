sketchybar --set $NAME label="$(curl --silent "wttr.in?format=j1" | jq --raw-output '@text "\(.weather[0].mintempF) < \(.current_condition[0].temp_F) < \(.weather[0].maxtempF)"')"
