" Vim syntax file
" Language: TiddlyWiki Tiddler
" Maintainer: Generated for tw CLI
" Latest Revision: 2025-12-16

if exists("b:current_syntax")
  finish
endif

" Metadata section (everything before first blank line)
" Field names (before colon)
syn match tiddlerFieldName "^\w\+:" contained nextgroup=tiddlerFieldValue
syn region tiddlerMetadata start="^" end="^$" contains=tiddlerFieldName,tiddlerFieldValue,tiddlerBracketTag transparent

" Field values (after colon to end of line)
syn match tiddlerFieldValue ":\s*.*$"hs=s+1 contained contains=tiddlerBracketTag,tiddlerTimestamp

" Special highlighting for [[tag]] style brackets in field values
syn match tiddlerBracketTag "\[\[[^\]]\+\]\]" contained

" Timestamp format (TiddlyWiki format: YYYYMMDDHHMMSSMMM)
syn match tiddlerTimestamp "\d\{17\}" contained

" Content section (after first blank line)
" Basic markdown-style highlighting for content
syn region tiddlerContent start="^$" end="\%$" contains=tiddlerContentHeader,tiddlerContentBold,tiddlerContentItalic,tiddlerContentCode,tiddlerContentLink,tiddlerContentListItem

" Markdown-style elements in content
syn match tiddlerContentHeader "^#\+\s.*$" contained
syn match tiddlerContentBold "\*\*[^*]\+\*\*" contained
syn match tiddlerContentBold "__[^_]\+__" contained
syn match tiddlerContentItalic "\*[^*]\+\*" contained
syn match tiddlerContentItalic "_[^_]\+_" contained
syn match tiddlerContentCode "`[^`]\+`" contained
syn match tiddlerContentLink "\[\[[^\]]\+\]\]" contained
syn match tiddlerContentListItem "^\s*[-*+]\s" contained

" Highlighting groups
hi def link tiddlerFieldName Identifier
hi def link tiddlerFieldValue String
hi def link tiddlerBracketTag Type
hi def link tiddlerTimestamp Number
hi def link tiddlerContentHeader Title
hi def link tiddlerContentBold Bold
hi def link tiddlerContentItalic Italic
hi def link tiddlerContentCode Constant
hi def link tiddlerContentLink Underlined
hi def link tiddlerContentListItem Special

let b:current_syntax = "tiddlywiki"
