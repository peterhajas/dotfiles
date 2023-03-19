WEATHERDETAILS=$(curl --silent "wttr.in?format=j1" | jq --raw-output '@text "\(.current_condition[0].weatherDesc[0].value) \(.current_condition[0].precipInches)in \(.current_condition[0].windspeedMiles)mph \(.current_condition[0].winddir16Point)"' | awk '{ print toupper($0) }')
sketchybar --set $NAME label="$WEATHERDETAILS"
