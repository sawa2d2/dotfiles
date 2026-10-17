let mapleader = " "

source ~/.vimrc
nnoremap Y yy

" Neovim session management is provided by persistence.nvim.
lua require('dotfiles_session').setup()

" Format Python and shell scripts with conform.nvim.
lua require('dotfiles_format')
