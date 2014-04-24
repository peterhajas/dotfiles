#!/bin/sh
pluginName=`basename $1`
pluginName=`echo ${pluginName%.*}`

git submodule add $1 .vim/bundle/$pluginName
