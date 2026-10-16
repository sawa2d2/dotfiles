" Use Molokai when installed; otherwise keep the default colorscheme
if !empty(globpath(&runtimepath, 'colors/molokai.vim'))
    colorscheme molokai
endif

" Apply shared UI colors after Molokai (or any default colorscheme).
if filereadable(expand('~/.vim.theme.vim'))
    execute 'source' fnameescape(expand('~/.vim.theme.vim'))
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
set showtabline=2

" Show only file names in tabs, avoiding abbreviated parent paths.
function! DotfilesTabline() abort
    let l:line = ''
    for l:tab in range(1, tabpagenr("$"))
        let l:buffers = tabpagebuflist(l:tab)
        let l:buffer = get(l:buffers, tabpagewinnr(l:tab) - 1, -1)
        let l:name = fnamemodify(bufname(l:buffer), ':t')
        if empty(l:name)
            let l:name = '[No Name]'
        endif
        let l:name = substitute(l:name, '%', '%%', 'g')
        let l:modified = l:buffer > 0 && getbufvar(l:buffer, '&modified')
        let l:severity = 0
        if has('nvim') && l:buffer > 0
            let l:counts = luaeval("require('dotfiles_status').counts(_A)", l:buffer)
            let l:severity = l:counts[0] > 0 ? 2 : (l:counts[1] > 0 ? 1 : 0)
        endif

        let l:line .= '%' . l:tab . 'T'
        if l:severity == 2
            let l:group = l:tab == tabpagenr() ? 'DotTabError' : 'DotTabErrorNC'
        elseif l:severity == 1
            let l:group = l:tab == tabpagenr() ? 'DotTabWarn' : 'DotTabWarnNC'
        else
            let l:group = l:tab == tabpagenr() ? 'TabLineSel' : 'TabLine'
        endif
        let l:line .= '%#' . l:group . '#'
        let l:line .= ' ' . l:name . (l:modified ? ' *' : '') . ' '
    endfor
    let l:line .= '%#TabLineFill#%T%='
    if !empty(g:dotfiles_git_branch)
        let l:line .= '%#TabLine# (' . g:dotfiles_git_branch . ') '
    endif
    return l:line
endfunction
set tabline=%!DotfilesTabline()

" Update unsaved markers on tab titles as buffer contents change.
augroup dotfiles_tabline_modified
    autocmd!
    autocmd TextChanged,TextChangedI,BufWritePost * redrawtabline
augroup END

" Cache the branch name instead of spawning Git during each tabline redraw.
let g:dotfiles_git_branch = ''
function! s:UpdateGitBranch() abort
    let g:dotfiles_git_branch = ''
    if !executable('git')
        return
    endif
    let l:branch = systemlist('git -C ' . shellescape(getcwd()) . ' symbolic-ref --quiet --short HEAD 2>/dev/null')
    if v:shell_error == 0 && !empty(l:branch)
        let g:dotfiles_git_branch = substitute(l:branch[0], '%', '%%', 'g')
    endif
endfunction

augroup dotfiles_git_branch
    autocmd!
    autocmd VimEnter,BufEnter,DirChanged,FocusGained * call <SID>UpdateGitBranch()
augroup END

" Automatically restore and save one editing session per project/directory.
" Store sessions outside the repository and keep Vim/Neovim sessions separate.
" Capture the startup file before a session changes the argument list or directory.
let s:startup_file = argc() == 1 && !isdirectory(argv(0)) ? fnamemodify(argv(0), ':p') : ''

function! s:ProjectContext() abort
    " Prefer the explicitly opened file's Git worktree, even when launched elsewhere.
    let l:root = empty(s:startup_file) ? getcwd() : fnamemodify(s:startup_file, ':h')
    let l:root = resolve(l:root)
    if executable('git')
        let l:roots = systemlist('git -C ' . shellescape(l:root) . ' rev-parse --show-toplevel 2>/dev/null')
        if v:shell_error == 0 && !empty(l:roots)
            return [resolve(l:roots[0]), 1]
        endif
    endif
    return [l:root, 0]
endfunction

let [s:project_root, s:project_is_git] = s:ProjectContext()
let s:session_dir = expand('~/.local/state/dotfiles/vim-sessions')
let s:editor = has('nvim') ? 'nvim' : 'vim'
let s:session_key = s:project_root
if s:project_is_git
    " Keep sessions separate when switching branches in the same worktree.
    let s:branch = systemlist('git -C ' . shellescape(s:project_root) . ' symbolic-ref --quiet HEAD 2>/dev/null')
    if v:shell_error != 0 || empty(s:branch)
        " Detached HEAD: identify the checked-out commit instead.
        let s:branch = systemlist('git -C ' . shellescape(s:project_root) . ' rev-parse HEAD 2>/dev/null')
    endif
    if !empty(s:branch)
        let s:session_key .= "\n" . s:branch[0]
    endif
endif
let s:project_session = s:session_dir . '/' . s:editor . '-' . sha256(s:session_key) . '.vim'

function! s:RestoreProjectSession() abort
    " Manually loaded sessions take precedence.
    if !empty(v:this_session)
        return
    endif
    " Use the repository root as cwd, regardless of the startup subdirectory.
    if s:project_is_git
        execute 'cd ' . fnameescape(s:project_root)
    endif
    if filereadable(s:project_session)
        execute 'silent source ' . fnameescape(s:project_session)
        " An older saved session may change cwd; normalize it again.
        if s:project_is_git
            execute 'cd ' . fnameescape(s:project_root)
        endif
        " Open an explicit startup file in a new tab, preserving the restored layout.
        if !empty(s:startup_file)
            execute 'tabedit ' . fnameescape(s:startup_file)
        endif
    endif
endfunction

function! s:SaveProjectSession() abort
    call mkdir(fnamemodify(s:project_session, ':h'), 'p')
    " Do not snapshot editor-specific settings or live terminal processes.
    let l:options = &sessionoptions
    try
        set sessionoptions=blank,buffers,curdir,folds,help,tabpages,winsize
        execute 'silent mksession! ' . fnameescape(s:project_session)
    finally
        let &sessionoptions = l:options
    endtry
endfunction

augroup dotfiles_project_session
    autocmd!
    autocmd VimEnter * call <SID>RestoreProjectSession()
    autocmd VimLeavePre * call <SID>SaveProjectSession()
augroup END

" Colored statusline segments; Vim shares UI styling, Neovim adds LSP diagnostics.
function! DotfilesStatusline() abort
    let l:window = get(g:, 'statusline_winid', win_getid())
    let l:active = (l:window == win_getid())
    let l:base = l:active ? 'StatusLine' : 'StatusLineNC'

    if l:active
        let l:line = '%#DotStatusFile# %t %m%r '
    else
        let l:line = '%#StatusLineNC# %t %m%r '
    endif

    let l:line .= '%#' . l:base . '#%='
    if has('nvim') && winbufnr(l:window) > 0
        let l:counts = luaeval("require('dotfiles_status').counts(_A)", winbufnr(l:window))
        if l:counts[0] > 0
            let l:group = l:active ? 'DotStatusError' : 'DotStatusErrorNC'
            let l:line .= '%#' . l:group . '# E ' . l:counts[0] . ' '
        endif
        if l:counts[1] > 0
            let l:group = l:active ? 'DotStatusWarn' : 'DotStatusWarnNC'
            let l:line .= '%#' . l:group . '# W ' . l:counts[1] . ' '
        endif
    endif

    let l:meta = l:active ? 'DotStatusMeta' : 'StatusLineNC'
    return l:line . '%#' . l:meta . '# %y  %l:%c '
endfunction
set statusline=%!DotfilesStatusline()
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

" Move the nearest split border with Alt/Option + hjkl.
" Keep the movement direction consistent regardless of which pane has focus.
function! DotfilesMoveSplitBorder(direction) abort
    if a:direction ==# 'h' || a:direction ==# 'l'
        if !exists('*win_move_separator')
            return
        endif
        let l:target = winnr()
        if winnr('l') == l:target
            let l:target = winnr('h')
        endif
        if l:target != winnr() || winnr('l') != winnr()
            call win_move_separator(l:target, a:direction ==# 'l' ? 3 : -3)
        endif
    else
        if !exists('*win_move_statusline')
            return
        endif
        let l:target = winnr()
        if winnr('j') == l:target
            let l:target = winnr('k')
        endif
        if l:target != winnr() || winnr('j') != winnr()
            call win_move_statusline(l:target, a:direction ==# 'j' ? 2 : -2)
        endif
    endif
endfunction

nnoremap <silent> <M-h> :call DotfilesMoveSplitBorder('h')<CR>
nnoremap <silent> <M-j> :call DotfilesMoveSplitBorder('j')<CR>
nnoremap <silent> <M-k> :call DotfilesMoveSplitBorder('k')<CR>
nnoremap <silent> <M-l> :call DotfilesMoveSplitBorder('l')<CR>
imap <C-c> <Esc>

" Quit all tabs with two consecutive Ctrl+Q presses (honors unsaved changes).
nnoremap <silent> <C-q><C-q> :qa<CR>

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
