local INFO = vim.log.levels.INFO
local api = require('pipenv.api')

---@class Pipenv.Commands
local M = {}

function M.cmd_usage()
  vim.notify(
    [[
    Usage:
    :Pipenv[!] clean
    :Pipenv[!] install [<pkg1> [<pkg2> [...]\]\] [dev=true|false]
    :Pipenv[!] lock
    :Pipenv requirements [dev=true|false] [file=/path/to/file]
    :Pipenv[!] run <command> [<args> [...]\]
    :Pipenv[!] sync [dev=true|false]
    ]],
    INFO
  )
end

function M.setup()
  vim.api.nvim_create_user_command('Pipenv', function(ctx)
    local subcommand = ctx.fargs[1] or '' ---@type 'clean'|'install'|'lock'|'requirements'|'run'|'sync'
    local valid = { 'clean', 'install', 'lock', 'requirements', 'run', 'sync' }
    if not vim.list_contains(valid, subcommand) then
      M.cmd_usage()
      return
    end

    if subcommand == 'clean' then
      api.clean(ctx.bang)
      return
    end
    if subcommand == 'lock' then
      api.lock(ctx.bang)
      return
    end
    if subcommand == 'run' then
      if #ctx.fargs == 1 then
        M.cmd_usage()
        return
      end
      local cmds = {}
      for i = 2, #ctx.fargs, 1 do
        table.insert(cmds, ctx.fargs[i])
      end

      api.run(cmds, ctx.bang)
      return
    end
    if subcommand == 'sync' then
      local dev = false
      for i = 2, #ctx.fargs, 1 do
        local subsubcmd = vim.split(ctx.fargs[i], '=', { plain = true, trimempty = false })
        if #subsubcmd == 1 or subsubcmd[1] ~= 'dev' then
          M.cmd_usage()
          return
        end
        if not vim.list_contains({ 'true', 'false' }, subsubcmd[2]) then
          M.cmd_usage()
          return
        end
        if subsubcmd[2] == 'true' then
          dev = true
        else
          dev = false
        end
      end

      api.sync(dev, ctx.bang)
      return
    end
    if subcommand == 'install' then
      local dev = false
      local pkgs = {} ---@type string[]
      for i = 2, #ctx.fargs, 1 do
        if ctx.fargs[i]:match('dev=') then
          local subsubcmd = vim.split(ctx.fargs[i], '=', { plain = true, trimempty = false })
          if #subsubcmd == 1 or subsubcmd[1] ~= 'dev' then
            M.cmd_usage()
            return
          end
          if not vim.list_contains({ 'true', 'false' }, subsubcmd[2]) then
            M.cmd_usage()
            return
          end
          if subsubcmd[2] == 'true' then
            dev = true
          else
            dev = false
          end
        else
          table.insert(pkgs, ctx.fargs[i])
        end
      end
      if vim.tbl_isempty(pkgs) then
        api.install(nil, dev, ctx.bang)
      else
        api.install(pkgs, dev, ctx.bang)
      end
      return
    end
    if subcommand == 'requirements' then
      ---@type boolean, nil|string
      local dev, file = false, nil
      for i = 2, #ctx.fargs, 1 do
        if ctx.fargs[i]:match('dev=') then
          local subsubcmd = vim.split(ctx.fargs[i], '=', { plain = true, trimempty = false })
          if #subsubcmd == 1 or subsubcmd[1] ~= 'dev' then
            M.cmd_usage()
            return
          end
          if not vim.list_contains({ 'true', 'false' }, subsubcmd[2]) then
            M.cmd_usage()
            return
          end
          if subsubcmd[2] == 'true' then
            dev = true
          else
            dev = false
          end
        elseif ctx.fargs[i]:match('file=') then
          local subsubcmd = vim.split(ctx.fargs[i], '=', { plain = true, trimempty = false })
          if #subsubcmd == 1 or subsubcmd[1] ~= 'file' then
            M.cmd_usage()
            return
          end
          file = subsubcmd[2]
        end
      end

      api.requirements(file, dev)
      return
    end
  end, {
    nargs = '+',
    bang = true,
    desc = 'Pipenv user command',
  })
end

local Commands = setmetatable(M, { ---@type Pipenv.Commands
  __index = M,
  __newindex = function()
    vim.notify('Pipenv.Commands module is read-only!', vim.log.levels.ERROR)
  end,
})

return Commands
-- vim: set ts=2 sts=2 sw=2 et ai si sta:
