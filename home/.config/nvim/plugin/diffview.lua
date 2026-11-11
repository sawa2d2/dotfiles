-- Keep PR review separate from the working tree and its unsaved buffers.
local origins = setmetatable({}, { __mode = "k" })

vim.keymap.set("n", "<leader>gd", function()
  local ok, diffview = pcall(require, "diffview")
  if not ok then
    vim.notify("Git diff: diffview.nvim is unavailable; install Neovim plugins first", vim.log.levels.ERROR)
    return
  end

  local lib = require("diffview.lib")
  local view = lib.get_current_view()
  if view then
    local origin = origins[view]
    diffview.close()
    if origin and vim.api.nvim_win_is_valid(origin) then
      vim.api.nvim_set_current_win(origin)
    end
    return
  end

  local directory = vim.fn.getcwd()
  if vim.bo.buftype == "" and vim.api.nvim_buf_get_name(0) ~= "" then
    directory = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(0), ":h")
  end
  if vim.fn.executable("git") == 0 then
    vim.notify("Git diff: git is unavailable", vim.log.levels.ERROR)
    return
  end
  local root = vim.fn.systemlist({ "git", "-C", directory, "rev-parse", "--show-toplevel" })
  if vim.v.shell_error ~= 0 then
    vim.notify("Git diff: not in a Git working tree", vim.log.levels.ERROR)
    return
  end
  vim.fn.system({ "git", "-C", root[1], "rev-parse", "--verify", "refs/heads/main^{commit}" })
  if vim.v.shell_error ~= 0 then
    vim.notify("Git diff: local main branch is missing; use :DiffviewOpen <base>...HEAD explicitly", vim.log.levels.ERROR)
    return
  end

  local origin = vim.api.nvim_get_current_win()
  diffview.open({ "refs/heads/main...HEAD", "-C=" .. root[1] })
  view = lib.get_current_view()
  if view then
    origins[view] = origin
  end
end, { desc = "Toggle Git diff (main...HEAD)" })
