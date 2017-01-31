#!/bin/sh

TRIMCHARS='\":,\t'

ZIP=`curl -s "http://ipinfo.io/json" | grep "\"postal\"" | sed 's/postal//' | tr -d $TRIMCHARS | tr -d ' '`

WEATHER_PATH="https://www.wunderground.com/weather-forecast/$ZIP"

TEMP=`curl -s $WEATHER_PATH | grep "\"temperature\":" | sed 's/temperature//' | tr -d $TRIMCHARS | tr -d ' '`

CONDITION=`curl -s $WEATHER_PATH | grep "\"condition\":" | sed 's/condition//' | tr -d $TRIMCHARS`

CONDITION_CHAR=''

if [[ "$CONDITION" =~ "Partly Cloudy" ]]; then
    CONDITION_CHAR='⛅'
elif [[ "$CONDITION" =~ "Mostly Cloudy" ]]; then
    CONDITION_CHAR='⛅'
elif [[ "CONDITION" =~ "Cloudy" ]]; then
    CONDITION_CHAR='☁'
elif [[ "CONDITION" =~ "Overcast" ]]; then
    CONDITION_CHAR='☁'
elif [[ "CONDITION" =~ "Rain" ]]; then
    CONDITION_CHAR='🌧'
elif [[ "CONDITION" =~ "Drizzle" ]]; then
    CONDITION_CHAR='🌧'
elif [[ "CONDITION" =~ "Snow" ]]; then
    CONDITION_CHAR='🌨'
elif [[ "CONDITION" =~ "Fog" ]]; then
    CONDITION_CHAR='FOG'
else 
    CONDITION_CHAR=$CONDITION
fi

echo "$TEMP $CONDITION_CHAR | color=#ffcc66"
