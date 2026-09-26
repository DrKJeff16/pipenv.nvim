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
  require('pipenv.util').validate({ opts = { opts, { 'table', 'nil' }, true } })
  if require('pipenv.util').executable('pipenv') then
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

    if require('pipenv.util').mod_exists('pipenv.' .. k) then
      return require('pipenv.util').rawset(self, k, require('pipenv.' .. k))
    end
    if k == 'clean' then
      return require('pipenv.util').rawset(self, k, require('pipenv.core').clean)
    end
    if k == 'graph' then
      return require('pipenv.util').rawset(self, k, require('pipenv.core').graph)
    end
    if k == 'edit' then
      return require('pipenv.util').rawset(self, k, require('pipenv.core').edit)
    end
    if k == 'install' then
      return require('pipenv.util').rawset(self, k, require('pipenv.core').install)
    end
    if k == 'list_installed' then
      return require('pipenv.util').rawset(self, k, require('pipenv.core').list_installed)
    end
    if k == 'list_scripts' then
      return require('pipenv.util').rawset(self, k, require('pipenv.core').list_scripts)
    end
    if k == 'lock' then
      return require('pipenv.util').rawset(self, k, require('pipenv.core').lock)
    end
    if k == 'requirements' then
      return require('pipenv.util').rawset(self, k, require('pipenv.core').requirements)
    end
    if k == 'run' then
      return require('pipenv.util').rawset(self, k, require('pipenv.core').run)
    end
    if k == 'scripts' then
      return require('pipenv.util').rawset(self, k, require('pipenv.core').scripts)
    end
    if k == 'sync' then
      return require('pipenv.util').rawset(self, k, require('pipenv.core').sync)
    end
    if k == 'uninstall' then
      return require('pipenv.util').rawset(self, k, require('pipenv.core').uninstall)
    end
    if k == 'update' then
      return require('pipenv.util').rawset(self, k, require('pipenv.core').update)
    end
    if k == 'upgrade' then
      return require('pipenv.util').rawset(self, k, require('pipenv.core').upgrade)
    end
    if k == 'verify' then
      return require('pipenv.util').rawset(self, k, require('pipenv.core').verify)
    end
  end,
})

return Pipenv
-- vim: set ts=2 sts=2 sw=2 et ai si sta:
