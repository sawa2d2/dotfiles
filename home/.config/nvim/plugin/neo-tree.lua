-- Keep Telescope for fuzzy search; use Neo-tree for directory navigation.
-- Keep both Ctrl-P and leader-e available for the project tree.
vim.keymap.set("n", "<C-p>", "<cmd>Neotree filesystem toggle float<cr>", {
  desc = "Browse project tree",
})
vim.keymap.set("n", "<leader>e", "<cmd>Neotree filesystem toggle float<cr>", {
  desc = "Browse project tree",
})

vim.api.nvim_create_autocmd("VimEnter", {
  once = true,
  callback = function()
    local ok, neo_tree = pcall(require, "neo-tree")
    if not ok then
      vim.notify("Neo-tree is unavailable", vim.log.levels.WARN)
      return
    end

    neo_tree.setup({
      default_component_configs = {
        icon = {
          folder_closed = "[+]",
          folder_open = "[-]",
          folder_empty = "[ ]",
          folder_empty_open = "[ ]",
          default = " ",
        },
      },
      close_if_last_window = true,
      filesystem = {
        hijack_netrw_behavior = "disabled",
        window = {
          mappings = {
            ["Z"] = "expand_all_nodes",
          },
        },
      },
      window = {
        position = "float",
        mappings = {
          ["<C-c>"] = "close_window",
        },
        popup = {
          size = {
            width = "80%",
          },
        },
      },
    })

    -- Start in the file browser only when Neovim was launched without a file.
    if vim.fn.argc() == 0
        and vim.bo.buftype == ""
        and vim.api.nvim_buf_get_name(0) == ""
        and not vim.bo.modified
    then
      vim.schedule(function()
        vim.cmd("Neotree filesystem float")
      end)
    end
  end,
})

-- A fresh, unnamed tab acts as another file-selection screen.
vim.api.nvim_create_autocmd("TabNewEntered", {
  callback = function()
    local tab = vim.api.nvim_get_current_tabpage()
    vim.schedule(function()
      if vim.api.nvim_get_current_tabpage() ~= tab then
        return
      end
      if vim.bo.buftype == ""
          and vim.api.nvim_buf_get_name(0) == ""
          and not vim.bo.modified
      then
        vim.cmd("Neotree filesystem float")
      end
    end)
  end,
})
