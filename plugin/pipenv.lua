if vim.g.pipenv_command_loaded == 1 then
  return
end

vim.g.pipenv_command_loaded = 1

local INFO = vim.log.levels.INFO
local WARN = vim.log.levels.WARN
local ERROR = vim.log.levels.ERROR

---@param lead string
---@param choices string[]
---@return string[] candidates
local function narrow_candidates(lead, choices)
  require('pipenv.util').validate({
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
    if vim.list_contains(subs, sub) then
      subcmd, subcmd_val = true, sub
    elseif vim.list_contains(gen_candidates('dev'), sub) then
      dev = true
    elseif vim.list_contains(gen_candidates('pre'), sub) then
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
      vim.list_contains({ 'edit', 'help', 'list-installed', 'list-scripts', 'scripts', 'remove' }, subcmd_val)
      and not (dev or python or file or dev)
    then
      return {}
    end
    if vim.list_contains({ 'graph', 'verify', 'clean', 'run' }, subcmd_val) and not python then
      return narrow_candidates(args[#args], gen_candidates('none', 'python='))
    end
    if vim.list_contains({ 'sync', 'lock', 'install', 'uninstall', 'update', 'upgrade' }, subcmd_val) then
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
        gen_candidates('pre', 'install', 'lock', 'requirements', 'sync', 'uninstall', 'update', 'upgrade')
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
        gen_candidates('none', 'python=', 'uninstall', 'install', 'lock', 'sync', 'update', 'upgrade')
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
        gen_candidates('pre', 'install', 'lock', 'python=', 'requirements', 'sync', 'uninstall', 'update', 'upgrade')
      )
    end
  end
  return {}
end

---@param valid string[]
---@param except string[]
---@param opts Pipenv.Util.PopupOpts
---@overload fun(valid: string[], except: string[])
local function popup(valid, except, opts)
  require('pipenv.util').validate({
    valid = { valid, { 'table' } },
    except = { except, { 'table' } },
    opts = { opts, { 'table', 'nil' }, true },
  })
  opts = opts or {}

  local new_valid = {}
  for _, v in ipairs(valid) do
    if not (vim.list_contains(new_valid, v) or vim.list_contains(except, v)) then
      table.insert(new_valid, v)
    end
  end

  vim.ui.select(
    new_valid,
    { prompt = 'Select your operation:' },
    function(item) ---@param item nil|string|Pipenv.ValidOps
      if not (item and vim.list_contains(new_valid, item)) then
        return
      end

      local Core = require('pipenv.core')
      if item == 'run' then
        vim.ui.input({ prompt = 'Type the command to run' }, function(input)
          if not input or input == '' then
            return
          end
          Core.run(vim.split(input, ' ', { plain = true, trimempty = true }), opts)
        end)
      elseif item == 'list' then
        Core.list_installed()
      elseif vim.list_contains({ 'install', 'uninstall' }, item) then
        vim.ui.input({ prompt = ('Type the packages to %s (separated by a space)'):format(item) }, function(input)
          if not input or input == '' then
            return
          end
          Core[item](vim.split(input, ' ', { plain = true, trimempty = true }), opts)
        end)
      elseif
        vim.list_contains({
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
        Core[item](opts)
      end
    end
  )
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

  local Core = require('pipenv.core')
  local dev, pre = false, false ---@type boolean, boolean
  local file, python, subcommand = nil, nil, nil ---@type nil|string, nil|string, string|Pipenv.ValidOps|nil
  local subsubcmd = {} ---@type string[]
  for _, arg in ipairs(ctx.fargs) do
    if arg:find('=') then
      local subsubcommand = vim.split(arg, '=', { plain = true, trimempty = true })
      if #subsubcommand == 2 then
        if subsubcommand[1] == 'dev' then
          if not vim.list_contains({ 'true', 'false' }, subsubcommand[2]) then
            Core.help(WARN)
            return
          end
          dev = subsubcommand[2] == 'true' and true or false
        elseif subsubcommand[1] == 'pre' then
          if not vim.list_contains({ 'true', 'false' }, subsubcommand[2]) then
            Core.help(WARN)
            return
          end
          pre = subsubcommand[2] == 'true' and true or false
        elseif subsubcommand[1] == 'file' then
          file = subsubcommand[2]
        elseif subsubcommand[1] == 'python' then
          python = subsubcommand[2]
        else
          Core.help(ERROR)
          return
        end
      else
        Core.help(ERROR)
        return
      end
    elseif not subcommand then
      if vim.list_contains(valid, arg) then
        subcommand = arg ---@type Pipenv.ValidOps
      else
        Core.help(ERROR)
        return
      end
    else
      table.insert(subsubcmd, arg)
    end
  end

  if not subcommand and #subsubcmd == 0 then
    popup(
      valid,
      { 'help', 'list-installed', 'list-scripts' },
      { dev = dev, file = file, pre = pre, python = python, verbose = ctx.bang }
    )
  elseif subcommand == 'help' then
    Core.help(INFO)
  elseif subcommand == 'install' then
    Core.install(#subsubcmd == 0 and nil or subsubcmd, { dev = dev, verbose = ctx.bang, python = python, pre = pre })
  elseif subcommand == 'list-scripts' and #subsubcmd == 0 then
    Core.list_scripts()
  elseif subcommand == 'list-installed' and #subsubcmd == 0 then
    Core.list_installed()
  elseif vim.list_contains({ 'edit', 'remove' }, subcommand) and #subsubcmd == 0 then
    Core[subcommand]()
  elseif vim.list_contains({ 'graph', 'scripts' }, subcommand) and #subsubcmd == 0 then
    Core[subcommand]({ python = python })
  elseif vim.list_contains({ 'verify', 'clean', 'lock' }, subcommand) and #subsubcmd == 0 then
    Core[subcommand]({ verbose = ctx.bang, python = python })
  elseif subcommand == 'run' and #subsubcmd > 0 then
    Core.run(subsubcmd, { verbose = ctx.bang, python = python })
  elseif vim.list_contains({ 'sync', 'update', 'upgrade' }, subcommand) and #subsubcmd == 0 then
    Core[subcommand]({ dev = dev, verbose = ctx.bang, python = python, pre = pre })
  elseif subcommand == 'requirements' and #subsubcmd == 0 then
    Core.requirements({ file = file, dev = dev, python = python, verbose = ctx.bang })
  else
    Core.help(WARN)
  end
end, { bang = true, complete = complete_fun, desc = 'Pipenv user command', nargs = '*' })
