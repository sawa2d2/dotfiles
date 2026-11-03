-- Keep terminal Neovim in an ASCII input mode outside Insert mode.
-- Requires macism (macOS), fcitx5-remote or ibus (Linux); otherwise does nothing.
local backend
-- For source-based backends: the command that prints the current source and
-- sets it when given one, and the default ASCII source.
local source_cmd, default_ascii_source

if vim.fn.has("mac") == 1 and vim.fn.executable("macism") == 1 then
  backend = "source"
  source_cmd = { "macism" }
  default_ascii_source = "com.apple.keylayout.ABC"
elseif vim.fn.has("unix") == 1 and vim.fn.executable("fcitx5-remote") == 1 then
  backend = "fcitx5"
elseif vim.fn.has("unix") == 1 and vim.fn.executable("ibus") == 1 then
  backend = "source"
  source_cmd = { "ibus", "engine" }
  default_ascii_source = "xkb:jp::jpn"
end

if not backend then
  return
end

local saved_source

local function run(args)
  local result = vim.fn.system(args)
  if vim.v.shell_error ~= 0 then
    return nil
  end
  return vim.trim(result)
end

local function leave_insert()
  if backend == "source" then
    -- Read at use time so the option can be set after this file loads.
    local ascii_source = vim.g.dotfiles_ime_ascii_source or default_ascii_source
    local source = run(source_cmd)
    if not source or source == "" or source == ascii_source then
      saved_source = nil
      return
    end
    -- Only restore a source that was successfully switched away from.
    if run(vim.list_extend(vim.deepcopy(source_cmd), { ascii_source })) ~= nil then
      saved_source = source
    else
      saved_source = nil
    end
  else
    local status = run({ "fcitx5-remote" })
    if status == "2" then
      if run({ "fcitx5-remote", "-c" }) ~= nil then
        saved_source = "active"
      else
        saved_source = nil
      end
    else
      saved_source = nil
    end
  end
end

local function enter_insert()
  if not saved_source then
    return
  end

  local source = saved_source
  saved_source = nil
  if backend == "source" then
    run(vim.list_extend(vim.deepcopy(source_cmd), { source }))
  elseif source == "active" then
    run({ "fcitx5-remote", "-o" })
  end
end

local group = vim.api.nvim_create_augroup("DotfilesImeSwitch", { clear = true })
vim.api.nvim_create_autocmd("InsertLeave", { group = group, callback = leave_insert })
vim.api.nvim_create_autocmd("InsertEnter", { group = group, callback = enter_insert })
