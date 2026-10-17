-- Highlight references to the symbol under the cursor (VS Code-like).
-- Prefer semantic LSP references; fall back to Tree-sitter or text matching.
local ok, illuminate = pcall(require, "illuminate")
if not ok then
  return
end

local delay = 250
illuminate.configure({
  providers = { "lsp", "treesitter", "regex" },
  delay = delay,
})

-- Reuse the highlighting of *: Search for other occurrences, CurSearch for
-- the occurrence under the cursor. Preserve the underline on both.
local function apply_highlights()
  local search = vim.api.nvim_get_hl(0, { name = "Search", link = false })
  for _, group in ipairs({ "IlluminatedWordText", "IlluminatedWordRead", "IlluminatedWordWrite" }) do
    vim.api.nvim_set_hl(0, group, { fg = search.fg, bg = search.bg, underline = true })
  end

  local current = vim.api.nvim_get_hl(0, { name = "CurSearch", link = false })
  vim.api.nvim_set_hl(0, "DotfilesIlluminateCurrent", {
    fg = current.fg or 0x222222,
    bg = current.bg or 0xe5a45b,
    underline = true,
    bold = current.bold,
  })
end

apply_highlights()
vim.api.nvim_create_autocmd("ColorScheme", {
  group = vim.api.nvim_create_augroup("DotfilesIlluminateColors", { clear = true }),
  callback = apply_highlights,
})

-- vim-illuminate highlights references but has no separate "under cursor"
-- highlight group. Overlay one extmark with a higher priority instead.
local ns = vim.api.nvim_create_namespace("dotfiles-illuminate-current")
local generation = 0

local function clear_current()
  generation = generation + 1
  vim.api.nvim_buf_clear_namespace(0, ns, 0, -1)
end

local function highlight_current()
  clear_current()
  if vim.fn.mode() ~= "n" then
    return
  end

  local buf = vim.api.nvim_get_current_buf()
  if vim.bo[buf].buftype ~= "" then
    return
  end

  local pos = vim.api.nvim_win_get_cursor(0)
  local line = vim.api.nvim_get_current_line()
  local col = pos[2] -- Zero-based byte column.
  local offset = 0

  while offset < #line do
    local match = vim.fn.matchstrpos(line, [[\k\+]], offset)
    local start_col, end_col = match[2], match[3]
    if start_col < 0 then
      break
    end
    if start_col <= col and col < end_col then
      vim.api.nvim_buf_set_extmark(buf, ns, pos[1] - 1, start_col, {
        end_col = end_col,
        hl_group = "DotfilesIlluminateCurrent",
        priority = 220,
      })
      break
    end
    offset = math.max(end_col, offset + 1)
  end
end

local function schedule_current()
  clear_current()
  local pending = generation
  vim.defer_fn(function()
    if pending == generation and vim.api.nvim_get_current_buf() ~= 0 then
      highlight_current()
    end
  end, delay)
end

vim.api.nvim_create_autocmd({ "CursorMoved", "BufEnter" }, {
  group = vim.api.nvim_create_augroup("DotfilesIlluminateCursor", { clear = true }),
  callback = schedule_current,
})
vim.api.nvim_create_autocmd({ "InsertEnter", "BufLeave" }, {
  group = "DotfilesIlluminateCursor",
  callback = clear_current,
})
