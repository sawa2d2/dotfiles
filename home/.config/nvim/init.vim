let mapleader = " "

source ~/.vimrc
nnoremap Y yy
" Yank to the system clipboard; plain y keeps using the unnamed register.
nnoremap <leader>y "+y
xnoremap <leader>y "+y

" Neovim session management is provided by persistence.nvim.
lua require('dotfiles_session').setup()


" Diagnostic highlighting and on-cursor messages.
lua require("dotfiles_diagnostic_lines")
