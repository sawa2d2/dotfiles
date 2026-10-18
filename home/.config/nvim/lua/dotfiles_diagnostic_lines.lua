-- Highlight diagnostic lines and show messages only when the cursor rests on them.
local ns = vim.api.nvim_create_namespace("dotfiles_diagnostic_lines")
local message_ns = vim.api.nvim_create_namespace("dotfiles_diagnostic_message")
local severity = vim.diagnostic.severity
local is_visible = function(d)
  return d.severity == severity.ERROR or d.severity == severity.WARN
end

vim.diagnostic.config({
  virtual_text = false,
  virtual_lines = false,
  underline = false,
  signs = { severity = { min = severity.WARN } },
  update_in_insert = false,
})

local function colors()
  vim.api.nvim_set_hl(0, "DotDiagnosticLineError", { bg = "#39272b" })
  vim.api.nvim_set_hl(0, "DotDiagnosticLineWarn", { bg = "#393422" })
end

local function refresh(bufnr)
  if not vim.api.nvim_buf_is_valid(bufnr) then
    return
  end
  vim.api.nvim_buf_clear_namespace(bufnr, ns, 0, -1)
  local lines = {}
  for _, diagnostic in ipairs(vim.diagnostic.get(bufnr)) do
    if is_visible(diagnostic) then
      local line = diagnostic.lnum
      if not lines[line] or diagnostic.severity < lines[line] then
        lines[line] = diagnostic.severity
      end
    end
  end
  for line, level in pairs(lines) do
    if line < vim.api.nvim_buf_line_count(bufnr) then
      vim.api.nvim_buf_set_extmark(bufnr, ns, line, 0, {
        -- Use a low-priority range instead of line_hl_group so cursor-word
        -- highlights (vim-illuminate, priority 220) retain their foreground/background.
        end_row = line + 1,
        end_col = 0,
        hl_group = level == severity.ERROR and "DotDiagnosticLineError" or "DotDiagnosticLineWarn",
        hl_eol = true,
        priority = 10,
      })
    end
  end
end

colors()
local group = vim.api.nvim_create_augroup("DotfilesDiagnosticLines", { clear = true })
vim.api.nvim_create_autocmd("ColorScheme", { group = group, callback = colors })
vim.api.nvim_create_autocmd("DiagnosticChanged", {
  group = group,
  callback = function(event)
    refresh(event.buf)
  end,
})
vim.api.nvim_create_autocmd("BufEnter", {
  group = group,
  callback = function(event)
    refresh(event.buf)
  end,
})
-- Show the original subtle inline diagnostic text only on the cursor line.
local function show_cursor_message()
  local bufnr = vim.api.nvim_get_current_buf()
  if not vim.api.nvim_buf_is_valid(bufnr) then
    return
  end
  vim.api.nvim_buf_clear_namespace(bufnr, message_ns, 0, -1)
  if vim.bo[bufnr].buftype ~= "" or vim.api.nvim_get_mode().mode:sub(1, 1) == "i" then
    return
  end
  local line = vim.api.nvim_win_get_cursor(0)[1] - 1
  local messages = {}
  local level
  for _, diagnostic in ipairs(vim.diagnostic.get(bufnr, { lnum = line })) do
    if is_visible(diagnostic) then
      table.insert(messages, (diagnostic.message:gsub("%s*\\n%s*", " ")))
      if not level or diagnostic.severity < level then
        level = diagnostic.severity
      end
    end
  end
  if #messages > 0 then
    local col = #vim.api.nvim_buf_get_lines(bufnr, line, line + 1, false)[1]
    vim.api.nvim_buf_set_extmark(bufnr, message_ns, line, col, {
      virt_text = { { "    ■ " .. table.concat(messages, " | "), level == severity.ERROR and "DiagnosticVirtualTextError" or "DiagnosticVirtualTextWarn" } },
      virt_text_pos = "inline",
      priority = 90,
    })
  end
end

vim.api.nvim_create_autocmd({ "CursorMoved", "BufEnter", "InsertLeave", "DiagnosticChanged" }, {
  group = group,
  callback = function()
    show_cursor_message()
  end,
})
vim.api.nvim_create_autocmd("InsertEnter", {
  group = group,
  callback = function()
    vim.api.nvim_buf_clear_namespace(vim.api.nvim_get_current_buf(), message_ns, 0, -1)
  end,
})
