---@class PipenvOpts
---@field auto_detect? boolean
---@field python_version? string|nil

local Util = require('pipenv.util')

---@class Pipenv.Config
local M = {}

---@return PipenvOpts defaults
function M.get_defaults()
  return { ---@type PipenvOpts
    auto_detect = true,
    python_version = nil,
  }
end

---@param opts PipenvOpts
---@overload fun()
function M.setup(opts)
  Util.validate({ opts = { opts, { 'table', 'nil' }, true } })

  -- TODO: Actually use these options in the codebase
  M.config = vim.tbl_deep_extend('keep', opts or {}, M.get_defaults())

  vim.g.pipenv_setup = 1
end

return M
-- vim: set ts=2 sts=2 sw=2 et ai si sta:
