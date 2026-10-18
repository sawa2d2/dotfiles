let mapleader = " "

source ~/.vimrc
nnoremap Y yy

" Neovim session management is provided by persistence.nvim.
lua require('dotfiles_session').setup()


" Diagnostic highlighting and on-cursor messages.
lua require("dotfiles_diagnostic_lines")
