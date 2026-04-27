local M = {}

local sep = package.config:sub(1, 1)

local function is_windows()
  return sep == "\\"
end

local function expand_user_path(path)
  local text = tostring(path or "")
  if text == "~" then
    return os.getenv("HOME") or text
  end
  if text:sub(1, 2) == "~/" then
    local home = os.getenv("HOME")
    if home and home ~= "" then
      return home .. text:sub(2)
    end
  end
  return text
end

local function shell_read(command)
  local handle = io.popen(command)
  if not handle then
    return nil
  end
  local line = handle:read("*l")
  handle:close()
  return line
end

local function shell_all(command)
  local handle = io.popen(command)
  if not handle then
    return nil, 1
  end
  local data = handle:read("*a")
  local ok, _, code = handle:close()
  if ok == nil then
    ok = false
  end
  if ok then
    return data, 0
  end
  return data, tonumber(code) or 1
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

function M.expand_user(path)
  return expand_user_path(path)
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
  if is_windows() then
    local quoted = M.cmd_quote(expand_user_path(path) .. "\\NUL")
    return shell_read("if exist " .. quoted .. " (echo yes)") == "yes"
  end
  local quoted = M.sh_quote(expand_user_path(path))
  return shell_read("[ -d " .. quoted .. " ] && printf yes") == "yes"
end

function M.exists(path)
  local handle = io.open(expand_user_path(path), "rb")
  if handle then
    handle:close()
    return true
  end
  return M.directory_exists(path)
end

function M.read_file(path)
  local handle, err = io.open(expand_user_path(path), "rb")
  if not handle then
    return nil, err
  end
  local data = handle:read("*a")
  handle:close()
  return data
end

function M.write_file(path, data)
  local handle, err = io.open(expand_user_path(path), "wb")
  if not handle then
    return nil, err
  end
  handle:write(data)
  handle:close()
  return true
end

function M.capture_command(command)
  local output, code = shell_all(command)
  if output == nil then
    return nil, code
  end
  output = output:gsub("%s+$", "")
  if code ~= 0 then
    return nil, code, output
  end
  return output
end

function M.is_executable(path)
  if is_windows() then
    local expanded = expand_user_path(path)
    if not M.exists(expanded) then
      return false
    end
    local lowered = expanded:lower()
    return lowered:match("%.exe$") or lowered:match("%.cmd$") or lowered:match("%.bat$")
  end
  local quoted = M.sh_quote(expand_user_path(path))
  return shell_read("[ -x " .. quoted .. " ] && printf yes") == "yes"
end

function M.run_command(command)
  local ok, why, code = os.execute(command)
  if type(ok) == "number" then
    return ok == 0, ok
  end
  if type(ok) == "boolean" then
    if why == "exit" or why == "signal" then
      return ok and tonumber(code) == 0, tonumber(code) or 1
    end
    return ok, ok and 0 or 1
  end
  return false, 1
end

function M.ensure_dir(path)
  if reaper and reaper.RecursiveCreateDirectory then
    reaper.RecursiveCreateDirectory(path, 0)
  elseif is_windows() then
    os.execute("mkdir " .. M.cmd_quote(path) .. " >NUL 2>NUL")
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

  local quoted = M.sh_quote(expand_user_path(path))
  local value = shell_read("stat -f %m " .. quoted .. " 2>/dev/null")
  if not value or value == "" then
    value = shell_read("stat -c %Y " .. quoted .. " 2>/dev/null")
  end
  return tonumber(value)
end

function M.file_size(path)
  if not M.exists(path) then
    return nil
  end

  if is_windows() then
    local value = shell_read("for %I in (" .. M.cmd_quote(expand_user_path(path)) .. ") do @echo %~zI")
    return tonumber(value)
  end

  local quoted = M.sh_quote(expand_user_path(path))
  local value = shell_read("stat -f %z " .. quoted .. " 2>/dev/null")
  if not value or value == "" then
    value = shell_read("stat -c %s " .. quoted .. " 2>/dev/null")
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

function M.remove_path(path)
  if M.directory_exists(path) then
    return M.remove_tree(path)
  end
  if M.exists(path) then
    return os.remove(path)
  end
  return false
end

function M.move_path(source, destination)
  local ok = M.run_command("mv " .. M.sh_quote(source) .. " " .. M.sh_quote(destination))
  return ok
end

function M.copy_file(source, destination)
  local ok = M.run_command("cp " .. M.sh_quote(source) .. " " .. M.sh_quote(destination))
  return ok
end

function M.mktemp_dir(prefix)
  local template = (prefix or "/tmp/reaper-audio-tag") .. "-XXXXXX"
  local dir = shell_read("mktemp -d " .. M.sh_quote(template) .. " 2>/dev/null")
  if dir and dir ~= "" then
    return dir
  end

  local fallback = (prefix or "/tmp/reaper-audio-tag") .. "-" .. tostring(os.time())
  M.ensure_dir(fallback)
  return fallback
end

function M.sha256(path)
  if is_windows() then
    local output = shell_all("certutil -hashfile " .. M.cmd_quote(path) .. " SHA256 2>NUL")
    if output and output ~= "" then
      for line in tostring(output):gmatch("[^\r\n]+") do
        local digest = line:match("^%s*([0-9a-fA-F]+)%s*$")
        if digest and #digest == 64 then
          return digest
        end
      end
    end
  end

  local line = shell_read("shasum -a 256 " .. M.sh_quote(path) .. " 2>/dev/null")
  if line and line ~= "" then
    return line:match("^([0-9a-fA-F]+)")
  end

  line = shell_read("openssl dgst -sha256 " .. M.sh_quote(path) .. " 2>/dev/null")
  if line and line ~= "" then
    return line:match("= ([0-9a-fA-F]+)$")
  end
  return nil
end

function M.sh_quote(value)
  local text = tostring(value)
  return "'" .. text:gsub("'", "'\\''") .. "'"
end

function M.cmd_quote(value)
  local text = tostring(value)
  return '"' .. text:gsub('"', '\\"') .. '"'
end

function M.sanitize_job_id(raw)
  local text = tostring(raw or "job")
  return text:gsub("[^%w%-_]+", "_")
end

return M
