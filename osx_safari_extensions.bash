#!/bin/bash

EXTENSIONPATH="$HOME/Library/Safari/Extensions"
GRABEXTENSION="wget --unlink -P $EXTENSIONPATH"

rm $EXTENSIONPATH/*.safariextz

$GRABEXTENSION "https://cache.agilebits.com/dist/1P/ext/1Password-4.2.5.safariextz"
$GRABEXTENSION "http://redditenhancementsuite.com/latest/RES.safariextz"
$GRABEXTENSION "https://data.getadblock.com/safari/AdBlock.safariextz"
