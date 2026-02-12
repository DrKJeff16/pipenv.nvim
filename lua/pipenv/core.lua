---@module 'pipenv._meta'

local Util = require('pipenv.util')
local Config = require('pipenv.config')
local uv = vim.uv or vim.loop
local ERROR = vim.log.levels.ERROR
local WARN = vim.log.levels.WARN
local INFO = vim.log.levels.INFO

local stdout, stderr = {}, {} ---@type string[], string[]
local spinner = nil ---@type PipenvSpinner|nil
local ec = -1 ---@type integer

---@return boolean spinner
local function has_spinner()
  return Util.mod_exists('spinner')
end

---@param id string
---@param opts spinner.Opts
local function new_spinner(id, opts)
  local Spinner = require('spinner')
  Spinner.config(id, opts)
  spinner = { ---@type PipenvSpinner
    id = id,
    text = Spinner.render(id),
    start = function(self)
      Spinner.start(self.id)
    end,
    stop = function(self, force)
      Spinner.stop(self.id, force)
    end,
    pause = function(self, force)
      Spinner.stop(self.id, force)
    end,
  }
end

---@param cmd string[]
---@param on_exit fun(code: integer, out: string, err: string)
---@param opts? Pipenv.SystemOpts
local function run_cmd(cmd, on_exit, opts)
  Util.validate({
    cmd = { cmd, { 'table' } },
    opts = { opts, { 'table', 'nil' }, true },
  })
  opts = opts or {}

  opts.text = opts.text ~= nil and opts.text or true
  if Config.env and not vim.tbl_isempty(Config.env) then
    opts.env = vim.tbl_deep_extend('keep', opts.env or {}, Config.env)
  end

  stdout, stderr = {}, {}
  local job = require('job')
  if has_spinner() then
    new_spinner(table.concat(cmd, ' '), { kind = 'cursor' })
    if spinner then
      spinner:start()
    end
  end
  local jobid = job.start(cmd, {
    env = opts.env,
    cwd = uv.cwd(),
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

---@param create? boolean
---@return boolean pipfile
local function has_pipfile(create)
  Util.validate({ create = { create, { 'boolean', 'nil' }, true } })
  create = create ~= nil and create or false

  if not vim.fn.filereadable('./Pipfile') then
    if not create or vim.fn.confirm('No Pipfile found. Create?', '&Yes\n&No', 2) ~= 1 then
      vim.notify('No Pipfile found!', ERROR)
      return false
    end
    ec = -1
    run_cmd({ 'pipenv', 'install' }, function(code)
      ec = code
    end)
    return ec == 0
  end

  return true
end

---@class Pipenv.Core
local M = {}

function M.edit()
  if vim.g.pipenv_setup ~= 1 then
    vim.notify('pipenv.nvim is not configured!', ERROR)
    return
  end
  if not has_pipfile(true) then
    return
  end

  vim.cmd.tabedit('./Pipfile')
  vim.schedule(function()
    local bufnr = vim.api.nvim_get_current_buf()
    local tab = vim.api.nvim_get_current_tabpage()
    vim.keymap.set('n', 'q', function()
      pcall(vim.api.nvim_buf_delete, bufnr, { force = true })
      pcall(vim.api.nvim_cmd, { cmd = 'tabclose', range = { tab } }, { output = false })
    end, { buffer = bufnr })
  end)
end

---@return string[]|nil res
function M.retrieve_scripts()
  if not has_pipfile() then
    return
  end
  local stat = uv.fs_stat('Pipfile')
  if not stat or stat.size == 0 then
    return
  end
  local fd = uv.fs_open('Pipfile', 'r', tonumber('644', 8))
  if not fd then
    return
  end

  local data = uv.fs_read(fd, stat.size)
  uv.fs_close(fd)
  if not data then
    return
  end

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
    if code ~= 0 or not out or out == '' then
      error((err and err ~= '') and err or 'Could not parse JSON graph!', ERROR)
    end

    ---@type boolean, PipenvJsonGraph[]|nil
    local ok, data = pcall(vim.json.decode, Util.trim_output(out))
    if not (ok and data) then
      error('Could not parse JSON graph!', ERROR)
    end

    for _, pkg in ipairs(data) do
      if
        pkg.package.package_name and not vim.list_contains(installed, pkg.package.package_name)
      then
        table.insert(installed, pkg.package.package_name)
      end
    end
  end)
  return installed
end

function M.list_installed()
  if vim.g.pipenv_setup ~= 1 then
    vim.notify('pipenv.nvim is not configured!', ERROR)
    return
  end
  if not has_pipfile() then
    return
  end

  local installed = M.retrieve_installed()
  if vim.tbl_isempty(installed) then
    vim.notify('No installed scripts found!', WARN)
    return
  end

  Util.open_win(table.concat(installed, '\n'), {
    height = 0.7,
    width = 0.4,
    title = 'Installed Packages',
    split = Config.opts.output.split,
    border = Config.opts.output.border,
    float = Config.opts.output.float,
    zindex = Config.opts.output.zindex,
  })
end

function M.list_scripts()
  if vim.g.pipenv_setup ~= 1 then
    vim.notify('pipenv.nvim is not configured!', ERROR)
    return
  end
  if not has_pipfile() then
    return
  end

  local data = M.retrieve_scripts()
  if not data then
    vim.notify('Unable to retrieve scripts from Pipfile!', ERROR)
    return
  end
  if vim.tbl_isempty(data) then
    vim.notify('No scripts in Pipfile!', WARN)
    return
  end

  Util.open_win(table.concat(data, '\n'), {
    height = 0.4,
    width = 0.3,
    title = 'Scripts',
    split = Config.opts.output.split,
    border = Config.opts.output.border,
    float = Config.opts.output.float,
    zindex = Config.opts.output.zindex,
  })
end

---@param opts? Pipenv.GraphOpts
---@param cmd_opts? Pipenv.SystemOpts
function M.graph(opts, cmd_opts)
  if vim.g.pipenv_setup ~= 1 then
    vim.notify('pipenv.nvim is not configured!', ERROR)
    return
  end
  if not has_pipfile() then
    return
  end

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
    table.insert(cmd, '--python')
    table.insert(cmd, opts.python)
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
      Util.open_win(Util.trim_output(out), {
        height = Config.opts.output.height,
        width = Config.opts.output.width,
        title = cmd_str,
        split = Config.opts.output.split,
        border = Config.opts.output.border,
        float = Config.opts.output.float,
        zindex = Config.opts.output.zindex,
      })
      return
    end
    vim.notify(('(%s): No output given!'):format(cmd_str), INFO)
  end, cmd_opts)
end

---@param opts? Pipenv.LockOpts
---@param cmd_opts? Pipenv.SystemOpts
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
    verbose = { opts.verbose, { 'boolean', 'nil' }, true },
    python = { opts.python, { 'string', 'nil' }, true },
  })
  opts.dev = opts.dev ~= nil and opts.dev or false
  opts.pre = opts.pre ~= nil and opts.pre or false
  opts.verbose = opts.verbose ~= nil and opts.verbose or false
  opts.python = opts.python or nil

  local cmd = { 'pipenv' }
  if opts.python and opts.python ~= '' then
    table.insert(cmd, '--python')
    table.insert(cmd, opts.python)
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

    if code ~= 0 then
      vim.notify(err, ERROR)
      return
    end
    if not opts.verbose then
      return
    end
    if out and out ~= '' then
      Util.open_win(Util.trim_output(out), {
        height = Config.opts.output.height,
        width = Config.opts.output.width,
        title = cmd_str,
        split = Config.opts.output.split,
        border = Config.opts.output.border,
        float = Config.opts.output.float,
        zindex = Config.opts.output.zindex,
      })
      return
    end
    vim.notify(('(%s): No output given!'):format(cmd_str), INFO)
  end, cmd_opts)
end

---@param opts? Pipenv.CleanOpts
---@param cmd_opts? Pipenv.SystemOpts
function M.clean(opts, cmd_opts)
  if vim.g.pipenv_setup ~= 1 then
    vim.notify('pipenv.nvim is not configured!', ERROR)
    return
  end
  if not has_pipfile() then
    return
  end

  Util.validate({
    opts = { opts, { 'table', 'nil' }, true },
    cmd_opts = { cmd_opts, { 'table', 'nil' }, true },
  })
  opts = opts or {}
  cmd_opts = cmd_opts or {}

  Util.validate({
    verbose = { opts.verbose, { 'boolean', 'nil' }, true },
    python = { opts.python, { 'string', 'nil' }, true },
  })
  opts.verbose = opts.verbose ~= nil and opts.verbose or false
  opts.python = opts.python or nil

  local cmd = { 'pipenv' }
  if opts.python and opts.python ~= '' then
    table.insert(cmd, '--python')
    table.insert(cmd, opts.python)
  end
  table.insert(cmd, 'clean')

  run_cmd(cmd, function(code, out, err)
    local cmd_str = table.concat(cmd, ' ')
    err = (err and err ~= '') and err or ('Error when running `%s`'):format(cmd_str)

    if code ~= 0 then
      vim.notify(err, ERROR)
      return
    end
    if not opts.verbose then
      return
    end
    if out and out ~= '' then
      Util.open_win(Util.trim_output(out), {
        height = Config.opts.output.height,
        width = Config.opts.output.width,
        title = cmd_str,
        split = Config.opts.output.split,
        border = Config.opts.output.border,
        float = Config.opts.output.float,
        zindex = Config.opts.output.zindex,
      })
      return
    end
    vim.notify(('(%s): No output given!'):format(cmd_str), INFO)
  end, cmd_opts)
end

---@param opts? Pipenv.VerifyOpts
---@param cmd_opts? Pipenv.SystemOpts
function M.verify(opts, cmd_opts)
  if vim.g.pipenv_setup ~= 1 then
    vim.notify('pipenv.nvim is not configured!', ERROR)
    return
  end
  if not has_pipfile() then
    return
  end

  Util.validate({
    opts = { opts, { 'table', 'nil' }, true },
    cmd_opts = { cmd_opts, { 'table', 'nil' }, true },
  })
  opts = opts or {}
  cmd_opts = cmd_opts or {}

  Util.validate({
    verbose = { opts.verbose, { 'boolean', 'nil' }, true },
    python = { opts.python, { 'string', 'nil' }, true },
  })
  opts.verbose = opts.verbose ~= nil and opts.verbose or false
  opts.python = opts.python or nil

  local cmd = { 'pipenv' }
  if opts.python and opts.python ~= '' then
    table.insert(cmd, '--python')
    table.insert(cmd, opts.python)
  end
  table.insert(cmd, 'verify')

  run_cmd(cmd, function(code, out, err)
    local cmd_str = table.concat(cmd, ' ')
    err = (err and err ~= '') and err or ('Error when running `%s`'):format(cmd_str)

    if code ~= 0 then
      vim.notify(err, ERROR)
      return
    end
    if not opts.verbose then
      return
    end
    if out and out ~= '' then
      Util.open_win(Util.trim_output(out), {
        height = Config.opts.output.height,
        width = Config.opts.output.width,
        title = cmd_str,
        split = Config.opts.output.split,
        border = Config.opts.output.border,
        float = Config.opts.output.float,
        zindex = Config.opts.output.zindex,
      })
      return
    end
    vim.notify(('(%s): No output given!'):format(cmd_str), INFO)
  end, cmd_opts)
end

---@param opts? Pipenv.SyncOpts
---@param cmd_opts? Pipenv.SystemOpts
function M.sync(opts, cmd_opts)
  if vim.g.pipenv_setup ~= 1 then
    vim.notify('pipenv.nvim is not configured!', ERROR)
    return
  end
  if not has_pipfile() then
    return
  end

  Util.validate({
    opts = { opts, { 'table', 'nil' }, true },
    cmd_opts = { cmd_opts, { 'table', 'nil' }, true },
  })
  opts = opts or {}
  cmd_opts = cmd_opts or {}

  Util.validate({
    dev = { opts.dev, { 'boolean', 'nil' }, true },
    pre = { opts.pre, { 'boolean', 'nil' }, true },
    verbose = { opts.verbose, { 'boolean', 'nil' }, true },
    python = { opts.python, { 'string', 'nil' }, true },
  })
  opts.dev = opts.dev ~= nil and opts.dev or false
  opts.pre = opts.pre ~= nil and opts.pre or false
  opts.verbose = opts.verbose ~= nil and opts.verbose or false
  opts.python = opts.python or nil

  local cmd = { 'pipenv' }
  if opts.python and opts.python ~= '' then
    table.insert(cmd, '--python')
    table.insert(cmd, opts.python)
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

    if code ~= 0 then
      vim.notify(err, ERROR)
      return
    end
    if not opts.verbose then
      return
    end
    if out and out ~= '' then
      Util.open_win(Util.trim_output(out), {
        height = Config.opts.output.height,
        width = Config.opts.output.width,
        title = cmd_str,
        split = Config.opts.output.split,
        border = Config.opts.output.border,
        float = Config.opts.output.float,
        zindex = Config.opts.output.zindex,
      })
      return
    end
    vim.notify(('(%s): No output given!'):format(cmd_str), INFO)
  end, cmd_opts)
end

---@param opts? Pipenv.UpgradeOpts
---@param cmd_opts? Pipenv.SystemOpts
function M.update(opts, cmd_opts)
  if vim.g.pipenv_setup ~= 1 then
    vim.notify('pipenv.nvim is not configured!', ERROR)
    return
  end
  if not has_pipfile() then
    return
  end

  Util.validate({
    opts = { opts, { 'table', 'nil' }, true },
    cmd_opts = { cmd_opts, { 'table', 'nil' }, true },
  })
  opts = opts or {}
  cmd_opts = cmd_opts or {}

  Util.validate({
    dev = { opts.dev, { 'boolean', 'nil' }, true },
    pre = { opts.pre, { 'boolean', 'nil' }, true },
    verbose = { opts.verbose, { 'boolean', 'nil' }, true },
    python = { opts.python, { 'string', 'nil' }, true },
  })
  opts.dev = opts.dev ~= nil and opts.dev or false
  opts.pre = opts.pre ~= nil and opts.pre or false
  opts.verbose = opts.verbose ~= nil and opts.verbose or false
  opts.python = opts.python or nil

  local cmd = { 'pipenv' }
  if opts.python and opts.python ~= '' then
    table.insert(cmd, '--python')
    table.insert(cmd, opts.python)
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

    if code ~= 0 then
      vim.notify(err, ERROR)
      return
    end
    if not opts.verbose then
      return
    end
    if out and out ~= '' then
      Util.open_win(Util.trim_output(out), {
        height = Config.opts.output.height,
        width = Config.opts.output.width,
        title = cmd_str,
        split = Config.opts.output.split,
        border = Config.opts.output.border,
        float = Config.opts.output.float,
        zindex = Config.opts.output.zindex,
      })
      return
    end
    vim.notify(('(%s): No output given!'):format(cmd_str), INFO)
  end, cmd_opts)
end

---@param opts? Pipenv.UpgradeOpts
---@param cmd_opts? Pipenv.SystemOpts
function M.upgrade(opts, cmd_opts)
  if vim.g.pipenv_setup ~= 1 then
    vim.notify('pipenv.nvim is not configured!', ERROR)
    return
  end
  if not has_pipfile() then
    return
  end

  Util.validate({
    opts = { opts, { 'table', 'nil' }, true },
    cmd_opts = { cmd_opts, { 'table', 'nil' }, true },
  })
  opts = opts or {}
  cmd_opts = cmd_opts or {}

  Util.validate({
    dev = { opts.dev, { 'boolean', 'nil' }, true },
    pre = { opts.pre, { 'boolean', 'nil' }, true },
    verbose = { opts.verbose, { 'boolean', 'nil' }, true },
    python = { opts.python, { 'string', 'nil' }, true },
  })
  opts.dev = opts.dev ~= nil and opts.dev or false
  opts.pre = opts.pre ~= nil and opts.pre or false
  opts.verbose = opts.verbose ~= nil and opts.verbose or false
  opts.python = opts.python or nil

  local cmd = { 'pipenv' }
  if opts.python and opts.python ~= '' then
    table.insert(cmd, '--python')
    table.insert(cmd, opts.python)
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

    if code ~= 0 then
      vim.notify(err, ERROR)
      return
    end
    if not opts.verbose then
      return
    end
    if out and out ~= '' then
      Util.open_win(Util.trim_output(out), {
        height = Config.opts.output.height,
        width = Config.opts.output.width,
        title = cmd_str,
        split = Config.opts.output.split,
        border = Config.opts.output.border,
        float = Config.opts.output.float,
        zindex = Config.opts.output.zindex,
      })
      return
    end
    vim.notify(('(%s): No output given!'):format(cmd_str), INFO)
  end, cmd_opts)
end

---@param opts? Pipenv.ScriptsOpts
---@param cmd_opts? Pipenv.SystemOpts
function M.scripts(opts, cmd_opts)
  if vim.g.pipenv_setup ~= 1 then
    vim.notify('pipenv.nvim is not configured!', ERROR)
    return
  end
  if not has_pipfile() then
    return
  end

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
    table.insert(cmd, '--python')
    table.insert(cmd, opts.python)
  end
  table.insert(cmd, 'scripts')

  run_cmd(cmd, function(code, out, err)
    local cmd_str = table.concat(cmd, ' ')
    err = (err and err ~= '') and err or ('Error when running `%s`'):format(cmd_str)

    if code ~= 0 then
      vim.notify(err, ERROR)
      return
    end
    if out and out ~= '' then
      Util.open_win(Util.trim_output(out), {
        height = Config.opts.output.height,
        width = Config.opts.output.width,
        title = cmd_str,
        split = Config.opts.output.split,
        border = Config.opts.output.border,
        float = Config.opts.output.float,
        zindex = Config.opts.output.zindex,
      })
      return
    end
    vim.notify(('(%s): No output given!'):format(cmd_str), INFO)
  end, cmd_opts)
end

---@param packages? string[]|string|nil
---@param opts? Pipenv.InstallOpts
---@param cmd_opts? Pipenv.SystemOpts
function M.install(packages, opts, cmd_opts)
  if vim.g.pipenv_setup ~= 1 then
    vim.notify('pipenv.nvim is not configured!', ERROR)
    return
  end

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
    verbose = { opts.verbose, { 'boolean', 'nil' }, true },
    python = { opts.python, { 'string', 'nil' }, true },
  })
  opts.dev = opts.dev ~= nil and opts.dev or false
  opts.pre = opts.pre ~= nil and opts.pre or false
  opts.verbose = opts.verbose ~= nil and opts.verbose or false
  opts.python = opts.python or nil

  local cmd = { 'pipenv' }
  if opts.python and opts.python ~= '' then
    table.insert(cmd, '--python')
    table.insert(cmd, opts.python)
  end
  table.insert(cmd, 'install')
  if opts.dev then
    table.insert(cmd, '--dev')
  end
  if opts.pre then
    table.insert(cmd, '--pre')
  end
  if packages then
    if Util.is_type('string', packages) then
      ---@cast packages string
      table.insert(cmd, packages)
    elseif not vim.tbl_isempty(packages) then
      ---@cast packages string[]
      for _, pkg in ipairs(packages) do
        if Util.is_type('string', pkg) and pkg ~= '' then
          table.insert(cmd, pkg)
        end
      end
    else
      vim.notify('(pipenv install): Empty packages table!', ERROR)
      return
    end
  end

  run_cmd(cmd, function(code, out, err)
    local cmd_str = table.concat(cmd, ' ')
    err = (err and err ~= '') and err or ('Error when running `%s`'):format(cmd_str)

    if code ~= 0 then
      vim.notify(err, ERROR)
      return
    end
    if not opts.verbose then
      return
    end
    if out and out ~= '' then
      Util.open_win(Util.trim_output(out), {
        height = Config.opts.output.height,
        width = Config.opts.output.width,
        title = cmd_str,
        split = Config.opts.output.split,
        border = Config.opts.output.border,
        float = Config.opts.output.float,
        zindex = Config.opts.output.zindex,
      })
      return
    end
    vim.notify(('(%s): No output given!'):format(cmd_str), INFO)
  end, cmd_opts)
