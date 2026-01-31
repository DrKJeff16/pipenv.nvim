---@class PipenvOpts.Output
---Can be a number between `0` and `1` (percentage) or a fixed width.
--- ---
---@field width? number
---Can be a number between `0` and `1` (percentage) or a fixed height.
--- ---
---@field height? number
---The `zindex` value of the output window.
--- ---
---@field zindex? integer

---For more info see https://pipenv.pypa.io/en/latest/configuration.html#installation-and-dependencies
--- ---
---@class PipenvOpts.InstallAndDeps
---If `false` then `$PIPENV_INSTALL_DEPENDENCIES` will be set to `0`.
--- ---
---@field install_dependencies? boolean
---If `false` then `$PIPENV_RESOLVE_VCS` will be set to `0`.
--- ---
---@field resolve_vcs? boolean
---If `true` then `$PIPENV_SKIP_LOCK` will be set to `1`.
--- ---
---@field skip_lock? boolean
---If non-nil then `$PIPENV_PYPI_MIRROR` will be set to its value.
--- ---
---@field pypi_mirror? string
---Will set `$PIPENV_MAX_DEPTH` to its value.
--- ---
---@field max_depth? integer
---Will set `$PIPENV_INSTALL_TIMEOUT` to its value.
--- ---
---@field install_timeout? integer
---Will set `$PIPENV_TIMEOUT` to its value.
--- ---
---@field timeout? integer

---For more info see https://pipenv.pypa.io/en/latest/configuration.html#virtual-environment
--- ---
---@class PipenvOpts.VirtualEnv
---If `true` then `$PIPENV_IGNORE_VIRTUALENVS` will be set to `1`.
--- ---
---@field ignore_virtual_envs? boolean
---If non-nil then `$PIPENV_PYTHON` will be set to its value.
--- ---
---@field python_path? string
---If non-nil then `$PIPENV_DEFAULT_PYTHON_VERSION` will be set to its value.
--- ---
---@field python_version? string
---If `true` then `$PIPENV_VENV_IN_PROJECT` will be set to `1`.
--- ---
---@field venv_in_project? boolean
---If non-nil then `$PIPENV_CUSTOM_VENV_NAME` will be set to its value.
--- ---
---@field venv_name? string
---If non-nil then `$PIPENV_VIRTUALENV` will be set to its value.
--- ---
---@field venv_path? string

---For more info see https://pipenv.pypa.io/en/latest/configuration.html#security
--- ---
---@class PipenvOpts.Security
---If non-nil then `$PIPENV_PYUP_API_KEY` will be set to its value.
--- ---
---@field pyup_api_key? string

---For more info see https://pipenv.pypa.io/en/latest/configuration.html#file-locations
--- ---
---@class PipenvOpts.Behavior
---If `true` then `$PIPENV_DONT_LOAD_ENV` will be set to `1`.
--- ---
---@field no_load_env? boolean
---If `true` then `$PIPENV_DONT_USE_PYENV` will be set to `1`.
--- ---
---@field no_pyenv? boolean
---If `true` then `$PIPENV_DONT_USE_ASDF` will be set to `1`.
--- ---
---@field no_asdf? boolean
---If `true` then `$PIPENV_SHELL_FANCY` will be set to `1`.
--- ---
---@field fancy_shell? boolean
---If `true` then `$PIPENV_NOSPIN` will be set to `1`.
--- ---
---@field no_spin? boolean
---If `true` then `$PIPENV_QUIET` will be set to `1`.
--- ---
---@field quiet? boolean
---If `true` then `$PIPENV_VERBOSE` will be set to `1`.
--- ---
---@field verbose? boolean
---If `true` then `$PIPENV_YES` will be set to `1`.
--- ---
---@field auto_accept? boolean
---If `true` then `$PIPENV_IGNORE_PIPFILE` will be set to `1`.
--- ---
---@field ignore_pipfile? boolean
---Will set `$PIPENV_REQUESTS_TIMEOUT` to its value.
--- ---
---@field timeout? integer
---If `true` then `$PIPENV_CLEAR` will be set to `1`.
--- ---
---@field clear_cache? boolean
---If `true` then `$PIPENV_SITE_PACKAGES` will be set to `1`.
--- ---
---@field site_packages? boolean

---For more info see https://pipenv.pypa.io/en/latest/configuration.html#file-locations
--- ---
---@class PipenvOpts.FileLocations
---If non-nil then `$PIPENV_CACHE_DIR` will be set to its value.
--- ---
---@field cache_dir? string
---If non-nil then `$PIPENV_PIPFILE` will be set to its value.
--- ---
---@field pipfile_path? string
---If non-nil then `$PIPENV_DOTENV_LOCATION` will be set to its value.
--- ---
---@field dotenv_location? string

---@class PipenvOpts
---@field output? PipenvOpts.Output
---@field install? PipenvOpts.InstallAndDeps
---@field virtual_env? PipenvOpts.VirtualEnv
---@field file_location? PipenvOpts.FileLocations
---@field behavior? PipenvOpts.Behavior
---@field security? PipenvOpts.Security

local Util = require('pipenv.util')

---@class Pipenv.Config
---@field env table<string, string|number>
local M = {}

---@return PipenvOpts defaults
function M.get_defaults()
  return { ---@type PipenvOpts
    output = { width = 0.85, height = 0.85, zindex = 100 },
    install = {},
    virtual_env = {},
    file_location = {},
    security = {},
    behavior = {},
  }
end

function M.gen_env()
  ---@class Pipenv.EnvTypes
  ---@field install { type: 'string'|'boolean'|'number', var: string }
  ---@field virtual_env { type: 'string'|'boolean'|'number', var: string }
  ---@field file_location { type: 'string'|'boolean'|'number', var: string }
  ---@field behavior { type: 'string'|'boolean'|'number', var: string }
  ---@field security { type: 'string'|'boolean'|'number', var: string }
  local types = {
    install = {
      install_dependencies = { type = 'boolean', var = 'PIPENV_INSTALL_DEPENDENCIES' },
      install_timeout = { type = 'number', var = 'PIPENV_INSTALL_TIMEOUT' },
      max_depth = { type = 'number', var = 'PIPENV_MAX_DEPTH' },
      pypi_mirror = { type = 'string', var = 'PIPENV_PYPI_MIRROR' },
      resolve_vcs = { type = 'boolean', var = 'PIPENV_RESOLVE_VCS' },
      skip_lock = { type = 'boolean', var = 'PIPENV_SKIP_LOCK' },
      timeout = { type = 'number', var = 'PIPENV_TIMEOUT' },
    },
    virtual_env = {
      ignore_virtual_envs = { type = 'boolean', var = 'PIPENV_IGNORE_VIRTUALENVS' },
      python_path = { type = 'string', var = 'PIPENV_PYTHON' },
      python_version = { type = 'string', var = 'PIPENV_DEFAULT_PYTHON_VERSION' },
      venv_in_project = { type = 'boolean', var = 'PIPENV_VENV_IN_PROJECT' },
      venv_name = { type = 'string', var = 'PIPENV_CUSTOM_VENV_NAME' },
      venv_path = { type = 'string', var = 'PIPENV_VIRTUALENV' },
    },
    file_location = {
      cache_dir = { type = 'string', var = 'PIPENV_CACHE_DIR' },
      dotenv_location = { type = 'string', var = 'PIPENV_DOTENV_LOCATION' },
      pipfile_path = { type = 'string', var = 'PIPENV_PIPFILE' },
    },
    behavior = {
      auto_accept = { type = 'boolean', var = 'PIPENV_YES' },
      clear_cache = { type = 'boolean', var = 'PIPENV_CLEAR' },
      fancy_shell = { type = 'boolean', var = 'PIPENV_SHELL_FANCY' },
      ignore_pipfile = { type = 'boolean', var = 'PIPENV_IGNORE_PIPFILE' },
      no_asdf = { type = 'boolean', var = 'PIPENV_DONT_USE_ASDF' },
      no_load_env = { type = 'boolean', var = 'PIPENV_DONT_LOAD_ENV' },
      no_pyenv = { type = 'boolean', var = 'PIPENV_DONT_USE_PYENV' },
      no_spin = { type = 'boolean', var = 'PIPENV_NOSPIN' },
      quiet = { type = 'boolean', var = 'PIPENV_QUIET' },
      requests_timeout = { type = 'number', var = 'PIPENV_REQUESTS_TIMEOUT' },
      site_packages = { type = 'boolean', var = 'PIPENV_SITE_PACKAGES' },
      verbose = { type = 'boolean', var = 'PIPENV_VERBOSE' },
    },
    security = {
      pyup_api_key = { type = 'string', var = 'PIPENV_PYUP_API_KEY' },
    },
  }

  for key, T in pairs(types) do
    if M.opts[key] then
      for k, t in pairs(T) do
        if M.opts[key][k] ~= nil and type(M.opts[key][k]) == t.type then
          M.env[t.var] = t.type == 'boolean' and (M.opts[key][k] and 1 or 0) or M.opts[key][k]
        end
      end
    end
  end
end

---@param opts? PipenvOpts
function M.setup(opts)
  Util.validate({ opts = { opts, { 'table', 'nil' }, true } })

  M.opts = vim.tbl_deep_extend('keep', opts or {}, M.get_defaults())
  M.gen_env()

  vim.g.pipenv_setup = 1
end

return M
-- vim: set ts=2 sts=2 sw=2 et ai si sta:
