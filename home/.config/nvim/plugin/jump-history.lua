-- Keep jump history within the current Neovim instance, without disabling ShaDa marks.
vim.api.nvim_create_autocmd("VimEnter", {
  callback = function()
    vim.cmd("clearjumps")
  end,
})