end

---@param packages string[]|string
---@param opts? Pipenv.UninstallOpts
---@param cmd_opts? Pipenv.SystemOpts
function M.uninstall(packages, opts, cmd_opts)
  if vim.g.pipenv_setup ~= 1 then
    vim.notify('pipenv.nvim is not configured!', ERROR)
    return
  end
  if not has_pipfile() then
    return
  end

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
    verbose = { opts.verbose, { 'boolean', 'nil' }, true },
    python = { opts.python, { 'string', 'nil' }, true },
  })
  opts.dev = opts.dev ~= nil and opts.dev or false
  opts.pre = opts.pre ~= nil and opts.pre or false
  opts.verbose = opts.verbose ~= nil and opts.verbose or false
  opts.python = opts.python or nil

  local cmd = { 'pipenv' }
  if opts.python and opts.python ~= '' then
    table.insert(cmd, '--python')
    table.insert(cmd, opts.python)
  end
  table.insert(cmd, 'uninstall')
  if opts.dev then
    table.insert(cmd, '--dev')
  end
  if opts.pre then
    table.insert(cmd, '--pre')
  end
  if Util.is_type('string', packages) then
    ---@cast packages string
    table.insert(cmd, packages)
  elseif not vim.tbl_isempty(packages) then
    ---@cast packages string[]
    for _, pkg in ipairs(packages) do
      if Util.is_type('string', pkg) and pkg ~= '' then
        table.insert(cmd, pkg)
      end
    end
  else
    vim.notify('(pipenv uninstall): Empty packages table!', ERROR)
    return
  end

  run_cmd(cmd, function(code, out, err)
    local cmd_str = table.concat(cmd, ' ')
    err = (err and err ~= '') and err or ('Error when running `%s`'):format(cmd_str)

    if code ~= 0 then
      vim.notify(err, ERROR)
      return
    end
    if not opts.verbose then
      return
    end
    if out and out ~= '' then
      Util.open_win(Util.trim_output(out), {
        height = Config.opts.output.height,
        width = Config.opts.output.width,
        title = cmd_str,
        split = Config.opts.output.split,
        border = Config.opts.output.border,
        float = Config.opts.output.float,
        zindex = Config.opts.output.zindex,
      })
      return
    end
    vim.notify(('(%s): No output given!'):format(cmd_str), INFO)
  end, cmd_opts)
end

---@param command string[]|string
---@param opts? Pipenv.RunOpts
---@param cmd_opts? Pipenv.SystemOpts
function M.run(command, opts, cmd_opts)
  if vim.g.pipenv_setup ~= 1 then
    vim.notify('pipenv.nvim is not configured!', ERROR)
    return
  end
  if not has_pipfile() then
    return
  end

  Util.validate({
    command = { command, { 'string', 'table' } },
    opts = { opts, { 'table', 'nil' }, true },
    cmd_opts = { cmd_opts, { 'table', 'nil' }, true },
  })
  opts = opts or {}
  cmd_opts = cmd_opts or {}

  Util.validate({
    verbose = { opts.verbose, { 'boolean', 'nil' }, true },
    python = { opts.python, { 'string', 'nil' }, true },
  })
  opts.verbose = opts.verbose ~= nil and opts.verbose or false
  opts.python = opts.python or nil

  local cmd ---@type string[]
  if Util.is_type('string', command) then
    ---@cast command string
    cmd = { 'pipenv' }
    if opts.python and opts.python ~= '' then
      table.insert(cmd, '--python')
      table.insert(cmd, opts.python)
    end
    table.insert(cmd, 'run')
    table.insert(cmd, command)
  elseif vim.tbl_isempty(command) then
    vim.notify('(pipenv run): Empty command table!')
    return
  else
    ---@cast command string[]
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

    if code ~= 0 then
      vim.notify(err, ERROR)
      return
    end
    if not opts.verbose then
      return
    end
    if out and out ~= '' then
      Util.open_win(Util.trim_output(out), {
        height = Config.opts.output.height,
        width = Config.opts.output.width,
        title = cmd_str,
        split = Config.opts.output.split,
        border = Config.opts.output.border,
        float = Config.opts.output.float,
        zindex = Config.opts.output.zindex,
      })
      return
    end
    vim.notify(('(%s): No output given!'):format(cmd_str), INFO)
  end, cmd_opts)
end

---@param opts? Pipenv.RequirementsOpts
---@param cmd_opts? Pipenv.SystemOpts
function M.requirements(opts, cmd_opts)
  if vim.g.pipenv_setup ~= 1 then
    vim.notify('pipenv.nvim is not configured!', ERROR)
    return
  end
  if not has_pipfile() then
    return
  end

  Util.validate({
    opts = { opts, { 'table', 'nil' }, true },
    cmd_opts = { cmd_opts, { 'table', 'nil' }, true },
  })
  opts = opts or {}
  cmd_opts = cmd_opts or {}

  Util.validate({
    verbose = { opts.verbose, { 'boolean', 'nil' }, true },
    dev = { opts.dev, { 'boolean', 'nil' }, true },
    file = { opts.file, { 'string', 'table', 'nil' }, true },
    python = { opts.python, { 'string', 'nil' }, true },
  })
  opts.dev = opts.dev ~= nil and opts.dev or false
  opts.file = opts.file or nil
  opts.python = opts.python or nil

  local cmd = { 'pipenv' }
  if opts.python and opts.python ~= '' then
    table.insert(cmd, '--python')
    table.insert(cmd, opts.python)
  end
  table.insert(cmd, 'requirements')

  if opts.dev then
    table.insert(cmd, '--dev')
  end

  run_cmd(cmd, function(code, out, err)
    local cmd_str = table.concat(cmd, ' ')
    err = (err and err ~= '') and err or ('Error when running `%s`'):format(cmd_str)

    if code ~= 0 then
      vim.notify(err, ERROR)
      return
    end

    if not out or out == '' then
      vim.notify(('(%s): No output given!'):format(cmd_str), INFO)
      return
    end

    out = Util.trim_output(out)

    if not opts.file or opts.file == '' then
      Util.open_win(out, {
        ft = 'requirements',
        height = Config.opts.output.height,
        width = Config.opts.output.width,
        title = cmd_str,
        split = Config.opts.output.split,
        border = Config.opts.output.border,
        float = Config.opts.output.float,
        zindex = Config.opts.output.zindex,
      })
      return
    end

    local stat = uv.fs_stat(opts.file)
    if stat and stat.size ~= 0 then
      if vim.fn.confirm(("Overwrite '%s'?"):format(opts.file), '&Yes\n&No', 2) ~= 1 then
        return
      end
    end

    if
      vim.fn.writefile(vim.split(out, '\n', { plain = true, trimempty = false }), opts.file) == -1
    then
      vim.notify(('(%s): Unable to write to `%s`!'):format(cmd_str, opts.file), ERROR)
    end

    if opts.verbose then
      vim.notify(('(%s): Wrote requirements to `%s`!'):format(cmd_str, opts.file), INFO)
    end
  end, cmd_opts)
end

local Core = setmetatable(M, { ---@type Pipenv.Core
  __index = M,
  __newindex = function()
    vim.notify('Pipenv module is read-only!', ERROR)
  end,
})

return Core
-- vim: set ts=2 sts=2 sw=2 et ai si sta:
