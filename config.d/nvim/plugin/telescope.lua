-- On-demand project navigation with Telescope. Shared Vim settings stay in .vimrc.
local ok, telescope = pcall(require, "telescope")
if not ok then
  return
end

telescope.setup({
  defaults = {
    mappings = {
      i = {
        ["<C-j>"] = "move_selection_next",
        ["<C-k>"] = "move_selection_previous",
      },
    },
  },
})

local builtin = require("telescope.builtin")
vim.keymap.set("n", "<leader>ff", builtin.find_files, { desc = "Find project files" })
vim.keymap.set("n", "<C-f>", builtin.live_grep, { desc = "Search project text" })
vim.keymap.set("n", "<leader>fg", builtin.live_grep, { desc = "Search project text" })
vim.keymap.set("n", "<leader>fb", builtin.buffers, { desc = "Find open buffers" })
vim.keymap.set("n", "<leader>fh", builtin.help_tags, { desc = "Search help tags" })
