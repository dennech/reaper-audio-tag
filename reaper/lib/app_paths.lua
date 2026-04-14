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
  local packaged_runtime_source = path_utils.join(script_dir(), "runtime", "src")
  local checkout_runtime_source = path_utils.join(repo_root, "reaper", "runtime", "src")
  local runtime_source_root = path_utils.directory_exists(packaged_runtime_source) and packaged_runtime_source or checkout_runtime_source
  local os_name = reaper.GetOS()

  return {
    script_path = script_path(),
    script_dir = script_dir(),
    repo_root = repo_root,
    data_dir = data_dir,
    jobs_dir = path_utils.join(data_dir, "jobs"),
    tmp_dir = path_utils.join(data_dir, "tmp"),
    logs_dir = path_utils.join(data_dir, "logs"),
    config_path = path_utils.join(data_dir, "config.json"),
    runtime_source_root = runtime_source_root,
    runtime_dir = path_utils.join(data_dir, "runtime"),
    models_dir = path_utils.join(data_dir, "models"),
    configure_script_path = path_utils.join(script_dir(), "REAPER Audio Tag - Configure.lua"),
    os_name = os_name,
  }
end

return M
