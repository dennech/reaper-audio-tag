local json = require("json")
local path_utils = require("path_utils")

local M = {}

local SCHEMA_VERSION = "reaper-panns-item-report/v1"
local DEFAULT_TIMEOUT_SEC = 60
local MAX_TIMEOUT_SEC = 600

M.MODEL_FILENAME = "cnn14_waveform_clipwise_opset17.onnx"
M.MODEL_SIZE_BYTES = 327331996
M.MODEL_SHA256 = "deb65c5a2d291b3ce4ebf2360af71072b789ba11a4214ef77406b89ab97333aa"
M.MODEL_URL = "https://github.com/dennech/reaper-audio-tag/releases/download/v0.4.0/cnn14_waveform_clipwise_opset17.onnx"

local function is_windows(paths)
  return tostring(paths.os_name or ""):match("^Win") ~= nil
end

local function attempted_backends(paths, requested_backend)
  if requested_backend == "cpu" then
    return { "cpu" }
  end
  if is_windows(paths) then
    return { "directml", "cpu" }
  end
  return { "coreml", "cpu" }
end

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

local function write_request(path, payload)
  local text = json.encode(payload)
  path_utils.write_file(path, text)
end

local function positive_number(value)
  local numeric = tonumber(value)
  if numeric and numeric > 0 then
    return numeric
  end
  return nil
end

local function backend_executable_ready(paths)
  if not path_utils.exists(paths.backend_path) then
    return false, "The REAPER Audio Tag backend is missing. Run Extensions -> ReaPack -> Synchronize packages and update this package."
  end
  if not is_windows(paths) and not path_utils.is_executable(paths.backend_path) then
    path_utils.run_command("chmod 755 " .. path_utils.sh_quote(paths.backend_path))
  end
  if not is_windows(paths) and not path_utils.is_executable(paths.backend_path) then
    return false, "The REAPER Audio Tag backend is installed but is not executable. Run ReaPack synchronize/update again."
  end
  return true
end

function M.model_status(paths, options)
  options = options or {}
  if not path_utils.exists(paths.model_path) then
    return {
      ok = false,
      state = "missing",
      message = "The ONNX model has not been downloaded yet.",
    }
  end

  local size = path_utils.file_size(paths.model_path)
  if size ~= M.MODEL_SIZE_BYTES then
    return {
      ok = false,
      state = "bad_size",
      message = string.format("The downloaded model has the wrong size (%s bytes). Download it again.", tostring(size or "unknown")),
    }
  end

  if options.verify_checksum then
    local sha = path_utils.sha256(paths.model_path)
    if tostring(sha or ""):lower() ~= M.MODEL_SHA256 then
      return {
        ok = false,
        state = "bad_checksum",
        message = "The downloaded model checksum does not match. Download it again.",
      }
    end
  end

  return {
    ok = true,
    state = "ready",
    message = "Model is ready.",
    size = size,
  }
end

function M.runtime_ready(paths)
  local backend_ok = backend_executable_ready(paths)
  if not backend_ok then
    return false
  end
  return M.model_status(paths, { verify_checksum = false }).ok
end

function M.suggest_timeout_sec(item_payload, requested_backend)
  local item_metadata = item_payload and item_payload.item_metadata or {}
  local item_length = positive_number(item_metadata.item_length) or 0
  local multiplier = requested_backend == "cpu" and 5 or 3
  local computed = math.ceil((item_length * multiplier) + 30)
  computed = math.max(DEFAULT_TIMEOUT_SEC, computed)
  return math.min(MAX_TIMEOUT_SEC, computed)
end

local function error_payload(job, code, message, backend, warnings, elapsed_ms)
  local requested_backend = job and job.request_payload and job.request_payload.requested_backend or "auto"
  return {
    schema_version = SCHEMA_VERSION,
    status = "error",
    stage = "runtime",
    backend = backend or "cpu",
    attempted_backends = attempted_backends(job and job.paths or {}, requested_backend),
    timing_ms = {
      preprocess = 0,
      inference = 0,
      total = elapsed_ms or 0,
    },
    summary = "No analysis summary is available.",
    predictions = {},
    highlights = {},
    warnings = warnings or {},
    model_status = {
      name = "Cnn14 ONNX",
      source = "downloaded model",
    },
    item = job and job.request_payload and job.request_payload.item_metadata or {},
    error = {
      code = code,
      message = message,
    },
  }
end

local function write_posix_launcher(script_path, backend_path, subcommand, args, log_file)
  local lines = {
    "#!/bin/sh",
    "set -u",
    "{",
    "  printf '[%s] Launcher started.\\n' \"$(date '+%Y-%m-%d %H:%M:%S')\"",
    "  exec " .. path_utils.sh_quote(backend_path) .. " " .. subcommand .. " " .. table.concat(args, " "),
    "} >> " .. path_utils.sh_quote(log_file) .. " 2>&1",
    "",
  }
  return path_utils.write_file(script_path, table.concat(lines, "\n"))
end

local function launch_posix(script_path)
  path_utils.run_command("chmod 700 " .. path_utils.sh_quote(script_path))
  local command = "/bin/sh " .. path_utils.sh_quote(script_path) .. " >/dev/null 2>&1 &"
  local ok = path_utils.run_command(command)
  return ok, command
end

local function write_windows_launcher(script_path, backend_path, subcommand, args, log_file)
  local function quote(value)
    return '"' .. tostring(value):gsub('"', '\\"') .. '"'
  end
  local command = quote(backend_path) .. " " .. subcommand .. " " .. table.concat(args, " ")
  local lines = {
    "@echo off",
    command .. " >> " .. quote(log_file) .. " 2>&1",
    "",
  }
  return path_utils.write_file(script_path, table.concat(lines, "\r\n"))
end

local function launch_windows(script_path)
  local command = 'start "" /B cmd /C "' .. tostring(script_path):gsub('"', '\\"') .. '"'
  local ok = path_utils.run_command(command)
  return ok, command
end

local function posix_arg(name, value)
  return name .. " " .. path_utils.sh_quote(value)
end

local function windows_quote(value)
  return '"' .. tostring(value):gsub('"', '\\"') .. '"'
end

local function make_arg(paths, name, value)
  if is_windows(paths) then
    return name .. " " .. windows_quote(value)
  end
  return posix_arg(name, value)
end

local function make_job_dir(paths)
  path_utils.ensure_dir(paths.jobs_dir)
  local job_id = path_utils.sanitize_job_id(reaper.genGuid(""))
  local job_dir = path_utils.join(paths.jobs_dir, job_id)
  path_utils.ensure_dir(job_dir)
  return job_id, job_dir
end

function M.start_model_download(paths)
  local backend_ok, backend_err = backend_executable_ready(paths)
  if not backend_ok then
    return nil, backend_err
  end

  path_utils.ensure_dir(paths.models_dir)
  local job_id, job_dir = make_job_dir(paths)
  local result_file = path_utils.join(job_dir, "download-result.json")
  local progress_file = path_utils.join(job_dir, "download-progress.json")
  local log_file = path_utils.join(job_dir, "download.log")
  local launch_script = path_utils.join(job_dir, is_windows(paths) and "download-runtime.cmd" or "download-runtime.sh")

  local args = {
    make_arg(paths, "--url", M.MODEL_URL),
    make_arg(paths, "--output", paths.model_path),
    make_arg(paths, "--sha256", M.MODEL_SHA256),
    make_arg(paths, "--size", tostring(M.MODEL_SIZE_BYTES)),
    make_arg(paths, "--progress-file", progress_file),
    make_arg(paths, "--result-file", result_file),
    make_arg(paths, "--log-file", log_file),
  }

  local ok, write_err
  if is_windows(paths) then
    ok, write_err = write_windows_launcher(launch_script, paths.backend_path, "download-model", args, log_file)
  else
    ok, write_err = write_posix_launcher(launch_script, paths.backend_path, "download-model", args, log_file)
  end
  if not ok then
    return nil, "Could not write the model download launcher: " .. tostring(write_err or "unknown error")
  end

  local launched, launch_command
  if is_windows(paths) then
    launched, launch_command = launch_windows(launch_script)
  else
    launched, launch_command = launch_posix(launch_script)
  end
  if not launched then
    return nil, "Could not start the model download helper."
  end

  return {
    id = job_id,
    kind = "download",
    paths = paths,
    job_dir = job_dir,
    result_file = result_file,
    progress_file = progress_file,
    log_file = log_file,
    launch_script = launch_script,
    launch_command = launch_command,
    started_at = reaper.time_precise(),
  }
end

function M.poll_download(job)
  local progress = read_json(job.progress_file) or {}
  if path_utils.exists(job.result_file) then
    local payload, err = read_json(job.result_file)
    if payload then
      return {
        done = true,
        payload = payload,
        progress = progress,
      }
    end
    return {
      done = true,
      payload = { status = "error", error = { code = "malformed_json", message = tostring(err) } },
      progress = progress,
    }
  end
  return {
    done = false,
    elapsed_ms = math.floor((reaper.time_precise() - job.started_at) * 1000),
    progress = progress,
  }
end

function M.start_job(paths, item_payload, options)
  options = options or {}
  local backend_ok, backend_err = backend_executable_ready(paths)
  if not backend_ok then
    return nil, backend_err
  end

  local model_status = M.model_status(paths, { verify_checksum = true })
  if not model_status.ok then
    return nil, model_status.message
  end
  if not path_utils.exists(paths.labels_path) then
    return nil, "Audio tag labels are missing. Run Extensions -> ReaPack -> Synchronize packages and update this package."
  end

  local job_id, job_dir = make_job_dir(paths)
  local request_file = path_utils.join(job_dir, "request.json")
  local result_file = path_utils.join(job_dir, "result.json")
  local log_file = path_utils.join(job_dir, "runtime.log")
  local launch_script = path_utils.join(job_dir, is_windows(paths) and "launch-runtime.cmd" or "launch-runtime.sh")
  local requested_backend = options.requested_backend or "auto"
  local timeout_sec = positive_number(options.timeout_sec) or M.suggest_timeout_sec(item_payload, requested_backend)

  local request_payload = {
    schema_version = SCHEMA_VERSION,
    temp_audio_path = item_payload.temp_audio_path,
    item_metadata = item_payload.item_metadata,
    requested_backend = requested_backend,
    timeout_sec = timeout_sec,
  }
  write_request(request_file, request_payload)

  local args = {
    make_arg(paths, "--request-file", request_file),
    make_arg(paths, "--result-file", result_file),
    make_arg(paths, "--log-file", log_file),
    make_arg(paths, "--model-file", paths.model_path),
    make_arg(paths, "--labels-file", paths.labels_path),
    make_arg(paths, "--cache-dir", paths.model_cache_dir),
  }

  local ok, write_err
  if is_windows(paths) then
    ok, write_err = write_windows_launcher(launch_script, paths.backend_path, "analyze", args, log_file)
  else
    ok, write_err = write_posix_launcher(launch_script, paths.backend_path, "analyze", args, log_file)
  end
  if not ok then
    return nil, "Could not write the runtime launcher script: " .. tostring(write_err or "unknown error")
  end

  local launched, launch_command
  if is_windows(paths) then
    launched, launch_command = launch_windows(launch_script)
  else
    launched, launch_command = launch_posix(launch_script)
  end
  if not launched then
    return nil, "Could not start the REAPER Audio Tag backend."
  end

  return {
    id = job_id,
    kind = "analysis",
    paths = paths,
    job_dir = job_dir,
    request_file = request_file,
    result_file = result_file,
    log_file = log_file,
    launch_script = launch_script,
    launch_command = launch_command,
    started_at = reaper.time_precise(),
    timeout_sec = timeout_sec,
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
      payload = error_payload(job, "malformed_json", "Runtime returned malformed JSON: " .. tostring(err), "cpu", {}, 0),
    }
  end

  local elapsed = reaper.time_precise() - job.started_at
  if elapsed > job.timeout_sec then
    return {
      done = true,
      payload = error_payload(
        job,
        "timeout",
        "Analysis timed out before the runtime produced a result file.",
        "cpu",
        { "The runtime timed out." },
        math.floor(elapsed * 1000)
      ),
    }
  end

  return {
    done = false,
    elapsed_ms = math.floor(elapsed * 1000),
  }
end

return M
