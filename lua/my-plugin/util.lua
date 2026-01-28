---Non-legacy validation spec (>=v0.11)
---@class ValidateSpec
---@field [1] any
---@field [2] vim.validate.Validator
---@field [3]? boolean
---@field [4]? string

---@class MyPlugin.Util
local M = {}

---Checks whether nvim is running on Windows.
--- ---
---@return boolean win32
function M.is_windows()
  return M.vim_has('win32')
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
      not_dup = not vim.list_contains(NT, v)
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
---@overload fun(mod: string): exists: boolean
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

  if str == '' or not vim.startswith(str, char) then
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
  local i, len, new_str = 1, str:len(), ''
  local other = false
  while i <= len + 1 do
    if str:sub(i, i) ~= char and not other then
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
  str = str:reverse()

  if not vim.startswith(str, char) then
    return str:reverse()
  end
  return M.lstrip(char, str):reverse()
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
  return M.rstrip(char, M.lstrip(char, str))
end

return M
-- vim: set ts=2 sts=2 sw=2 et ai si sta:
