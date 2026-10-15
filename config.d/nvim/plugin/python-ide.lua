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
})
vim.lsp.enable("pyright")

vim.diagnostic.config({
  underline = true,
  signs = true,
  virtual_text = { spacing = 2 },
  update_in_insert = false,
  severity_sort = true,
})
