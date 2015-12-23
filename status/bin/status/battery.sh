#!/bin/sh
# based on https://github.com/koekeishiya/kwm/issues/8

battery_remaining=`system_profiler SPPowerDataType | grep "Charge Remaining" | awk '{printf "%d", $4}'`
battery_capacity=`system_profiler SPPowerDataType | grep "Full Charge" | awk '{printf "%d", $5}'`
percent=$(echo "scale = 2; $battery_remaining * 100 / $battery_capacity" | bc | awk '{printf("%d",$1 + 0.5)}')
printf "⚡%s" "$percent"
