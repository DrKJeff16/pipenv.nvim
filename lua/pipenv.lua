local ERROR = vim.log.levels.ERROR
local Util = require('pipenv.util')
local Config = require('pipenv.config')
local Api = require('pipenv.api')

---@class Pipenv
local M = {}

---@param opts? PipenvOpts
function M.setup(opts)
  Util.validate({ opts = { opts, { 'table', 'nil' }, true } })

  if not Util.executable('pipenv') then
    error('Pipenv not found in your PATH!', ERROR)
  end

  Config.setup(opts or {})

  require('pipenv.commands').setup()
end

M.clean = Api.clean
M.graph = Api.graph
M.install = Api.install
M.list_installed = Api.list_installed
M.lock = Api.lock
M.requirements = Api.requirements
M.run = Api.run
M.sync = Api.sync
M.uninstall = Api.uninstall
M.verify = Api.verify

local Pipenv = setmetatable(M, { ---@type Pipenv
  __index = M,
  __newindex = function()
    vim.notify('Pipenv module is read-only!', ERROR)
  end,
})

return Pipenv
-- vim: set ts=2 sts=2 sw=2 et ai si sta:
