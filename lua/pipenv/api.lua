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

---@param cmd string[]
---@param timeout? integer
---@return vim.SystemCompleted sys_obj
local function run_cmd(cmd, timeout)
  Util.validate({
    cmd = { cmd, { 'table' } },
    timeout = { timeout, { 'number', 'nil' }, true },
  })
  timeout = (timeout and Util.is_int(timeout)) and timeout or 300000

  return vim.system(cmd, { text = true }):wait(timeout)
end

---@class Pipenv.API
local M = {}

function M.edit()
  if vim.g.pipenv_setup ~= 1 then
    vim.notify('pipenv.nvim is not configured!', ERROR)
    return
  end

  local target = './Pipfile'
  if vim.fn.filereadable(target) ~= 1 then
    if vim.fn.confirm('No Pipfile found. Create?', '&Yes\n&No', 2) ~= 1 then
      return
    end
    if not vim.fn.writefile({}, target) ~= 0 then
      vim.notify('Could not create Pipfile!', WARN)
      return
    end
  end

  vim.cmd.tabedit(target)
  vim.schedule(function()
    local bufnr = vim.api.nvim_get_current_buf()
    local tab = vim.api.nvim_get_current_tabpage()
    vim.keymap.set('n', 'q', function()
      pcall(vim.api.nvim_buf_delete, bufnr, { force = true })
      pcall(vim.api.nvim_cmd, { cmd = 'tabclose', range = { tab } }, { output = false })
    end, { buffer = bufnr })
  end)
end

---@return string[] installed
function M.retrieve_installed()
  local sys_obj = run_cmd({ 'pipenv', 'graph', '--json' })
  if sys_obj.code ~= 0 then
    error(sys_obj.stderr or 'Could not parse JSON graph!', ERROR)
  end
  if not sys_obj.stdout or sys_obj.stdout == '' then
    error(sys_obj.stderr or 'Could not parse JSON graph!', ERROR)
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

  Util.open_float(table.concat(M.retrieve_installed(), '\n'), {
    title = 'Installed Packages',
    height = Config.config.output.height,
    width = Config.config.output.width,
  })
end

function M.graph()
  if vim.g.pipenv_setup ~= 1 then
    vim.notify('pipenv.nvim is not configured!', ERROR)
    return
  end

  local sys_obj = run_cmd({ 'pipenv', 'graph' })
  if sys_obj.code ~= 0 then
    if sys_obj.stderr and sys_obj.stderr ~= '' then
      vim.notify(sys_obj.stderr, ERROR)
    end
    return
  end
  if sys_obj.stdout and sys_obj.stdout ~= '' then
    Util.open_float(Util.trim_output(sys_obj.stdout), {
      title = 'pipenv graph',
      height = Config.config.output.height,
      width = Config.config.output.width,
    })
    return
  end
  vim.notify('(pipenv graph): No output given!', INFO)
end

---@param opts? Pipenv.LockOpts
function M.lock(opts)
  Util.validate({ opts = { opts, { 'table', 'nil' }, true } })
  opts = opts or {}

  Util.validate({ verbose = { opts.verbose, { 'boolean', 'nil' }, true } })
  opts.verbose = opts.verbose ~= nil and opts.verbose or false

  local sys_obj = run_cmd({ 'pipenv', 'lock' })
  if sys_obj.code ~= 0 then
    if sys_obj.stderr and sys_obj.stderr ~= '' then
      vim.notify(sys_obj.stderr, ERROR)
    end
    return
  end
  if opts.verbose then
    if sys_obj.stdout and sys_obj.stdout ~= '' then
      Util.open_float(Util.trim_output(sys_obj.stdout), {
        title = 'pipenv lock',
        height = Config.config.output.height,
        width = Config.config.output.width,
      })
      return
    end
    vim.notify('(pipenv lock): No output given!', INFO)
  end
end

---@param opts? Pipenv.CleanOpts
function M.clean(opts)
  if vim.g.pipenv_setup ~= 1 then
    vim.notify('pipenv.nvim is not configured!', ERROR)
    return
  end

  Util.validate({ opts = { opts, { 'table', 'nil' }, true } })
  opts = opts or {}

  Util.validate({ verbose = { opts.verbose, { 'boolean', 'nil' }, true } })
  opts.verbose = opts.verbose ~= nil and opts.verbose or false

  local sys_obj = run_cmd({ 'pipenv', 'clean' })
  if sys_obj.code ~= 0 then
    if sys_obj.stderr and sys_obj.stderr ~= '' then
      vim.notify(sys_obj.stderr, ERROR)
    end
    return
  end
  if opts.verbose then
    if sys_obj.stdout and sys_obj.stdout ~= '' then
      Util.open_float(Util.trim_output(sys_obj.stdout), {
        title = 'pipenv clean',
        height = Config.config.output.height,
        width = Config.config.output.width,
      })
      return
    end
    vim.notify('(pipenv clean): No output given!', INFO)
  end
end

---@param opts? Pipenv.VerifyOpts
function M.verify(opts)
  if vim.g.pipenv_setup ~= 1 then
    vim.notify('pipenv.nvim is not configured!', ERROR)
    return
  end

  Util.validate({ opts = { opts, { 'table', 'nil' }, true } })
  opts = opts or {}

  Util.validate({ verbose = { opts.verbose, { 'boolean', 'nil' }, true } })
  opts.verbose = opts.verbose ~= nil and opts.verbose or false

  local sys_obj = run_cmd({ 'pipenv', 'verify' })
  if sys_obj.code ~= 0 then
    if sys_obj.stderr and sys_obj.stderr ~= '' then
      vim.notify(sys_obj.stderr, ERROR)
    end
    return
  end
  if opts.verbose then
    if sys_obj.stdout and sys_obj.stdout ~= '' then
      Util.open_float(Util.trim_output(sys_obj.stdout), {
        title = 'pipenv verify',
        height = Config.config.output.height,
        width = Config.config.output.width,
      })
      return
    end
    vim.notify('(pipenv clean): No output given!', INFO)
  end
end

---@param opts? Pipenv.SyncOpts
function M.sync(opts)
  if vim.g.pipenv_setup ~= 1 then
    vim.notify('pipenv.nvim is not configured!', ERROR)
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
  if sys_obj.code ~= 0 then
    if sys_obj.stderr and sys_obj.stderr ~= '' then
      vim.notify(sys_obj.stderr, ERROR)
    end
    return
  end
  if opts.verbose then
    if sys_obj.stdout and sys_obj.stdout ~= '' then
      Util.open_float(Util.trim_output(sys_obj.stdout), {
        title = table.concat(cmd, ' '),
        height = Config.config.output.height,
        width = Config.config.output.width,
      })
      return
    end
    vim.notify(('(%s): No output given!'):format(table.concat(cmd, ' ')), INFO)
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
  if sys_obj.code ~= 0 then
    if sys_obj.stderr and sys_obj.stderr ~= '' then
      vim.notify(sys_obj.stderr, ERROR)
    end
    return
  end
  if opts.verbose then
    if sys_obj.stdout and sys_obj.stdout ~= '' then
      Util.open_float(Util.trim_output(sys_obj.stdout), {
        title = table.concat(cmd, ' '),
        height = Config.config.output.height,
        width = Config.config.output.width,
      })
      return
    end
    vim.notify(('(%s): No output given!'):format(table.concat(cmd, ' ')), INFO)
  end
end

---@param packages string[]|string
---@param opts? Pipenv.UninstallOpts
function M.uninstall(packages, opts)
  if vim.g.pipenv_setup ~= 1 then
    vim.notify('pipenv.nvim is not configured!', ERROR)
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
  if sys_obj.code ~= 0 then
    if sys_obj.stderr and sys_obj.stderr ~= '' then
      vim.notify(sys_obj.stderr, ERROR)
    end
    return
  end
  if opts.verbose then
    if sys_obj.stdout and sys_obj.stdout ~= '' then
      Util.open_float(Util.trim_output(sys_obj.stdout), {
        title = table.concat(cmd, ' '),
        height = Config.config.output.height,
        width = Config.config.output.width,
      })
      return
    end
    vim.notify(('(%s): No output given!'):format(table.concat(cmd, ' ')), INFO)
  end
end

---@param command string[]|string
---@param opts? Pipenv.RunOpts
function M.run(command, opts)
  if vim.g.pipenv_setup ~= 1 then
    vim.notify('pipenv.nvim is not configured!', ERROR)
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
  if sys_obj.code ~= 0 then
    if sys_obj.stderr and sys_obj.stderr ~= '' then
      vim.notify(sys_obj.stderr, ERROR)
    end
    return
  end
  if opts.verbose then
    if sys_obj.stdout and sys_obj.stdout ~= '' then
      Util.open_float(Util.trim_output(sys_obj.stdout), {
        title = table.concat(cmd, ' '),
        height = Config.config.output.height,
        width = Config.config.output.width,
      })
      return
    end
    vim.notify(('(%s): No output given!'):format(table.concat(cmd, ' ')), INFO)
  end
end

---@param opts? Pipenv.RequirementsOpts
function M.requirements(opts)
  if vim.g.pipenv_setup ~= 1 then
    vim.notify('pipenv.nvim is not configured!', ERROR)
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
  if sys_obj.code ~= 0 then
    if sys_obj.stderr and sys_obj.stderr ~= '' then
      vim.notify(sys_obj.stderr, ERROR)
    end
    return
  end

  if not sys_obj.stdout or sys_obj.stdout == '' then
    vim.notify(('(%s): No output given!'):format(table.concat(cmd, ' ')), INFO)
    return
  end

  sys_obj.stdout = Util.trim_output(sys_obj.stdout)

  if not opts.file or opts.file == '' then
    Util.open_float(sys_obj.stdout, {
      title = table.concat(cmd, ' '),
      ft = 'requirements',
      height = Config.config.output.height,
      width = Config.config.output.width,
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
    vim.notify(('(pipenv requirements): Unable to write to `%s`!'):format(opts.file), ERROR)
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
