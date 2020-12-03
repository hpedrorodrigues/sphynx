" Interesting references
" - https://stackoverflow.com/questions/3776117/what-is-the-difference-between-the-remap-noremap-nnoremap-and-vnoremap-mapping


""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" => Plugin Manager (Vundle)
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""


" Set the runtime path to include Vundle and initialize
set rtp+=~/.vim/bundle/Vundle.vim

" Set the runtime path to include fuzzy finder
set rtp+=/usr/local/opt/fzf

call vundle#begin()
  Plugin 'VundleVim/Vundle.vim'
  Plugin 'scrooloose/nerdtree'
  Plugin 'semibran/vim-colors-synthetic'
  Plugin 'vim-airline/vim-airline'
  Plugin 'vim-airline/vim-airline-themes'
  Plugin 'junegunn/fzf.vim'
  Plugin 'vimwiki/vimwiki'
call vundle#end()


""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" => Functions
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""


" Check if a colorscheme exists
function! s:hasColorScheme(name)
  let path='colors/'.a:name.'.vim'
  return !empty(globpath(&rtp, path))
endfunction


""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" => General
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""


" Enable filetype plugins
filetype plugin on
filetype indent on

" Set to auto read when a file is changed from the outside
set autoread

" Sets how many lines of history VIM has to remember
set history=500

" Make Vim more useful
set nocompatible

" Optimize for fast terminal connections
set ttyfast

" Add the g flag to search/replace by default
set gdefault

" Centralize backups, swapfiles and undo history
set backupdir=~/.vim/backups
set directory=~/.vim/swaps
if exists("&undodir")
  set undodir=~/.vim/undo
endif

" Don’t create backups when editing files in certain directories
set backupskip=/tmp/*,/private/tmp/*

" Enable per-directory .vimrc files and disable unsafe commands in them
set exrc
set secure

" Enable mouse in all modes
set mouse=a

" Disable error bells
set noerrorbells

" Don’t reset cursor to start of line when moving around.
set nostartofline

" Show the cursor position
set ruler


""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" => UI
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""


" Use the Dark theme
set background=dark

" Change cursor to block
let &t_ti.="\<Esc>]50;CursorShape=1\x7" " Vertical bar when vim starts
let &t_ks.="\<Esc>]50;CursorShape=1\x7" " Vertical bar when vim exits

let &t_SI.="\<Esc>]50;CursorShape=1\x7" " Vertical bar in insert mode
let &t_EI.="\<Esc>]50;CursorShape=1\x7" " Vertical bar in normal mode

" Enable line numbers
set number

" Enable syntax highlighting
syntax on

" Highlight current line
set cursorline

" Linebreak on 500 characters
set lbr
set tw=500

" Show “invisible” characters
set lcs=tab:▸\ ,trail:·,eol:¬,nbsp:_
set list

" Highlight searches
set hlsearch

" Ignore case of searches
set ignorecase

" Highlight dynamically as pattern is typed
set incsearch

" Always show status line
set laststatus=2

" Don’t show the intro message when starting Vim
set shortmess=atI

" Show the current mode
set showmode

" Show the filename in the window titlebar
set title

" Show the (partial) command as it’s being typed
set showcmd

" Use relative line numbers
if exists("&relativenumber")
  set relativenumber
  au BufReadPost * set relativenumber
endif

" Start scrolling three lines before the horizontal window border
set scrolloff=3

" Show matching brackets when text indicator is over them
set showmatch

" How many tenths of a second to blink when matching brackets
set mat=2

if s:hasColorScheme('synthetic')
  colorscheme synthetic
endif


""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" => Text Input
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""


" Change map leader
let mapleader=","

" Use the OS clipboard by default (on versions compiled with `+clipboard`)
set clipboard=unnamed

" Enhance command-line completion
set wildmenu

" Allow cursor keys in insert mode
set esckeys

" Allow backspace in insert mode
set backspace=indent,eol,start

" Use UTF-8 without BOM
set encoding=utf-8 nobomb

" Don’t add empty newlines at the end of files
set binary
set noeol

" Respect modeline in files
set modeline
set modelines=4

" Use spaces instead of tabs
set expandtab

" Be smart when using tabs ;)
set smarttab

" 1 tab == 2 spaces
set shiftwidth=2

" Make tabs as wide as 2 spaces
set tabstop=2

" Strip trailing whitespace (,ss)
function! StripWhitespace()
    let save_cursor=getpos(".")
    let old_query=getreg('/')
    :%s/\s\+$//e
    call setpos('.', save_cursor)
    call setreg('/', old_query)
endfunction
noremap <leader>ss :call StripWhitespace()<CR>


""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" => Plugins
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""


" =====> NERDTree

let g:NERDTreeWinPos="left"
let NERDTreeShowHidden=1

" Initial NERDTree width
let g:NERDTreeWinSize=35

" Automatically delete the buffer of the file you just deleted with NerdTree
let NERDTreeAutoDeleteBuffer=1

autocmd StdinReadPre * let s:std_in=1
" Open a NERDTree automatically when vim starts up if no files were specified
autocmd VimEnter * if argc() == 0 && !exists("s:std_in") | NERDTree | endif
" Open NERDTree automatically when vim starts up on opening a directory
autocmd VimEnter * if argc() == 1 && isdirectory(argv()[0]) && !exists("s:std_in") | exe 'NERDTree' argv()[0] | wincmd p | ene | endif

" Close vim if the only window left open is a NERDTree
autocmd bufenter * if (winnr("$") == 1 && exists("b:NERDTree") && b:NERDTree.isTabTree()) | q | endif

" Start NERDTree in minimal UI mode (No help lines)
let NERDTreeMinimalUI=1

" Hide .pyc files in NERDTree
let NERDTreeIgnore=['\.pyc$', '.DS_Store']

map <leader>t :NERDTreeToggle<cr>
map <leader>v :NERDTreeFind<cr>


" =====> Airline

" Automatically displays all buffers when there's only one tab open
let g:airline#extensions#tabline#enabled=1

" Separators
let g:airline#extensions#tabline#left_sep=' '
let g:airline#extensions#tabline#left_alt_sep='|'

let $FZF_DEFAULT_COMMAND='ag --files-with-matches --hidden --vimgrep --smart-case --nocolor --ignore .git'


" =====> Fuzzy files finder

nnoremap \ :Files<cr>
