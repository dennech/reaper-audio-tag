local M = {}

local sep = package.config:sub(1, 1)

local function shell_read(command)
  local handle = io.popen(command)
  if not handle then
    return nil
  end
  local line = handle:read("*l")
  handle:close()
  return line
end

local function shell_lines(command)
  local handle = io.popen(command)
  if not handle then
    return {}
  end
  local lines = {}
  for line in handle:lines() do
    if line and line ~= "" then
      lines[#lines + 1] = line
    end
  end
  handle:close()
  table.sort(lines)
  return lines
end

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

function M.normalize(path)
  local text = tostring(path or ""):gsub("[/\\]+", sep)
  if #text > 1 and text:sub(-1) == sep then
    text = text:sub(1, -2)
  end
  return text
end

function M.is_subpath(path, root)
  local normalized_path = M.normalize(path)
  local normalized_root = M.normalize(root)
  if normalized_path == normalized_root then
    return true
  end
  return normalized_path:sub(1, #normalized_root + 1) == normalized_root .. sep
end

function M.directory_exists(path)
  local quoted = M.sh_quote(path)
  return shell_read("[ -d " .. quoted .. " ] && printf yes") == "yes"
end

function M.exists(path)
  local handle = io.open(path, "rb")
  if handle then
    handle:close()
    return true
  end
  return M.directory_exists(path)
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
  else
    os.execute("mkdir -p " .. M.sh_quote(path))
  end
end

function M.list_files(path)
  if not M.directory_exists(path) then
    return {}
  end

  if reaper and reaper.EnumerateFiles then
    local files = {}
    local index = 0
    while true do
      local name = reaper.EnumerateFiles(path, index)
      if not name then
        break
      end
      files[#files + 1] = M.join(path, name)
      index = index + 1
    end
    table.sort(files)
    return files
  end

  return shell_lines("find " .. M.sh_quote(path) .. " -maxdepth 1 -type f -print 2>/dev/null")
end

function M.list_dirs(path)
  if not M.directory_exists(path) then
    return {}
  end

  if reaper and reaper.EnumerateSubdirectories then
    local dirs = {}
    local index = 0
    while true do
      local name = reaper.EnumerateSubdirectories(path, index)
      if not name then
        break
      end
      dirs[#dirs + 1] = M.join(path, name)
      index = index + 1
    end
    table.sort(dirs)
    return dirs
  end

  return shell_lines("find " .. M.sh_quote(path) .. " -mindepth 1 -maxdepth 1 -type d -print 2>/dev/null")
end

function M.mtime(path)
  if not M.exists(path) then
    return nil
  end

  local quoted = M.sh_quote(path)
  local value = shell_read("stat -f %m " .. quoted .. " 2>/dev/null")
  if not value or value == "" then
    value = shell_read("stat -c %Y " .. quoted .. " 2>/dev/null")
  end
  return tonumber(value)
end

function M.remove_tree(path)
  if not M.directory_exists(path) then
    return false
  end

  for _, child_dir in ipairs(M.list_dirs(path)) do
    M.remove_tree(child_dir)
  end
  for _, child_file in ipairs(M.list_files(path)) do
    os.remove(child_file)
  end
  return os.remove(path)
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
