#!/bin/sh

itunesRunning=`ps -ax |grep iTunes | grep -v Helper | grep -v "Extension" | grep -v Service | grep -v "grep" | wc -l`

if [ $itunesRunning -gt 0 ]
then
    if [[ "$1" = "playpause" ]]; then
        exit
    fi

    album=`osascript -e "tell application \"iTunes\" to album of the current track" 2>/dev/null`
    artist=`osascript -e "tell application \"iTunes\" to artist of the current track" 2>/dev/null`
    track=`osascript -e "tell application \"iTunes\" to name of the current track" 2>/dev/null`
    playstatus=`osascript -e "tell application \"iTunes\" to get player state" 2>/dev/null`

    if [ $playstatus = stopped ]
    then
        playstatus=◼︎
    fi
    if [ $playstatus = paused ]
    then
        playstatus=❘❘
    fi
    if [ $playstatus = playing ]
    then
        playstatus=▶︎
    fi

    trackLength=`echo $track | wc -c`

    colorString=" | color=#f2777a"

    if [ $trackLength -gt 1 ]
    then
        echo "$playstatus - $artist - $track $colorString" | tr -d '\n'
    else
        echo "$playstatus $colorString"
    fi
fi
