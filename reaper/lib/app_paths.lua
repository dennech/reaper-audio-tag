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

local function resolve_runtime_source(resource_root, data_dir, repo_root)
  local app_scoped_runtime_source = path_utils.join(data_dir, "runtime", "src")
  local legacy_runtime_source = path_utils.join(resource_root, "Data", "runtime", "src")
  local checkout_runtime_source = path_utils.join(repo_root, "reaper", "reaper-panns-item-report", "runtime", "src")
  local checkout_legacy_runtime_source = path_utils.join(repo_root, "reaper", "runtime", "src")

  if path_utils.directory_exists(app_scoped_runtime_source) then
    return app_scoped_runtime_source, "data_app", app_scoped_runtime_source, legacy_runtime_source, checkout_runtime_source
  end
  if path_utils.directory_exists(legacy_runtime_source) then
    return legacy_runtime_source, "data_legacy", app_scoped_runtime_source, legacy_runtime_source, checkout_runtime_source
  end
  if path_utils.directory_exists(checkout_runtime_source) then
    return checkout_runtime_source, "checkout", app_scoped_runtime_source, legacy_runtime_source, checkout_runtime_source
  end
  if path_utils.directory_exists(checkout_legacy_runtime_source) then
    return checkout_legacy_runtime_source, "checkout", app_scoped_runtime_source, legacy_runtime_source, checkout_runtime_source
  end

  return app_scoped_runtime_source, "missing", app_scoped_runtime_source, legacy_runtime_source, checkout_runtime_source
end

function M.build()
  local resource_root = resource_dir()
  local repo_root = path_utils.dirname(script_dir())
  local data_dir = path_utils.join(resource_root, "Data", "reaper-panns-item-report")
  local runtime_source_root, runtime_source_origin, runtime_source_expected_root, runtime_source_legacy_root, checkout_runtime_source =
    resolve_runtime_source(resource_root, data_dir, repo_root)
  local os_name = reaper.GetOS()

  return {
    script_path = script_path(),
    script_dir = script_dir(),
    repo_root = repo_root,
    resource_dir = resource_root,
    data_dir = data_dir,
    jobs_dir = path_utils.join(data_dir, "jobs"),
    tmp_dir = path_utils.join(data_dir, "tmp"),
    logs_dir = path_utils.join(data_dir, "logs"),
    config_path = path_utils.join(data_dir, "config.json"),
    runtime_source_root = runtime_source_root,
    runtime_source_origin = runtime_source_origin,
    runtime_source_expected_root = runtime_source_expected_root,
    runtime_source_legacy_root = runtime_source_legacy_root,
    checkout_runtime_source = checkout_runtime_source,
    runtime_dir = path_utils.join(data_dir, "runtime"),
    models_dir = path_utils.join(data_dir, "models"),
    configure_script_path = path_utils.join(script_dir(), "REAPER Audio Tag - Configure.lua"),
    os_name = os_name,
  }
end

return M
