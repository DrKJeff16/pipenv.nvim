---@class PipenvSpinner
---@field id string
---@field text string
local M = {}

function M:start()
  require('spinner').start(self.id)
end

---@param force? boolean
function M:stop(force)
  require('spinner').stop(self.id, force)
end

---@param force? boolean
function M:pause(force)
  require('spinner').stop(self.id, force)
end

---@param id string
---@param opts spinner.Opts|PipenvSpinner.Opts
---@return PipenvSpinner spinner
---@nodiscard
function M.new(id, opts)
  local Spinner = require('spinner')
  Spinner.config(id, vim.tbl_deep_extend('keep', opts, require('pipenv.config').opts.spinner.opts or {}))

  return setmetatable({ id = id, text = Spinner.render(id) }, { __index = M })
end

return M
-- vim: set ts=2 sts=2 sw=2 et ai si sta:
