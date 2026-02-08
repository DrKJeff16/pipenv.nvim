local ERROR = vim.log.levels.ERROR
local Util = require('pipenv.util')
local Config = require('pipenv.config')
local Core = require('pipenv.core')

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

M.clean = Core.clean
M.edit = Core.edit
M.graph = Core.graph
M.install = Core.install
M.list_installed = Core.list_installed
M.list_scripts = Core.list_scripts
M.lock = Core.lock
M.requirements = Core.requirements
M.run = Core.run
M.scripts = Core.scripts
M.sync = Core.sync
M.uninstall = Core.uninstall
M.update = Core.update
M.upgrade = Core.upgrade
M.verify = Core.verify

local Pipenv = setmetatable(M, { ---@type Pipenv
  __index = M,
  __newindex = function()
    vim.notify('Pipenv module is read-only!', ERROR)
  end,
})

return Pipenv
-- vim: set ts=2 sts=2 sw=2 et ai si sta:
