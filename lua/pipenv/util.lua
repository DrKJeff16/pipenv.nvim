---Non-legacy validation spec (>=v0.11)
---@class ValidateSpec
---@field [1] any
---@field [2] vim.validate.Validator
---@field [3]? boolean
---@field [4]? string

---@class Pipenv.Util.OpenWinOpts
---@field border? 'none'|'single'|'double'|'rounded'|'solid'|'shadow'
---@field float? boolean
---@field ft? string
---@field modifiable? boolean
---@field split? 'right'|'left'|'below'|'above'
---@field title? string
---@field height? number
---@field width? number
---@field zindex? integer

local in_list = vim.list_contains

---@class Pipenv.Util
local M = {}

---@param T table
---@param keys (string|integer)[]
---@param reference table
---@return table T
function M.deep_clean(T, keys, reference)
  if vim.tbl_isempty(T) then
    return T
  end

  for k, v in pairs(T) do
    if not in_list(keys, k) or (type(v) == 'table' and type(reference[k]) ~= 'table') then
      T[k] = nil
    elseif type(v) == 'table' and type(reference[k]) == 'table' then
      T[k] = M.deep_clean(v, vim.tbl_keys(reference[k]), reference[k])
    end
  end
  return T
end

---@param t type
---@param data nil|number|string|boolean|table|function
---@param sep? string
---@param constraints? string[]
---@return string
---@return boolean|nil
function M.format_per_type(t, data, sep, constraints)
  M.validate({
    t = { t, { 'string' } },
    sep = { sep, { 'string', 'nil' }, true },
    constraints = { constraints, { 'table', 'nil' }, true },
  })
  sep = sep or ''
  constraints = constraints or nil

  if t == 'string' then
    local res = ('%s`"%s"`'):format(sep, data)
    if not M.is_type('table', constraints) then
      return res
    end
    if constraints ~= nil and in_list(constraints, data) then
      return res
    end
    return res, true
  end
  if in_list({ 'number', 'boolean' }, t) then
    return ('%s`%s`'):format(sep, tostring(data))
  end
  if t == 'function' then
    return ('%s`%s`'):format(sep, t)
  end

  local msg = ''
  if t == 'nil' then
    return ('%s%s `nil`'):format(sep, msg)
  end
  if t ~= 'table' then
    return ('%s%s `?`'):format(sep, msg)
  end
  if vim.tbl_isempty(data) then
    return ('%s%s `{}`'):format(sep, msg)
  end

  sep = ('%s '):format(sep)
  for k, v in pairs(data) do
    k = M.is_type('number', k) and ('[%s]'):format(tostring(k)) or k
    msg = ('%s\n%s%s: '):format(msg, sep, k)
    if not M.is_type('string', v) then
      msg = ('%s%s'):format(msg, M.format_per_type(type(v), v, sep))
    else
      msg = ('%s`"%s"`'):format(msg, v)
    end
  end
  return msg
end

---@param T any[]
---@param elem any
---@return any[] new_tbl
function M.remove_elem(T, elem)
  M.validate({ T = { T, { 'table' } } })
  if vim.tbl_isempty(T) or not vim.islist(T) then
    return T
  end

  local new_tbl = {} ---@type any[]
  for _, v in ipairs(T) do
    if not vim.deep_equal(v, elem) then
      table.insert(new_tbl, v)
    end
  end

  return new_tbl
end

---@param data string
---@return string new_data
---@nodiscard
function M.trim_output(data)
  M.validate({ data = { data, { 'string' } } })
  if data == '' then
    return data
  end

  local data_tbl = vim.split(data, '\n', { plain = true, trimempty = false })
  if vim.tbl_isempty(data_tbl) or #data_tbl == 1 then
    return data
  end

  data_tbl = M.remove_elem(data_tbl, "To activate this project's virtualenv, run pipenv shell.")
  data_tbl =
    M.remove_elem(data_tbl, 'Alternatively, run a command inside the virtualenv with pipenv run.')

  if vim.startswith(data_tbl[1], 'Running command:') then
    table.remove(data_tbl, 1)
  end
  if vim.tbl_isempty(data_tbl) then
    return data
  end

  if vim.startswith(data_tbl[1], '/usr/lib') then
    table.remove(data_tbl, 1)
  end
  if vim.tbl_isempty(data_tbl) then
    return data
  end

  return table.concat(data_tbl, '\n')
end

---@param data string
---@param opts? Pipenv.Util.OpenWinOpts
---@return integer bufnr
---@return integer win
function M.open_win(data, opts)
  M.validate({
    data = { data, { 'string' } },
    opts = { opts, { 'table', 'nil' }, true },
  })
  opts = opts or {}

  M.validate({
    border = { opts.border, { 'string', 'nil' }, true },
    ft = { opts.ft, { 'string', 'nil' }, true },
    height = { opts.height, { 'number', 'nil' }, true },
    modifiable = { opts.modifiable, { 'boolean', 'nil' }, true },
    title = { opts.title, { 'string', 'nil' }, true },
    split = { opts.split, { 'string', 'nil' }, true },
    width = { opts.width, { 'number', 'nil' }, true },
    zindex = { opts.zindex, { 'number', 'nil' }, true },
  })
  opts.ft = opts.ft or 'log'
  opts.modifiable = opts.modifiable ~= nil and opts.modifiable or false
  opts.height = (opts.height and opts.height > 0) and opts.height or 0.85
  opts.width = (opts.width and opts.width > 0) and opts.width or 0.85
  opts.title = opts.title or nil
  opts.zindex = (opts.zindex and opts.zindex > 0 and M.is_int(opts.zindex)) and opts.zindex or 100
  opts.border = (
    opts.border
    and in_list({ 'double', 'none', 'rounded', 'shadow', 'single', 'solid' }, opts.border)
  )
      and opts.border
    or 'single'
  opts.split = (opts.split and in_list({ 'above', 'below', 'left', 'right' }, opts.split))
      and opts.split
    or 'right'

  local bufnr = vim.api.nvim_create_buf(true, true)
  vim.api.nvim_buf_set_lines(
    bufnr,
    0,
    -1,
    true,
    vim.split(data, '\n', { plain = true, trimempty = false })
  )

  local width, height ---@type integer, integer
  if opts.height <= 1 and opts.height > 0 then
    height = math.floor(vim.o.lines * opts.height)
  elseif math.floor(opts.height) > 1 then
    height = math.floor(opts.height)
  end
  if opts.width <= 1 and opts.width > 0 then
    width = math.floor(vim.o.columns * opts.width)
  elseif math.floor(opts.width) > 1 then
    width = math.floor(opts.width)
  end

  local col = vim.o.columns - width > 0 and math.floor((vim.o.columns - width) / 2) - 1 or 0
  local row = vim.o.lines - height > 0 and math.floor((vim.o.lines - height) / 2) - 1 or 0
  local win_opts = { split = opts.split, style = 'minimal' } ---@type vim.api.keyset.win_config
  if opts.float then
    win_opts = {
      height = height,
      width = width,
      col = col,
      row = row,
      border = opts.border,
      focusable = true,
      relative = 'editor',
      style = 'minimal',
      title = opts.title,
      title_pos = 'center',
      zindex = opts.zindex,
    }
  end
  local win = vim.api.nvim_open_win(bufnr, true, win_opts)

  vim.api.nvim_set_option_value('filetype', opts.ft, { buf = bufnr })
  vim.api.nvim_set_option_value('fileencoding', 'utf-8', { buf = bufnr })

  vim.api.nvim_set_option_value('foldenable', false, { win = win })
  vim.api.nvim_set_option_value('list', false, { win = win })
  vim.api.nvim_set_option_value('number', false, { win = win })
  vim.api.nvim_set_option_value('signcolumn', 'no', { win = win })
  vim.api.nvim_set_option_value('spell', false, { win = win })
  vim.api.nvim_set_option_value('wrap', false, { win = win })

  vim.api.nvim_set_option_value('modifiable', opts.modifiable, { buf = bufnr })
  vim.api.nvim_set_option_value('buftype', opts.modifiable and '' or 'nowrite', { buf = bufnr })
  if opts.modifiable then
    vim.api.nvim_set_option_value('modified', false, { buf = bufnr })
  end

  vim.keymap.set('n', 'q', function()
    pcall(vim.api.nvim_buf_delete, bufnr, { force = true })
    pcall(vim.api.nvim_win_close, win, true)
  end, { buffer = bufnr })

  return bufnr, win
end

---Checks whether nvim is running on Windows.
--- ---
---@return boolean win32
function M.is_windows()
  return M.vim_has('win32')
end

---@param expr string
---@return boolean exists
function M.vim_exists(expr)
  M.validate({ expr = { expr, { 'string' } } })

  return vim.fn.exists(expr) == 1
end

---@return boolean active
function M.virtual_env()
  return M.vim_exists('$VIRTUAL_ENV')
end

---Get rid of all duplicates in the given list.
---
---If the list is empty it'll just return it as-is.
---
---If the data passed to the function is not a table,
---an error will be raised.
--- ---
---@param T any[]
---@return any[] NT
function M.dedup(T)
  M.validate({ T = { T, { 'table' } } })

  if vim.tbl_isempty(T) then
    return T
  end

  local NT = {} ---@type any[]
  for _, v in ipairs(T) do
    local not_dup = false
    if M.is_type('table', v) then
      not_dup = not vim.tbl_contains(NT, function(val)
        return vim.deep_equal(val, v)
      end, { predicate = true })
    else
      not_dup = not in_list(NT, v)
    end
    if not_dup then
      table.insert(NT, v)
    end
  end
  return NT
end

---@param feature string
---@return boolean has
function M.vim_has(feature)
  return vim.fn.has(feature) == 1
end

---Dynamic `vim.validate()` wrapper which covers both legacy and newer implementations.
--- ---
---@param T table<string, vim.validate.Spec|ValidateSpec>
function M.validate(T)
  if not M.vim_has('nvim-0.11') then
    ---Filter table to fit legacy standard
    ---@cast T table<string, vim.validate.Spec>
    for name, spec in pairs(T) do
      while #spec > 3 do
        table.remove(spec, #spec)
      end

      T[name] = spec
    end

    vim.validate(T)
    return
  end

  ---Filter table to fit non-legacy standard
  ---@cast T table<string, ValidateSpec>
  for name, spec in pairs(T) do
    while #spec > 4 do
      table.remove(spec, #spec)
    end

    T[name] = spec
  end

  for name, spec in pairs(T) do
    table.insert(spec, 1, name)
    vim.validate(unpack(spec))
  end
end

---@param T table<string|integer, any>
---@return integer len
function M.get_dict_size(T)
  M.validate({ T = { T, { 'table' } } })

  if vim.tbl_isempty(T) then
    return 0
  end

  local len = 0
  for _, _ in pairs(T) do
    len = len + 1
  end
  return len
end

---Reverses a given list-like table.
---
---If the passed data is an empty table it'll be returned as-is.
---
---If the data passed to the function is not a table,
---an error will be raised.
--- ---
---@param T any[]
---@return any[] T
function M.reverse(T)
  M.validate({ T = { T, { 'table' } } })

  if vim.tbl_isempty(T) then
    return T
  end

  local len = #T
  for i = 1, math.floor(len / 2) do
    T[i], T[len - i + 1] = T[len - i + 1], T[i]
  end
  return T
end

---Checks if module `mod` exists to be imported.
--- ---
---@param mod string The `require()` argument to be checked
---@param ret? boolean Whether to return the called module
---@return boolean exists A boolean indicating whether the module exists or not
---@return unknown? module
function M.mod_exists(mod, ret)
  M.validate({
    mod = { mod, { 'string' } },
    ret = { ret, { 'boolean', 'nil' }, true },
  })
  ret = ret ~= nil and ret or false

  if mod == '' then
    return false
  end
  local exists, module = pcall(require, mod)

  if ret then
    return exists, module
  end

  return exists
end

---Checks if a given number is type integer.
--- ---
---@param num number
---@return boolean int
function M.is_int(num)
  M.validate({ num = { num, { 'number' } } })

  return math.floor(num) == num and math.ceil(num) == num
end

---Checks whether `data` is of type `t` or not.
---
---If `data` is `nil`, the function will always return `false`.
--- ---
---@param t type Any return value the `type()` function would return
---@param data any The data to be type-checked
---@return boolean correct_type
function M.is_type(t, data)
  return data ~= nil and type(data) == t
end

---@param exe string[]|string
---@return boolean is_executable
function M.executable(exe)
  M.validate({ exe = { exe, { 'string', 'table' } } })

  ---@cast exe string
  if M.is_type('string', exe) then
    return vim.fn.executable(exe) == 1
  end

  local res = false

  ---@cast exe string[]
  for _, v in ipairs(exe) do
    res = M.executable(v)
    if not res then
      break
    end
  end
  return res
end

---Left strip given a leading string (or list of strings) within a string, if any.
--- ---
---@param char string[]|string
---@param str string
---@return string new_str
function M.lstrip(char, str)
  M.validate({
    char = { char, { 'string', 'table' } },
    str = { str, { 'string' } },
  })

  if str == '' then
    return str
  end

  ---@cast char string[]
  if M.is_type('table', char) then
    if not vim.tbl_isempty(char) then
      for _, c in ipairs(char) do
        str = M.lstrip(c, str)
      end
    end
    return str
  end

  ---@cast char string
  if not vim.startswith(str, char) or char:len() > str:len() then
    return str
  end

  local i, len, new_str = 1, str:len(), ''
  local other = false
  while i <= len and i + char:len() - 1 <= len do
    if str:sub(i, i + char:len() - 1) ~= char and not other then
      other = true
    end
    if other then
      new_str = ('%s%s'):format(new_str, str:sub(i, i))
    end
    i = i + 1
  end
  return new_str
end

---Right strip given a leading string (or list of strings) within a string, if any.
--- ---
---@param char string[]|string
---@param str string
---@return string new_str
function M.rstrip(char, str)
  M.validate({
    char = { char, { 'string', 'table' } },
    str = { str, { 'string' } },
  })

  if str == '' then
    return str
  end

  ---@cast char string[]
  if M.is_type('table', char) then
    if not vim.tbl_isempty(char) then
      for _, c in ipairs(char) do
        str = M.rstrip(c, str)
      end
    end
    return str
  end

  ---@cast char string
  if not vim.startswith(str:reverse(), char) or char:len() > str:len() then
    return str
  end

  return M.lstrip(char, str:reverse()):reverse()
end

---Strip given a leading string (or list of strings) within a string, if any, bidirectionally.
--- ---
---@param char string[]|string
---@param str string
---@return string new_str
function M.strip(char, str)
  M.validate({
    char = { char, { 'string', 'table' } },
    str = { str, { 'string' } },
  })

  if str == '' then
    return str
  end

  ---@cast char string[]
  if M.is_type('table', char) then
    if not vim.tbl_isempty(char) then
      for _, c in ipairs(char) do
        str = M.strip(c, str)
      end
    end
    return str
  end

  ---@cast char string
  if char:len() > str:len() then
    return str
  end

  return M.rstrip(char, M.lstrip(char, str))
end

local Util = setmetatable(M, { ---@type Pipenv.Util
  __index = M,
  __newindex = function()
    vim.notify('Pipenv.Util is read-only!', vim.log.levels.ERROR)
  end,
})

return Util
-- vim: set ts=2 sts=2 sw=2 et ai si sta:
