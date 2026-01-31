---@class Pipenv.CommandOpts
---@field verbose? boolean

---@class Pipenv.RequirementsOpts
---@field dev? boolean
---@field file? string[]|string|nil

---@class Pipenv.SyncOpts: Pipenv.CommandOpts
---@field dev? boolean

---@class Pipenv.CleanOpts: Pipenv.CommandOpts
---@class Pipenv.InstallOpts: Pipenv.SyncOpts
---@class Pipenv.LockOpts: Pipenv.CommandOpts
---@class Pipenv.RunOpts: Pipenv.CommandOpts
---@class Pipenv.UninstallOpts: Pipenv.SyncOpts
---@class Pipenv.VerifyOpts: Pipenv.CommandOpts

---@class PipenvJsonPackage
---@field key string
---@field package_name string
---@field installed_version string

---@alias PipenvJsonGraph table<'package', PipenvJsonPackage>

local Util = require('pipenv.util')
local Config = require('pipenv.config')
local uv = vim.uv or vim.loop
local ERROR = vim.log.levels.ERROR
local WARN = vim.log.levels.WARN
local INFO = vim.log.levels.INFO

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
    if not vim.fn.writefile({}, './Pipfile') ~= 0 then
      vim.notify('Could not create Pipfile!', WARN)
      return false
    end
  end

  return true
end

---@param cmd string[]
---@param timeout? integer
---@return vim.SystemCompleted sys_obj
local function run_cmd(cmd, timeout)
  Util.validate({
    cmd = { cmd, { 'table' } },
    timeout = { timeout, { 'number', 'nil' }, true },
  })
  timeout = (timeout and Util.is_int(timeout) and timeout > 0) and timeout or 300000

  return vim.system(cmd, { text = true }):wait(timeout)
end

---@class Pipenv.API
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
  local sys_obj = run_cmd({ 'pipenv', 'graph', '--json' })
  if sys_obj.code ~= 0 then
    error(
      (sys_obj.stderr and sys_obj.stderr ~= '') and sys_obj.stderr or 'Could not parse JSON graph!',
      ERROR
    )
  end
  if not sys_obj.stdout or sys_obj.stdout == '' then
    error(
      (sys_obj.stderr and sys_obj.stderr ~= '') and sys_obj.stderr or 'Could not parse JSON graph!',
      ERROR
    )
  end

  ---@type boolean, PipenvJsonGraph[]|nil
  local ok, data = pcall(vim.json.decode, Util.trim_output(sys_obj.stdout))
  if not (ok and data) then
    error('Could not parse JSON graph!', ERROR)
  end

  local installed = {} ---@type string[]
  for _, pkg in ipairs(data) do
    if pkg.package.package_name and not vim.list_contains(installed, pkg.package.package_name) then
      table.insert(installed, pkg.package.package_name)
    end
  end
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

  Util.open_float(table.concat(installed, '\n'), {
    height = 0.7,
    width = 0.4,
    title = 'Installed Packages',
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

  Util.open_float(table.concat(data, '\n'), {
    height = 0.4,
    width = 0.3,
    title = 'Installed Packages',
    zindex = Config.opts.output.zindex,
  })
end

function M.graph()
  if vim.g.pipenv_setup ~= 1 then
    vim.notify('pipenv.nvim is not configured!', ERROR)
    return
  end
  if not has_pipfile() then
    return
  end

  local cmd = { 'pipenv', 'graph' }
  local sys_obj = run_cmd(cmd)
  local cmd_str = table.concat(cmd, ' ')
  local err = (sys_obj.stderr and sys_obj.stderr ~= '') and sys_obj.stderr
    or ('Error when running `%s`'):format(cmd_str)

  if sys_obj.code ~= 0 then
    vim.notify(err, ERROR)
    return
  end
  if sys_obj.stdout and sys_obj.stdout ~= '' then
    Util.open_float(Util.trim_output(sys_obj.stdout), {
      height = Config.opts.output.height,
      width = Config.opts.output.width,
      title = cmd_str,
      zindex = Config.opts.output.zindex,
    })
    return
  end
  vim.notify(('(%s): No output given!'):format(cmd_str), INFO)
end

---@param opts? Pipenv.LockOpts
function M.lock(opts)
  Util.validate({ opts = { opts, { 'table', 'nil' }, true } })
  opts = opts or {}

  Util.validate({ verbose = { opts.verbose, { 'boolean', 'nil' }, true } })
  opts.verbose = opts.verbose ~= nil and opts.verbose or false

  local cmd = { 'pipenv', 'lock' }
  local sys_obj = run_cmd(cmd)
  local cmd_str = table.concat(cmd, ' ')
  local err = (sys_obj.stderr and sys_obj.stderr ~= '') and sys_obj.stderr
    or ('Error when running `%s`'):format(cmd_str)

  if sys_obj.code ~= 0 then
    vim.notify(err, ERROR)
    return
  end
  if opts.verbose then
    if sys_obj.stdout and sys_obj.stdout ~= '' then
      Util.open_float(Util.trim_output(sys_obj.stdout), {
        height = Config.opts.output.height,
        width = Config.opts.output.width,
        title = cmd_str,
        zindex = Config.opts.output.zindex,
      })
      return
    end
    vim.notify(('(%s): No output given!'):format(cmd_str), INFO)
  end
end

---@param opts? Pipenv.CleanOpts
function M.clean(opts)
  if vim.g.pipenv_setup ~= 1 then
    vim.notify('pipenv.nvim is not configured!', ERROR)
    return
  end
  if not has_pipfile() then
    return
  end

  Util.validate({ opts = { opts, { 'table', 'nil' }, true } })
  opts = opts or {}

  Util.validate({ verbose = { opts.verbose, { 'boolean', 'nil' }, true } })
  opts.verbose = opts.verbose ~= nil and opts.verbose or false

  local cmd = { 'pipenv', 'clean' }
  local sys_obj = run_cmd({ 'pipenv', 'clean' })
  local cmd_str = table.concat(cmd, ' ')
  local err = (sys_obj.stderr and sys_obj.stderr ~= '') and sys_obj.stderr
    or ('Error when running `%s`'):format(cmd_str)

  if sys_obj.code ~= 0 then
    vim.notify(err, ERROR)
    return
  end
  if opts.verbose then
    if sys_obj.stdout and sys_obj.stdout ~= '' then
      Util.open_float(Util.trim_output(sys_obj.stdout), {
        height = Config.opts.output.height,
        width = Config.opts.output.width,
        title = cmd_str,
        zindex = Config.opts.output.zindex,
      })
      return
    end
    vim.notify(('(%s): No output given!'):format(cmd_str), INFO)
  end
end

---@param opts? Pipenv.VerifyOpts
function M.verify(opts)
  if vim.g.pipenv_setup ~= 1 then
    vim.notify('pipenv.nvim is not configured!', ERROR)
    return
  end
  if not has_pipfile() then
    return
  end

  Util.validate({ opts = { opts, { 'table', 'nil' }, true } })
  opts = opts or {}

  Util.validate({ verbose = { opts.verbose, { 'boolean', 'nil' }, true } })
  opts.verbose = opts.verbose ~= nil and opts.verbose or false

  local cmd = { 'pipenv', 'verify' }
  local sys_obj = run_cmd(cmd)
  local cmd_str = table.concat(cmd, ' ')
  local err = (sys_obj.stderr and sys_obj.stderr ~= '') and sys_obj.stderr
    or ('Error when running `%s`'):format(cmd_str)

  if sys_obj.code ~= 0 then
    vim.notify(err, ERROR)
    return
  end
  if opts.verbose then
    if sys_obj.stdout and sys_obj.stdout ~= '' then
      Util.open_float(Util.trim_output(sys_obj.stdout), {
        height = Config.opts.output.height,
        width = Config.opts.output.width,
        title = cmd_str,
        zindex = Config.opts.output.zindex,
      })
      return
    end
    vim.notify(('(%s): No output given!'):format(cmd_str), INFO)
  end
end

---@param opts? Pipenv.SyncOpts
function M.sync(opts)
  if vim.g.pipenv_setup ~= 1 then
    vim.notify('pipenv.nvim is not configured!', ERROR)
    return
  end
  if not has_pipfile() then
    return
  end

  Util.validate({ opts = { opts, { 'table', 'nil' }, true } })
  opts = opts or {}

  Util.validate({
    dev = { opts.dev, { 'boolean', 'nil' }, true },
    verbose = { opts.verbose, { 'boolean', 'nil' }, true },
  })
  opts.dev = opts.dev ~= nil and opts.dev or false
  opts.verbose = opts.verbose ~= nil and opts.verbose or false

  local cmd = { 'pipenv', 'sync' }
  if opts.dev then
    table.insert(cmd, '--dev')
  end

  local sys_obj = run_cmd(cmd)
  local cmd_str = table.concat(cmd, ' ')
  local err = (sys_obj.stderr and sys_obj.stderr ~= '') and sys_obj.stderr
    or ('Error when running `%s`'):format(cmd_str)

  if sys_obj.code ~= 0 then
    vim.notify(err, ERROR)
    return
  end
  if opts.verbose then
    if sys_obj.stdout and sys_obj.stdout ~= '' then
      Util.open_float(Util.trim_output(sys_obj.stdout), {
        height = Config.opts.output.height,
        width = Config.opts.output.width,
        title = cmd_str,
        zindex = Config.opts.output.zindex,
      })
      return
    end
    vim.notify(('(%s): No output given!'):format(cmd_str), INFO)
  end
end

---@param packages? string[]|string|nil
---@param opts? Pipenv.InstallOpts
function M.install(packages, opts)
  if vim.g.pipenv_setup ~= 1 then
    vim.notify('pipenv.nvim is not configured!', ERROR)
    return
  end

  Util.validate({
    packages = { packages, { 'string', 'table', 'nil' }, true },
    opts = { opts, { 'table', 'nil' }, true },
  })
  packages = packages or nil
  opts = opts or {}

  Util.validate({
    dev = { opts.dev, { 'boolean', 'nil' }, true },
    verbose = { opts.verbose, { 'boolean', 'nil' }, true },
  })
  opts.dev = opts.dev ~= nil and opts.dev or false
  opts.verbose = opts.verbose ~= nil and opts.verbose or false

  local cmd = { 'pipenv', 'install' }
  if opts.dev then
    table.insert(cmd, '--dev')
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

  local sys_obj = run_cmd(cmd)
  local cmd_str = table.concat(cmd, ' ')
  local err = (sys_obj.stderr and sys_obj.stderr ~= '') and sys_obj.stderr
    or ('Error when running `%s`'):format(cmd_str)

  if sys_obj.code ~= 0 then
    vim.notify(err, ERROR)
    return
  end
  if opts.verbose then
    if sys_obj.stdout and sys_obj.stdout ~= '' then
      Util.open_float(Util.trim_output(sys_obj.stdout), {
        height = Config.opts.output.height,
        width = Config.opts.output.width,
        title = cmd_str,
        zindex = Config.opts.output.zindex,
      })
      return
    end
    vim.notify(('(%s): No output given!'):format(cmd_str), INFO)
  end
end

---@param packages string[]|string
---@param opts? Pipenv.UninstallOpts
function M.uninstall(packages, opts)
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
  })
  opts = opts or {}

  Util.validate({
    dev = { opts.dev, { 'boolean', 'nil' }, true },
    verbose = { opts.verbose, { 'boolean', 'nil' }, true },
  })
  opts.dev = opts.dev ~= nil and opts.dev or false
  opts.verbose = opts.verbose ~= nil and opts.verbose or false

  local cmd = { 'pipenv', 'uninstall' }
  if opts.dev then
    table.insert(cmd, '--dev')
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

  local sys_obj = run_cmd(cmd)
  local cmd_str = table.concat(cmd, ' ')
  local err = (sys_obj.stderr and sys_obj.stderr ~= '') and sys_obj.stderr
    or ('Error when running `%s`'):format(cmd_str)

  if sys_obj.code ~= 0 then
    vim.notify(err, ERROR)
    return
  end
  if opts.verbose then
    if sys_obj.stdout and sys_obj.stdout ~= '' then
      Util.open_float(Util.trim_output(sys_obj.stdout), {
        height = Config.opts.output.height,
        width = Config.opts.output.width,
        title = cmd_str,
        zindex = Config.opts.output.zindex,
      })
      return
    end
    vim.notify(('(%s): No output given!'):format(cmd_str), INFO)
  end
end

---@param command string[]|string
---@param opts? Pipenv.RunOpts
function M.run(command, opts)
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
  })
  opts = opts or {}

  Util.validate({ verbose = { opts.verbose, { 'boolean', 'nil' }, true } })
  opts.verbose = opts.verbose ~= nil and opts.verbose or false

  local cmd ---@type string[]
  if Util.is_type('string', command) then
    ---@cast command string
    cmd = { 'pipenv', 'run', command }
  elseif vim.tbl_isempty(command) then
    vim.notify('(pipenv run): Empty command table!')
    return
  else
    ---@cast command string[]
    cmd = vim.deepcopy(command)
    table.insert(cmd, 1, 'run')
    table.insert(cmd, 1, 'pipenv')
  end

  local sys_obj = run_cmd(cmd)
  local cmd_str = table.concat(cmd, ' ')
  local err = (sys_obj.stderr and sys_obj.stderr ~= '') and sys_obj.stderr
    or ('Error when running `%s`'):format(cmd_str)

  if sys_obj.code ~= 0 then
    vim.notify(err, ERROR)
    return
  end
  if opts.verbose then
    if sys_obj.stdout and sys_obj.stdout ~= '' then
      Util.open_float(Util.trim_output(sys_obj.stdout), {
        height = Config.opts.output.height,
        width = Config.opts.output.width,
        title = cmd_str,
        zindex = Config.opts.output.zindex,
      })
      return
    end
    vim.notify(('(%s): No output given!'):format(cmd_str), INFO)
  end
end

---@param opts? Pipenv.RequirementsOpts
function M.requirements(opts)
  if vim.g.pipenv_setup ~= 1 then
    vim.notify('pipenv.nvim is not configured!', ERROR)
    return
  end
  if not has_pipfile() then
    return
  end

  Util.validate({
    opts = { opts, { 'table', 'nil' }, true },
  })
  opts = opts or {}

  Util.validate({
    dev = { opts.dev, { 'boolean', 'nil' }, true },
    file = { opts.file, { 'string', 'table', 'nil' }, true },
  })
  opts.dev = opts.dev ~= nil and opts.dev or false
  opts.file = opts.file or nil

  local cmd = { 'pipenv', 'requirements' }
  if opts.dev then
    table.insert(cmd, '--dev')
  end

  local sys_obj = run_cmd(cmd)
  local cmd_str = table.concat(cmd, ' ')
  local err = (sys_obj.stderr and sys_obj.stderr ~= '') and sys_obj.stderr
    or ('Error when running `%s`'):format(cmd_str)

  if sys_obj.code ~= 0 then
    vim.notify(err, ERROR)
    return
  end

  if not sys_obj.stdout or sys_obj.stdout == '' then
    vim.notify(('(%s): No output given!'):format(cmd_str), INFO)
    return
  end

  sys_obj.stdout = Util.trim_output(sys_obj.stdout)

  if not opts.file or opts.file == '' then
    Util.open_float(sys_obj.stdout, {
      ft = 'requirements',
      height = Config.opts.output.height,
      width = Config.opts.output.width,
      title = cmd_str,
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
    vim.fn.writefile(
      vim.split(sys_obj.stdout, '\n', { plain = true, trimempty = false }),
      opts.file
    ) == -1
  then
    vim.notify(('(%s): Unable to write to `%s`!'):format(cmd_str, opts.file), ERROR)
  end
end

local Api = setmetatable(M, { ---@type Pipenv.API
  __index = M,
  __newindex = function()
    vim.notify('Pipenv module is read-only!', ERROR)
  end,
})

return Api
-- vim: set ts=2 sts=2 sw=2 et ai si sta:
