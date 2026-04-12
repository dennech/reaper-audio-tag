local path_utils = require("path_utils")

local M = {}

local function script_path()
  local _, script = reaper.get_action_context()
  return script
end

local function script_dir()
  return path_utils.dirname(script_path())
end

local function resource_dir()
  local ini_path = reaper.get_ini_file()
  return path_utils.dirname(ini_path)
end

function M.build()
  local repo_root = path_utils.dirname(script_dir())
  local data_dir = path_utils.join(resource_dir(), "Data", "reaper-panns-item-report")
  local runtime_dir = path_utils.join(data_dir, "runtime")
  local os_name = reaper.GetOS()
  local python_path
  if os_name:match("^Win") then
    python_path = path_utils.join(runtime_dir, "venv", "Scripts", "python.exe")
  else
    python_path = path_utils.join(runtime_dir, "venv", "bin", "python")
  end

  return {
    script_path = script_path(),
    script_dir = script_dir(),
    repo_root = repo_root,
    data_dir = data_dir,
    jobs_dir = path_utils.join(data_dir, "jobs"),
    tmp_dir = path_utils.join(data_dir, "tmp"),
    logs_dir = path_utils.join(data_dir, "logs"),
    config_path = path_utils.join(data_dir, "config.json"),
    python_path = python_path,
    bootstrap_command = path_utils.join(repo_root, "scripts", "bootstrap.command"),
    bootstrap_shell = path_utils.join(repo_root, "scripts", "bootstrap_runtime.sh"),
    os_name = os_name,
  }
end

return M

