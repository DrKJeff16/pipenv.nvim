local INFO = vim.log.levels.INFO
local ERROR = vim.log.levels.ERROR
local util = require('pipenv.util')
local config = require('pipenv.config')

---@class Pipenv
local M = {}

---@param opts PipenvOpts
---@overload fun()
function M.setup(opts)
  util.validate({ opts = { opts, { 'table', 'nil' }, true } })

  if not util.executable('pipenv') then
    error('Pipenv not found in your path!', ERROR)
  end

  config.setup(opts or {})
end

---@param verbose boolean
---@overload fun()
function M.lock(verbose)
  util.validate({ verbose = { verbose, { 'boolean', 'nil' }, true } })
  verbose = verbose ~= nil and verbose or false

  local msg, err = '', ''
  local success ---@type boolean
  vim.system({ 'pipenv', 'lock' }, function(out)
    if out.code ~= 0 then
      if out.stderr and out.stderr ~= '' then
        err = out.stderr
      end
      success = false
      return
    end
    if out.stdout and out.stdout ~= '' then
      msg = out.stdout
      return
    end
  end)

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

---@param dev boolean|nil
---@param verbose boolean
---@overload fun()
---@overload fun(dev: boolean)
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
  local success ---@type boolean
  vim.system(cmd, function(out)
    if out.code ~= 0 then
      if out.stderr and out.stderr ~= '' then
        err = out.stderr
      end
      success = false
      return
    end
    if out.stdout and out.stdout ~= '' then
      msg = out.stdout
      return
    end
  end)

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

return M
-- vim: set ts=2 sts=2 sw=2 et ai si sta:
