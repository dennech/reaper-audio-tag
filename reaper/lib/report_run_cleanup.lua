local path_utils = require("path_utils")

local M = {}

local DEFAULT_RETENTION_SEC = 7 * 24 * 60 * 60

local function safe_remove_file(root, path)
  if not path or path == "" then
    return false
  end
  if not path_utils.is_subpath(path, root) then
    return false
  end
  if path_utils.directory_exists(path) then
    return false
  end
  if not path_utils.exists(path) then
    return false
  end
  return os.remove(path)
end

local function safe_remove_tree(root, path)
  if not path or path == "" then
    return false
  end
  if not path_utils.is_subpath(path, root) then
    return false
  end
  if not path_utils.directory_exists(path) then
    return false
  end
  return path_utils.remove_tree(path)
end

local function is_stale(path, cutoff)
  local modified_at = path_utils.mtime(path)
  return modified_at and modified_at < cutoff or false
end

function M.new_artifacts(export_path, export_log_file, job)
  return {
    export_path = export_path,
    export_log_file = export_log_file,
    job_dir = job and job.job_dir or nil,
    request_file = job and job.request_file or nil,
    result_file = job and job.result_file or nil,
    runtime_log_file = job and job.log_file or nil,
  }
end

function M.clear_temp_audio(paths, artifacts)
  if not artifacts then
    return
  end
  safe_remove_file(paths.tmp_dir, artifacts.export_path)
  artifacts.export_path = nil
end

function M.cleanup_run(paths, artifacts)
  if not artifacts then
    return
  end

  M.clear_temp_audio(paths, artifacts)
  safe_remove_file(paths.logs_dir, artifacts.export_log_file)
  safe_remove_file(paths.jobs_dir, artifacts.request_file)
  safe_remove_file(paths.jobs_dir, artifacts.result_file)
  safe_remove_file(paths.jobs_dir, artifacts.runtime_log_file)
  safe_remove_tree(paths.jobs_dir, artifacts.job_dir)
end

function M.prune_stale(paths, options)
  options = options or {}
  local retention_sec = tonumber(options.retention_sec) or DEFAULT_RETENTION_SEC
  local now = tonumber(options.now) or os.time()
  local cutoff = now - retention_sec

  for _, file_path in ipairs(path_utils.list_files(paths.tmp_dir)) do
    if is_stale(file_path, cutoff) then
      safe_remove_file(paths.tmp_dir, file_path)
    end
  end

  for _, file_path in ipairs(path_utils.list_files(paths.logs_dir)) do
    if is_stale(file_path, cutoff) then
      safe_remove_file(paths.logs_dir, file_path)
    end
  end

  for _, file_path in ipairs(path_utils.list_files(paths.jobs_dir)) do
    if is_stale(file_path, cutoff) then
      safe_remove_file(paths.jobs_dir, file_path)
    end
  end

  for _, dir_path in ipairs(path_utils.list_dirs(paths.jobs_dir)) do
    if is_stale(dir_path, cutoff) then
      safe_remove_tree(paths.jobs_dir, dir_path)
    end
  end
end

return M
