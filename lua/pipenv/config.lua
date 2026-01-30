---@class PipenvOpts.Output
---Can be a number between `0` and `1` (percentage) or a fixed width
---@field width? number
---Can be a number between `0` and `1` (percentage) or a fixed height
---@field height? number

---@class PipenvOpts
---@field output? PipenvOpts.Output

local Util = require('pipenv.util')

---@class Pipenv.Config
local M = {}

---@return PipenvOpts defaults
function M.get_defaults()
  return { ---@type PipenvOpts
    output = { width = 0.85, height = 0.85 },
  }
end

---@param opts PipenvOpts
---@overload fun()
function M.setup(opts)
  Util.validate({ opts = { opts, { 'table', 'nil' }, true } })

  M.config = vim.tbl_deep_extend('keep', opts or {}, M.get_defaults())
  vim.g.pipenv_setup = 1
end

return M
-- vim: set ts=2 sts=2 sw=2 et ai si sta:
