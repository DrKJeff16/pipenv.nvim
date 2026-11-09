---@module 'pipenv._meta'
---@module 'spinner'

local Util = require('pipenv.util')
local Config = require('pipenv.config')
local ERROR = vim.log.levels.ERROR
local WARN = vim.log.levels.WARN
local INFO = vim.log.levels.INFO

local stdout, stderr = {}, {} ---@type string[], string[]
local spinner = nil ---@type PipenvSpinner|nil|?
local ec = -1 ---@type integer

---@return boolean spinner
local function has_spinner()
  local config = Config.get()
  return Util.mod_exists('spinner') and config.spinner and config.spinner.enabled
end

---@param cmd string[]
---@param on_exit fun(code: integer, out: string, err: string)
---@param opts? Pipenv.CmdOpts
local function run_cmd(cmd, on_exit, opts)
  Util.validate({
    cmd = { cmd, { 'table' } },
    opts = { opts, { 'table', 'nil' }, true },
  })
  opts = opts or {}

  Util.validate({
    ['opts.cwd'] = { opts.cwd, { 'string', 'nil' }, true },
    ['opts.env'] = { opts.env, { 'table', 'nil' }, true },
  })
  opts.cwd = opts.cwd or vim.uv.cwd() or vim.fn.getcwd()
  local env = Config.get_env()
  if env and not vim.tbl_isempty(env) then
    opts.env = vim.tbl_deep_extend('keep', opts.env or {}, env)
  end

  stdout, stderr = {}, {}
  local job = require('job')
  if has_spinner() then
    spinner = require('pipenv.spinner').new(
      table.concat(cmd, ' '),
      vim.tbl_deep_extend('keep', Config.get().spinner.opts, { kind = 'cursor' })
    )
    if spinner then
      spinner:start()
    end
  end
  local jobid = job.start(cmd, {
    env = opts.env,
    cwd = opts.cwd,
    on_stdout = function(_, data)
      table.insert(stdout, table.concat(data, '\n'))
    end,
    on_stderr = function(_, data)
      table.insert(stderr, table.concat(data, '\n'))
    end,
    on_exit = function(_, code)
      if has_spinner() and spinner then
        spinner:stop()
      end

      on_exit(code, table.concat(stdout, '\n'), table.concat(stderr, '\n'))
    end,
  })

  if vim.list_contains({ 0, -1, -2 }, jobid) then
    if has_spinner() and spinner then
      spinner:stop()
    end
    vim.notify(('Error while executing `%s`!'):format(table.concat(cmd, ' ')), ERROR)
  end
end

---@param create boolean
---@return boolean pipfile
---@overload fun(): pipfile: boolean
local function has_pipfile(create)
  Util.validate({ create = { create, { 'boolean', 'nil' }, true } })
  if create == nil then
    create = false
  end

  local pipfile = true
  if not vim.fn.filereadable('./Pipfile') then
    if not (create and Util.yes_no('No Pipfile found. Create?')) then
      vim.notify('No Pipfile found', ERROR)
      pipfile = false
    else
      ec = -1
      run_cmd({ 'pipenv', 'install' }, function(code, out, err)
        ec = code
        local txt = code ~= 1 and out or err
        if txt ~= '' then
          local config = Config.get()
          Util.open_win(txt, {
            border = config.output.border,
            float = config.output.float,
            height = config.output.height,
            split = config.output.split,
            title = 'pipenv install',
            width = config.output.width,
            zindex = config.output.zindex,
          })
        end
      end)
      pipfile = ec == 0
    end
  end
  return pipfile
end

---@class Pipenv.Core
local M = {}

function M.edit()
  assert(vim.g.pipenv_setup == 1, 'pipenv.nvim is not configured')
  assert(has_pipfile(true), 'No `Pipfile` could be created in the current working directory')

  vim.cmd.tabedit({ args = { './Pipfile' } })
  vim.schedule(function()
    local bufnr = vim.api.nvim_get_current_buf()
    local tab = vim.api.nvim_get_current_tabpage()
    vim.keymap.set('n', 'q', function()
      pcall(vim.api.nvim_buf_delete, bufnr, { force = true })
      pcall(vim.api.nvim_cmd, { cmd = 'tabclose', range = { tab } }, { output = false })
    end, { buffer = bufnr })
  end)
end

---@return string[]|nil|? res
function M.retrieve_scripts()
  assert(vim.g.pipenv_setup == 1, 'pipenv.nvim is not configured')
  assert(has_pipfile(), 'No `Pipfile` in the current working directory')

  local stat = vim.uv.fs_stat('Pipfile')
  if not stat or stat.size == 0 then
    return
  end
  local fd = vim.uv.fs_open('Pipfile', 'r', tonumber('644', 8))
  if not fd then
    return
  end

  local data = assert(vim.uv.fs_read(fd, stat.size), 'Unable to read data from Pipfile')
  assert(vim.uv.fs_close(fd), 'Unable to close file descriptor')

  local l_data = vim.split(data, '\n', { plain = true, trimempty = false })
  local res, scripts = {}, false ---@type string[], boolean
  for _, line in ipairs(l_data) do
    if vim.startswith(line, '[scripts]') and not scripts then
      scripts = true
    elseif scripts then
      if vim.startswith(line, '[') then
        break
      end
      local split_line = vim.split(line, ' ', { plain = true, trimempty = false })
      if #split_line >= 3 and split_line[2] == '=' then
        table.insert(res, split_line[1])
      end
    end
  end

  return res
end

---@return string[] installed
function M.retrieve_installed()
  local installed = {} ---@type string[]
  run_cmd({ 'pipenv', 'graph', '--json' }, function(code, out, err)
    assert(code == 0 and out and out ~= '', (err and err ~= '') and err or 'Could not parse JSON graph')

    ---@type boolean, PipenvJsonGraph[]|nil|?
    local ok, data = pcall(vim.json.decode, Util.trim_output(out))
    assert(ok and data, 'Could not parse JSON graph')

    for _, pkg in ipairs(data) do
      if pkg.package.package_name and not vim.list_contains(installed, pkg.package.package_name) then
        table.insert(installed, pkg.package.package_name)
      end
    end
  end)
  return installed
end

---@param opts? Pipenv.RemoveOpts
---@param cmd_opts? Pipenv.CommandOpts
function M.remove(opts, cmd_opts)
  assert(vim.g.pipenv_setup == 1, 'pipenv.nvim is not configured')
  assert(has_pipfile(false), 'No `Pipfile` in the current working directory')

  Util.validate({
    opts = { opts, { 'table', 'nil' }, true },
    cmd_opts = { cmd_opts, { 'table', 'nil' }, true },
  })
  opts = opts or {}
  cmd_opts = cmd_opts or {}

  Util.validate({ verbose = { opts.verbose, { 'boolean', 'nil' }, true } })
  if opts.verbose == nil then
    opts.verbose = false
  end

  -- Treat as `force` for compatibility with other commands
  if not opts.verbose then
    if not Util.yes_no('Remove current Pipenv environment?') then
      return
    end
  end

  local cmd1 = { 'pipenv', '--rm' }
  run_cmd(cmd1, function(code, out, err)
    local cmd_str = table.concat(cmd1, ' ')
    local txt = code ~= 1 and out or err
    if txt ~= '' then
      local config = Config.get()
      Util.open_win(txt, {
        border = config.output.border,
        float = config.output.float,
        height = config.output.height,
        split = config.output.split,
        title = cmd_str,
        width = config.output.width,
        zindex = config.output.zindex,
      })
      return
    end
    vim.notify(('%s - No output'):format(cmd_str), INFO)
  end, cmd_opts)

  if not opts.verbose then
    if not Util.yes_no('Remove Pipfile and Pipfile.lock?') then
      return
    end
  end

  run_cmd({ 'rm', '-f', 'Pipenv', 'Pipenv.lock' }, function() end, cmd_opts)
end

function M.list_installed()
  assert(vim.g.pipenv_setup == 1, 'pipenv.nvim is not configured')
  assert(has_pipfile(), 'No `Pipfile` in the current working directory')

  local installed = M.retrieve_installed()
  assert(#installed > 0, 'No installed scripts found')

  local config = Config.get()
  Util.open_win(table.concat(installed, '\n'), {
    border = config.output.border,
    float = config.output.float,
    height = 0.7,
    split = config.output.split,
    title = 'Installed Packages',
    width = 0.4,
    zindex = config.output.zindex,
  })
end

function M.list_scripts()
  assert(vim.g.pipenv_setup == 1, 'pipenv.nvim is not configured')
  assert(has_pipfile(), 'No `Pipfile` in the current working directory')

  local data = assert(M.retrieve_scripts(), 'Unable to retrieve scripts from Pipfile')
  assert(#data > 0, 'No scripts in Pipfile')

  local config = Config.get()
  Util.open_win(table.concat(data, '\n'), {
    border = config.output.border,
    float = config.output.float,
    height = 0.4,
    split = config.output.split,
    title = 'Scripts',
    width = 0.3,
    zindex = config.output.zindex,
  })
end

---@param opts? Pipenv.GraphOpts
---@param cmd_opts? Pipenv.CommandOpts
function M.graph(opts, cmd_opts)
  assert(vim.g.pipenv_setup == 1, 'pipenv.nvim is not configured')
  assert(has_pipfile(), 'No `Pipfile` in the current working directory')

  Util.validate({
    opts = { opts, { 'table', 'nil' }, true },
    cmd_opts = { cmd_opts, { 'table', 'nil' }, true },
  })
  opts = opts or {}
  cmd_opts = cmd_opts or {}

  Util.validate({ python = { opts.python, { 'string', 'nil' }, true } })
  opts.python = opts.python or nil

  local cmd = { 'pipenv' }
  if opts.python and opts.python ~= '' then
    vim.list_extend(cmd, { '--python', opts.python })
  end
  table.insert(cmd, 'graph')

  run_cmd(cmd, function(code, out, err)
    local cmd_str = table.concat(cmd, ' ')
    err = (err and err ~= '') and err or ('Error when running `%s`'):format(cmd_str)

    if code ~= 0 then
      vim.notify(err, ERROR)
      return
    end
    if out and out ~= '' then
      local config = Config.get()
      Util.open_win(Util.trim_output(out), {
        border = config.output.border,
        float = config.output.float,
        height = config.output.height,
        split = config.output.split,
        title = cmd_str,
        width = config.output.width,
        zindex = config.output.zindex,
      })
      return
    end
    vim.notify(('(%s): No output given!'):format(cmd_str), INFO)
  end, cmd_opts)
end

---@param opts? Pipenv.LockOpts
---@param cmd_opts? Pipenv.CommandOpts
function M.lock(opts, cmd_opts)
  Util.validate({
    opts = { opts, { 'table', 'nil' }, true },
    cmd_opts = { cmd_opts, { 'table', 'nil' }, true },
  })
  opts = opts or {}
  cmd_opts = cmd_opts or {}

  Util.validate({
    dev = { opts.dev, { 'boolean', 'nil' }, true },
    pre = { opts.pre, { 'boolean', 'nil' }, true },
    python = { opts.python, { 'string', 'nil' }, true },
    verbose = { opts.verbose, { 'boolean', 'nil' }, true },
  })
  if opts.dev == nil then
    opts.dev = false
  end
  if opts.pre == nil then
    opts.pre = false
  end
  if opts.verbose == nil then
    opts.verbose = false
  end
  opts.python = opts.python or nil

  local cmd = { 'pipenv' }
  if opts.python and opts.python ~= '' then
    vim.list_extend(cmd, { '--python', opts.python })
  end
  if opts.dev then
    table.insert(cmd, '--dev')
  end
  if opts.pre then
    table.insert(cmd, '--pre')
  end
  table.insert(cmd, 'lock')

  run_cmd(cmd, function(code, out, err)
    local cmd_str = table.concat(cmd, ' ')
    err = (err and err ~= '') and err or ('Error when running `%s`'):format(cmd_str)
    assert(code == 0, err)

    if not opts.verbose then
      return
    end
    if out and out ~= '' then
      local config = Config.get()
      Util.open_win(Util.trim_output(out), {
        title = cmd_str,
        border = config.output.border,
        float = config.output.float,
        height = config.output.height,
        split = config.output.split,
        width = config.output.width,
        zindex = config.output.zindex,
      })
      return
    end
    vim.notify(('(%s): No output given!'):format(cmd_str), INFO)
  end, cmd_opts)
end

---@param opts? Pipenv.CleanOpts
---@param cmd_opts? Pipenv.CommandOpts
function M.clean(opts, cmd_opts)
  assert(vim.g.pipenv_setup == 1, 'pipenv.nvim is not configured')
  assert(has_pipfile(), 'No `Pipfile` in the current working directory')

  Util.validate({
    opts = { opts, { 'table', 'nil' }, true },
    cmd_opts = { cmd_opts, { 'table', 'nil' }, true },
  })
  opts = opts or {}
  cmd_opts = cmd_opts or {}

  Util.validate({
    python = { opts.python, { 'string', 'nil' }, true },
    verbose = { opts.verbose, { 'boolean', 'nil' }, true },
  })
  if opts.verbose == nil then
    opts.verbose = false
  end
  opts.python = opts.python or nil

  local cmd = { 'pipenv' }
  if opts.python and opts.python ~= '' then
    vim.list_extend(cmd, { '--python', opts.python })
  end
  table.insert(cmd, 'clean')

  run_cmd(cmd, function(code, out, err)
    local cmd_str = table.concat(cmd, ' ')
    err = (err and err ~= '') and err or ('Error when running `%s`'):format(cmd_str)
    assert(code == 0, err)

    if not opts.verbose then
      return
    end
    if out and out ~= '' then
      local config = Config.get()
      Util.open_win(Util.trim_output(out), {
        title = cmd_str,
        border = config.output.border,
        float = config.output.float,
        height = config.output.height,
        split = config.output.split,
        width = config.output.width,
        zindex = config.output.zindex,
      })
      return
    end
    vim.notify(('(%s): No output given!'):format(cmd_str), INFO)
  end, cmd_opts)
end

---@param opts? Pipenv.VerifyOpts
---@param cmd_opts? Pipenv.CommandOpts
function M.verify(opts, cmd_opts)
  assert(vim.g.pipenv_setup == 1, 'pipenv.nvim is not configured')
  assert(has_pipfile(), 'No `Pipfile` in the current working directory')

  Util.validate({
    opts = { opts, { 'table', 'nil' }, true },
    cmd_opts = { cmd_opts, { 'table', 'nil' }, true },
  })
  opts = opts or {}
  cmd_opts = cmd_opts or {}

  Util.validate({
    python = { opts.python, { 'string', 'nil' }, true },
    verbose = { opts.verbose, { 'boolean', 'nil' }, true },
  })
  if opts.verbose == nil then
    opts.verbose = false
  end
  opts.python = opts.python or nil

  local cmd = { 'pipenv' }
  if opts.python and opts.python ~= '' then
    vim.list_extend(cmd, { '--python', opts.python })
  end
  table.insert(cmd, 'verify')

  run_cmd(cmd, function(code, out, err)
    local cmd_str = table.concat(cmd, ' ')
    err = (err and err ~= '') and err or ('Error when running `%s`'):format(cmd_str)
    assert(code == 0, err)

    if not opts.verbose then
      return
    end
    if out and out ~= '' then
      local config = Config.get()
      Util.open_win(Util.trim_output(out), {
        title = cmd_str,
        border = config.output.border,
        float = config.output.float,
        height = config.output.height,
        split = config.output.split,
        width = config.output.width,
        zindex = config.output.zindex,
      })
      return
    end
    vim.notify(('(%s): No output given!'):format(cmd_str), INFO)
  end, cmd_opts)
end

---@param opts? Pipenv.SyncOpts
---@param cmd_opts? Pipenv.CommandOpts
function M.sync(opts, cmd_opts)
  assert(vim.g.pipenv_setup == 1, 'pipenv.nvim is not configured')
  assert(has_pipfile(), 'No `Pipfile` in the current working directory')

  Util.validate({
    opts = { opts, { 'table', 'nil' }, true },
    cmd_opts = { cmd_opts, { 'table', 'nil' }, true },
  })
  opts = opts or {}
  cmd_opts = cmd_opts or {}

  Util.validate({
    dev = { opts.dev, { 'boolean', 'nil' }, true },
    pre = { opts.pre, { 'boolean', 'nil' }, true },
    python = { opts.python, { 'string', 'nil' }, true },
    verbose = { opts.verbose, { 'boolean', 'nil' }, true },
  })
  if opts.dev == nil then
    opts.dev = false
  end
  if opts.pre == nil then
    opts.pre = false
  end
  if opts.verbose == nil then
    opts.verbose = false
  end
  opts.python = opts.python or nil

  local cmd = { 'pipenv' }
  if opts.python and opts.python ~= '' then
    vim.list_extend(cmd, { '--python', opts.python })
  end
  table.insert(cmd, 'sync')
  if opts.dev then
    table.insert(cmd, '--dev')
  end
  if opts.pre then
    table.insert(cmd, '--pre')
  end

  run_cmd(cmd, function(code, out, err)
    local cmd_str = table.concat(cmd, ' ')
    err = (err and err ~= '') and err or ('Error when running `%s`'):format(cmd_str)
    assert(code == 0, err)

    if not opts.verbose then
      return
    end
    if out and out ~= '' then
      local config = Config.get()
      Util.open_win(Util.trim_output(out), {
        title = cmd_str,
        border = config.output.border,
        float = config.output.float,
        height = config.output.height,
        split = config.output.split,
        width = config.output.width,
        zindex = config.output.zindex,
      })
      return
    end
    vim.notify(('(%s): No output given!'):format(cmd_str), INFO)
  end, cmd_opts)
end

---@param opts? Pipenv.UpgradeOpts
---@param cmd_opts? Pipenv.CommandOpts
function M.update(opts, cmd_opts)
  assert(vim.g.pipenv_setup == 1, 'pipenv.nvim is not configured')
  assert(has_pipfile(), 'No `Pipfile` in the current working directory')

  Util.validate({
    opts = { opts, { 'table', 'nil' }, true },
    cmd_opts = { cmd_opts, { 'table', 'nil' }, true },
  })
  opts = opts or {}
  cmd_opts = cmd_opts or {}

  Util.validate({
    dev = { opts.dev, { 'boolean', 'nil' }, true },
    pre = { opts.pre, { 'boolean', 'nil' }, true },
    python = { opts.python, { 'string', 'nil' }, true },
    verbose = { opts.verbose, { 'boolean', 'nil' }, true },
  })
  if opts.dev == nil then
    opts.dev = false
  end
  if opts.pre == nil then
    opts.pre = false
  end
  if opts.verbose == nil then
    opts.verbose = false
  end
  opts.python = opts.python or nil

  local cmd = { 'pipenv' }
  if opts.python and opts.python ~= '' then
    vim.list_extend(cmd, { '--python', opts.python })
  end
  table.insert(cmd, 'update')
  if opts.dev then
    table.insert(cmd, '--dev')
  end
  if opts.pre then
    table.insert(cmd, '--pre')
  end

  run_cmd(cmd, function(code, out, err)
    local cmd_str = table.concat(cmd, ' ')
    err = (err and err ~= '') and err or ('Error when running `%s`'):format(cmd_str)
    assert(code == 0, err)

    if not opts.verbose then
      return
    end
    if out and out ~= '' then
      local config = Config.get()
      Util.open_win(Util.trim_output(out), {
        border = config.output.border,
        float = config.output.float,
        height = config.output.height,
        split = config.output.split,
        title = cmd_str,
        width = config.output.width,
        zindex = config.output.zindex,
      })
      return
    end
    vim.notify(('(%s): No output given!'):format(cmd_str), INFO)
  end, cmd_opts)
end

---@param opts? Pipenv.UpgradeOpts
---@param cmd_opts? Pipenv.CommandOpts
function M.upgrade(opts, cmd_opts)
  assert(vim.g.pipenv_setup == 1, 'pipenv.nvim is not configured')
  assert(has_pipfile(), 'No `Pipfile` in the current working directory')

  Util.validate({
    opts = { opts, { 'table', 'nil' }, true },
    cmd_opts = { cmd_opts, { 'table', 'nil' }, true },
  })
  opts = opts or {}
  cmd_opts = cmd_opts or {}

  Util.validate({
    dev = { opts.dev, { 'boolean', 'nil' }, true },
    pre = { opts.pre, { 'boolean', 'nil' }, true },
    python = { opts.python, { 'string', 'nil' }, true },
    verbose = { opts.verbose, { 'boolean', 'nil' }, true },
  })
  if opts.dev == nil then
    opts.dev = false
  end
  if opts.pre == nil then
    opts.pre = false
  end
  if opts.verbose == nil then
    opts.verbose = false
  end
  opts.python = opts.python or nil

  local cmd = { 'pipenv' }
  if opts.python and opts.python ~= '' then
    vim.list_extend(cmd, { '--python', opts.python })
  end
  table.insert(cmd, 'upgrade')
  if opts.dev then
    table.insert(cmd, '--dev')
  end
  if opts.pre then
    table.insert(cmd, '--pre')
  end

  run_cmd(cmd, function(code, out, err)
    local cmd_str = table.concat(cmd, ' ')
    err = (err and err ~= '') and err or ('Error when running `%s`'):format(cmd_str)
    assert(code == 0, err)

    if not opts.verbose then
      return
    end
    if out and out ~= '' then
      local config = Config.get()
      Util.open_win(Util.trim_output(out), {
        border = config.output.border,
        float = config.output.float,
        height = config.output.height,
        split = config.output.split,
        title = cmd_str,
        width = config.output.width,
        zindex = config.output.zindex,
      })
      return
    end
    vim.notify(('(%s): No output given!'):format(cmd_str), INFO)
  end, cmd_opts)
end

---@param opts? Pipenv.ScriptsOpts
---@param cmd_opts? Pipenv.CommandOpts
function M.scripts(opts, cmd_opts)
  assert(vim.g.pipenv_setup == 1, 'pipenv.nvim is not configured')
  assert(has_pipfile(), 'No `Pipfile` in the current working directory')

  Util.validate({
    opts = { opts, { 'table', 'nil' }, true },
    cmd_opts = { cmd_opts, { 'table', 'nil' }, true },
  })
  opts = opts or {}
  cmd_opts = cmd_opts or {}

  Util.validate({ python = { opts.python, { 'string', 'nil' }, true } })
  opts.python = opts.python or nil

  local cmd = { 'pipenv' }
  if opts.python and opts.python ~= '' then
    vim.list_extend(cmd, { '--python', opts.python })
  end
  table.insert(cmd, 'scripts')

  run_cmd(cmd, function(code, out, err)
    local cmd_str = table.concat(cmd, ' ')
    err = (err and err ~= '') and err or ('Error when running `%s`'):format(cmd_str)
    assert(code == 0, err)

    if out and out ~= '' then
      local config = Config.get()
      Util.open_win(Util.trim_output(out), {
        border = config.output.border,
        float = config.output.float,
        height = config.output.height,
        split = config.output.split,
        title = cmd_str,
        width = config.output.width,
        zindex = config.output.zindex,
      })
      return
    end
    vim.notify(('(%s): No output given!'):format(cmd_str), INFO)
  end, cmd_opts)
end

---@param packages? string[]|string
---@param opts? Pipenv.InstallOpts
---@param cmd_opts? Pipenv.CommandOpts
function M.install(packages, opts, cmd_opts)
  assert(vim.g.pipenv_setup == 1, 'pipenv.nvim is not configured')

  Util.validate({
    packages = { packages, { 'string', 'table', 'nil' }, true },
    opts = { opts, { 'table', 'nil' }, true },
    cmd_opts = { cmd_opts, { 'table', 'nil' }, true },
  })
  packages = packages or nil
  opts = opts or {}
  cmd_opts = cmd_opts or {}

  Util.validate({
    dev = { opts.dev, { 'boolean', 'nil' }, true },
    pre = { opts.pre, { 'boolean', 'nil' }, true },
    python = { opts.python, { 'string', 'nil' }, true },
    verbose = { opts.verbose, { 'boolean', 'nil' }, true },
  })
  if opts.dev == nil then
    opts.dev = false
  end
  if opts.pre == nil then
    opts.pre = false
  end
  if opts.verbose == nil then
    opts.verbose = false
  end
  opts.python = opts.python or nil

  local cmd = { 'pipenv' }
  if opts.python and opts.python ~= '' then
    vim.list_extend(cmd, { '--python', opts.python })
  end
  table.insert(cmd, 'install')
  if opts.dev then
    table.insert(cmd, '--dev')
  end
  if opts.pre then
    table.insert(cmd, '--pre')
  end

  if packages and type(packages) == 'string' then
    table.insert(cmd, packages)
  elseif packages and type(packages) == 'table' then
    for _, pkg in ipairs(packages) do
      if type(pkg) == 'string' and pkg ~= '' then
        table.insert(cmd, pkg)
      end
    end
  end

  run_cmd(cmd, function(code, out, err)
    local cmd_str = table.concat(cmd, ' ')
    err = (err and err ~= '') and err or ('Error when running `%s`'):format(cmd_str)
    assert(code == 0, err)

    if not opts.verbose then
      return
    end
    if out and out ~= '' then
      local config = Config.get()
      Util.open_win(Util.trim_output(out), {
        border = config.output.border,
        float = config.output.float,
        height = config.output.height,
        split = config.output.split,
        title = cmd_str,
        width = config.output.width,
        zindex = config.output.zindex,
      })
      return
    end
    vim.notify(('(%s): No output given!'):format(cmd_str), INFO)
  end, cmd_opts)
end

---@param packages string[]|string
---@param opts? Pipenv.UninstallOpts
---@param cmd_opts? Pipenv.CommandOpts
function M.uninstall(packages, opts, cmd_opts)
  assert(vim.g.pipenv_setup == 1, 'pipenv.nvim is not configured')
  assert(has_pipfile(), 'No `Pipfile` in the current working directory')

  Util.validate({
    packages = { packages, { 'string', 'table' } },
    opts = { opts, { 'table', 'nil' }, true },
    cmd_opts = { cmd_opts, { 'table', 'nil' }, true },
  })
  opts = opts or {}
  cmd_opts = cmd_opts or {}

  Util.validate({
    dev = { opts.dev, { 'boolean', 'nil' }, true },
    pre = { opts.pre, { 'boolean', 'nil' }, true },
    python = { opts.python, { 'string', 'nil' }, true },
    verbose = { opts.verbose, { 'boolean', 'nil' }, true },
  })
  if opts.dev == nil then
    opts.dev = false
  end
  if opts.pre == nil then
    opts.pre = false
  end
  if opts.verbose == nil then
    opts.verbose = false
  end
  opts.python = opts.python or nil

  local cmd = { 'pipenv' }
  if opts.python and opts.python ~= '' then
    vim.list_extend(cmd, { '--python', opts.python })
  end
  table.insert(cmd, 'uninstall')
  if opts.dev then
    table.insert(cmd, '--dev')
  end
  if opts.pre then
    table.insert(cmd, '--pre')
  end
  if type(packages) == 'string' then
    table.insert(cmd, packages)
  else
    assert(#packages > 0, 'Empty packages table')
    for _, pkg in ipairs(packages) do
      if type(pkg) == 'string' and pkg ~= '' then
        table.insert(cmd, pkg)
      end
    end
  end

  run_cmd(cmd, function(code, out, err)
    local cmd_str = table.concat(cmd, ' ')
    err = (err and err ~= '') and err or ('Error when running `%s`'):format(cmd_str)
    assert(code == 0, err)

    if not opts.verbose then
      return
    end
    if out and out ~= '' then
      local config = Config.get()
      Util.open_win(Util.trim_output(out), {
        border = config.output.border,
        float = config.output.float,
        height = config.output.height,
        split = config.output.split,
        title = cmd_str,
        width = config.output.width,
        zindex = config.output.zindex,
      })
      return
    end
    vim.notify(('(%s): No output given!'):format(cmd_str), INFO)
  end, cmd_opts)
end

---@param command string[]|string
---@param opts? Pipenv.RunOpts
---@param cmd_opts? Pipenv.CommandOpts
function M.run(command, opts, cmd_opts)
  assert(vim.g.pipenv_setup == 1, 'pipenv.nvim is not configured')
  assert(has_pipfile(), 'No `Pipfile` in the current working directory')

  Util.validate({
    command = { command, { 'string', 'table' } },
    opts = { opts, { 'table', 'nil' }, true },
    cmd_opts = { cmd_opts, { 'table', 'nil' }, true },
  })
  opts = opts or {}
  cmd_opts = cmd_opts or {}

  Util.validate({
    python = { opts.python, { 'string', 'nil' }, true },
    verbose = { opts.verbose, { 'boolean', 'nil' }, true },
  })
  if opts.verbose == nil then
    opts.verbose = false
  end
  opts.python = opts.python or nil

  local cmd ---@type string[]
  if type(command) == 'string' then
    cmd = { 'pipenv' }
    if opts.python and opts.python ~= '' then
      vim.list_extend(cmd, { '--python', opts.python })
    end
    table.insert(cmd, 'run')
    table.insert(cmd, command)
  else
    assert(#command > 0, 'Empty command table')

    cmd = vim.deepcopy(command)
    if opts.python and opts.python ~= '' then
      table.insert(cmd, 1, opts.python)
      table.insert(cmd, 1, '--python')
    end
    table.insert(cmd, 1, 'run')
    table.insert(cmd, 1, 'pipenv')
  end

  run_cmd(cmd, function(code, out, err)
    local cmd_str = table.concat(cmd, ' ')
    err = (err and err ~= '') and err or ('Error when running `%s`'):format(cmd_str)
    assert(code == 0, err)

    if not opts.verbose then
      return
    end
    if out and out ~= '' then
      local config = Config.get()
      Util.open_win(Util.trim_output(out), {
        border = config.output.border,
        float = config.output.float,
        height = config.output.height,
        split = config.output.split,
        title = cmd_str,
        width = config.output.width,
        zindex = config.output.zindex,
      })
      return
    end
    vim.notify(('(%s): No output given'):format(cmd_str), INFO)
  end, cmd_opts)
end

---@param opts? Pipenv.RequirementsOpts
---@param cmd_opts? Pipenv.CommandOpts
function M.requirements(opts, cmd_opts)
  assert(vim.g.pipenv_setup == 1, 'pipenv.nvim is not configured')
  assert(has_pipfile(), 'No `Pipfile` in the current working directory')

  Util.validate({
    opts = { opts, { 'table', 'nil' }, true },
    cmd_opts = { cmd_opts, { 'table', 'nil' }, true },
  })
  opts = opts or {}
  cmd_opts = cmd_opts or {}

  Util.validate({
    dev = { opts.dev, { 'boolean', 'nil' }, true },
    file = { opts.file, { 'string', 'table', 'nil' }, true },
    python = { opts.python, { 'string', 'nil' }, true },
    verbose = { opts.verbose, { 'boolean', 'nil' }, true },
  })
  if opts.dev == nil then
    opts.dev = false
  end
  if opts.verbose == nil then
    opts.verbose = false
  end
  opts.file = opts.file or nil
  opts.python = opts.python or nil

  local cmd = { 'pipenv' }
  if opts.python and opts.python ~= '' then
    vim.list_extend(cmd, { '--python', opts.python })
  end
  table.insert(cmd, 'requirements')

  if opts.dev then
    table.insert(cmd, '--dev')
  end

  run_cmd(cmd, function(code, out, err)
    local cmd_str = table.concat(cmd, ' ')
    err = (err and err ~= '') and err or ('Error when running `%s`'):format(cmd_str)
    assert(code == 0, err)

    if not out or out == '' then
      vim.notify(('(%s): No output given'):format(cmd_str), INFO)
      return
    end

    local config = Config.get()
    if not opts.file or opts.file == '' then
      Util.open_win(Util.trim_output(out), {
        border = config.output.border,
        float = config.output.float,
        ft = 'requirements',
        height = config.output.height,
        split = config.output.split,
        title = cmd_str,
        width = config.output.width,
        zindex = config.output.zindex,
      })
      return
    end

    local stat = vim.uv.fs_stat(opts.file)
    if stat and stat.size ~= 0 and Util.yes_no(("Overwrite '%s'?"):format(opts.file)) then
      return
    end

    local fd = assert(
      vim.uv.fs_open(opts.file, 'w', tonumber('644', 8)),
      ('(%s): Unable to open file: `%s`'):format(cmd_str, opts.file)
    )
    assert(
      vim.uv.fs_write(fd, vim.split(out, '\n', { trimempty = false })),
      ('(%s): Unable to write data to `%s`'):format(cmd_str, opts.file)
    )
    assert(vim.uv.fs_close(fd), 'Unable to close file descriptor')

    if opts.verbose then
      vim.notify(('(%s): Wrote requirements to `%s`!'):format(cmd_str, opts.file), INFO)
    end
  end, cmd_opts)
end

---@param level? vim.log.levels
function M.help(level)
  Util.validate({ level = { level, { 'number', 'nil' }, true } })
  level = (level and Util.is_int(level, level <= 5 and level >= 0)) and level or INFO

  vim.notify(
    [[Usage:
  :Pipenv[!] [dev=true|false] [file=/path/to/file] [python=<VERSION>] [pre=true|false] [<OPERATION>]

Subcommands:
  :Pipenv edit
  :Pipenv graph [python=<VERSION>]
  :Pipenv help
  :Pipenv list-installed
  :Pipenv list-scripts
  :Pipenv scripts [python=<VERSION>]
  :Pipenv[!] clean [python=<VERSION>]
  :Pipenv[!] install [dev=true|false] [pre=true|false] [python=<VERSION>] [<pkg1> [<pkg2> [...]\]\]
  :Pipenv[!] lock [pre=true|false] [python=<VERSION>]
  :Pipenv[!] remove
  :Pipenv[!] requirements [dev=true|false] [file=/path/to/file] [python=<VERSION>]
  :Pipenv[!] run [python=<VERSION>] <command> [<args> [...]\]
  :Pipenv[!] sync [dev=true|false] [pre=true|false] [python=<VERSION>]
  :Pipenv[!] uninstall [dev=true|false] [pre=true|false] [python=<VERSION>] <pkg1> [...]
  :Pipenv[!] update [dev=true|false] [pre=true|false] [python=<VERSION>]
  :Pipenv[!] upgrade [dev=true|false] [pre=true|false] [python=<VERSION>]
  :Pipenv[!] verify [python=<VERSION>]\]],
    level
  )
end

return M
-- vim: set ts=2 sts=2 sw=2 et ai si sta:
