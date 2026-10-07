local Util = require('pipenv.util')

---@class Pipenv
---@field clean fun(opts?: Pipenv.CleanOpts, cmd_opts?: Pipenv.CommandOpts)
---@field commands Pipenv.Commands
---@field config Pipenv.Config
---@field core Pipenv.Core
---@field edit function
---@field graph fun(opts?: Pipenv.GraphOpts, cmd_opts?: Pipenv.CommandOpts)
---@field health Pipenv.Health
---@field install fun(packages?: string[]|string, opts?: Pipenv.InstallOpts, cmd_opts?: Pipenv.CommandOpts)
---@field list_installed function
---@field list_scripts function
---@field lock fun(opts?: Pipenv.LockOpts, cmd_opts?: Pipenv.CommandOpts)
---@field requirements fun(opts?: Pipenv.RequirementsOpts, cmd_opts?: Pipenv.CommandOpts)
---@field run fun(command: string[]|string, opts?: Pipenv.RunOpts, cmd_opts?: Pipenv.CommandOpts)
---@field scripts fun(opts?: Pipenv.ScriptsOpts, cmd_opts?: Pipenv.CommandOpts)
---@field sync fun(opts?: Pipenv.SyncOpts, cmd_opts?: Pipenv.CommandOpts)
---@field uninstall fun(packages: string[]|string, opts?: Pipenv.UninstallOpts, cmd_opts?: Pipenv.CommandOpts)
---@field update fun(opts?: Pipenv.UpgradeOpts, cmd_opts?: Pipenv.CommandOpts)
---@field upgrade fun(opts?: Pipenv.UpgradeOpts, cmd_opts?: Pipenv.CommandOpts)
---@field util Pipenv.Util
---@field verify fun(opts?: Pipenv.VerifyOpts, cmd_opts?: Pipenv.CommandOpts)
local M = {}

---@param opts? PipenvOpts
function M.setup(opts)
  Util.validate({ opts = { opts, { 'table', 'nil' }, true } })
  if Util.executable('pipenv') then
    require('pipenv.config').setup(opts or {})
    if vim.g.pipenv_setup == 1 then
      require('pipenv.commands').setup()
    end
  else
    vim.notify('Pipenv not found in your PATH!', vim.log.levels.ERROR)
  end
end

local Pipenv = setmetatable(M, { ---@type Pipenv
  ---@param self Pipenv
  ---@param k string|integer
  __index = function(self, k)
    local raw = rawget(self, k) or nil
    if raw then
      return raw
    end

    if Util.mod_exists('pipenv.' .. k) then
      return Util.rawset(self, k, require('pipenv.' .. k))
    end

    local Core = require('pipenv.core')
    if k == 'clean' then
      return Util.rawset(self, k, Core.clean)
    end
    if k == 'graph' then
      return Util.rawset(self, k, Core.graph)
    end
    if k == 'edit' then
      return Util.rawset(self, k, Core.edit)
    end
    if k == 'install' then
      return Util.rawset(self, k, Core.install)
    end
    if k == 'list_installed' then
      return Util.rawset(self, k, Core.list_installed)
    end
    if k == 'list_scripts' then
      return Util.rawset(self, k, Core.list_scripts)
    end
    if k == 'lock' then
      return Util.rawset(self, k, Core.lock)
    end
    if k == 'requirements' then
      return Util.rawset(self, k, Core.requirements)
    end
    if k == 'run' then
      return Util.rawset(self, k, Core.run)
    end
    if k == 'scripts' then
      return Util.rawset(self, k, Core.scripts)
    end
    if k == 'sync' then
      return Util.rawset(self, k, Core.sync)
    end
    if k == 'uninstall' then
      return Util.rawset(self, k, Core.uninstall)
    end
    if k == 'update' then
      return Util.rawset(self, k, Core.update)
    end
    if k == 'upgrade' then
      return Util.rawset(self, k, Core.upgrade)
    end
    if k == 'verify' then
      return Util.rawset(self, k, Core.verify)
    end
  end,
})

return Pipenv
-- vim: set ts=2 sts=2 sw=2 et ai si sta:
