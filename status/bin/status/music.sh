#!/bin/sh

itunesRunning=`ps -ax |grep iTunes | grep -v Helper | grep -v "grep" | wc -l`

if [ $itunesRunning -gt 0 ]
then
    album=`osascript -e "tell application \"iTunes\" to album of the current track" 2>/dev/null`
    artist=`osascript -e "tell application \"iTunes\" to artist of the current track" 2>/dev/null`
    track=`osascript -e "tell application \"iTunes\" to name of the current track" 2>/dev/null`

    trackLength=`echo $track | wc -c`

    if [ $trackLength -gt 1 ]
    then
        echo "$artist - $track" | tr -d '\n'
    else
        echo "[stopped]"
    fi
fi
