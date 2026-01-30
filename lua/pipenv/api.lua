---@class Pipenv.CommandOpts
---@field verbose? boolean

---@class Pipenv.LockOpts: Pipenv.CommandOpts
---@class Pipenv.CleanOpts: Pipenv.CommandOpts
---@class Pipenv.RunOpts: Pipenv.CommandOpts

---@class Pipenv.SyncOpts: Pipenv.CommandOpts
---@field dev? boolean

---@class Pipenv.RequirementsOpts
---@field dev? boolean

---@class Pipenv.InstallOpts: Pipenv.SyncOpts

local util = require('pipenv.util')
local uv = vim.uv or vim.loop
local INFO = vim.log.levels.INFO
local ERROR = vim.log.levels.ERROR

---@class Pipenv.API
local M = {}

---@param opts? Pipenv.LockOpts
function M.lock(opts)
  util.validate({ opts = { opts, { 'table', 'nil' }, true } })
  opts = opts or {}

  util.validate({ verbose = { opts.verbose, { 'boolean', 'nil' }, true } })
  opts.verbose = opts.verbose ~= nil and opts.verbose or false

  local success, msg, err = true, '', ''
  vim
    .system({ 'pipenv', 'lock' }, function(out)
      if out.code ~= 0 then
        if out.stderr and out.stderr ~= '' then
          err = out.stderr
        end
        success = false
        return
      end
      if out.stdout and out.stdout ~= '' then
        msg = out.stdout
      end
    end)
    :wait(200000)

  if success then
    if msg ~= '' and opts.verbose then
      vim.notify(msg, INFO)
    end
    return
  end

  if err ~= '' then
    vim.notify(err, ERROR)
  end
end

---@param opts? Pipenv.CleanOpts
function M.clean(opts)
  util.validate({ opts = { opts, { 'table', 'nil' }, true } })
  opts = opts or {}

  util.validate({ verbose = { opts.verbose, { 'boolean', 'nil' }, true } })
  opts.verbose = opts.verbose ~= nil and opts.verbose or false

  local success, msg, err = true, '', ''
  vim
    .system({ 'pipenv', 'clean' }, function(out)
      if out.code ~= 0 then
        if out.stderr and out.stderr ~= '' then
          err = out.stderr
        end
        success = false
        return
      end
      if out.stdout and out.stdout ~= '' then
        msg = out.stdout
      end
    end)
    :wait(200000)

  if success then
    if msg ~= '' and opts.verbose then
      vim.notify(msg, INFO)
    end
    return
  end

  if err ~= '' then
    vim.notify(err, ERROR)
  end
end

---@param opts? Pipenv.SyncOpts
function M.sync(opts)
  util.validate({ opts = { opts, { 'table', 'nil' }, true } })
  opts = opts or {}

  util.validate({
    dev = { opts.dev, { 'boolean', 'nil' }, true },
    verbose = { opts.verbose, { 'boolean', 'nil' }, true },
  })
  opts.dev = opts.dev ~= nil and opts.dev or false
  opts.verbose = opts.verbose ~= nil and opts.verbose or false

  local cmd = { 'pipenv', 'sync' }
  if opts.dev then
    table.insert(cmd, '--dev')
  end

  local success, msg, err = true, '', ''
  vim
    .system(cmd, function(out)
      if out.code ~= 0 then
        if out.stderr and out.stderr ~= '' then
          err = out.stderr
        end
        success = false
        return
      end
      if out.stdout and out.stdout ~= '' then
        msg = out.stdout
      end
    end)
    :wait(200000)

  if success then
    if msg ~= '' and opts.verbose then
      vim.notify(msg, INFO)
    end
    return
  end

  if err ~= '' then
    vim.notify(err, ERROR)
  end
end

