local M = {}

local function trim_trailing_spaces(text)
  text = text:gsub('\r\n', '\n')
  text = text:gsub('\n+$', '')
  local lines = {}
  for line in (text .. '\n'):gmatch('(.-)\n') do
    lines[#lines + 1] = line:gsub('%s+$', '')
  end
  return table.concat(lines, '\n')
end

function M.assert_snapshot(actual, snapshot_name)
  local snapshot_path = assert(SNAPSHOT_DIR, 'SNAPSHOT_DIR is not set')
  local file = assert(io.open(snapshot_path .. '/' .. snapshot_name, 'r'))
  local expected = file:read('*a')
  file:close()
  actual = trim_trailing_spaces(actual)
  expected = trim_trailing_spaces(expected)
  if actual ~= expected then
    error('snapshot mismatch for ' .. snapshot_name .. '\n--- expected ---\n' .. expected .. '\n--- actual ---\n' .. actual, 2)
  end
end

return M
