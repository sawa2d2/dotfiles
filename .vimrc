colorscheme molokai

set fenc=utf-8
set nobackup
set noswapfile
set autoread
set hidden
set showcmd

set relativenumber
set number
set cursorline
"set cursorcolumn
set relativenumber
set virtualedit=onemore
set smartindent
"set visualbell
set showmatch
set laststatus=2
set wildmode=list:longest
nnoremap j gj
nnoremap k gk
syntax enable

set list listchars=tab:\▸\-
set expandtab
set tabstop=2
set shiftwidth=2

set ignorecase
set smartcase
set incsearch
set wrapscan
set hlsearch
nmap <Esc><Esc> :nohlsearch<CR><Esc>

" pane
nmap ss :split<Return><C-w>w
nmap sv :vsplit<Return><C-w>w
map sh <C-w>h
map sk <C-w>k
map sj <C-w>j
map sl <C-w>l
map sH <C-w>H
map sK <C-w>K
map sJ <C-w>J
map sL <C-w>L
nmap <C-w><left> <C-w><
nmap <C-w><right> <C-w>>
nmap <C-w><up> <C-w>+
nmap <C-w><down> <C-w>-

"tab
nmap <S-L> gt
nmap <S-H> gT
nmap t :tabe<Return>:E<Return>
"nmap te :tabedit
"nmap tl :Unite tab

"filer (newtr)
nmap <C-e> :Lex<Return>
"'ls -la' like
let g:netrw_liststyle=1
"hidden header
let g:netrw_banner=0
" サイズを(K,M,G)で表示する
let g:netrw_sizestyle="H"
"yyyy/mm/dd(A) hh:mm:ss
let g:netrw_timefmt="%Y/%m/%d(%a) %H:%M:%S"
"
let g:netrw_preview=1
