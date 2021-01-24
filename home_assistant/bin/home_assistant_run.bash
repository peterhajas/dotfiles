#!/bin/bash

ENDPOINT=$1
PARAMETERS=$2
BEARER="eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJpc3MiOiI3MGRiZTVhMGZmZGU0MTFhOTY5MzI0NjM0YTYzNmY5YyIsImlhdCI6MTYxMDYwODIxNiwiZXhwIjoxOTI1OTY4MjE2fQ.cLQX5-u71GgxlGkXXVXSpt0ZQ4IS9Kz9coqAVXbefHw"

curl -X POST --data "$PARAMETERS" -H "Authorization: Bearer $BEARER" -H "Content-Type: application/json" http://lighthouse.local:8123/api/$ENDPOINT
