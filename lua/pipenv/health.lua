local Util = require('pipenv.util')

---@class Pipenv.Health
local M = {}

---@param exe string
---@param idx integer
---@return string version
local function get_version(exe, idx)
  Util.validate({
    exe = { exe, { 'string' } },
    idx = { idx, { 'number' } },
  })
  if not Util.is_int(idx) then
    error(('Not an integer `%s`!'):format(idx), vim.log.levels.ERROR)
  end

  local out = vim.system({ exe, '--version' }):wait(1000).stdout
  if not out or out == '' then
    return ''
  end
  out = out:sub(1, out:len() - 1)

  return ('%s'):format(vim.split(out, ' ', { trimempty = true })[idx])
end

function M.check()
  vim.health.start('Setup')
  if vim.g.pipenv_setup ~= 1 then
    vim.health.error('`pipenv.nvim` has not been setup correctly!')
    return
  end
  vim.health.ok('`pipenv.nvim` has been setup!')

  vim.health.start('Config')
  for name, opt in pairs(require('pipenv.config').config) do
    local str, warning = Util.format_per_type(type(opt), opt)
    str = ('`%s`: %s'):format(name, str)
    if Util.is_type('boolean', warning) and warning then
      vim.health.warn(str)
    else
      vim.health.ok(str)
    end
  end

  vim.health.start('Requirements')
  for _, exe in ipairs({ { 'python', 2 }, { 'pipenv', 3 } }) do
    if not Util.executable(exe[1]) then
      vim.health.error(('`%s` not found in `PATH`!'):format(exe[1]))
      return
    end
    vim.health.ok(
      ('`%s %s` found in `PATH`'):format(exe[1], get_version(vim.fn.exepath(exe[1]), exe[2]))
    )
    vim.health.info(('`%s`'):format(vim.fn.exepath(exe[1])))
  end

  vim.health.start('Environment')
  vim.health.info("If warnings are raised in this section that doesn't mean the plugin won't work.")

  local env = vim.fn.environ()
  local ret = false
  if not vim.fn.has_key(env, 'PIPENV_ACTIVE') or env.PIPENV_ACTIVE ~= '1' then
    vim.health.warn('`$PIPENV_ACTIVE` not set!')
    ret = true
  end
  if not vim.fn.has_key(env, 'VIRTUAL_ENV') or env.VIRTUAL_ENV ~= '1' then
    vim.health.warn('`$VIRTUAL_ENV` not set!')
    ret = true
  end
  if ret then
    return
  end

  vim.health.ok('`$PIPENV_ACTIVE` is `1`')
  vim.health.ok(('`$VIRTUAL_ENV` is `%s`'):format(env.VIRTUAL_ENV))
end

return M
-- vim: set ts=2 sts=2 sw=2 et ai si sta:
