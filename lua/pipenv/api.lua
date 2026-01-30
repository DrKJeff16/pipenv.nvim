local util = require('pipenv.util')
local uv = vim.uv or vim.loop
local INFO = vim.log.levels.INFO
local ERROR = vim.log.levels.ERROR

---@class Pipenv.API
local M = {}

---@param verbose? boolean
function M.lock(verbose)
  util.validate({ verbose = { verbose, { 'boolean', 'nil' }, true } })
  verbose = verbose ~= nil and verbose or false

  local msg, err = '', ''
  local success = true ---@type boolean
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
    if msg ~= '' and verbose then
      vim.notify(msg, INFO)
    end
    return
  end

  if err ~= '' then
    vim.notify(err, ERROR)
  end
end

---@param verbose? boolean
function M.clean(verbose)
  util.validate({ verbose = { verbose, { 'boolean', 'nil' }, true } })
  verbose = verbose ~= nil and verbose or false

  local msg, err = '', ''
  local success = true ---@type boolean
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
    if msg ~= '' and verbose then
      vim.notify(msg, INFO)
    end
    return
  end

  if err ~= '' then
    vim.notify(err, ERROR)
  end
end

---@param dev? boolean
---@param verbose? boolean
function M.sync(dev, verbose)
  util.validate({
    dev = { dev, { 'boolean', 'nil' }, true },
    verbose = { verbose, { 'boolean', 'nil' }, true },
  })
  dev = dev ~= nil and dev or false
  verbose = verbose ~= nil and verbose or false

  local cmd = { 'pipenv', 'sync' }
  if dev then
    table.insert(cmd, '--dev')
  end

  local msg, err = '', ''
  local success = true ---@type boolean
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
    if msg ~= '' and verbose then
      vim.notify(msg, INFO)
    end
    return
  end

  if err ~= '' then
    vim.notify(err, ERROR)
  end
end

---@param packages? string[]|string|nil
---@param dev? boolean
---@param verbose? boolean
function M.install(packages, dev, verbose)
  util.validate({
    packages = { packages, { 'string', 'table', 'nil' }, true },
    dev = { dev, { 'boolean', 'nil' }, true },
    verbose = { verbose, { 'boolean', 'nil' }, true },
  })
  packages = packages or nil
  dev = dev ~= nil and dev or false
  verbose = verbose ~= nil and verbose or false

  local cmd = { 'pipenv', 'install' }
  if dev then
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

  local msg, err = '', ''
  local success = true ---@type boolean
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
    if msg ~= '' and verbose then
      vim.notify(msg, INFO)
    end
    return
  end

  if err ~= '' then
    vim.notify(err, ERROR)
  end
end

---@param command string[]|string
---@param verbose? boolean
function M.run(command, verbose)
  util.validate({
    command = { command, { 'string', 'table' } },
    verbose = { verbose, { 'boolean', 'nil' }, true },
  })
  verbose = verbose ~= nil and verbose or false

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

  local msg, err = '', ''
  local success = true ---@type boolean
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
    if msg ~= '' and verbose then
      vim.notify(msg, INFO)
    end
    return
  end

  if err ~= '' then
    vim.notify(err, ERROR)
  end
end

---@param file? string[]|string|nil
---@param dev? boolean
function M.requirements(file, dev)
  util.validate({
    file = { file, { 'string', 'table', 'nil' }, true },
    dev = { dev, { 'boolean', 'nil' }, true },
  })
  file = file or nil
  dev = dev ~= nil and dev or false

  local cmd = { 'pipenv', 'requirements' }
  if dev then
    table.insert(cmd, '--dev')
  end

  local msg, err = '', ''
  local success = true ---@type boolean
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
