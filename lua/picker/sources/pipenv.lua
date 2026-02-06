---@module 'picker'

local Util = require('pipenv.util')
local ERROR = vim.log.levels.ERROR

---@param item 'run'|'uninstall'|'install'
---@param opts? Pipenv.RunOpts|Pipenv.UninstallOpts|Pipenv.InstallOpts
local function run_item(item, opts)
  Util.validate({
    item = { item, { 'string' } },
    opts = { opts, { 'table', 'nil' }, true },
  })
  opts = opts or {}
  if not vim.list_contains({ 'run', 'install', 'uninstall' }, item) then
    vim.notify(('Bad item: `%s`'):format(item), ERROR)
    return
  end

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
  ---@cast opts Pipenv.InstallOpts|Pipenv.UninstallOpts
  vim.ui.input(
    { prompt = ('Type the packages to %s (separated by a space)'):format(item) },
    function(input)
      if not input or input == '' then
        return
      end
      (item == 'install' and Core.install or Core.uninstall)(
        vim.split(input, ' ', { plain = true, trimempty = true }),
        opts
      )
    end
  )
end

---@return string[] actions
local function get_all_actions()
  return {
    'clean',
    'edit',
    'graph',
    'install',
    'install (dev)',
    'install (pre)',
    'install (dev,pre)',
    'list installed',
    'list scripts',
    'lock',
    'requirements',
    'requirements (dev)',
    'run',
    'scripts',
    'sync',
    'sync (dev)',
    'sync (pre)',
    'sync (dev,pre)',
    'uninstall',
    'uninstall (dev)',
    'uninstall (pre)',
    'uninstall (dev,pre)',
    'verify',
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

---@class Picker.Sources.PipenvOpts
---@field dev? boolean
---@field pre? boolean
---@field verbose? boolean
---@field python? string

---@class Picker.Sources.Pipenv
local M = {}

M.verbose = true ---@type boolean
M.dev = false ---@type boolean
M.pre = false ---@type boolean
M.python = nil ---@type string|nil

---@param opt Picker.Sources.PipenvOpts
function M.set(opt)
  if not opt or vim.tbl_isempty(opt) then
    return
  end

  Util.validate({
    dev = { opt.dev, { 'boolean', 'nil' }, true },
    pre = { opt.pre, { 'boolean', 'nil' }, true },
    python = { opt.python, { 'string', 'nil' }, true },
  })

  if opt.verbose ~= nil then
    M.verbose = opt.verbose
  end
  if opt.dev ~= nil then
    M.dev = opt.dev
  end
  if opt.pre ~= nil then
    M.pre = opt.pre
  end
  if opt.python and opt.python ~= '' then
    M.python = opt.python
  end
end

function M.get()
  return gen_items(get_all_actions())
end

---@param entry PickerItem
function M.default_action(entry)
  local Core = require('pipenv.core')
  local value = vim.split(entry.value, ' ', { plain = true, trimempty = true })
  if vim.tbl_isempty(value) then
    vim.notify('Empty action!', ERROR)
    return
  end

  if value[1] == 'list' and #value == 2 then
    Core[table.concat(value, '_')]()
    return
  end
  local action = value[1] ---@type 'clean'|'install'|'lock'|'uninstall'|'sync'|'verify'|'run'|'requirements'
  local opts = { verbose = M.verbose, dev = M.dev, pre = M.pre, python = M.python }
  if #value == 2 then
    value[2] = value[2]:sub(2, value[2]:len())
    value[2] = value[2]:sub(1, value[2]:len() - 1)
    for _, choice in ipairs(vim.split(value[2], ',', { plain = true, trimempty = true })) do
      ---@cast choice 'dev'|'pre'
      opts[choice] = true
    end
  end

  if vim.list_contains({ 'run', 'install', 'uninstall' }, action) then
    ---@cast action 'run'|'install'|'uninstall'
    run_item(action, opts)
    return
  end

  if Core[action] and vim.is_callable(Core[action]) then
    ---@cast action 'clean'|'lock'|'sync'|'verify'|'requirements'
    Core[action](opts)
    return
  end

  vim.notify(('Bad entry `%s`!'):format(table.concat(value, ' ')), ERROR)
end

return M
-- vim: set ts=2 sts=2 sw=2 et ai si sta:
