#!/usr/bin/env bash
set -euo pipefail
ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)
DIFFVIEW_PATH=${DIFFVIEW_PATH:-$HOME/.local/share/nvim/site/pack/dotfiles/start/diffview-nvim}
[[ -f "$DIFFVIEW_PATH/plugin/diffview.lua" ]] || { echo 'Set DIFFVIEW_PATH to a diffview.nvim checkout' >&2; exit 1; }
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
export ROOT DIFFVIEW_PATH TMP GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1
export XDG_STATE_HOME="$TMP/state" XDG_CACHE_HOME="$TMP/cache" XDG_DATA_HOME="$TMP/data"
git init -q -b main "$TMP/repo with spaces"
cd "$TMP/repo with spaces"
git config user.name Test
git config user.email test@example.com
mkdir sub
echo base > sub/shared
git add .
git commit -qm base
git switch -qc feature
echo feature > sub/shared
echo committed > branch-only
git add .
git commit -qm feature
git switch -q main
echo upstream > sub/shared
echo upstream > upstream-only
git add .
git commit -qm upstream
git switch -q feature
echo staged > staged-only
git add staged-only
echo working > sub/shared
echo untracked > untracked-only

cat > "$TMP/check.lua" <<'LUA'
local function check()
  vim.g.mapleader = " "
  vim.opt.rtp:prepend(vim.env.ROOT .. "/home/.config/nvim")
  local messages = {}
  vim.notify = function(message) messages[#messages + 1] = message end
  vim.keymap.set("n", "gd", "<cmd>echo 'definition'<cr>")
  local definition = vim.fn.maparg("gd", "n")
  dofile(vim.env.ROOT .. "/home/.config/nvim/plugin/diffview.lua")
  local function toggle()
    vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes(" gd", true, false, true), "xt", false)
  end
  if vim.env.MISSING_PLUGIN == "1" then
    toggle()
    assert(messages[#messages]:find("diffview.nvim is unavailable", 1, true))
    return
  end
  vim.opt.rtp:append(vim.env.DIFFVIEW_PATH)
  dofile(vim.env.DIFFVIEW_PATH .. "/plugin/diffview.lua")
  vim.cmd("edit " .. vim.fn.fnameescape(vim.env.TMP .. "/repo with spaces/sub/shared"))
  vim.api.nvim_buf_set_lines(0, 0, -1, false, { "unsaved" })
  local buffer = vim.api.nvim_get_current_buf()
  vim.cmd("vsplit")
  vim.cmd("tabnew")
  vim.cmd("tabprevious")
  local tab, win = vim.api.nvim_get_current_tabpage(), vim.api.nvim_get_current_win()
  local tabs, windows = vim.api.nvim_list_tabpages(), vim.api.nvim_tabpage_list_wins(tab)
  local function restored()
    assert(vim.deep_equal(tabs, vim.api.nvim_list_tabpages()), "tabs changed")
    assert(vim.deep_equal(windows, vim.api.nvim_tabpage_list_wins(tab)), "splits changed")
    assert(vim.api.nvim_get_current_win() == win, "wrong return window")
    assert(vim.bo[buffer].modified and vim.api.nvim_buf_get_lines(buffer, 0, -1, false)[1] == "unsaved")
  end
  local function visible_text()
    local lines = {}
    for _, w in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
      vim.list_extend(lines, vim.api.nvim_buf_get_lines(vim.api.nvim_win_get_buf(w), 0, -1, false))
    end
    return table.concat(lines, "\n")
  end
  for _ = 1, 2 do
    toggle()
    assert(#vim.api.nvim_list_tabpages() == #tabs + 1, "diff tab did not open")
    assert(vim.wait(10000, function()
      local text = "\n" .. visible_text() .. "\n"
      return text:find("branch%-only")
        and (text:find("\ncommitted\n", 1, true) or text:find("\nfeature\n", 1, true))
    end, 20), "diff buffers did not load")
    local text = visible_text()
    assert(not text:find("upstream%-only") and not text:find("staged%-only") and not text:find("untracked%-only"), text)
    -- Select the shared file through Diffview's public command/path interface
    -- below to verify the actual displayed merge-base and HEAD contents.
    toggle()
    restored()
  end
  vim.cmd("DiffviewOpen main...HEAD -- sub/shared")
  assert(vim.wait(10000, function()
    local text = "\n" .. visible_text() .. "\n"
    return text:find("\nbase\n", 1, true) and text:find("\nfeature\n", 1, true)
  end, 20), "expected merge-base and committed HEAD contents")
  assert(not visible_text():find("working", 1, true) and not visible_text():find("unsaved", 1, true))
  vim.cmd("DiffviewClose")
  -- Direct commands retain Diffview's own return-tab behavior.
  vim.api.nvim_set_current_win(win)
  restored()
  vim.cmd("DiffviewOpen HEAD~1..HEAD")
  assert(#vim.api.nvim_list_tabpages() == #tabs + 1, "explicit comparison failed")
  assert(vim.wait(10000, function()
    local text = "\n" .. visible_text() .. "\n"
    return text:find("\ncommitted\n", 1, true) or text:find("\nfeature\n", 1, true)
  end, 20), "explicit comparison did not load")
  toggle()
  vim.api.nvim_set_current_win(win)
  restored()
  vim.fn.system({ "git", "branch", "-m", "main", "other" })
  assert(vim.v.shell_error == 0)
  toggle()
  assert(messages[#messages]:find("local main branch is missing", 1, true))
  restored()
  vim.cmd("tabnew")
  vim.cmd("cd " .. vim.fn.fnameescape(vim.env.TMP))
  toggle()
  assert(messages[#messages]:find("not in a Git working tree", 1, true))
  assert(vim.fn.maparg("gd", "n") == definition, "plain gd was overridden")
end
local ok, err = xpcall(check, debug.traceback)
if not ok then
  io.stderr:write(err .. "\n")
  vim.cmd("cquit 1")
end
vim.cmd("qa!")
LUA
MISSING_PLUGIN=1 nvim --headless -u NONE -i NONE -n -l "$TMP/check.lua"
nvim --headless -u NONE -i NONE -n -l "$TMP/check.lua"
echo 'PASS: Neovim Git diff comparison, toggle preservation, explicit bases and errors'
