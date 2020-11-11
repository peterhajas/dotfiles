#!/bin/sh
# based on https://github.com/koekeishiya/kwm/issues/8

CPU_USAGE=`ps -A -o %cpu | awk '{s+=$1} END {printf("%.2f",s/8);}'`
echo "$CPU_USAGE"
