" .vimrc
" phajas
" Originally written Feb 1, 2014

" vim:fdm=marker

" Sourcing

" Source local .vimrcs
set exrc

" Errors
set noerrorbells

" Wrapping
set wrap

" Tabs, spaces and indenting {{{
set tabstop=4
set shiftwidth=4
set softtabstop=4
set expandtab

" Numbers
set number
set relativenumber

" }}}
" Key remapping {{{

" Make leader the , key

let mapleader = ","

" I don't use ;, I don't even know what it does! Let's just use :

nnoremap ; :

" Use jk and kj to escape

inoremap jk <Esc>
inoremap kj <Esc>

" Y to yank to the end of the line, to match C and D

nnoremap Y y$

" Leader-. to reload .vimrc

nmap <silent> <leader>. :so $MYVIMRC<CR>

" Remap <BS> to % to easily jump to matching identifier (bracket, paren, tag)

nmap <BS> %

" Leader-p to delete visual contents into void register and replace with
" clipboard register
vnoremap <leader>p "_dP

" }}}
" Searching / Moving {{{

set ignorecase
set smartcase
set gdefault
set incsearch
set showmatch

" Don't highlight all the matches for the current search query

set nohlsearch

" When searching for things, keep the current match in the middle of the
" window and pulse the line when moving to them

nnoremap n nzzzv
nnoremap N Nzzzv

" Move up and down visually. I'm not totally sold on this...

nnoremap j gj
nnoremap k gk

" }}}
" Split windows {{{

" leader-w makes a new split and moves to it

nnoremap <leader>w <C-w>v<C-w>l

" leader-W makes a new horizontal split and moves to it

nnoremap <leader>W <C-w>s<C-w>j

" Remap ctrl-movement keys to move to adjacent splits
nnoremap <C-h> <C-\><C-N><C-w>h
nnoremap <C-j> <C-\><C-N><C-w>j
nnoremap <C-k> <C-\><C-N><C-w>k
nnoremap <C-l> <C-\><C-N><C-w>l

" Map arrow keys to move to adjacent splits also
nnoremap <silent><left> <C-\><C-N><C-w>h
nnoremap <silent><down> <C-\><C-N><C-w>j
nnoremap <silent><up> <C-\><C-N><C-w>k
nnoremap <silent><right> <C-\><C-N><C-w>l

" Resize splits when resizing vim

au VimResized * :wincmd =

" }}}
" Tabs {{{

" Remap leader-t to make a new tab

nmap <silent> <leader>t :tabnew <CR>

" Remap ]w to next tab

