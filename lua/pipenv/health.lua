---@class Pipenv.Health
local M = {}

function M.check()
  vim.health.start('pipenv')

  if vim.g.Pipenv_setup == 1 then
    vim.health.ok('`pipenv` has been setup!')
    return
  end

  vim.health.error('`pipenv` has not been setup correctly!')
end

return M
-- vim: set ts=2 sts=2 sw=2 et ai si sta:
