---@alias Pipenv.ValidOps
---|'clean'
---|'edit'
---|'graph'
---|'help'
---|'install'
---|'list-installed'
---|'lock'
---|'requirements'
---|'run'
---|'scripts'
---|'sync'
---|'uninstall'
---|'verify'

local INFO = vim.log.levels.INFO
local WARN = vim.log.levels.WARN
local ERROR = vim.log.levels.ERROR
local Core = require('pipenv.core')
local Util = require('pipenv.util')

---@param lead string
---@return string[] completions
local function complete_fun(_, lead)
  local args = vim.split(lead, '%s+', { trimempty = false })
  if #args == 2 then
    return {
      'dev=true',
      'dev=false',
      'clean',
      'edit',
      'help',
      'install',
      'list-installed',
      'lock',
      'requirements',
      'run',
      'scripts',
      'sync',
      'uninstall',
      'verify',
    }
  end

  if #args >= 3 then
    local subcmd, dev = false, false
    for _, sub in ipairs({
      'clean',
      'edit',
      'help',
      'install',
      'list-installed',
      'lock',
      'requirements',
      'run',
      'scripts',
      'sync',
      'uninstall',
      'verify',
    }) do
      if vim.list_contains(args, sub) then
        subcmd = true
        break
      end
    end
    for _, sub in ipairs({ 'dev=true', 'dev=false' }) do
      if vim.list_contains(args, sub) then
        dev = true
        break
      end
    end
    if dev and not subcmd then
      return { 'uninstall', 'install', 'requirements', 'sync' }
    end
    if not subcmd then
      if
        vim.list_contains(
          { 'clean', 'graph', 'help', 'list-installed', 'lock', 'run', 'edit', 'scripts' },
          args[2]
        )
      then
        return {}
      end
      if vim.list_contains({ 'uninstall', 'install', 'requirements', 'sync' }, args[2]) then
        if dev then
          return {}
        end
        return { 'dev=true', 'dev=false' }
      end
    end
  end
  return {}
end

---@class Pipenv.Commands
local M = {}

---@param level? vim.log.levels
function M.cmd_usage(level)
  Util.validate({ level = { level, { 'number', 'nil' }, true } })
  level = (level and Util.is_int(level)) and level or INFO

  local msg = [[Usage - :Pipenv[!] [dev=true|false] [file=/path/to/file] [<OPERATION>]

  :Pipenv help
  :Pipenv list-installed
  :Pipenv scripts

  :Pipenv graph
  :Pipenv[!] clean
  :Pipenv[!] install [<pkg1> [<pkg2> [...]\]\] [dev=true|false]
  :Pipenv[!] lock
  :Pipenv requirements [dev=true|false] [file=/path/to/file]
  :Pipenv[!] run <command> [<args> [...]\]
  :Pipenv[!] sync [dev=true|false]
  :Pipenv[!] verify]]

  vim.notify(msg, level)
end

---@param valid string[]
---@param except string[]
---@param verbose boolean
---@param dev boolean
---@param file nil|string
---@param python nil|string
function M.popup(valid, except, verbose, dev, file, python)
  Util.validate({
    valid = { valid, { 'table' } },
    except = { except, { 'table' } },
    verbose = { verbose, { 'boolean' } },
    dev = { dev, { 'boolean' } },
    file = { file, { 'string', 'nil' }, true },
    python = { python, { 'string', 'nil' }, true },
  })

  local new_valid = {}
  for _, v in ipairs(valid) do
    if not (vim.list_contains(new_valid, v) or vim.list_contains(except, v)) then
      table.insert(new_valid, v)
    end
  end

  local opts = { verbose = verbose, dev = dev, file = file, python = python }
  vim.notify(vim.inspect(opts))

  vim.ui.select(
    new_valid,
    { prompt = 'Select your operation:' },
    function(item) ---@param item nil|string|Pipenv.ValidOps
      if not (item and vim.list_contains(new_valid, item)) then
        return
      end
      if item == 'run' then
        vim.ui.input({ prompt = 'Type the command to run' }, function(input)
          Core.run(vim.split(input, ' ', { plain = true, trimempty = true }), opts)
        end)
        return
      end
      if vim.list_contains({ 'install', 'uninstall' }, item) then
        vim.ui.input(
          { prompt = ('Type the packages to %s (separated by a space)'):format(item) },
          function(input)
            Core[item](vim.split(input, ' ', { plain = true, trimempty = true }), opts)
          end
        )
        return
      end
      if
        vim.list_contains(
          { 'clean', 'edit', 'verify', 'requirements', 'lock', 'sync', 'graph' },
          item
        )
      then
        Core[item](opts)
        return
      end
    end
  )
