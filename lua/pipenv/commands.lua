---@alias Pipenv.ValidOps
---|'clean'
---|'edit'
---|'graph'
---|'help'
---|'install'
---|'list-installed'
---|'list-scripts'
---|'lock'
---|'remove'
---|'requirements'
---|'run'
---|'scripts'
---|'sync'
---|'uninstall'
---|'update'
---|'upgrade'
---|'verify'

local in_list = vim.list_contains
local INFO = vim.log.levels.INFO
local WARN = vim.log.levels.WARN
local ERROR = vim.log.levels.ERROR
local Core = require('pipenv.core')
local Util = require('pipenv.util')

---@class Pipenv.Commands
local M = {}

---@param lead string
---@param choices string[]
---@return string[] candidates
local function narrow_candidates(lead, choices)
  Util.validate({
    lead = { lead, { 'string' } },
    choices = { choices, { 'table' } },
  })

  local candidates = {}
  for _, comp in ipairs(choices) do
    if vim.startswith(comp, lead) then
      table.insert(candidates, comp)
    end
  end
  return candidates
end

---@param opt 'dev'|'pre'|'both'|'none'
---@param ... string
---@return string[] candidates
local function gen_candidates(opt, ...)
  local candidates ---@type string[]
  if opt == 'both' then
    candidates = { 'dev=true', 'dev=false', 'pre=true', 'pre=false' }
  end
  if opt == 'dev' then
    candidates = { 'dev=true', 'dev=false' }
  end
  if opt == 'pre' then
    candidates = { 'pre=true', 'pre=false' }
  end
  if opt == 'none' then
    candidates = {}
  end

  for i = 1, select('#', ...), 1 do
    local comp = select(i, ...) ---@type string
    if not vim.list_contains(candidates, comp) then
      table.insert(candidates, comp)
    end
  end

  return candidates
end

