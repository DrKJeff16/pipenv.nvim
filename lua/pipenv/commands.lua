---@alias Pipenv.ValidOps
---|'clean'
---|'edit'
---|'graph'
---|'help'
---|'install'
---|'list-installed'
---|'list-scripts'
---|'lock'
---|'requirements'
---|'run'
---|'scripts'
---|'sync'
---|'uninstall'
---|'upgrade'
---|'verify'

local in_list = vim.list_contains
local INFO = vim.log.levels.INFO
local WARN = vim.log.levels.WARN
local ERROR = vim.log.levels.ERROR
local Core = require('pipenv.core')
local Util = require('pipenv.util')

---@param lead string
---@return string[] completions
local function complete_fun(_, lead)
  local args = vim.split(lead, '%s+', { trimempty = false })
  if args[1]:sub(args[1]:len()) == '!' and #args == 1 then
    return {}
  end

  local subcmd, dev, pre = false, false, false ---@type boolean, boolean, boolean
  local subs = { ---@type string[]
    'clean',
    'edit',
    'graph',
    'help',
    'install',
    'list-installed',
    'list-scripts',
    'lock',
    'requirements',
    'run',
    'scripts',
    'sync',
    'uninstall',
    'upgrade',
    'verify',
  }
  for _, sub in ipairs(args) do
    if in_list(subs, sub) then
      subcmd = true
    elseif in_list({ 'dev=true', 'dev=false' }, sub) then
      dev = true
    elseif in_list({ 'pre=true', 'pre=false' }, sub) then
      pre = true
    end
  end
  if dev and subcmd and pre then
    return {}
  end
  if dev and not subcmd and pre then
    return { 'uninstall', 'install', 'requirements', 'lock', 'sync', 'upgrade' }
  end
  if dev and not (subcmd or pre) then
    return { 'uninstall', 'install', 'requirements', 'lock', 'sync', 'upgrade' }
  end
  if pre and not (subcmd or dev) then
    return { 'uninstall', 'install', 'requirements', 'lock', 'sync', 'upgrade' }
  end
  if not (subcmd or dev or pre) then
    return {
      'dev=true',
      'dev=false',
      'pre=true',
      'pre=false',
      'clean',
      'edit',
      'graph',
      'help',
      'install',
      'list-installed',
      'list-scripts',
      'lock',
      'requirements',
      'run',
      'scripts',
      'sync',
      'uninstall',
      'verify',
    }
  end
  if not (subcmd or pre) and dev then
    return {
      'pre=true',
      'pre=false',
      'install',
      'lock',
      'sync',
      'upgrade',
      'uninstall',
    }
  end
  if not (subcmd or dev) and pre then
    return {
      'dev=true',
      'dev=false',
      'install',
      'lock',
      'sync',
      'upgrade',
      'uninstall',
    }
  end
  for _, sub in ipairs(args) do
    if subcmd and in_list({ 'uninstall', 'install', 'requirements', 'sync' }, sub) then
      if not (dev or pre) then
        return { 'dev=true', 'dev=false', 'pre=true', 'pre=false' }
      end
      if not dev and pre then
        return { 'dev=true', 'dev=false' }
      end
      if not pre and dev then
        return { 'pre=true', 'pre=false' }
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
      :Pipenv list-scripts

      :Pipenv graph [python=PYTHON_VERSION]
      :Pipenv scripts [python=PYTHON_VERSION]
      :Pipenv[!] clean [python=PYTHON_VERSION]
      :Pipenv[!] install [<pkg1> [<pkg2> [...]\]\] [dev=true|false] [python=PYTHON_VERSION]
      :Pipenv[!] lock [python=PYTHON_VERSION]
      :Pipenv requirements [dev=true|false] [file=/path/to/file] [python=PYTHON_VERSION]
      :Pipenv[!] run <command> [<args> [...]\] [python=PYTHON_VERSION]
      :Pipenv[!] sync [dev=true|false] [python=PYTHON_VERSION]
      :Pipenv[!] verify [python=PYTHON_VERSION]
      ]]

  vim.notify(msg, level)
end

---@class Pipenv.Util.PopupOpts
---@field dev? boolean
---@field pre? boolean
---@field verbose? boolean
---@field file? string
---@field python? string

---@param valid string[]
---@param except string[]
---@param opts? Pipenv.Util.PopupOpts
function M.popup(valid, except, opts)
  Util.validate({
    valid = { valid, { 'table' } },
    except = { except, { 'table' } },
    opts = { opts, { 'table', 'nil' }, true },
  })
  opts = opts or {}

  local new_valid = {}
  for _, v in ipairs(valid) do
    if not (in_list(new_valid, v) or in_list(except, v)) then
      table.insert(new_valid, v)
    end
  end

  vim.ui.select(
    new_valid,
    { prompt = 'Select your operation:' },
    function(item) ---@param item nil|string|Pipenv.ValidOps
      if not (item and in_list(new_valid, item)) then
        return
      end
      if item == 'run' then
        vim.ui.input({ prompt = 'Type the command to run' }, function(input)
          Core.run(vim.split(input, ' ', { plain = true, trimempty = true }), opts)
        end)
        return
      end
      if item == 'list' then
        Core.list_installed()
        return
      end
      if in_list({ 'install', 'uninstall' }, item) then
        vim.ui.input(
          { prompt = ('Type the packages to %s (separated by a space)'):format(item) },
          function(input)
            Core[item](vim.split(input, ' ', { plain = true, trimempty = true }), opts)
          end
        )
        return
      end
      if in_list({ 'clean', 'edit', 'verify', 'requirements', 'lock', 'sync', 'graph' }, item) then
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
      'list',
      'list-installed',
      'list-scripts',
      'lock',
      'requirements',
      'run',
      'scripts',
      'sync',
      'uninstall',
      'verify',
    }

    local dev, pre = false, false ---@type boolean, boolean
    local file, python, subcommand = nil, nil, nil ---@type nil|string, nil|string, string|Pipenv.ValidOps|nil
    local subsubcmd = {} ---@type string[]
    for _, arg in ipairs(ctx.fargs) do
      if arg:find('=') then
        local subsubcommand = vim.split(arg, '=', { plain = true, trimempty = false })
        if #subsubcommand > 1 then
          if subsubcommand[1] == 'dev' then
            if not in_list({ 'true', 'false' }, subsubcommand[2]) then
              M.cmd_usage(WARN)
              return
            end
            dev = subsubcommand[2] == 'true' and true or false
          elseif subsubcommand[1] == 'pre' then
            if not in_list({ 'true', 'false' }, subsubcommand[2]) then
              M.cmd_usage(WARN)
              return
            end
            pre = subsubcommand[2] == 'true' and true or false
          elseif subsubcommand[1] == 'file' then
            file = subsubcommand[2]
          elseif subsubcommand[1] == 'python' then
            python = subsubcommand[2]
          else
            M.cmd_usage(WARN)
          end
        end
      elseif not subcommand then
        subcommand = arg ---@type Pipenv.ValidOps
      else
        table.insert(subsubcmd, arg)
      end
    end

    if not subcommand then
      M.popup(valid, { 'help', 'list-installed' }, {
        verbose = ctx.bang,
        dev = dev,
        pre = pre,
        file = file,
        python = python,
      })
      return
    end

    if subcommand == 'help' then
      ---@cast subcommand 'help'
      M.cmd_usage(INFO)
      return
    end
    if subcommand == 'install' then
      ---@cast subcommand 'install'
      Core.install(
        vim.tbl_isempty(subsubcmd) and nil or subsubcmd,
        { dev = dev, verbose = ctx.bang, python = python, pre = pre }
      )
      return
    end
    if subcommand == 'list-scripts' then
      ---@cast subcommand 'list-scripts'
      if not vim.tbl_isempty(subsubcmd) then
        M.cmd_usage(WARN)
        return
      end
      Core.list_scripts()
      return
    end
    if subcommand == 'list-installed' then
      ---@cast subcommand 'list-installed'
      if not vim.tbl_isempty(subsubcmd) then
        M.cmd_usage(WARN)
        return
      end
      Core.list_installed()
      return
    end
    if subcommand == 'edit' then
      ---@cast subcommand 'edit'
      if not vim.tbl_isempty(subsubcmd) then
        M.cmd_usage(WARN)
        return
      end
      Core.edit()
      return
    end
    if in_list({ 'graph', 'scripts' }, subcommand) then
      ---@cast subcommand 'graph'|'scripts'
      if not vim.tbl_isempty(subsubcmd) then
        M.cmd_usage(WARN)
        return
      end
      Core[subcommand]({ python = python })
      return
    end
    if in_list({ 'verify', 'clean', 'lock' }, subcommand) then
      ---@cast subcommand 'verify'|'clean'|'lock'
      if not vim.tbl_isempty(subsubcmd) then
        M.cmd_usage(WARN)
        return
      end
      Core[subcommand]({ verbose = ctx.bang, python = python })
      return
    end
    if subcommand == 'run' then
      ---@cast subcommand 'run'
      if vim.tbl_isempty(subsubcmd) then
        M.cmd_usage(WARN)
        return
      end

      Core.run(subsubcmd, { verbose = ctx.bang, python = python })
      return
    end
    if vim.list_contains({ 'sync', 'upgrade' }, subcommand) then
      ---@cast subcommand 'sync'|'upgrade'
      if vim.tbl_isempty(subsubcmd) then
        M.cmd_usage(WARN)
      end
      Core[subcommand]({ dev = dev, verbose = ctx.bang, python = python, pre = pre })
      return
    end
    if subcommand == 'requirements' then
      ---@cast subcommand 'requirements'
      if vim.tbl_isempty(subsubcmd) then
        M.cmd_usage(WARN)
      end
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
