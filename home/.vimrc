" Use Molokai when installed; otherwise keep the default colorscheme
silent! packadd molokai
if !empty(globpath(&runtimepath, 'colors/molokai.vim'))
    colorscheme molokai
endif

" Apply shared UI colors after Molokai (or any default colorscheme).
if filereadable(expand('~/dotfiles/theme/generated/vim.theme.vim'))
    execute 'source' fnameescape(expand('~/dotfiles/theme/generated/vim.theme.vim'))
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

" Insert matching brackets and keep cursor inside.
inoremap ( ()<Left>
inoremap [ []<Left>
inoremap { {}<Left>
set laststatus=2
set showtabline=2

" Show only file names in tabs, avoiding abbreviated parent paths.
function! DotfilesTabline() abort
    let l:line = '%#TabLineFill#   '
    for l:tab in range(1, tabpagenr("$"))
        let l:buffers = tabpagebuflist(l:tab)
        let l:buffer = get(l:buffers, tabpagewinnr(l:tab) - 1, -1)
        let l:name = gettabvar(l:tab, 'dotfiles_tab_name', '')
        if empty(l:name)
            let l:name = fnamemodify(bufname(l:buffer), ':t')
            if empty(l:name)
                let l:name = '[No Name]'
            endif
        endif
        let l:name = substitute(l:name, '%', '%%', 'g')
        let l:modified = l:buffer > 0 && getbufvar(l:buffer, '&modified')
        let l:severity = 0
        if has('nvim') && l:buffer > 0
            let l:counts = luaeval("require('dotfiles_status').counts(_A)", l:buffer)
            let l:severity = l:counts[0] > 0 ? 2 : (l:counts[1] > 0 ? 1 : 0)
        endif

        if l:tab > 1
            let l:line .= '%T%#TabLineFill# '
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

" A tab name overrides its file title; empty restores the default.
function! DotfilesRenameTab(name) abort
    let t:dotfiles_tab_name = a:name
    redrawtabline
endfunction
command! -nargs=* RenameTab call DotfilesRenameTab(<q-args>)

function! DotfilesPromptRenameTab() abort
    call inputsave()
    try
        let l:name = input('Tab name: ', get(t:, 'dotfiles_tab_name', ''))
    finally
        call inputrestore()
    endtry
    call DotfilesRenameTab(l:name)
endfunction
nnoremap <silent> <leader>, :call DotfilesPromptRenameTab()<CR>

" Move the selected window's buffer to a new split in an existing named tab.
" The original buffer, including unsaved edits, stays loaded.
function! DotfilesMoveToTab(name) abort
    let l:matches = []
    for l:tab in range(1, tabpagenr('$'))
        if gettabvar(l:tab, 'dotfiles_tab_name', '') ==# a:name
            call add(l:matches, l:tab)
        endif
    endfor
    if len(l:matches) != 1
        echoerr len(l:matches) == 0 ? 'MoveToTab: tab not found: ' . a:name : 'MoveToTab: ambiguous tab name: ' . a:name
        return
    endif
    if l:matches[0] == tabpagenr()
        echoerr 'MoveToTab: destination is the current tab'
        return
    endif
    if &buftype !=# ''
        echoerr 'MoveToTab: special buffers are not supported'
        return
    endif

    let l:source_window = win_getid()
    let l:buffer = bufnr('%')
    execute 'tabnext ' . l:matches[0]
    try
        execute 'rightbelow vertical sbuffer ' . l:buffer
    catch
        call win_gotoid(l:source_window)
        echoerr 'MoveToTab: failed to open buffer: ' . v:exception
        return
    endtry
    let l:target_window = win_getid()
    if !win_gotoid(l:source_window)
        echoerr 'MoveToTab: source window disappeared'
        return
    endif
    close
    call win_gotoid(l:target_window)
endfunction
command! -nargs=+ MoveToTab call DotfilesMoveToTab(<q-args>)
nnoremap <leader>. :MoveToTab<Space>

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

" Colored statusline segments; Vim shares UI styling, Neovim adds LSP diagnostics.
" Display paths relative to their Git root; otherwise use absolute paths.
" Cache per buffer to avoid launching Git on every statusline redraw.
function! DotfilesStatusPath(buffer) abort
    let l:name = bufname(a:buffer)
    if empty(l:name)
        return '[No Name]'
    endif
    if getbufvar(a:buffer, '&buftype') !=# ''
        return substitute(l:name, '%', '%%', 'g')
    endif
    let l:file = fnamemodify(l:name, ':p')
    let l:cached = getbufvar(a:buffer, 'dotfiles_status_path_cache', {})
    if get(l:cached, 'file', '') !=# l:file
        let l:display = l:file
        if executable('git')
            let l:root = systemlist('git -C ' . shellescape(fnamemodify(l:file, ':h')) . ' rev-parse --show-toplevel 2>/dev/null')
            if v:shell_error == 0 && !empty(l:root)
                let l:root_path = resolve(l:root[0])
                let l:resolved_file = resolve(l:file)
                if stridx(l:resolved_file, l:root_path . '/') == 0
                    let l:display = strpart(l:resolved_file, strlen(l:root_path) + 1)
                endif
            endif
        endif
        let l:cached = {'file': l:file, 'display': l:display}
        call setbufvar(a:buffer, 'dotfiles_status_path_cache', l:cached)
    endif
    return substitute(l:cached.display, '%', '%%', 'g')
endfunction

function! DotfilesStatusline() abort
    let l:window = get(g:, 'statusline_winid', win_getid())
    let l:active = (l:window == win_getid())
    let l:base = l:active ? 'StatusLine' : 'StatusLineNC'
    let l:path = DotfilesStatusPath(winbufnr(l:window))

    if l:active
        let l:line = '%#DotStatusFile# ' . l:path . ' %m%r '
    else
        let l:line = '%#StatusLineNC# ' . l:path . ' %m%r '
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

" Line start and end without reaching for ^ and $. gh (Select mode) is
" rarely used and gl is unmapped by default.
nnoremap gh ^
xnoremap gh ^
onoremap gh ^
nnoremap gl $
xnoremap gl $
onoremap gl $

"tab
nmap <S-L> gt
nmap <S-H> gT
nnoremap <silent> <leader>h :tabmove -1<CR>
nnoremap <silent> <leader>l :tabmove +1<CR>
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
    " A recognized shebang takes precedence over filename extensions.
    if &buftype ==# ''
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

" ALE owns formatting on both Vim and Neovim; keep LSP/completion in their existing plugins.
let g:ale_linters_explicit = 1
let g:ale_linters = {}
let g:ale_disable_lsp = 1
let g:ale_completion_enabled = 0
let g:ale_fix_on_save = 1
let g:ale_fixers = {
\ 'python': ['ruff', 'ruff_format'],
\ 'sh': ['shfmt'],
\ 'bash': ['shfmt'],
\}
let g:ale_sh_shfmt_options = '-i 2 -ci -sr'
