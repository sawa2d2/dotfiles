-- Python IDE features; init.vim and the shared .vimrc remain untouched.
if vim.fn.has("nvim-0.11") == 0 then
  vim.notify("Python IDE configuration requires Neovim 0.11+", vim.log.levels.WARN)
  return
end

local ok, cmp = pcall(require, "cmp")
if ok then
  cmp.setup({
    completion = { completeopt = "menu,menuone" },
    preselect = cmp.PreselectMode.Item,
    view = { docs = { auto_open = false } },
    window = {
      completion = {
        border = "none",
        side_padding = 0,
        max_height = 12,
        winhighlight = "Normal:DotCmpNormal,FloatBorder:DotCmpNormal,CursorLine:DotCmpSelected,Search:None",
        winblend = 0,
      },
    },
    formatting = {
      fields = { "kind", "abbr" },
      format = function(_, item)
        local icons = {
          Variable = "V", Function = "F", Method = "M", Class = "C",
          Module = "P", Field = "V", Property = "V", Constant = "K",
          Keyword = "K", Constructor = "C", Interface = "I",
          Enum = "E", EnumMember = "E", Snippet = "S", File = "P",
          Folder = "D", Text = "T",
        }
        item.kind = " " .. (icons[item.kind] or "·")
        return item
      end,
    },
    snippet = {
      expand = function(args)
        vim.snippet.expand(args.body)
      end,
    },
    mapping = cmp.mapping.preset.insert({
      ["<C-Space>"] = cmp.mapping.complete(),
      ["<CR>"] = cmp.mapping.confirm({ select = false }),
      ["<C-j>"] = cmp.mapping.select_next_item(),
      ["<C-k>"] = cmp.mapping.select_prev_item(),
      ["<Tab>"] = cmp.mapping.select_next_item(),
      ["<S-Tab>"] = cmp.mapping.select_prev_item(),
    }),
    sources = cmp.config.sources({
      { name = "nvim_lsp" },
      { name = "path" },
      { name = "buffer" },
    }),
  })

  -- Python: prefer semantic LSP suggestions over words from the current buffer.
  -- Enter confirms the selected candidate or the first suggestion.
  cmp.setup.filetype("python", {
    mapping = cmp.mapping.preset.insert({
      ["<CR>"] = cmp.mapping.confirm({ select = true }),
    }),
    sources = cmp.config.sources({
      { name = "nvim_lsp", priority = 1000 },
      { name = "path", priority = 250 },
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

-- Give markdown hover floats a light-background palette without changing the
-- syntax highlights used by regular editing windows.
local hover_hl_ns = vim.api.nvim_create_namespace("dotfiles_hover_colors")
local hover_fg = vim.api.nvim_get_hl(0, { name = "NormalFloat", link = false }).fg
local hover_bg = vim.api.nvim_get_hl(0, { name = "NormalFloat", link = false }).bg
if hover_fg and hover_bg then
  for _, group in ipairs({
    "@variable", "@variable.python", "@lsp.type.variable", "@lsp.type.parameter",
    "@type", "@type.python", "@lsp.type.type", "@lsp.type.class",
    "@function", "@function.python", "@lsp.type.function", "@lsp.type.method",
    "@string", "@string.python", "@keyword", "@keyword.python",
    "@markup.raw", "@markup.raw.block", "@markup.raw.markdown_inline",
    "Identifier", "Type", "Function", "String", "Statement",
    "markdownCode", "markdownCodeBlock", "markdownInlineCode",
  }) do
    vim.api.nvim_set_hl(hover_hl_ns, group, { fg = hover_fg, bg = hover_bg })
  end
end

vim.api.nvim_create_autocmd("WinNew", {
  group = vim.api.nvim_create_augroup("dotfiles_hover_colors", { clear = true }),
  callback = function()
    vim.schedule(function()
      for _, win in ipairs(vim.api.nvim_list_wins()) do
        local config = vim.api.nvim_win_get_config(win)
        local buf = vim.api.nvim_win_get_buf(win)
        if config.relative ~= "" and vim.bo[buf].filetype == "markdown" then
          vim.api.nvim_win_set_hl_ns(win, hover_hl_ns)
        end
      end
    end)
  end,
})

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


-- Diagnostic presentation is configured in dotfiles_diagnostic_lines.lua.

-- Diagnostic navigation and lists (Neovim built-ins; no extra plugin).
vim.keymap.set("n", "]d", function()
  vim.diagnostic.jump({ count = 1, float = { severity = { min = vim.diagnostic.severity.WARN } }, severity = { min = vim.diagnostic.severity.WARN } })
end, { desc = "Next diagnostic" })

vim.keymap.set("n", "[d", function()
  vim.diagnostic.jump({ count = -1, float = { severity = { min = vim.diagnostic.severity.WARN } }, severity = { min = vim.diagnostic.severity.WARN } })
end, { desc = "Previous diagnostic" })

vim.keymap.set("n", "<leader>dl", function()
  vim.diagnostic.setqflist({ open = true, severity = { min = vim.diagnostic.severity.WARN } })
end, { desc = "All diagnostics (quickfix)" })

