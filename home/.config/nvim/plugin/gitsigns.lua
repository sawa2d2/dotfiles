-- Minimal Git diff markers in the sign column.
local ok, gitsigns = pcall(require, "gitsigns")
if not ok then
  return
end

gitsigns.setup({
  signs = {
    add = { text = "+" },
    change = { text = "~" },
    delete = { text = "_" },
    topdelete = { text = "_" },
    changedelete = { text = "_" },
    untracked = { text = "+" },
  },
  signs_staged_enable = false,
  signcolumn = true,
  numhl = false,
  linehl = false,
  current_line_blame = true,
  current_line_blame_opts = {
    delay = 0,
  },
})

vim.keymap.set("n", "<leader>gb", function()
  gitsigns.blame()
end, { desc = "Git blame" })
