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

" Tabs

" Remap leader-t to make a new tab

nmap <silent> <leader>t :tabnew <CR>

" Remap ]w to next tab

nmap <silent> ]w :tabnext <CR>
nmap <silent> [w :tabprevious <CR>

" Line handling

set formatoptions=qrn1

" TODO: we need a way to do 80-char column indication

" Filetypes

filetype on
filetype plugin indent on

" Visual styling

" Font

if has('gui_running')
    set guifont=Menlo\ Regular:h13
    " Sets up the clipboard to interface with the system clipboard
    set clipboard=unnamed
endif

" Theme and coloring

" Turn on syntax highlighting

syntax on

" Advertise that our terminal supports 256 colors

set t_Co=256

" Use a dark background

set background=dark

" Use the Molokai colorscheme

colorscheme molokai

" Status Line
" Divided into two sides:

" Left:

" Branch

set statusline+=%{fugitive#head()}

" Path

set statusline+=\ %F

" Modified state

set statusline+=\ %m

" Right:

" Delimeter character

set statusline+=%=

" File kind

set statusline+=%y

" Encoding

set statusline+=\ %{strlen(&fenc)?&fenc:'none'}

" File type

set statusline+=[%{&ff}]

" Total lines

set statusline+=\ (%L)

" Percentage

set statusline+=\ %P\ :

" Line

set statusline+=\ %l:

" Column

set statusline+=\ %c\ 


" Cursor visualization

set cursorline

au WinLeave * set nocursorline
au WinEnter * set cursorline

" Line numbers
" These are mostly handled by numbers.vim

set number

" Invisible characters

set list
set listchars=tab:▸\ ,eol:¬

" GUI Options

" Disable the scrollbars, for more room

set guioptions=

" Shell

set shell=/bin/sh

" Plugins

" NeoBundle

if has('vim_starting')
    set runtimepath+=~/.vim/bundle/neobundle.vim/
endif

call neobundle#begin(expand('~/.vim/bundle/'))

" Let NeoBundle manage NeoBundle
NeoBundleFetch 'Shougo/neobundle.vim'

" List of plugins:

NeoBundle 'Keithbsmiley/swift.vim'
NeoBundle 'dag/vim-fish'
NeoBundle 'ervandew/supertab'
NeoBundle 'junegunn/vim-easy-align'
NeoBundle 'justinmk/vim-sneak'
NeoBundle 'kien/ctrlp.vim'
NeoBundle 'mattn/flappyvird-vim'
NeoBundle 'myusuf3/numbers.vim'
NeoBundle 'plasticboy/vim-markdown'
NeoBundle 'rizzatti/dash.vim'
NeoBundle 'rizzatti/funcoo.vim'
NeoBundle 'sjl/gundo.vim'
NeoBundle 't9md/vim-tryit'
NeoBundle 'thinca/vim-quickrun'
NeoBundle 'tpope/vim-commentary'
NeoBundle 'tpope/vim-fugitive'
NeoBundle 'tpope/vim-obsession'
NeoBundle 'tpope/vim-repeat'
NeoBundle 'tpope/vim-sensible'
NeoBundle 'tpope/vim-surround'
NeoBundle 'tpope/vim-unimpaired'
NeoBundle 'tpope/vim-vinegar'
NeoBundle 'vimwiki/vimwiki'

call neobundle#end()

NeoBundleCheck

" Commentary

nmap <leader>/ <Plug>CommentaryLine
xmap <leader>/ <Plug>Commentary

" Ctrl-P

set runtimepath^=~/.vim/bundle/ctrlp.vim
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

" Sneak

" Turn on s_next

let g:sneak#s_next = 1

" Misc.

" Leader-. to reload .vimrc

nmap <silent> <leader>. :so $MYVIMRC<CR>

" Enable matchit, which has smarter matching support (HTML tags, etc.)

runtime macros/matchit.vim

" Remap <BS> to % to easily jump to matching identifier (bracket, paren, tag)

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
au WinLeave,FocusLost,BufLeave,InsertLeave,CursorHold * wall

" If a file has changed outside of vim, reload it (it seems MacVim may do this
" automatically, but terminal vim does not)

set autoread