end

function M.setup()
  if vim.g.pipenv_setup ~= 1 then
    vim.notify('pipenv.nvim is not configured!', ERROR)
    return
  end

  vim.api.nvim_create_user_command('Pipenv', function(ctx)
    local valid = {
      'clean',
      'edit',
      'graph',
      'help',
      'install',
      'list-installed',
      'lock',
      'requirements',
      'run',
      'scripts',
      'sync',
      'uninstall',
      'verify',
    }

    local dev, file, python, subcommand, subsubcmd = false, nil, nil, nil, {} ---@type boolean, nil|string, nil|string, string|Pipenv.ValidOps|nil, string[]
    for _, arg in ipairs(ctx.fargs) do
      if arg:find('=') then
        local subsubcommand = vim.split(arg, '=', { plain = true, trimempty = false })
        if #subsubcommand > 1 then
          if subsubcommand[1] == 'dev' then
            if not vim.list_contains({ 'true', 'false' }, subsubcommand[2]) then
              M.cmd_usage(WARN)
              return
            end
            if subsubcommand[2] == 'true' then
              dev = true
            else
              dev = false
            end
          elseif subsubcommand[1] == 'file' then
            file = subsubcommand[2]
          elseif subsubcommand[1] == 'python' then
            python = subsubcommand[2]
          end
        end
      elseif vim.list_contains(valid, arg) and not subcommand then
        subcommand = arg ---@type Pipenv.ValidOps
      else
        table.insert(subsubcmd, arg)
      end
    end

    if not subcommand then
      M.popup(valid, { 'help', 'list-installed' }, ctx.bang, dev, file, python)
      return
    end

    if subcommand == 'help' then
      M.cmd_usage(INFO)
      return
    end
    if subcommand == 'scripts' then
      Core.list_scripts()
      return
    end
    if subcommand == 'list-installed' then
      Core.list_installed()
      return
    end
    if vim.list_contains({ 'graph', 'edit' }, subcommand) then
      Core[subcommand]()
      return
    end
    if vim.list_contains({ 'verify', 'clean', 'lock' }, subcommand) then
      Core[subcommand]({ verbose = ctx.bang, python = python })
      return
    end
    if subcommand == 'run' then
      if #ctx.fargs == 1 then
        M.cmd_usage(WARN)
        return
      end
      local cmds = {}
      for i, cmd in ipairs(ctx.fargs) do
        if i > 1 then
          table.insert(cmds, cmd)
        end
      end

      Core.run(cmds, { verbose = ctx.bang, python = python })
      return
    end
    if subcommand == 'sync' then
      Core.sync({ dev = dev, verbose = ctx.bang, python = python })
      return
    end
    if subcommand == 'install' then
      Core.install(
        vim.tbl_isempty(subsubcmd) and nil or subsubcmd,
        { dev = dev, verbose = ctx.bang, python = python }
      )
      return
    end
    if subcommand == 'requirements' then
      Core.requirements({ file = file, dev = dev, python = python })
      return
    end

    M.cmd_usage(WARN)
  end, {
    nargs = '*',
    bang = true,
    desc = 'Pipenv user command',
    complete = complete_fun,
  })
end

local Commands = setmetatable(M, { ---@type Pipenv.Commands
  __index = M,
  __newindex = function()
    vim.notify('Pipenv.Commands module is read-only!', ERROR)
  end,
})

return Commands
-- vim: set ts=2 sts=2 sw=2 et ai si sta:
