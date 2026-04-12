package.path = './?.lua;./?/init.lua;./?/?.lua;./reaper/lib/?.lua;' .. package.path
SNAPSHOT_DIR = 'tests/lua/snapshots'

local luaunit = require('tests.lua.vendor.luaunit')
local tests = {}
local report_tests = require('tests.lua.test_report_formatter')
local runtime_tests = require('tests.lua.test_runtime_client')

for name, fn in pairs(report_tests) do
  tests[name] = fn
end

for name, fn in pairs(runtime_tests) do
  tests[name] = fn
end

os.exit(luaunit.LuaUnit.run(tests))
