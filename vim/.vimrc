" .vimrc
" phajas
" Originally written Feb 1, 2014

" Tabs, spaces and indenting

set tabstop=4
set shiftwidth=4
set softtabstop=4
set expandtab

" Key remapping

" Make leader the , key

let mapleader = ","
nnoremap ; :

" Y to yank to the end of the line, to match C and D

nnoremap Y y$

" Searching / Moving

set ignorecase
set gdefault
set incsearch
set showmatch

" Highlight all the matches for the current search query

set hlsearch
nnoremap <silent> <leader><space> :noh<cr>

inoremap <up> <nop>
inoremap <down> <nop>
inoremap <left> <nop>
inoremap <right> <nop>
nnoremap j gj
nnoremap k gk

" Split windows

" leader-w makes a new split and moves to it

nnoremap <leader>w <C-w>v<C-w>l

" leader-W makes a new horizontal split and moves to it

nnoremap <leader>W <C-w>s<C-w>j

" Remap ctrl-movement keys to move to adjacent splits

nnoremap <C-h> <C-w>h
nnoremap <C-j> <C-w>j
nnoremap <C-k> <C-w>k
nnoremap <C-l> <C-w>l

" Map arrow keys to move to adjacent splits also

nnoremap <left> <C-w>h
nnoremap <down> <C-w>j
nnoremap <up> <C-w>k
nnoremap <right> <C-w>l

" Map ctrl-] and ctrl-[ to go to the next/previous error

nnoremap <silent> <leader>] :cnext <CR>
nnoremap <silent> <leader>[ :cprevious <CR>

" Line handling

set formatoptions=qrn1

" TODO: we need a way to do 80-char column indication

" Filetypes

filetype on

" Visual styling

" Font

if has('gui_running')
    set guifont=Menlo\ Regular:h13
    " Sets up the clipboard to interface with the system clipboard
    set clipboard=unnamed
endif

" Theme and coloring

syntax on
colorscheme molokai
set background=dark

" Status Line

set statusline+=%{fugitive#statusline()}

" Cursor visualization

set cursorline

au WinLeave * set nocursorline
au WinEnter * set cursorline

" Line numbers

" Enable relative line numbers

set relativenumber

" ...but also have absolute line numbers

set number

" When leaving a window or losing focus, turn off relative line numbers

au WinLeave * set norelativenumber
au FocusLost * set norelativenumber

" When re-entering a window or gaining focus, turn back on relative line numbers

au WinEnter * set relativenumber
au FocusGained * set relativenumber

" Invisible characters

set list
set listchars=tab:▸\ ,eol:¬

" GUI Options

" Disable the scrollbars, for more room

set guioptions=

" Plugins

" Pathogen

call pathogen#infect()
call pathogen#helptags()
call pathogen#infect('bundle/{}')

" Commentary

nmap <leader>/ <Plug>CommentaryLine
xmap <leader>/ <Plug>Commentary

" Ctrl-P

set runtimepath^=~/.vim/bundle/ctrlp.vim
let g:ctrlp_map = '<c-p>'
let g:ctrlp_cmd = 'CtrlPMixed'
let g:ctrlp_map = '<leader>,'
let g:ctrlp_switch_buffer = 0

" Fugitive

" Map leader-b to blame

nmap <silent> <leader>b :Gblame <CR>

" Easy Align

" Map enter to align in VISUAL mode

vmap <Enter> <Plug>(EasyAlign)

" QuickRun

" Disable the default keybindings

let g:quickrun_no_default_key_mappings = 1

" Map control-enter to QuickRun a file

nmap <silent> <C-CR> :QuickRun<CR>

" gundo

" Map control-u to toggle gundo

nmap <silent> <C-u> :GundoToggle<CR>

" Misc.

" Leader-. to reload .vimrc

nmap <silent> <leader>. :so $MYVIMRC<CR>

" Leader-o to open a file

nmap <silent> <leader>o :e 

" Leader-s to save a file

nmap <silent> <leader>s :w <CR>

" Leader-> to redraw the screen

nmap <silent> <leader>> :redraw! <CR>

" Leader-q to open up a netrw session

nmap <silent> <leader>q :e. <CR>

" Leader-Q to open up a netrw session in the file's path

nmap <silent> <leader>Q :Explore <CR>

" Remap <BS> to % to easily jump to matching character

nmap <BS> %

" Don't be `vi` compatible

set nocompatible

" Change the default shell vim uses to avoid a warning from Syntastic

set shell=bash

" Change vim's character encoding to UTF-8

set encoding=utf-8

" Never let there be less than 15 spaces above/below the insertion point

set scrolloff=15

" Automatically indent

set autoindent

" Show the current mode

set showmode

" Enable wildcard matching for commands. Complete until the longest common
" string

set wildmenu
set wildmode=list:longest

" Instead of beeping, use the visual bell

set visualbell

" Indicate that we're on a fast terminal connection

set ttyfast

" Show the current line & column number of the cursor position

set ruler

" Not sure.

set backspace=indent,eol,start

" Always give the last window a statusline

set laststatus=2

" Keep an undo file. TODO: Do we need this? Seems annoying...

set undofile

" Don't keep a backup file or swap file

set nobackup
set noswapfile

" Save all the time, automatically. It's 2014, computers should do this.

set autowriteall
