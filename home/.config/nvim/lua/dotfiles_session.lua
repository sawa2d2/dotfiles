-- Keep session persistence separate from the rest of the Neovim configuration.
local M = {}

local function git_root(path)
  local output = vim.fn.systemlist({ "git", "-C", path, "rev-parse", "--show-toplevel" })
  if vim.v.shell_error == 0 and output[1] and output[1] ~= "" then
    return vim.fn.resolve(output[1])
  end
  return vim.fn.resolve(path)
end

local function focus_file(target, first)
  local resolved = vim.fn.resolve(target)
  for tab = 1, vim.fn.tabpagenr("$") do
    local buffers = vim.fn.tabpagebuflist(tab)
    for win, buffer in ipairs(buffers) do
      local name = vim.fn.bufname(buffer)
      if name ~= "" and vim.fn.resolve(vim.fn.fnamemodify(name, ":p")) == resolved then
        vim.cmd("tabnext " .. tab)
        vim.cmd(win .. "wincmd w")
        return
      end
    end
  end
  if first then
    vim.cmd("tabedit " .. vim.fn.fnameescape(target))
  else
    vim.cmd("vsplit " .. vim.fn.fnameescape(target))
  end
end

-- Session files can restore buffers after filetype detection has run.
local function restore_filetypes()
  for _, buffer in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_loaded(buffer)
      and vim.bo[buffer].buftype == ""
      and vim.api.nvim_buf_get_name(buffer) ~= ""
      and vim.bo[buffer].filetype == ""
    then
      local detected = vim.filetype.match({ buf = buffer })
      if detected and detected ~= "" then
        vim.bo[buffer].filetype = detected
      end
    end
  end
end

local function close_empty_first_tab()
  if vim.fn.tabpagenr("$") < 2 or vim.fn.tabpagewinnr(1, "$") ~= 1 then
    return
  end
  local buffer = vim.fn.tabpagebuflist(1)[1]
  if buffer
    and vim.fn.bufname(buffer) == ""
    and vim.bo[buffer].buftype == ""
    and not vim.bo[buffer].modified
  then
    vim.cmd("1tabclose")
  end
end

-- Session scripts do not persist tab-local variables. Append names after
-- persistence.nvim writes the session, so they share its lifecycle.
local function append_tab_names(session)
  local commands = {}
  for tab = 1, vim.fn.tabpagenr("$") do
    local name = vim.fn.gettabvar(tab, "dotfiles_tab_name", "")
    if name ~= "" then
      commands[#commands + 1] = string.format(
        "call settabvar(%d, 'dotfiles_tab_name', %s)",
        tab,
        vim.fn.string(name)
      )
    end
  end
  if #commands > 0 then
    vim.fn.writefile(commands, session, "a")
  end
end

function M.setup()
  local ok, persistence = pcall(require, "persistence")
  if not ok then
    return
  end

  local argc = vim.fn.argc()
  local startup_files = {}
  for i = 0, argc - 1 do
    if vim.fn.isdirectory(vim.fn.argv(i)) == 0 then
      startup_files[#startup_files + 1] = vim.fn.fnamemodify(vim.fn.argv(i), ":p")
    end
  end

  -- Use the first explicit file to identify the shared project session.
  local first_file = startup_files[1]
  local base = first_file and vim.fn.fnamemodify(first_file, ":h") or vim.fn.getcwd()
  local root = git_root(base)

  vim.opt.sessionoptions = { "curdir", "folds", "help", "tabpages", "winsize" }
  -- Ctrl-Q Ctrl-Q saves the current layout; ordinary quits preserve the last
  -- saved session without overwriting it.
  local keep_session = false
  local manage_session = true

  -- A PTY hangup can trigger the same exit events as :qa.
  -- Never delete a saved session as a side effect of quitting.
  vim.api.nvim_create_autocmd("VimLeavePre", {
    callback = function()
      if not manage_session then
        return
      end
      vim.cmd.cd(vim.fn.fnameescape(root))
      if not keep_session then
        -- Do not overwrite the last checkpoint on an ordinary exit or hangup.
        persistence.stop()
      end
    end,
  })

  -- Forgetting a session must be intentional, not inferred from exit events.
  vim.api.nvim_create_user_command("SessionForget", function()
    persistence.stop()
    vim.fn.delete(persistence.current())
  end, { desc = "Discard saved session for this project" })

  persistence.setup({
    dir = vim.fn.stdpath("state") .. "/dotfiles-persistence/",
    branch = false,
  })

  vim.keymap.set("n", "<C-q><C-q>", function()
    keep_session = true
    local ok, err = pcall(vim.cmd, "qa")
    if not ok then
      keep_session = false
      vim.notify(err, vim.log.levels.ERROR)
    end
  end, { silent = true, desc = "Save session and quit all" })

  vim.api.nvim_create_autocmd("User", {
    pattern = "PersistenceSavePost",
    callback = function()
      append_tab_names(persistence.current())
    end,
  })

  vim.api.nvim_create_autocmd("VimEnter", {
    once = true,
    callback = function()
      if vim.v.this_session ~= "" then
        manage_session = false
        persistence.stop()
        return
      end

      vim.cmd.cd(vim.fn.fnameescape(root))
      local saved_session = vim.fn.filereadable(persistence.current()) == 1
      persistence.load()
      vim.cmd.cd(vim.fn.fnameescape(root))

      -- With no saved session, preserve the editor's native -O layout.
      -- Otherwise restore the shared session and expose explicit files.
      if saved_session and first_file then
        for i, file in ipairs(startup_files) do
          focus_file(file, i == 1)
        end
      end
      close_empty_first_tab()
      restore_filetypes()
    end,
  })
end

return M
