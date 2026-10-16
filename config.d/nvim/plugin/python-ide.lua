-- Python IDE features; init.vim and the shared .vimrc remain untouched.
if vim.fn.has("nvim-0.11") == 0 then
  vim.notify("Python IDE configuration requires Neovim 0.11+", vim.log.levels.WARN)
  return
end

local ok, cmp = pcall(require, "cmp")
if ok then
  cmp.setup({
    snippet = {
      expand = function(args)
        vim.snippet.expand(args.body)
      end,
    },
    mapping = cmp.mapping.preset.insert({
      ["<C-Space>"] = cmp.mapping.complete(),
      ["<CR>"] = cmp.mapping.confirm({ select = false }),
      ["<Tab>"] = cmp.mapping.select_next_item(),
      ["<S-Tab>"] = cmp.mapping.select_prev_item(),
    }),
    sources = cmp.config.sources({
      { name = "nvim_lsp" },
      { name = "path" },
      { name = "buffer" },
    }),
  })
end

local capabilities = vim.lsp.protocol.make_client_capabilities()
if ok then
  capabilities = require("cmp_nvim_lsp").default_capabilities(capabilities)
end

vim.lsp.config("pyright", {
  cmd = { "pyright-langserver", "--stdio" },
  filetypes = { "python" },
  root_markers = { "pyrightconfig.json", "pyproject.toml", "setup.py", "setup.cfg", "requirements.txt", ".git" },
  capabilities = capabilities,
  -- Default to strict checks; project-level Pyright configuration can override this.
  settings = {
    python = {
      analysis = {
        typeCheckingMode = "strict",
      },
    },
  },
})
vim.lsp.enable("pyright")

vim.keymap.set("n", "gd", vim.lsp.buf.definition, { desc = "Go to definition" })
-- Use a blank one-cell border as padding around hover documentation.
local hover_border = {
  { " ", "DotfilesHoverPadding" },
  { " ", "DotfilesHoverPadding" },
  { " ", "DotfilesHoverPadding" },
  { " ", "DotfilesHoverPadding" },
  { " ", "DotfilesHoverPadding" },
  { " ", "DotfilesHoverPadding" },
  { " ", "DotfilesHoverPadding" },
  { " ", "DotfilesHoverPadding" },
}

-- Show LSP documentation after the cursor remains idle in normal mode.
vim.opt.updatetime = 700
vim.api.nvim_create_autocmd("CursorHold", {
  group = vim.api.nvim_create_augroup("dotfiles_lsp_hover", { clear = true }),
  callback = function(args)
    if vim.bo[args.buf].buftype ~= "" then
      return
    end
    if #vim.lsp.get_clients({ bufnr = args.buf, method = "textDocument/hover" }) == 0 then
      return
    end
    vim.lsp.buf.hover({ focusable = false, border = hover_border })
  end,
})


vim.diagnostic.config({
  underline = true,
  signs = true,
  virtual_text = { spacing = 2 },
  update_in_insert = false,
  severity_sort = true,
})

-- Diagnostic navigation and lists (Neovim built-ins; no extra plugin).
vim.keymap.set("n", "]d", function()
  vim.diagnostic.jump({ count = 1, float = true })
end, { desc = "Next diagnostic" })

vim.keymap.set("n", "[d", function()
  vim.diagnostic.jump({ count = -1, float = true })
end, { desc = "Previous diagnostic" })

vim.keymap.set("n", "<leader>dl", function()
  vim.diagnostic.setqflist({ open = true })
end, { desc = "All diagnostics (quickfix)" })

