local M = {}

local sep = package.config:sub(1, 1)

function M.separator()
  return sep
end

function M.join(...)
  local parts = { ... }
  local filtered = {}
  for _, part in ipairs(parts) do
    if part and part ~= "" then
      filtered[#filtered + 1] = tostring(part)
    end
  end
  local path = table.concat(filtered, sep)
  path = path:gsub(sep .. "+", sep)
  return path
end

function M.dirname(path)
  return tostring(path):match("^(.*" .. sep .. ")") and tostring(path):match("^(.*" .. sep .. ")"):sub(1, -2) or "."
end

function M.basename(path)
  return tostring(path):match("([^" .. sep .. "]+)$") or tostring(path)
end

function M.exists(path)
  local handle = io.open(path, "rb")
  if handle then
    handle:close()
    return true
  end
  return false
end

function M.read_file(path)
  local handle, err = io.open(path, "rb")
  if not handle then
    return nil, err
  end
  local data = handle:read("*a")
  handle:close()
  return data
end

function M.write_file(path, data)
  local handle, err = io.open(path, "wb")
  if not handle then
    return nil, err
  end
  handle:write(data)
  handle:close()
  return true
end

function M.ensure_dir(path)
  if reaper and reaper.RecursiveCreateDirectory then
    reaper.RecursiveCreateDirectory(path, 0)
  end
end

function M.sh_quote(value)
  local text = tostring(value)
  return "'" .. text:gsub("'", "'\\''") .. "'"
end

function M.sanitize_job_id(raw)
  local text = tostring(raw or "job")
  return text:gsub("[^%w%-_]+", "_")
end

return M

