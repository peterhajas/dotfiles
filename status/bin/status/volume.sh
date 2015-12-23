#!/bin/sh

osascript -e "output volume of (get volume settings)" | tr -d '\n'
