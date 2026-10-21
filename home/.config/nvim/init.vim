let mapleader = " "

source ~/.vimrc
nnoremap Y yy
" Yank to and paste from the system clipboard; plain y and p keep using the
" unnamed register.
nnoremap <leader>y "+y
xnoremap <leader>y "+y
nnoremap <leader>p "+p
xnoremap <leader>p "+p
nnoremap <leader>P "+P
xnoremap <leader>P "+P

" Neovim session management is provided by persistence.nvim.
lua require('dotfiles_session').setup()


" Diagnostic highlighting and on-cursor messages.
lua require("dotfiles_diagnostic_lines")