---@param lead string
---@return string[] completions
local function complete_fun(_, lead)
  local args = vim.split(lead, '%s+', { trimempty = false })
  if args[1]:sub(-1) == '!' and #args == 1 then
    return {}
  end

  ---@type boolean, boolean, boolean, boolean, boolean
  local subcmd, dev, pre, python, file = false, false, false, false, false
  local subcmd_val = ''
  local subs = { ---@type string[]
    'clean',
    'edit',
    'graph',
    'help',
    'install',
    'list-installed',
    'list-scripts',
    'lock',
    'remove',
    'requirements',
    'run',
    'scripts',
    'sync',
    'uninstall',
    'update',
    'upgrade',
    'verify',
  }
  for _, sub in ipairs(args) do
    if in_list(subs, sub) then
      subcmd = true
      subcmd_val = sub
    elseif in_list(gen_candidates('dev'), sub) then
      dev = true
    elseif in_list(gen_candidates('pre'), sub) then
      pre = true
    elseif vim.startswith(sub, 'python=') then
      python = true
    elseif vim.startswith(sub, 'file=') then
      file = true
    end
  end
  if dev and subcmd and pre and python and file then
    return {}
  end
  if not (subcmd or dev or pre or python or file) then
    return narrow_candidates(
      args[#args],
      gen_candidates(
        'both',
        'python=',
        'file=',
        'clean',
        'edit',
        'graph',
        'help',
        'install',
        'list-installed',
        'list-scripts',
        'lock',
        'remove',
        'requirements',
        'run',
        'scripts',
        'sync',
        'uninstall',
        'update',
        'upgrade',
        'verify'
      )
    )
  end
  if subcmd then
    if
      in_list({ 'edit', 'help', 'list-installed', 'list-scripts', 'scripts', 'remove' }, subcmd_val)
      and not (dev or python or file or dev)
    then
      return {}
    end
    if in_list({ 'graph', 'verify', 'clean', 'run' }, subcmd_val) and not python then
      return narrow_candidates(args[#args], gen_candidates('none', 'python='))
    end
    if in_list({ 'sync', 'lock', 'install', 'uninstall', 'update', 'upgrade' }, subcmd_val) then
      if not (python or pre or dev) then
        return narrow_candidates(args[#args], gen_candidates('both', 'python='))
      end
      if dev and not (python or pre) then
        return narrow_candidates(args[#args], gen_candidates('pre', 'python='))
      end
      if pre and not (python or dev) then
        return narrow_candidates(args[#args], gen_candidates('dev', 'python='))
      end
      if pre and dev and not python then
        return narrow_candidates(args[#args], gen_candidates('none', 'python='))
      end
      if python and not (dev or pre) then
        return narrow_candidates(args[#args], gen_candidates('both'))
      end
      if python and pre and not dev then
        return narrow_candidates(args[#args], gen_candidates('dev'))
      end
      if python and dev and not pre then
        return narrow_candidates(args[#args], gen_candidates('pre'))
      end
    end
    if subcmd_val == 'requirements' then
      if not (file or python or dev) then
        return narrow_candidates(args[#args], gen_candidates('dev', 'python=', 'file='))
      end
      if dev and not (file or python) then
        return narrow_candidates(args[#args], gen_candidates('none', 'python=', 'file='))
      end
      if python and not (file or dev) then
        return narrow_candidates(args[#args], gen_candidates('dev', 'file='))
      end
      if file and not (python or dev) then
        return narrow_candidates(args[#args], gen_candidates('dev', 'python='))
      end
      if file and dev and not python then
        return narrow_candidates(args[#args], gen_candidates('none', 'python='))
      end
      if python and dev and not file then
        return narrow_candidates(args[#args], gen_candidates('none', 'file='))
      end
      if python and file and not dev then
        return narrow_candidates(args[#args], gen_candidates('dev'))
      end
    end
    return {}
  end
  if file then
    if not (subcmd or dev or python) then
      return narrow_candidates(args[#args], gen_candidates('dev', 'python=', 'requirements'))
    end
    if dev and not (subcmd or python) then
      return narrow_candidates(args[#args], gen_candidates('none', 'python=', 'requirements'))
    end
    if dev and subcmd and not python then
      return narrow_candidates(args[#args], gen_candidates('none', 'python='))
    end
  end
  if python then
    if not (subcmd or dev or pre) then
      return narrow_candidates(
        args[#args],
        gen_candidates(
          'both',
          'clean',
          'graph',
          'install',
          'lock',
          'requirements',
          'run',
          'scripts',
          'sync',
          'uninstall',
          'update',
          'upgrade',
          'verify'
        )
      )
    end
    if dev and pre and not subcmd then
      return narrow_candidates(
        args[#args],
        gen_candidates('none', 'uninstall', 'install', 'lock', 'sync', 'update', 'upgrade')
      )
    end
    if dev and not (subcmd or pre) then
      return narrow_candidates(
        args[#args],
        gen_candidates(
          'pre',
          'install',
          'lock',
          'requirements',
          'sync',
          'uninstall',
          'update',
          'upgrade'
        )
      )
    end
    if pre and not (subcmd or dev) then
      return narrow_candidates(
        args[#args],
        gen_candidates('dev', 'install', 'lock', 'sync', 'uninstall', 'update', 'upgrade')
      )
    end
    if pre and subcmd and not dev then
      return narrow_candidates(args[#args], gen_candidates('dev'))
    end
    if dev and subcmd and not pre then
      return narrow_candidates(args[#args], gen_candidates('pre'))
    end
  end
  if dev then
    if pre and not (subcmd or python) then
      return narrow_candidates(
        args[#args],
        gen_candidates(
          'none',
          'python=',
          'uninstall',
          'install',
          'lock',
          'sync',
          'update',
          'upgrade'
        )
      )
    end
    if python and not (subcmd or pre) then
      return narrow_candidates(
        args[#args],
        gen_candidates('pre', 'uninstall', 'install', 'lock', 'sync', 'update', 'upgrade')
      )
    end
    if python and subcmd and not pre then
      return narrow_candidates(args[#args], gen_candidates('pre'))
    end
    if not (subcmd or pre or python) then
      return narrow_candidates(
        args[#args],
        gen_candidates(
          'pre',
          'install',
          'lock',
          'python=',
          'requirements',
          'sync',
          'uninstall',
          'update',
          'upgrade'
        )
      )
    end
  end
  return {}
end

---@param level? vim.log.levels
function M.cmd_usage(level)
  Util.validate({ level = { level, { 'number', 'nil' }, true } })
  level = (level and Util.is_int(level, level <= 5 and level >= 0)) and level or INFO

  local msg =
    [[Usage - :Pipenv[!] [dev=true|false] [file=/path/to/file] [python=PYTHON_VERSION] [pre=true|false] [<OPERATION>]

  :Pipenv help
  :Pipenv edit
  :Pipenv remove
  :Pipenv list-installed
  :Pipenv list-scripts

  :Pipenv graph [python=PYTHON_VERSION]
  :Pipenv scripts [python=PYTHON_VERSION]
  :Pipenv[!] requirements [dev=true|false] [file=/path/to/file] [python=PYTHON_VERSION]
  :Pipenv[!] clean [python=PYTHON_VERSION]
  :Pipenv[!] install [dev=true|false] [pre=true|false] [python=PYTHON_VERSION] [<pkg1> [<pkg2> [...]\]\]
  :Pipenv[!] lock [pre=true|false] [python=PYTHON_VERSION]
  :Pipenv[!] run [python=PYTHON_VERSION] <command> [<args> [...]\]
  :Pipenv[!] sync [dev=true|false] [pre=true|false] [python=PYTHON_VERSION]
  :Pipenv[!] uninstall [dev=true|false] [pre=true|false] [python=PYTHON_VERSION] <pkg1> [...]
  :Pipenv[!] update [dev=true|false] [pre=true|false] [python=PYTHON_VERSION]
  :Pipenv[!] upgrade [dev=true|false] [pre=true|false] [python=PYTHON_VERSION]
  :Pipenv[!] verify [python=PYTHON_VERSION]\]]

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
          if not input or input == '' then
            return
          end

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
            if not input or input == '' then
              return
            end

            Core[item](vim.split(input, ' ', { plain = true, trimempty = true }), opts)
          end
        )
        return
      end
      if
        not in_list({
          'clean',
          'edit',
          'graph',
          'lock',
          'remove',
          'requirements',
          'sync',
          'update',
          'upgrade',
          'verify',
        }, item)
      then
        return
      end

      Core[item](opts)
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
      'remove',
      'requirements',
      'run',
      'scripts',
      'sync',
      'uninstall',
      'update',
      'upgrade',
      'verify',
    }

    local dev, pre = false, false ---@type boolean, boolean
    local file, python, subcommand = nil, nil, nil ---@type nil|string, nil|string, string|Pipenv.ValidOps|nil
    local subsubcmd = {} ---@type string[]
    for _, arg in ipairs(ctx.fargs) do
      if arg:find('=') then
        local subsubcommand = vim.split(arg, '=', { plain = true, trimempty = true })
        if #subsubcommand == 2 then
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
            M.cmd_usage(ERROR)
            return
          end
        else
          M.cmd_usage(ERROR)
          return
        end
      elseif not subcommand then
        if vim.list_contains(valid, arg) then
          subcommand = arg ---@type Pipenv.ValidOps
        else
          M.cmd_usage(ERROR)
          return
        end
      else
        table.insert(subsubcmd, arg)
      end
    end

    if not subcommand then
      if vim.tbl_isempty(subsubcmd) then
        M.popup(valid, { 'help', 'list-installed', 'list-scripts' }, {
          verbose = ctx.bang,
          dev = dev,
          pre = pre,
          file = file,
          python = python,
        })
        return
      end
      M.cmd_usage(ERROR)
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
    if subcommand == 'remove' then
      ---@cast subcommand 'remove'
      if not vim.tbl_isempty(subsubcmd) then
        M.cmd_usage(WARN)
        return
      end
      Core.remove()
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
    if vim.list_contains({ 'sync', 'update', 'upgrade' }, subcommand) then
      ---@cast subcommand 'sync'|'upgrade'|'update'
      if not vim.tbl_isempty(subsubcmd) then
        M.cmd_usage(WARN)
        return
      end
      Core[subcommand]({ dev = dev, verbose = ctx.bang, python = python, pre = pre })
      return
    end
    if subcommand == 'requirements' then
      ---@cast subcommand 'requirements'
      if not vim.tbl_isempty(subsubcmd) then
        M.cmd_usage(WARN)
        return
      end
      Core.requirements({ file = file, dev = dev, python = python, verbose = ctx.bang })
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
