local util = require('my-plugin.util')
local config = require('my-plugin.config')

---@class MyPlugin
local M = {}

---@param opts? MyPluginOpts
function M.setup(opts)
  util.validate({ opts = { opts, { 'table', 'nil' }, true } })

  config.setup(opts or {})

  -- ...
end

return M
-- vim: set ts=2 sts=2 sw=2 et ai si sta:
