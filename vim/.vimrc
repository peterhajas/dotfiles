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

" I don't use ;, I don't even know what it does! Let's just use :

nnoremap ; :

" Use jk and kj to escape

inoremap jk <Esc>
inoremap kj <Esc>

" Y to yank to the end of the line, to match C and D

nnoremap Y y$

" Searching / Moving

set smartcase
set gdefault
set incsearch
set showmatch

" Highlight all the matches for the current search query

set hlsearch

" Clear the current query when hitting leader-<space>

nnoremap <silent> <leader><space> :noh<cr>

" When searching for things, keep the current match in the middle of the
" window and pulse the line when moving to them

nnoremap n nzzzv
nnoremap N Nzzzv

" Move up and down visually. I'm not totally sold on this...

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

" Resize splits when resizing vim

au VimResized * :wincmd =

" Tabs

" Remap leader-t to make a new tab

nmap <silent> <leader>t :tabnew <CR>

" Remap ]w to next tab

nmap <silent> ]w :tabnext <CR>
nmap <silent> [w :tabprevious <CR>

" Finding the cursor

" I tried to live without it, but I couldn't. Give me my cursorline

set cursorline

" Line handling

set formatoptions=qrn1

" Split lines (opposite of [J]oining lines)

nnoremap S i<cr><esc><right>

" Filetypes

filetype plugin indent on

" Visual styling

" Font

if has('gui_running')
    set guifont=Menlo\ Regular:h11
endif

" Sets up the clipboard to interface with the system clipboard

set clipboard=unnamed

" Theme and coloring

" Turn on syntax highlighting

syntax on

" Advertise that our terminal supports 256 colors

set t_Co=256

" Use a dark background

set background=dark

" Use the Molokai colorscheme

colorscheme molokai

" When a line exceeds 80 characters, color the 81st character red

highlight OverLength ctermbg=darkred ctermfg=white guibg=#FFD9D9
match OverLength /\%81v/


" Status Line

" Divided into two sides:

" Left:

" Branch
" Notice that this doesn't start with a +=. This resets the statusline in the
" event that the .vimrc is reloaded

set statusline=%{fugitive#head()}

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

" Line numbers
" These are mostly handled by numbers.vim

set number

" Invisible characters

set list
set listchars=tab:▸\ ,eol:¬

" GUI Options

" Disable everything in the GUI by passing empty guioptions

set guioptions=

" Folding

" On insertion entering / leaving (or window leaving), disable folding
" This causes significant speed increases when using folds

autocmd InsertEnter * if !exists('w:last_fdm') | let w:last_fdm=&foldmethod | setlocal foldmethod=manual | endif
autocmd InsertLeave,WinLeave * if exists('w:last_fdm') | let &l:foldmethod=w:last_fdm | unlet w:last_fdm | endif

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
NeoBundle 'godlygeek/tabular'
NeoBundle 'jpalardy/vim-slime'
NeoBundle 'junegunn/goyo.vim'
NeoBundle 'kien/ctrlp.vim'
NeoBundle 'myusuf3/numbers.vim'
NeoBundle 'plasticboy/vim-markdown'
NeoBundle 'sjl/gundo.vim'
NeoBundle 'tpope/vim-afterimage'
NeoBundle 'tpope/vim-commentary'
NeoBundle 'tpope/vim-fugitive'
NeoBundle 'tpope/vim-obsession'
NeoBundle 'tpope/vim-repeat'
NeoBundle 'tpope/vim-sensible'
NeoBundle 'tpope/vim-surround'
NeoBundle 'tpope/vim-unimpaired'
NeoBundle 'tpope/vim-vinegar'
NeoBundle 'vim-scripts/scratch.vim'

call neobundle#end()

NeoBundleCheck

" Commentary

nmap <leader>/ :Commentary <CR>
vmap <leader>/ :Commentary <CR>

" Ctrl-P

set runtimepath^=~/.vim/bundle/ctrlp.vim
let g:ctrlp_cmd = 'CtrlPMixed'
let g:ctrlp_map = '<leader>,'
let g:ctrlp_switch_buffer = 0

" Fugitive

" Map leader-b to blame

nmap <silent> <leader>b :Gblame <CR>

" gundo

" Map control-u to toggle gundo

nmap <silent> <C-u> :GundoToggle<CR>

" vim-slime

" Activate tmux, my multiplexer of choice

let g:slime_target = "tmux"

" Default to a tmux configuration with a REPL on the right and editor on the
" left

let g:slime_default_config = {"socket_name": "default", "target_pane": ":.1"}

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

" Save all the time, automatically. It's 2015, computers should do this.

set autowriteall

" If a file has changed outside of vim, reload it (it seems MacVim may do this
" automatically, but terminal vim does not)

set autoread