nmap <silent> ]w :tabnext <CR>
nmap <silent> [w :tabprevious <CR>

" }}}
" Line handling {{{

set formatoptions=qrn1

" Split lines (opposite of [J]oining lines)

nnoremap S i<cr><esc><right>

" }}}
" Filetypes {{{

filetype plugin indent on

" }}}
" Visual styling {{{

let g:LightModeActive = exists('w:LightModeActive') ? w:LightModeActive : 0

function ResetTheme()
    let g:LightModeActive = 0
    hi Normal ctermbg=NONE
    hi Normal ctermfg=NONE
    hi EndOfBuffer ctermbg=NONE
    hi EndOfBuffer ctermfg=NONE
    " Highlight selected text to be more visible
    hi Visual ctermbg=white
    hi Visual ctermfg=black
    " Highlight folds to be the same as the background
    hi Folded ctermbg=black
endfunction

function LightTheme()
    let g:LightModeActive = 1
    " This inverts all the settings above
    hi Normal ctermbg=white
    hi Normal ctermfg=black
    hi EndOfBuffer ctermbg=white
    hi EndOfBuffer ctermfg=black
    hi Visual ctermbg=black
    hi Visual ctermfg=white
    hi Folded ctermbg=white
endfunction

function ToggleTheme()
    if g:LightModeActive
        call ResetTheme()
    else
        call LightTheme()
    endif
endfunction

" Get into the default theme (dark)
call ResetTheme()

" Leader-s to toggle themes
" (I guess the hint here is "s for style"?)
nmap <silent> <leader>s :call ToggleTheme() <CR>

" Font

if has('gui_running')
    set guifont=Menlo\ Regular:h11
endif

" Turn on syntax highlighting

syntax on

" Advertise that our terminal supports 256 colors

set t_Co=256

" Disable everything in the GUI by passing empty guioptions

set guioptions=

" }}}
" Status Line {{{

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

" Line

set statusline+=\ %l
set statusline+=\/

" Total lines

set statusline+=\%L

" Always hide the status line. This can always be re-enabled.

set laststatus=0

" }}}
" Mouse Support {{{

" Turn on mouse support

set mouse=a

" }}}
" Folding {{{

" Toggle folds with Space

nnoremap <Space> za
vnoremap <Space> za

" }}}
" ALE {{{

" According to ALE docs, some / all of these need to be enabled *before* ALE
" has been loaded

" Turn on ALE completion
let g:ale_completion_enabled = 1

" Have ALE populate the quickfix
let g:ale_set_quickfix = 1

" Show ALE messages when near a line with errors / warnings
let g:ale_virtualtext_cursor = 1


" }}}
" vim-plug auto-downloading {{{
" This is a handy way to nab vim-plug when we launch
if empty(glob('~/.vim/autoload/plug.vim'))
  silent !curl -fLo ~/.vim/autoload/plug.vim --create-dirs
    \ https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim
  autocmd VimEnter * PlugInstall --sync | source $MYVIMRC
endif
" }}}
" vim-plug begin {{{
call plug#begin('~/.vim/plugged')
" }}}
" List of Plugins {{{

" Editing:

Plug 'dag/vim-fish'
Plug 'keith/swift.vim'
Plug 'ludovicchabant/vim-gutentags'
Plug 'plasticboy/vim-markdown'
Plug 'tpope/vim-afterimage'
Plug 'tpope/vim-commentary'
Plug 'tpope/vim-fugitive'
Plug 'tpope/vim-obsession'
Plug 'tpope/vim-repeat'
Plug 'tpope/vim-rsi'
Plug 'tpope/vim-speeddating'
Plug 'tpope/vim-surround'
Plug 'tpope/vim-unimpaired'
Plug 'tpope/vim-vinegar'
Plug 'tommcdo/vim-lion'
Plug 'justinmk/vim-sneak'
Plug 'wellle/targets.vim'
Plug 'tomtom/ttags_vim'

" QuickFix:

Plug 'romainl/vim-qf'
Plug 'romainl/vim-qlist'

" Syntax:

Plug 'ervandew/supertab'
Plug 'godlygeek/tabular'
Plug 'jpalardy/vim-slime'
Plug 'w0rp/ale'
Plug 'ap/vim-css-color'
Plug 'ledger/vim-ledger'

" PIM:
Plug 'vimwiki/vimwiki'

" Misc:

Plug 'jremmen/vim-ripgrep'
Plug 'junegunn/fzf.vim'
Plug 'junegunn/fzf'
Plug 'junegunn/vim-peekaboo'
Plug 'ludovicchabant/vim-gutentags'
Plug 'mbbill/undotree'
Plug 'tpope/vim-eunuch'
Plug 'tpope/vim-sensible'

" Prose:

Plug 'junegunn/goyo.vim'
Plug 'reedes/vim-lexical'
Plug 'reedes/vim-pencil'
Plug 'reedes/vim-wordy'

" Enable matchit, which has smarter matching support (HTML tags, etc.)

runtime macros/matchit.vim

" }}}
" vim-plug end {{{
call plug#end()
" }}}
" Plugin Settings {{{

" Commentary

nmap <leader>/ :Commentary <CR>
vmap <leader>/ :Commentary <CR>

" Fugitive

" Set up tags
set tags^=.git/tags

" Map leader-b to blame

nmap <silent> <leader>b :Gblame <CR>

" undotree

" Map control-u to toggle undotree

nmap <silent> <C-u> :UndotreeToggle<CR>

" vim-slime

" Activate tmux, my multiplexer of choice

let g:slime_target = "tmux"

" Default to a tmux configuration with a REPL on the right and editor on the
" left

let g:slime_default_config = {"socket_name": "default", "target_pane": ":.1"}

" fzf

" Set the runtimepath to also include fzf
set rtp+=/usr/local/opt/fzf

" Map leader-, to FZF (kind of like my old Ctrl-P configuration)
nmap <leader>, :FZF <CR>

" Map vv to FZF also
nmap vv :FZF <CR>

" vimwiki
" We want a wiki in ~/.vimwiki that uses Markdown and the .md extension
let g:vimwiki_list = [{'path': '~/.vimwiki',
                      \'auto_tags' : 1,
                      \'syntax': 'markdown', 'ext': '.md'}]

" Disable the auto-syntax detection for everything but my actual Wiki
let g:vimwiki_global_ext = 0

" For links made by vimwiki, append the markdown file extension
let g:vimwiki_markdown_link_ext = 1

" }}}
" Prose mode configuration {{{

let g:ProseModeActive = exists('w:ProseModeActive') ? w:ProseModeActive : 0

function EnterProseMode()
    let g:ProseModeActive = 1
    Goyo
    SoftPencil
    call lexical#init()
    set nocursorline
endfunction

function ExitProseMode()
    let g:ProseModeActive = 0
    Goyo!
    NoPencil
    set cursorline
endfunction

function ToggleProseMode()
    if g:ProseModeActive
        call ExitProseMode()
    else
        call EnterProseMode()
    endif
endfunction

nmap <silent> <leader>e :call ToggleProseMode() <CR>

" }}}
" Marked 2.app Integration {{{

function OpenInMarked2()
    !open -a Marked\ 2.app %
endfunction

nmap <silent> <leader>m :call OpenInMarked2() <CR> <CR>

" }}}
" Terminal Setup {{{
if has('terminal')
    " Remap ctrl-movement keys to move to adjacent splits
    tnoremap <C-h> <C-\><C-N><C-w>h
    tnoremap <C-j> <C-\><C-N><C-w>j
    tnoremap <C-k> <C-\><C-N><C-w>k
    tnoremap <C-l> <C-\><C-N><C-w>l

    " Map arrow keys to move to adjacent splits also
    tnoremap <silent><left> <C-\><C-N><C-w>h
    tnoremap <silent><down> <C-\><C-N><C-w>j
    tnoremap <silent><up> <C-\><C-N><C-w>k
    tnoremap <silent><right> <C-\><C-N><C-w>l

    " Leader-a to launch a terminal into a fish shell
    nmap <leader>a :term fish<CR>
endif
" }}}
" Misc. {{{

" Change the default shell vim uses to avoid a warning from Syntastic
set shell=bash

" Change vim's character encoding to UTF-8
set encoding=utf-8

" Never let there be less than 12 spaces above/below the insertion point
set scrolloff=12

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

" Not sure.
set backspace=indent,eol,start

" Only show the tab line if there are >1 tabs
set showtabline=1

" Turn on colorcolumn and the lint column
set colorcolumn=80
highlight ColorColumn ctermbg=0
set signcolumn=yes

" Keep an undo file. TODO: Do we need this? Seems annoying...
set undodir=~/.vim/undodir
set undofile

" Don't keep a backup file or swap file
set nobackup
set noswapfile

" Save all the time, automatically. It's 2015, computers should do this.
set autowrite
set autowriteall 

" If a file has changed outside of vim, reload it (it seems MacVim may do this
" automatically, but terminal vim does not)
set autoread

" Sets up the clipboard to interface with the system clipboard
set clipboard=unnamed

" Turn on ttyfast and lazyredraw for speed in the Terminal
set ttyfast
set lazyredraw

" Disable non-text characters by coloring them like the background
highlight EndOfBuffer ctermfg=black ctermbg=black

" Don't show text control characters
set nolist

" Let filetype plugins do indents
if has('autocmd')
  filetype plugin indent on
endif

" Turn on syntax highlighting if possible
if has('syntax') && !exists('g:syntax_on')
  syntax enable
endif

" Turn on "smarttab" for tab insertion / deletion
set smarttab

" For combos, give me 100 units of time (ms?) to hit a combo
set ttimeout
set ttimeoutlen=100

" Delete comment character when joining commented lines
set formatoptions+=j 

" Have a command history of 1000
set history=1000

" Not sure
if !empty(&viminfo)
  set viminfo^=!
endif

" Turn on hidden buffers
set hidden

" }}}
