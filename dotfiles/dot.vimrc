
"SETUP
set encoding=utf-8

" Set location so we can set variables accordingly
let g:os = "linux"
if has("win32") || has("win64")
    let g:os="win"
endif

" repalce backslash with forward slash
"if g:os != "win"
"    set shellslash
"endif

if has("autocmd")
  autocmd bufwritepost .vimrc source $MYVIMRC
  autocmd bufwritepost _vimrc source $MYVIMRC
endif

if version >= 704 && has("patch-7.4-399")
    set cryptmethod=blowfish2
elseif version >= 703
    set cryptmethod=blowfish
endif

"Settings
syntax on
set relativenumber
set number
set modelines=0
set nomodeline

" UI Settings: {{{2 ----------------------------------------------------------

set cmdheight=1
set colorcolumn=+1
set cursorline
set display+=lastline
set fillchars=
set guioptions=egc
set laststatus=2
set lazyredraw
set listchars=tab:\|\ ,trail:.,extends:>,precedes:<,eol:$
set noequalalways
set noerrorbells
set novisualbell
set ruler
set showcmd
set showmatch
set showmode
set synmaxcol=1000
set winminheight=0
set winminwidth=0

" Settings: {{{1 =============================================================

set browsedir=buffer
set hidden
set history=1000
set mouse=a
set shortmess=filmnrxoOtTI

set backspace=indent,eol,start
set confirm
set foldmethod=manual
set formatoptions=tcrqn
if v:version > 703 || v:version == 703 && has("patch541")
    set formatoptions+=j
endif
set nojoinspaces
set nowrap
set nrformats-=octal
set scrollopt=jump,ver,hor
set sidescroll=10
set splitbelow
set splitright
set virtualedit=block
set whichwrap+=<,>,h,l

" Terminal
if !has("gui_running")
    set t_Co=256
    set term=xterm-256color
    set ttymouse=xterm2
endif

" Indentation Settings: {{{2 -------------------------------------------------

set autoindent
set expandtab
set shiftwidth=4
set softtabstop=4
set tabstop=4
set smarttab
set shiftround

" File Settings: {{{2 --------------------------------------------------------

filetype plugin indent on
set autoread
set fileformats=unix,dos
set nobackup
set nowritebackup
set noswapfile

let g:mapleader = "\<Space>"
let g:maplocalleader = "\<Space>"

" Indenting in visual mode
xnoremap <silent> <tab> >gv
xnoremap <silent> <s-tab> <gv
xnoremap <silent> > >gv
xnoremap <silent> < <gv

" Backspace
xnoremap <BS> d
if g:os == "osx"
    inoremap <A-BS> <C-w>
elseif g:os == "win"
    inoremap <C-BS> <C-w>
endif

" Make x not yank to register
noremap x "_x

"UI Settings 

if has("gui_running")
    set title
    if g:os == "win"
        set guifont=Consolas:h10
    endif
else
    set guioptions+=aA
endif

" Use system clipboard
if has("clipboard")
    if has("unnamedplus")
        set clipboard=unnamedplus,unnamed
    else
        set clipboard=unnamed
    endif
else
    set clipboard=
endif

" Search Settings: {{{2 ------------------------------------------------------

set ignorecase
set incsearch
set nohlsearch
set smartcase

" Indentation Settings: {{{2 -------------------------------------------------

set autoindent
set expandtab
set shiftwidth=4
set softtabstop=4
set tabstop=4
set smarttab
set shiftround

" Completion Settings: {{{2 --------------------------------------------------

set complete=.,w,b,u
set completeopt=longest,menu
set wildignorecase
set wildmenu
set wildmode=longest:full,full
" set wildmode=list:longest,full
set pumheight=16

set wildignore+=*.pyc,*.pyd,*.pyo " python files
set wildignore+=*.bmp,*.gif,*.ico,*.png,*.jpg,*.jpeg " images
set wildignore+=*.csproj,*.pdb,*.resx,*.sln,*.suo " visual studio
set wildignore+=*.doc,*.docx,*.pdf,*.xls,*.xlsx " documents
set wildignore+=*.dll,*.exe,*.lib,*.map,*.o,*.obj,*.so " binaries
set wildignore+=*.h5,*.gz " compressed files
set wildignore+=*.bak,*~,tmp " misc files
set wildignore+=.svn\*,.git\* " scm
set wildignore+=cscope.out,tags " vim

if g:os == "win"
    let g:plug_dir = "~/vimfiles/autoload/plug.vim"
    let g:luc_dir = "~/vimfiles/bundle/vim-lucius/colors/lucius.vim"
else
    let g:plug_dir = "~/.vim/autoload/plug.vim"
    let g:luc_dir = "~/.vim/bundle/vim-lucius/colors/lucius.vim"
endif

"Plugins
if !empty(glob(g:plug_dir))
    if has("win32") || has("win64")
        call plug#begin('~/vimfiles/bundle')
    else
        call plug#begin('~/.vim/bundle')
    endif

    Plug 'ctrlpvim/ctrlp.vim'
    Plug 'jonathanfilip/vim-lucius'
    Plug 'scrooloose/nerdtree'
    Plug 'scrooloose/syntastic'
    Plug 'Xuyuanp/nerdtree-git-plugin'
    Plug 'tpope/vim-fugitive'
    Plug 'vim-airline/vim-airline'
    Plug 'vim-airline/vim-airline-themes'
    Plug 'PProvost/vim-ps1'
    call plug#end()
endif

" Save command typos
command! Q q
command! W w
command! Wq wq
command! WQ wq

if !empty(glob(g:luc_dir))
    colorscheme lucius
    if has("gui_running")
        LuciusLight
    else
        LuciusDark
    endif
endif

" Airline: {{{2 --------------------------------------------------------------

let g:airline_left_sep = ''
let g:airline_right_sep = ''
let g:airline_inactive_collapse=1

let g:airline#extensions#wordcount#enabled = 0
let g:airline#extensions#whitespace#enabled = 0
let g:airline#extensions#tabline#enabled = 0

let g:airline#extensions#default#layout = [
    \ [ 'a', 'c' ],
    \ [ 'x', 'y', 'z', 'error', 'warning' ]
    \ ]


" CtrlP: {{{2 ----------------------------------------------------------------

let g:ctrlp_clear_cache_on_exit = 0
let g:ctrlp_custom_ignore = {
            \ 'dir': 'tests$',
            \ 'file': '',
            \ }
let g:ctrlp_extensions = ['buffertag']
let g:ctrlp_lazy_update = 0
let g:ctrlp_match_window='position:bottom,order:btt,min:1,max:10,results:100'
let g:ctrlp_show_hidden = 0
let g:ctrlp_switch_buffer = 'vh'
let g:ctrlp_working_path_mode = 0

nnoremap <silent> <leader>ff :CtrlP<CR>
nnoremap <silent> <leader>fb :CtrlPBuffer<CR>
nnoremap <silent> <leader>fr :CtrlPMRU<CR>
nnoremap <silent> <leader>ft :CtrlPBufTag<CR>

nnoremap <silent> <leader>e :CtrlP<CR>
nnoremap <silent> <leader>b :CtrlPBuffer<CR>


