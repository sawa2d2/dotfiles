-- Neovim formatting is delegated to conform.nvim; classic Vim uses .vimrc.
local conform = require("conform")

local function shell_script(bufnr)
  local name = vim.api.nvim_buf_get_name(bufnr)
  if vim.fn.fnamemodify(name, ":e") == "sh" then
    return { "shfmt" }
  end
  local first = vim.api.nvim_buf_get_lines(bufnr, 0, 1, false)[1] or ""
  if vim.fn.match(first, [[^#!\s*\%(/\S*/\)\?\%(env\s\+\%(-S\s\+\)\?\)\?\%(ba\)\?sh\%(\s\|$\)]]) >= 0 then
    return { "shfmt" }
  end
  return {}
end

conform.setup({
  formatters_by_ft = {
    python = { "ruff_format" },
    sh = shell_script,
    bash = shell_script,
  },
  formatters = {
    ruff_format = { args = { "format", "--stdin-filename", "$FILENAME", "-" } },
    shfmt = { args = { "-filename", "$FILENAME", "-i", "2", "-ci", "-sr" } },
  },
  format_on_save = { timeout_ms = 3000, lsp_format = "never" },
})
