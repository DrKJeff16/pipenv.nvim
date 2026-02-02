local Util = require('pipenv.util')
local Config = require('pipenv.config')

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
  for name, opt in pairs(Config.opts) do
    ---@cast name string
    ---@cast opt PipenvOpts.Env|PipenvOpts.Output
    if name ~= 'env' then
      local str, warning = Util.format_per_type(type(opt), opt)
      str = ('`%s`: %s'):format(name, str)
      if warning ~= nil and warning then
        vim.health.warn(str)
      else
        vim.health.ok(str)
      end
    end
  end

  if not vim.tbl_isempty(Config.env) then
    vim.health.start('Custom Env')
    for var, val in pairs(Config.env) do
      vim.health.info(('- `%s`: `%s`'):format(var, val))
    end
  end

  vim.health.start('Requirements')

  local ver = vim.split(
    vim.split(
      vim.api.nvim_exec2('version', { output = true }).output,
      '\n',
      { trimempty = true, plain = true }
    )[1],
    ' ',
    { plain = true }
  )[2]
  if vim.version().minor >= 9 then
    vim.health.ok(('Neovim >= `v0.9.0` ==> `%s`'):format(ver))
  else
    vim.health.warn(('Neovim < `v0.9.0` ==> `%s`\nThe plugin will not be stable!'):format(ver))
  end
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

  local env = vim.fn.environ()
  local pipenv_active = vim.fn.has_key(env, 'PIPENV_ACTIVE') and env.PIPENV_ACTIVE == '1'
  local virtual_env = vim.fn.has_key(env, 'VIRTUAL_ENV') and env.VIRTUAL_ENV ~= ''
  local ret = false
  if not (pipenv_active and virtual_env) then
    vim.health.info("Warnings don't mean the plugin won't work.\n")
    ret = true
  end
  if not pipenv_active then
    vim.health.warn('`$PIPENV_ACTIVE` not set!')
  end
  if not virtual_env then
    vim.health.warn('`$VIRTUAL_ENV` not set!')
  end
  if ret then
    return
  end

  vim.health.ok('`$PIPENV_ACTIVE` is `1`')
  vim.health.ok(('`$VIRTUAL_ENV` is `%s`'):format(env.VIRTUAL_ENV))
end

return M
-- vim: set ts=2 sts=2 sw=2 et ai si sta:
