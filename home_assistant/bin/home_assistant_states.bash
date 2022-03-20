#!/bin/bash

home_assistant_run.bash 'GET' 'states' | jq '.[].entity_id' | sed -e 's/\"//g' | fzf --preview "zsh -c '~/bin/home_assistant_run.bash \"GET\" \"states/{}\" | jq --color-output'"
