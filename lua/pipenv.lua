local ERROR = vim.log.levels.ERROR
local util = require('pipenv.util')
local config = require('pipenv.config')
local api = require('pipenv.api')

---@class Pipenv
local M = {}

---@param opts? PipenvOpts
function M.setup(opts)
  util.validate({ opts = { opts, { 'table', 'nil' }, true } })

  if not util.executable('pipenv') then
    error('Pipenv not found in your PATH!', ERROR)
  end

  config.setup(opts or {})

  require('pipenv.commands').setup()
end

M.lock = api.lock
M.install = api.install
M.sync = api.sync
M.run = api.run
M.requirements = api.requirements
M.clean = api.clean
M.verify = api.verify

local Pipenv = setmetatable(M, { ---@type Pipenv
  __index = M,
  __newindex = function()
    vim.notify('Pipenv module is read-only!', ERROR)
  end,
})

return Pipenv
-- vim: set ts=2 sts=2 sw=2 et ai si sta:
