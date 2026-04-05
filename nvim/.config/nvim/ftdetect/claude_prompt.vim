" Filetype detection for Claude prompt files
" Use FileType event to override markdown detection for claude-prompt files
au FileType markdown if expand('<afile>:t') =~# 'claude-prompt' | set filetype=claude_prompt | endif
