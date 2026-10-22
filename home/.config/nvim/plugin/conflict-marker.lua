-- Resolve Git conflicts in place (VS Code-like): ]x / [x move between
-- conflicts; co, ct, cb, cB and cn keep ours, theirs, both or neither.
-- Packages load after this file, so the option below is seen by the plugin.

-- Color the sections instead of linking only the marker lines to Error.
vim.g.conflict_marker_highlight_group = ""

local function apply_highlights()
  local set = vim.api.nvim_set_hl
  set(0, "ConflictMarkerBegin", { bg = "#2E6B47", bold = true })
  set(0, "ConflictMarkerOurs", { bg = "#143724" })
  set(0, "ConflictMarkerCommonAncestors", { bg = "#5B3F7A", bold = true })
  set(0, "ConflictMarkerCommonAncestorsHunk", { bg = "#2E2440" })
  set(0, "ConflictMarkerSeparator", { bg = "#45475A", bold = true })
  set(0, "ConflictMarkerTheirs", { bg = "#1E3A5F" })
  set(0, "ConflictMarkerEnd", { bg = "#2F5A8F", bold = true })
end

apply_highlights()
vim.api.nvim_create_autocmd("ColorScheme", {
  group = vim.api.nvim_create_augroup("DotfilesConflictMarkerColors", { clear = true }),
  callback = apply_highlights,
})
