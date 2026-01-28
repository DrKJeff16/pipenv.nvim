---@class PipenvOpts
---@field auto_detect? boolean

local util = require('pipenv.util')

---@class Pipenv.Config
local M = {}

---@return PipenvOpts defaults
function M.get_defaults()
  return { ---@type PipenvOpts
    auto_detect = true,
  }
end

---@param opts PipenvOpts
---@overload fun()
function M.setup(opts)
  util.validate({ opts = { opts, { 'table', 'nil' }, true } })

  M.config = vim.tbl_deep_extend('keep', opts or {}, M.get_defaults())

  vim.g.pipenv_setup = 1
end

return M
-- vim: set ts=2 sts=2 sw=2 et ai si sta:
