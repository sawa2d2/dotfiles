# Add to the root install script (DOTPATH must already be defined).
if [ -x "$DOTPATH/theme/sync" ]; then
  "$DOTPATH/theme/sync" teal
  ln -snfv "$DOTPATH/.tmux.theme.conf" "$HOME/.tmux.theme.conf"
  ln -snfv "$DOTPATH/.vim.theme.vim" "$HOME/.vim.theme.vim"
fi
