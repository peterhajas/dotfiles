#!/bin/bash

OUTDATED_PACKAGES=`/usr/local/bin/brew upgrade --dry-run | wc -l | awk "{ print int($1)-1 }"`
echo "$OUTDATED_PACKAGES | color=#ffcc66"
