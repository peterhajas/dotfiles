#!/bin/sh
# based on https://github.com/koekeishiya/kwm/issues/8

OUTPUT=`ps -A -o %mem | awk '{s+=$1} END {print "🧠 " s}' | tr -d '\n'`
echo "$OUTPUT"
