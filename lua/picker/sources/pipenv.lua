local Util = require('pipenv.util')

---@param item 'run'|'uninstall'|'install'
---@param opts? Pipenv.RunOpts|Pipenv.UninstallOpts|Pipenv.InstallOpts
local function gen_item(item, opts)
  Util.validate({
    item = { item, { 'string' } },
    opts = { opts, { 'table', 'nil' }, true },
  })
  opts = opts or {}

  local Core = require('pipenv.core')
  if item == 'run' then
    vim.ui.input({ prompt = 'Type the command to run' }, function(input)
      if not input or input == '' then
        return
      end
      ---@cast opts Pipenv.RunOpts
      Core.run(vim.split(input, ' ', { plain = true, trimempty = true }), opts)
    end)
    return
  end
  if vim.list_contains({ 'install', 'uninstall' }, item) then
    vim.ui.input(
      { prompt = ('Type the packages to %s (separated by a space)'):format(item) },
      function(input)
        if item == 'install' then
          ---@cast opts Pipenv.InstallOpts
          Core.install(
            (input and input ~= '') and vim.split(input, ' ', { plain = true, trimempty = true })
              or nil,
            opts
          )
          return
        end

        ---@cast opts Pipenv.UninstallOpts
        Core.uninstall(
          (input and input ~= '') and vim.split(input, ' ', { plain = true, trimempty = true })
            or nil,
          opts
        )
      end
    )
    return
  end
end

---@return string[] actions
local function get_all_actions()
  return {
    'clean',
    'clean (verbose)',
    'edit',
    'graph',
    'install',
    'install (dev)',
    'install (pre)',
    'install (verbose)',
    'install (dev,pre)',
    'install (verbose,dev)',
    'install (verbose,pre)',
    'install (verbose,dev,pre)',
    'list installed',
    'list scripts',
    'lock',
    'lock (dev)',
    'lock (pre)',
    'lock (verbose)',
    'lock (dev,pre)',
    'lock (verbose,dev)',
    'lock (verbose,pre)',
    'lock (verbose,dev,pre)',
    'requirements',
    'requirements (dev)',
    'requirements (pre)',
    'requirements (dev,pre)',
    'run',
    'run (verbose)',
    'sync',
    'sync (dev)',
    'sync (pre)',
    'sync (verbose)',
    'sync (dev,pre)',
    'sync (verbose,dev)',
    'sync (verbose,pre)',
    'sync (verbose,dev,pre)',
    'scripts',
    'uninstall',
    'uninstall (dev)',
    'uninstall (pre)',
    'uninstall (verbose)',
    'uninstall (dev,pre)',
    'uninstall (verbose,dev)',
    'uninstall (verbose,pre)',
    'uninstall (verbose,dev,pre)',
    'verify',
    'verify (verbose)',
  }
end

---@param source string[]
---@return PickerItem[] items
local function gen_items(source)
  local items = {} ---@type PickerItem[]
  for _, v in ipairs(source) do
    local entry = ('- %s'):format(v)
    table.insert(items, {
      value = v,
      str = entry,
      highlight = {
        { 0, 1, 'Number' },
        { 2, entry:len(), 'String' },
      },
    })
  end
  return items
end

---@class Picker.Sources.Pipenv
local M = {}

function M.get()
  return gen_items(get_all_actions())
end

---@param entry PickerItem
function M.default_action(entry)
  local Core = require('pipenv.core')
  local value = vim.split(entry.value, ' ', { plain = true, trimempty = true })
  if #value == 1 then
    Core[value[1]]()
    return
  end
  if value[1] == 'list' and #value == 2 then
    Core[table.concat(value, '_')]()
    return
  end
  local action = value[1] ---@type 'clean'|'install'|'lock'|'uninstall'|'sync'|'verify'|'run'|'requirements'
  local opts = {}
  if #value == 2 then
    value[2] = value[2]:sub(2, value[2]:len())
    value[2] = value[2]:sub(1, value[2]:len() - 1)
    for _, choice in ipairs(vim.split(value[2], ',', { plain = true, trimempty = true })) do
      ---@cast choice 'dev'|'pre'|'verbose'
      opts[choice] = true
    end
  end

  if vim.list_contains({ 'run', 'install', 'uninstall' }, action) then
    ---@cast action 'run'|'install'|'uninstall'
    gen_item(action, opts)
    return
  end

  if Core[action] and vim.is_callable(Core[action]) then
    ---@cast action 'clean'|'lock'|'sync'|'verify'|'requirements'
    Core[action](opts)
    return
  end

  vim.notify(('Bad entry `%s`!'):format(table.concat(value, ' ')), vim.log.levels.ERROR)
end

return M
-- vim: set ts=2 sts=2 sw=2 et ai si sta:
