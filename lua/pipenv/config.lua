---@class PipenvOpts.Output
---Can be a number between `0` and `1` (percentage) or a fixed width.
--- ---
---Default: `0.85`
--- ---
---@field width? number
---Can be a number between `0` and `1` (percentage) or a fixed height.
--- ---
---Default: `0.85`
--- ---
---@field height? number
---The `zindex` value of the output window.
--- ---
---Default: `100`
--- ---
---@field zindex? integer

---@class PipenvOpts
---@field output? PipenvOpts.Output
---@field python_version? string|nil

local Util = require('pipenv.util')

---@class Pipenv.Config
local M = {}

---@return PipenvOpts defaults
function M.get_defaults()
  return { ---@type PipenvOpts
    output = { width = 0.85, height = 0.85, zindex = 100 },
    python_version = nil,
  }
end

function M.clean_setup_opts()
  local defaults = M.get_defaults()
  M.opts = Util.deep_clean(M.opts, vim.tbl_keys(defaults), defaults)
end

---@param opts? PipenvOpts
function M.setup(opts)
  Util.validate({ opts = { opts, { 'table', 'nil' }, true } })

  M.opts = vim.tbl_deep_extend('keep', opts or {}, M.get_defaults())
  M.clean_setup_opts()

  vim.g.pipenv_setup = 1
end

return M
-- vim: set ts=2 sts=2 sw=2 et ai si sta:
