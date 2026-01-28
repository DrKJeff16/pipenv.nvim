local util = require('pipenv.util')

---@class Pipenv.Config
local M = {}

---@return PipenvOpts defaults
function M.get_defaults()
  return { ---@class PipenvOpts
    debug = false,
    foo = true,
    bar = false,
  }
end

---@param opts? PipenvOpts
function M.setup(opts)
  util.validate({ opts = { opts, { 'table', 'nil' }, true } })

  M.config = vim.tbl_deep_extend('keep', opts or {}, M.get_defaults())

  -- ...
  vim.g.Pipenv_setup = 1 -- OPTIONAL for `health.lua`, delete if you want to
end

return M
-- vim: set ts=2 sts=2 sw=2 et ai si sta:
