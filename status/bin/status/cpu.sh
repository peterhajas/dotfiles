#!/bin/sh
# from https://github.com/koekeishiya/kwm/issues/8

ESC=`printf "\e"`
printf "cpu $ESC[32m"
ps -A -o %cpu | awk '{s+=$1} END {printf("%.2f",s/8);}'
