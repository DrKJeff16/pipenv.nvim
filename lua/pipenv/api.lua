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
---@class Pipenv.VerifyOpts: Pipenv.CommandOpts

---@class PipenvJsonPackage
---@field key string
---@field package_name string
---@field installed_version string

---@alias PipenvJsonGraph table<'package', PipenvJsonPackage>

local Util = require('pipenv.util')
local uv = vim.uv or vim.loop
local ERROR = vim.log.levels.ERROR
local INFO = vim.log.levels.INFO

---@class Pipenv.API
local M = {}

---@return string[] installed
function M.retrieve_installed()
  local sys_obj = vim.system({ 'pipenv', 'graph', '--json' }):wait(200000)
  if sys_obj.code ~= 0 then
    error(sys_obj.stderr or 'Could not parse JSON graph!', ERROR)
  end
  if not sys_obj.stdout or sys_obj.stdout == '' then
    error(sys_obj.stderr or 'Could not parse JSON graph!', ERROR)
  end

  ---@type boolean, PipenvJsonGraph[]|nil
  local ok, data = pcall(vim.json.decode, Util.trim_output_header(sys_obj.stdout))
  if not ok then
    error('Could not parse JSON graph!', ERROR)
  end

  ---@cast data PipenvJsonGraph[]
  local installed = {} ---@type string[]
  for _, pkg in ipairs(data) do
    if pkg.package.package_name and not vim.list_contains(installed, pkg.package.package_name) then
      table.insert(installed, pkg.package.package_name)
    end
  end

  return installed
end

function M.list_installed()
  Util.split_output(table.concat(M.retrieve_installed(), '\n'))
end

---@param opts? Pipenv.LockOpts
function M.lock(opts)
  Util.validate({ opts = { opts, { 'table', 'nil' }, true } })
  opts = opts or {}

  Util.validate({ verbose = { opts.verbose, { 'boolean', 'nil' }, true } })
  opts.verbose = opts.verbose ~= nil and opts.verbose or false

  local sys_obj = vim.system({ 'pipenv', 'lock' }):wait(200000)
  if sys_obj.code ~= 0 then
    if sys_obj.stderr and sys_obj.stderr ~= '' then
      vim.notify(sys_obj.stderr, ERROR)
    end
    return
  end
  if opts.verbose then
    if sys_obj.stdout and sys_obj.stdout ~= '' then
      Util.split_output(Util.trim_output_header(sys_obj.stdout), { title = 'pipenv lock' })
      return
    end
    vim.notify('(pipenv lock): No output given!', INFO)
  end
end

---@param opts? Pipenv.CleanOpts
function M.clean(opts)
  Util.validate({ opts = { opts, { 'table', 'nil' }, true } })
  opts = opts or {}

  Util.validate({ verbose = { opts.verbose, { 'boolean', 'nil' }, true } })
  opts.verbose = opts.verbose ~= nil and opts.verbose or false

  local sys_obj = vim.system({ 'pipenv', 'clean' }):wait(200000)
  if sys_obj.code ~= 0 then
    if sys_obj.stderr and sys_obj.stderr ~= '' then
      vim.notify(sys_obj.stderr, ERROR)
    end
    return
  end
  if opts.verbose then
    if sys_obj.stdout and sys_obj.stdout ~= '' then
      Util.split_output(Util.trim_output_header(sys_obj.stdout), { title = 'pipenv clean' })
      return
    end
    vim.notify('(pipenv clean): No output given!', INFO)
  end
end

---@param opts? Pipenv.VerifyOpts
function M.verify(opts)
  Util.validate({ opts = { opts, { 'table', 'nil' }, true } })
  opts = opts or {}

  Util.validate({ verbose = { opts.verbose, { 'boolean', 'nil' }, true } })
  opts.verbose = opts.verbose ~= nil and opts.verbose or false

  local sys_obj = vim.system({ 'pipenv', 'verify' }):wait(200000)
  if sys_obj.code ~= 0 then
    if sys_obj.stderr and sys_obj.stderr ~= '' then
      vim.notify(sys_obj.stderr, ERROR)
    end
    return
  end
  if opts.verbose then
    if sys_obj.stdout and sys_obj.stdout ~= '' then
      Util.split_output(Util.trim_output_header(sys_obj.stdout), { title = 'pipenv verify' })
      return
    end
    vim.notify('(pipenv clean): No output given!', INFO)
  end
end

---@param opts? Pipenv.SyncOpts
function M.sync(opts)
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

  local sys_obj = vim.system(cmd):wait(200000)
  if sys_obj.code ~= 0 then
    if sys_obj.stderr and sys_obj.stderr ~= '' then
      vim.notify(sys_obj.stderr, ERROR)
    end
    return
  end
  if opts.verbose then
    if sys_obj.stdout and sys_obj.stdout ~= '' then
      Util.split_output(Util.trim_output_header(sys_obj.stdout), { title = table.concat(cmd, ' ') })
      return
    end
    vim.notify(('(%s): No output given!'):format(table.concat(cmd, ' ')), INFO)
  end
end

---@param packages? string[]|string|nil
---@param opts? Pipenv.InstallOpts
function M.install(packages, opts)
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

  local sys_obj = vim.system(cmd):wait(200000)
  if sys_obj.code ~= 0 then
    if sys_obj.stderr and sys_obj.stderr ~= '' then
      vim.notify(sys_obj.stderr, ERROR)
    end
    return
  end
  if opts.verbose then
    if sys_obj.stdout and sys_obj.stdout ~= '' then
      Util.split_output(Util.trim_output_header(sys_obj.stdout), { title = table.concat(cmd, ' ') })
      return
    end
    vim.notify(('(%s): No output given!'):format(table.concat(cmd, ' ')), INFO)
  end
end

---@param command string[]|string
---@param opts? Pipenv.RunOpts
function M.run(command, opts)
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

  local sys_obj = vim.system(cmd):wait(200000)
  if sys_obj.code ~= 0 then
    if sys_obj.stderr and sys_obj.stderr ~= '' then
      vim.notify(sys_obj.stderr, ERROR)
    end
    return
  end
  if opts.verbose then
    if sys_obj.stdout and sys_obj.stdout ~= '' then
      Util.split_output(Util.trim_output_header(sys_obj.stdout), { title = table.concat(cmd, ' ') })
      return
    end
    vim.notify(('(%s): No output given!'):format(table.concat(cmd, ' ')), INFO)
  end
end

---@param opts? Pipenv.RequirementsOpts
function M.requirements(opts)
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

  local sys_obj = vim.system(cmd):wait(200000)
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

  sys_obj.stdout = Util.trim_output_header(sys_obj.stdout)

  if not opts.file or opts.file == '' then
    Util.split_output(sys_obj.stdout, { title = table.concat(cmd, ' '), ft = 'requirements' })
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
