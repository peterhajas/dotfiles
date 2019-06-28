#!/bin/sh
curl -s "wttr.in?format=1" | sed "s/+//" | sed "s/°F//" | grep -v "Unknow"
