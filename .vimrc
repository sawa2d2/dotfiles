" Use Molokai when installed; otherwise keep the default colorscheme
if !empty(globpath(&runtimepath, 'colors/molokai.vim'))
    colorscheme molokai
endif

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
imap <C-c> <Esc>

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

nnoremap <F2> :set invnumber invrelativenumber<CR>
nnoremap <F3> :set invrelativenumber<CR>

" Recognize extensionless Python and POSIX/Bash scripts by their shebang.
function! s:ShebangLanguage() abort
    let l:line = getline(1)
    if l:line =~# '^#!\s*\%(/\S*/\)\?\%(env\s\+\%(-S\s\+\)\?\)\?python\%([0-9.]\+\)\?\%(\s\|$\)'
        return 'python'
    endif
    if l:line =~# '^#!\s*\%(/\S*/\)\?\%(env\s\+\%(-S\s\+\)\?\)\?\%(ba\)\?sh\%(\s\|$\)'
        return 'sh'
    endif
    return ''
endfunction

function! s:DetectShebangFiletype() abort
    if expand('%:e') ==# '' && &buftype ==# ''
        let l:lang = <SID>ShebangLanguage()
        if l:lang !=# '' && &filetype !=# l:lang
            execute 'setlocal filetype=' . l:lang
        endif
    endif
endfunction

augroup dotfiles_shebang
    autocmd!
    autocmd BufReadPost,BufEnter,TextChanged,TextChangedI,BufWritePre * call <SID>DetectShebangFiletype()
augroup END

" Format Python on save in both Vim and Neovim, if Ruff is available.
function! s:RuffFormatOnSave() abort
    if !executable('ruff') || &buftype !=# '' || !&modifiable || &readonly
        return
    endif

    if &filetype !=# 'python' && expand('%:e') !=# 'py' && <SID>ShebangLanguage() !=# 'python'
        return
    endif

    let l:original = getline(1, '$')
    let l:command = 'ruff format --stdin-filename ' . shellescape(expand('%:p')) . ' -'
    let l:formatted = systemlist(l:command, join(l:original, "\n") . "\n")
    if v:shell_error
        echohl WarningMsg
        echom 'Ruff format failed; leaving buffer unchanged'
        echohl None
        return
    endif
    if l:formatted ==# l:original
        return
    endif

    let l:view = winsaveview()
    call setline(1, l:formatted)
    if len(l:formatted) < len(l:original)
        execute (len(l:formatted) + 1) . ',$delete _'
    endif
    call winrestview(l:view)
endfunction

augroup dotfiles_ruff
    autocmd!
    autocmd BufWritePre * call <SID>RuffFormatOnSave()
augroup END

" Format shell scripts on save in both Vim and Neovim.
function! s:ShfmtOnSave() abort
    if !executable('shfmt') || &buftype !=# '' || !&modifiable || &readonly
        return
    endif
    " Include .sh files and extensionless sh/bash scripts.
    if expand('%:e') !=# 'sh' && <SID>ShebangLanguage() !=# 'sh'
        return
    endif

    let l:original = getline(1, '$')
    let l:command = 'shfmt -filename ' . shellescape(expand('%:p')) . ' -i 2 -ci -sr'
    let l:formatted = systemlist(l:command, join(l:original, "\n") . "\n")
    if v:shell_error
        echohl WarningMsg
        echom 'shfmt failed; leaving buffer unchanged'
        echohl None
        return
    endif
    if l:formatted ==# l:original
        return
    endif

    let l:view = winsaveview()
    call setline(1, l:formatted)
    if len(l:formatted) < len(l:original)
        execute (len(l:formatted) + 1) . ',$delete _'
    endif
    call winrestview(l:view)
endfunction

augroup dotfiles_shfmt
    autocmd!
    autocmd BufWritePre * call <SID>ShfmtOnSave()
augroup END
