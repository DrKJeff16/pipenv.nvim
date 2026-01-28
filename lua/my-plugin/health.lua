---@class MyPlugin.Health
local M = {}

function M.check()
  vim.health.start('my-plugin')

  if vim.g.MyPlugin_setup == 1 then
    vim.health.ok('`my-plugin` has been setup!')
    return
  end

  vim.health.error('`my-plugin` has not been setup correctly!')
end

return M
-- vim: set ts=2 sts=2 sw=2 et ai si sta:
