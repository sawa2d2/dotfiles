-- Provide per-buffer diagnostics to the shared Vim statusline.
local M = {}

function M.counts(bufnr)
  local errors, warnings = 0, 0
  for _, diagnostic in ipairs(vim.diagnostic.get(bufnr)) do
    if diagnostic.severity == vim.diagnostic.severity.ERROR then
      errors = errors + 1
    elseif diagnostic.severity == vim.diagnostic.severity.WARN then
      warnings = warnings + 1
    end
  end
  return { errors, warnings }
end

vim.api.nvim_create_autocmd("DiagnosticChanged", {
  group = vim.api.nvim_create_augroup("DotfilesStatusDiagnostics", { clear = true }),
  callback = function()
    vim.cmd("redrawstatus!")
    vim.cmd("redrawtabline")
  end,
})

return M
