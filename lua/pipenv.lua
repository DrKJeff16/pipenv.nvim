local util = require('pipenv.util')
local config = require('pipenv.config')

---@class Pipenv
local M = {}

---@param opts? PipenvOpts
function M.setup(opts)
  util.validate({ opts = { opts, { 'table', 'nil' }, true } })

  config.setup(opts or {})

  -- ...
end

return M
-- vim: set ts=2 sts=2 sw=2 et ai si sta:
