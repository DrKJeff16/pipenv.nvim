---@module 'pipenv._meta'

---@class PipenvOpts
---@field output? PipenvOpts.Output
---@field env? PipenvOpts.Env

local Util = require('pipenv.util')

---@class Pipenv.Config
local M = {}

M.env = {} ---@type table<string, string|number>

---@return PipenvOpts defaults
function M.get_defaults()
  return { ---@type PipenvOpts
    output = {
      float = true,
      split = 'right',
      border = 'single',
      width = 0.85,
      height = 0.85,
      zindex = 100,
    },
    env = {},
  }
end

function M.gen_env()
  M.opts.env = M.opts.env or {}
  if vim.tbl_isempty(M.opts.env) then
    return
  end

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
      pyup_api_key = { type = 'string', var = 'PIPENV_PYUP_Core_KEY' },
    },
  }

  local err = ''
  for key, T in pairs(types) do
    local category = M.opts.env[key] or {}
    if not vim.tbl_isempty(category) then
      for k, t in pairs(T) do
        if category[k] ~= nil and type(category[k]) == t.type then
          M.env[t.var] = t.type == 'boolean' and (category[k] and 1 or 0) or category[k]
        elseif category[k] ~= nil and type(category[k]) ~= t.type then
          err = ('%s%s- `env.%s.%s` is of incorrect type (`%s`). Ignoring.'):format(
            err,
            err == '' and '' or '\n',
            key,
            k,
            type(category[k])
          )
        end
      end
    end
  end

  if err ~= '' then
    vim.notify(err, vim.log.levels.ERROR)
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
