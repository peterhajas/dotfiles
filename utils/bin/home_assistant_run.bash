#!/bin/bash

METHOD=$1
ENDPOINT=$2
PARAMETERS=$3
BEARER=$ha_token

curl -X $METHOD --data "$PARAMETERS" -H "Authorization: Bearer $BEARER" -H "Content-Type: application/json" --silent $ha_url/api/$ENDPOINT
