local luaunit = {}

local function format_message(message, default_message)
  if message == nil or message == '' then
    return default_message
  end
  return message .. ': ' .. default_message
end

function luaunit.assertEquals(actual, expected, message)
  if actual ~= expected then
    error(format_message(message, 'expected ' .. tostring(expected) .. ' but got ' .. tostring(actual)), 2)
  end
end

function luaunit.assertTrue(value, message)
  if not value then
    error(format_message(message, 'expected truthy value'), 2)
  end
end

function luaunit.assertStrContains(haystack, needle, message)
  if type(haystack) ~= 'string' or not haystack:find(needle, 1, true) then
    error(format_message(message, 'expected string to contain ' .. tostring(needle)), 2)
  end
end

local LuaUnit = {}

function LuaUnit.run(test_table)
  local passed = 0
  local failed = 0

  local function run_test(name, fn)
    local ok, err = pcall(fn)
    if ok then
      passed = passed + 1
      io.write('PASS ', name, '\n')
      return
    end
    failed = failed + 1
    io.write('FAIL ', name, ': ', tostring(err), '\n')
  end

  for name, fn in pairs(test_table) do
    if type(fn) == 'function' and name:match('^test_') then
      run_test(name, fn)
    end
  end

  io.write('Ran ', tostring(passed + failed), ' tests, ', tostring(failed), ' failed\n')
  return failed == 0 and 0 or 1
end

luaunit.LuaUnit = LuaUnit
return luaunit

