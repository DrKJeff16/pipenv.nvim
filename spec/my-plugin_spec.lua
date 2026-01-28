local assert = require('luassert') ---@type Luassert

describe('my-plugin', function()
  local M ---@type MyPlugin

  before_each(function()
    -- Clear module cache to get fresh instance
    package.loaded['my-plugin'] = nil
    M = require('my-plugin')
  end)

  describe('setup', function()
    it('should set default configuration', function()
      local ok = pcall(M.setup)
      assert.is_true(ok)
    end)

    it('should merge user configuration with defaults', function()
      local ok = pcall(M.setup, {})
      assert.is_true(ok)
    end)

    it('should handle nil options', function()
      local ok = pcall(M.setup, nil)
      assert.is_true(ok)
    end)

    local params = { 1, false, '', function() end }
    for _, param in ipairs(params) do
      it(('should throw error when called with param of type %s'):format(type(param)), function()
        local ok = pcall(M.setup, param)
        assert.is_false(ok)
      end)
    end
  end)
end)
-- vim: set ts=2 sts=2 sw=2 et ai si sta:
