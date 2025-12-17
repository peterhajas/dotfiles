" Filetype detection for TiddlyWiki tiddlers
" Auto-detect tw:// protocol buffers as tiddlywiki filetype

au BufNewFile,BufRead tw://* setfiletype tiddlywiki
