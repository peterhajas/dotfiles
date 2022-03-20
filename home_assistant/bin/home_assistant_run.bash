#!/bin/bash

METHOD=$1
ENDPOINT=$2
PARAMETERS=$3
BEARER="eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJpc3MiOiI3MGRiZTVhMGZmZGU0MTFhOTY5MzI0NjM0YTYzNmY5YyIsImlhdCI6MTYxMDYwODIxNiwiZXhwIjoxOTI1OTY4MjE2fQ.cLQX5-u71GgxlGkXXVXSpt0ZQ4IS9Kz9coqAVXbefHw"

curl -X $METHOD --data "$PARAMETERS" -H "Authorization: Bearer $BEARER" -H "Content-Type: application/json" --silent http://beacon:8123/api/$ENDPOINT
