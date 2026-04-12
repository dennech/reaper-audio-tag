local json = require("json")
local path_utils = require("path_utils")

local M = {}

local SCHEMA_VERSION = "reaper-panns-item-report/v1"

local function read_json(path)
  local text = path_utils.read_file(path)
  if not text then
    return nil
  end
  local ok, payload = pcall(json.decode, text)
  if not ok then
    return nil, payload
  end
  return payload
end

function M.load_config(paths)
  if not path_utils.exists(paths.config_path) then
    return nil, "Runtime config was not found. Run bootstrap.command first."
  end
  return read_json(paths.config_path)
end

function M.runtime_ready(paths)
  if not path_utils.exists(paths.config_path) then
    return false
  end
  return path_utils.exists(paths.python_path)
end

function M.open_bootstrap(paths)
  if not path_utils.exists(paths.bootstrap_command) then
    return false, "bootstrap.command was not found."
  end
  local command
  if paths.os_name:match("^Win") then
    command = 'cmd /c start "" "' .. paths.bootstrap_command .. '"'
  else
    command = "open " .. path_utils.sh_quote(paths.bootstrap_command)
  end
  reaper.ExecProcess(command, -2)
  return true
end

local function write_request(path, payload)
  local text = json.encode(payload)
  path_utils.write_file(path, text)
end

function M.start_job(paths, item_payload, options)
  if paths.os_name:match("^Win") then
    return nil, "Windows support is planned after the first macOS release."
  end

  local config, err = M.load_config(paths)
  if not config then
    return nil, err
  end

  local python_path = paths.python_path
  if not path_utils.exists(python_path) then
    return nil, "Configured Python runtime was not found. Run bootstrap.command again."
  end

  path_utils.ensure_dir(paths.jobs_dir)
  local job_id = path_utils.sanitize_job_id(reaper.genGuid(""))
  local job_dir = path_utils.join(paths.jobs_dir, job_id)
  path_utils.ensure_dir(job_dir)

  local request_file = path_utils.join(job_dir, "request.json")
  local result_file = path_utils.join(job_dir, "result.json")
  local log_file = path_utils.join(job_dir, "runtime.log")

  local request_payload = {
    schema_version = SCHEMA_VERSION,
    temp_audio_path = item_payload.temp_audio_path,
    item_metadata = item_payload.item_metadata,
    requested_backend = options.requested_backend or "auto",
    timeout_sec = options.timeout_sec or 30,
  }
  write_request(request_file, request_payload)

  local inner = table.concat({
    path_utils.sh_quote(python_path),
    "-m",
    "reaper_panns_runtime",
    "analyze",
    "--request-file",
    path_utils.sh_quote(request_file),
    "--result-file",
    path_utils.sh_quote(result_file),
    ">",
    path_utils.sh_quote(log_file),
    "2>&1",
  }, " ")
  local command = "/bin/sh -lc " .. path_utils.sh_quote(inner)

  reaper.ExecProcess(command, -1)

  return {
    id = job_id,
    job_dir = job_dir,
    request_file = request_file,
    result_file = result_file,
    log_file = log_file,
    started_at = reaper.time_precise(),
    timeout_sec = options.timeout_sec or 30,
    request_payload = request_payload,
  }
end

function M.poll_job(job)
  if path_utils.exists(job.result_file) then
    local payload, err = read_json(job.result_file)
    if payload then
      return {
        done = true,
        payload = payload,
      }
    end
    return {
      done = true,
      payload = {
        schema_version = SCHEMA_VERSION,
        status = "error",
        backend = "cpu",
        timing_ms = { total = 0 },
        predictions = {},
        highlights = {},
        warnings = {},
        error = {
          code = "malformed_json",
          message = "Runtime returned malformed JSON: " .. tostring(err),
        },
      },
    }
  end

  local elapsed = reaper.time_precise() - job.started_at
  if elapsed > job.timeout_sec then
    return {
      done = true,
      payload = {
        schema_version = SCHEMA_VERSION,
        status = "error",
        backend = "cpu",
        timing_ms = { total = math.floor(elapsed * 1000) },
        predictions = {},
        highlights = {},
        warnings = { "The runtime timed out." },
        error = {
          code = "timeout",
          message = "Analysis timed out before the runtime produced a result file.",
        },
      },
    }
  end

  return {
    done = false,
    elapsed_ms = math.floor(elapsed * 1000),
  }
end

return M