---@param packages? string[]|string|nil
---@param opts? Pipenv.InstallOpts
function M.install(packages, opts)
  util.validate({
    packages = { packages, { 'string', 'table', 'nil' }, true },
    opts = { opts, { 'table', 'nil' }, true },
  })
  packages = packages or nil
  opts = opts or {}

  util.validate({
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
    if util.is_type('string', packages) then
      ---@cast packages string
      table.insert(cmd, packages)
    elseif not vim.tbl_isempty(packages) then
      ---@cast packages string[]
      for _, pkg in ipairs(packages) do
        if util.is_type('string', pkg) and pkg ~= '' then
          table.insert(cmd, pkg)
        end
      end
    else
      vim.notify('(pipenv install): Empty packages table!', ERROR)
      return
    end
  end

  local success, msg, err = true, '', ''
  vim
    .system(cmd, function(out)
      if out.code ~= 0 then
        if out.stderr and out.stderr ~= '' then
          err = out.stderr
        end
        success = false
        return
      end
      if out.stdout and out.stdout ~= '' then
        msg = out.stdout
      end
    end)
    :wait(200000)

  if success then
    if msg ~= '' and opts.verbose then
      vim.notify(msg, INFO)
    end
    return
  end

  if err ~= '' then
    vim.notify(err, ERROR)
  end
end

---@param command string[]|string
---@param opts? Pipenv.RunOpts
function M.run(command, opts)
  util.validate({
    command = { command, { 'string', 'table' } },
    opts = { opts, { 'table', 'nil' }, true },
  })
  opts = opts or {}

  util.validate({ verbose = { opts.verbose, { 'boolean', 'nil' }, true } })
  opts.verbose = opts.verbose ~= nil and opts.verbose or false

  local cmd = { 'pipenv', 'install' }
  if util.is_type('string', command) then
    ---@cast command string
    table.insert(cmd, command)
  elseif vim.tbl_isempty(command) then
    vim.notify('(pipenv run): Empty command table!')
    return
  else
    for _, c in ipairs(command) do
      table.insert(command, tostring(c))
    end
  end

  local success, msg, err = true, '', ''
  vim
    .system(cmd, function(out)
      if out.code ~= 0 then
        if out.stderr and out.stderr ~= '' then
          err = out.stderr
        end
        success = false
        return
      end
      if out.stdout and out.stdout ~= '' then
        msg = out.stdout
      end
    end)
    :wait(200000)

  if success then
    if msg ~= '' and opts.verbose then
      vim.notify(msg, INFO)
    end
    return
  end

  if err ~= '' then
    vim.notify(err, ERROR)
  end
end

---@param file? string[]|string|nil
---@param opts? Pipenv.RequirementsOpts
function M.requirements(file, opts)
  util.validate({
    file = { file, { 'string', 'table', 'nil' }, true },
    opts = { opts, { 'table', 'nil' }, true },
  })
  file = file or nil
  opts = opts or {}

  util.validate({ dev = { opts.dev, { 'boolean', 'nil' }, true } })
  opts.dev = opts.dev ~= nil and opts.dev or false

  local cmd = { 'pipenv', 'requirements' }
  if opts.dev then
    table.insert(cmd, '--dev')
  end

  local success, msg, err = true, '', ''
  vim
    .system(cmd, function(out)
      if out.code ~= 0 then
        if out.stderr and out.stderr ~= '' then
          err = out.stderr
        end
        success = false
        return
      end
      if out.stdout and out.stdout ~= '' then
        msg = out.stdout
      end
    end)
    :wait(200000)

  if not success then
    if err ~= '' then
      vim.notify(err, ERROR)
    end
    return
  end

  if not file or file == '' then
    vim.notify(msg, INFO)
    return
  end

  local stat = uv.fs_stat(file)
  if stat and stat.size ~= 0 then
    if vim.fn.confirm(("Overwrite '%s'?"):format(file), '&Yes\n&No', 2) ~= 1 then
      return
    end
  end

  if vim.fn.writefile(vim.split(msg, '\n', { plain = true, trimempty = false }), file) == -1 then
    vim.notify(('(pipenv requirements): Unable to write to `%s`!'):format(file), ERROR)
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
