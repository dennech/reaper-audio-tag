local luaunit = require("tests.lua.vendor.luaunit")
local json = require("json")
local path_utils = require("path_utils")
local runtime_client = require("runtime_client")

local tests = {}

local function mktemp_dir()
  local handle = assert(io.popen("mktemp -d"))
  local dir = handle:read("*l")
  handle:close()
  return dir
end

local function write_text(path, value)
  path_utils.ensure_dir(path_utils.dirname(path))
  local handle = assert(io.open(path, "wb"))
  handle:write(value)
  handle:close()
end

local function write_json(path, payload)
  write_text(path, json.encode(payload))
end

local function sparse_model(path, size)
  path_utils.ensure_dir(path_utils.dirname(path))
  local ok = path_utils.run_command("truncate -s " .. tostring(size) .. " " .. path_utils.sh_quote(path))
  if not ok then
    local handle = assert(io.open(path, "wb"))
    handle:seek("set", size - 1)
    handle:write("\0")
    handle:close()
  end
end

local function write_fake_backend(path)
  write_text(path, [[#!/bin/sh
set -eu
subcommand="${1:-}"
shift || true
result=""
progress=""
log=""
request=""
model=""
labels=""
cache=""
while [ "$#" -gt 0 ]; do
  case "$1" in
    --result-file) result="$2"; shift 2 ;;
    --progress-file) progress="$2"; shift 2 ;;
    --log-file) log="$2"; shift 2 ;;
    --request-file) request="$2"; shift 2 ;;
    --model-file) model="$2"; shift 2 ;;
    --labels-file) labels="$2"; shift 2 ;;
    --cache-dir) cache="$2"; shift 2 ;;
    *) shift ;;
  esac
done
mkdir -p "$(dirname "$result")"
if [ -n "$log" ]; then
  printf 'subcommand=%s\nrequest=%s\nmodel=%s\nlabels=%s\ncache=%s\n' "$subcommand" "$request" "$model" "$labels" "$cache" >> "$log"
fi
if [ "$subcommand" = "download-model" ]; then
  if [ -n "$progress" ]; then
    printf '{"status":"done","downloaded":327331996,"total":327331996}\n' > "$progress"
  fi
  printf '{"status":"ok","path":"%s","size":327331996,"sha256":"deb65c5a2d291b3ce4ebf2360af71072b789ba11a4214ef77406b89ab97333aa"}\n' "$model" > "$result"
else
  cat > "$result" <<'JSON'
{"schema_version":"reaper-panns-item-report/v1","status":"ok","backend":"cpu","attempted_backends":["coreml","cpu"],"timing_ms":{"preprocess":1,"inference":2,"total":3},"summary":"ok","predictions":[],"highlights":[],"warnings":[],"model_status":{"name":"Cnn14 ONNX","source":"downloaded model"},"item":{},"error":null}
JSON
fi
]])
  path_utils.run_command("chmod +x " .. path_utils.sh_quote(path))
end

local function wait_for_file(path)
  for _ = 1, 50 do
    if path_utils.exists(path) then
      return true
    end
    path_utils.run_command("sleep 0.05")
  end
  return false
end

local function fake_paths(root)
  return {
    data_dir = path_utils.join(root, "Data", "reaper-panns-item-report"),
    jobs_dir = path_utils.join(root, "Data", "reaper-panns-item-report", "jobs"),
    models_dir = path_utils.join(root, "Data", "reaper-panns-item-report", "models"),
    logs_dir = path_utils.join(root, "Data", "reaper-panns-item-report", "logs"),
    tmp_dir = path_utils.join(root, "Data", "reaper-panns-item-report", "tmp"),
    backend_path = path_utils.join(root, "Data", "reaper-panns-item-report", "bin", "reaper-audio-tag-backend"),
    labels_path = path_utils.join(root, "Data", "reaper-panns-item-report", "metadata", "class_labels_indices.csv"),
    model_path = path_utils.join(root, "Data", "reaper-panns-item-report", "models", runtime_client.MODEL_FILENAME),
    model_cache_dir = path_utils.join(root, "Data", "reaper-panns-item-report", "coreml-cache"),
    os_name = "OSX64",
  }
end

local function prepare_runtime_tree(paths)
  write_fake_backend(paths.backend_path)
  write_text(paths.labels_path, "index,mid,display_name\n0,/m/09x0r,Speech\n")
  sparse_model(paths.model_path, runtime_client.MODEL_SIZE_BYTES)
end

function tests.test_model_status_reports_missing_and_bad_size()
  local root = mktemp_dir()
  local paths = fake_paths(root)

  local missing = runtime_client.model_status(paths, { verify_checksum = false })
  luaunit.assertEquals(missing.ok, false)
  luaunit.assertEquals(missing.state, "missing")

  write_text(paths.model_path, "too small")
  local bad_size = runtime_client.model_status(paths, { verify_checksum = false })
  luaunit.assertEquals(bad_size.ok, false)
  luaunit.assertEquals(bad_size.state, "bad_size")

  path_utils.remove_tree(root)
end

function tests.test_start_job_uses_self_contained_backend_and_model_paths()
  local original_reaper = _G.reaper
  local original_sha256 = path_utils.sha256
  local root = mktemp_dir()
  local paths = fake_paths(path_utils.join(root, "runtime launch with spaces"))
  prepare_runtime_tree(paths)
  path_utils.sha256 = function()
    return runtime_client.MODEL_SHA256
  end

  _G.reaper = {
    RecursiveCreateDirectory = function(path)
      path_utils.run_command("mkdir -p " .. path_utils.sh_quote(path))
    end,
    genGuid = function()
      return "{job-guid}"
    end,
    time_precise = function()
      return 1.25
    end,
  }

  local job, err = runtime_client.start_job(
    paths,
    {
      temp_audio_path = "/tmp/item with spaces.wav",
      item_metadata = {
        item_name = "Test Item",
      },
    },
    {
      requested_backend = "auto",
      timeout_sec = 12,
    }
  )

  _G.reaper = original_reaper
  path_utils.sha256 = original_sha256

  luaunit.assertEquals(err, nil)
  luaunit.assertEquals(job ~= nil, true)
  luaunit.assertEquals(job.timeout_sec, 12)
  luaunit.assertEquals(path_utils.exists(job.launch_script), true)

  local launch_source = assert(path_utils.read_file(job.launch_script))
  luaunit.assertStrContains(launch_source, path_utils.sh_quote(paths.backend_path))
  luaunit.assertStrContains(launch_source, "--model-file " .. path_utils.sh_quote(paths.model_path))
  luaunit.assertStrContains(launch_source, "--labels-file " .. path_utils.sh_quote(paths.labels_path))
  luaunit.assertEquals(launch_source:find("PYTHONPATH", 1, true), nil)
  luaunit.assertEquals(launch_source:find("venv", 1, true), nil)

  luaunit.assertEquals(wait_for_file(job.result_file), true)
  local log_text = assert(path_utils.read_file(job.log_file))
  luaunit.assertStrContains(log_text, "subcommand=analyze")
  luaunit.assertStrContains(log_text, "model=" .. paths.model_path)
  luaunit.assertStrContains(log_text, "labels=" .. paths.labels_path)

  path_utils.remove_tree(root)
end

function tests.test_start_job_requires_backend_model_and_labels()
  local root = mktemp_dir()
  local paths = fake_paths(root)

  local job, err = runtime_client.start_job(paths, { temp_audio_path = "/tmp/item.wav" }, {})
  luaunit.assertEquals(job, nil)
  luaunit.assertStrContains(err, "backend is missing")

  write_fake_backend(paths.backend_path)
  job, err = runtime_client.start_job(paths, { temp_audio_path = "/tmp/item.wav" }, {})
  luaunit.assertEquals(job, nil)
  luaunit.assertStrContains(err, "model has not been downloaded")

  sparse_model(paths.model_path, runtime_client.MODEL_SIZE_BYTES)
  local original_sha256 = path_utils.sha256
  path_utils.sha256 = function()
    return runtime_client.MODEL_SHA256
  end
  job, err = runtime_client.start_job(paths, { temp_audio_path = "/tmp/item.wav" }, {})
  path_utils.sha256 = original_sha256
  luaunit.assertEquals(job, nil)
  luaunit.assertStrContains(err, "Audio tag labels are missing")

  path_utils.remove_tree(root)
end

function tests.test_start_model_download_launches_backend_helper()
  local original_reaper = _G.reaper
  local root = mktemp_dir()
  local paths = fake_paths(root)
  write_fake_backend(paths.backend_path)

  _G.reaper = {
    RecursiveCreateDirectory = function(path)
      path_utils.run_command("mkdir -p " .. path_utils.sh_quote(path))
    end,
    genGuid = function()
      return "{download-guid}"
    end,
    time_precise = function()
      return 2.5
    end,
  }

  local job, err = runtime_client.start_model_download(paths)
  _G.reaper = original_reaper

  luaunit.assertEquals(err, nil)
  luaunit.assertEquals(job ~= nil, true)
  luaunit.assertEquals(wait_for_file(job.result_file), true)

  local polled = runtime_client.poll_download(job)
  luaunit.assertEquals(polled.done, true)
  luaunit.assertEquals(polled.payload.status, "ok")
  local progress = polled.progress or {}
  luaunit.assertEquals(progress.status, "done")

  path_utils.remove_tree(root)
end

function tests.test_start_job_scales_timeout_for_long_items()
  local original_reaper = _G.reaper
  local original_sha256 = path_utils.sha256
  local root = mktemp_dir()
  local paths = fake_paths(root)
  prepare_runtime_tree(paths)
  path_utils.sha256 = function()
    return runtime_client.MODEL_SHA256
  end

  _G.reaper = {
    RecursiveCreateDirectory = function(path)
      path_utils.run_command("mkdir -p " .. path_utils.sh_quote(path))
    end,
    genGuid = function()
      return "{long-job-guid}"
    end,
    time_precise = function()
      return 3.0
    end,
  }

  local job, err = runtime_client.start_job(
    paths,
    {
      temp_audio_path = "/tmp/item.wav",
      item_metadata = {
        item_name = "Long Item",
        item_length = 39.25,
      },
    },
    {
      requested_backend = "auto",
    }
  )

  _G.reaper = original_reaper
  path_utils.sha256 = original_sha256

  luaunit.assertEquals(err, nil)
  luaunit.assertEquals(job ~= nil, true)
  luaunit.assertEquals(job.timeout_sec > 45, true)
  luaunit.assertEquals(job.request_payload.timeout_sec, job.timeout_sec)

  path_utils.remove_tree(root)
end

function tests.test_poll_job_returns_normalized_timeout_payload()
  local original_reaper = _G.reaper
  _G.reaper = {
    time_precise = function()
      return 10.5
    end,
  }

  local polled = runtime_client.poll_job({
    result_file = "/tmp/does-not-exist.json",
    started_at = 0,
    timeout_sec = 2,
    request_payload = {
      requested_backend = "auto",
      item_metadata = {
        item_name = "Timed out item",
      },
    },
    paths = {
      os_name = "OSX64",
    },
  })

  _G.reaper = original_reaper

  luaunit.assertEquals(polled.done, true)
  luaunit.assertEquals(polled.payload.status, "error")
  luaunit.assertEquals(polled.payload.stage, "runtime")
  luaunit.assertEquals(polled.payload.error.code, "timeout")
  luaunit.assertEquals(polled.payload.attempted_backends[1], "coreml")
  luaunit.assertEquals(polled.payload.attempted_backends[2], "cpu")
  luaunit.assertEquals(polled.payload.item.item_name, "Timed out item")
end

function tests.test_poll_job_returns_normalized_malformed_json_payload()
  local original_reaper = _G.reaper
  local root = mktemp_dir()
  local result_file = path_utils.join(root, "result.json")
  write_text(result_file, "{not-json")

  _G.reaper = {
    time_precise = function()
      return 1.0
    end,
  }

  local polled = runtime_client.poll_job({
    result_file = result_file,
    started_at = 0,
    timeout_sec = 10,
    request_payload = {
      requested_backend = "cpu",
      item_metadata = {
        item_name = "Broken result",
      },
    },
    paths = {
      os_name = "OSX64",
    },
  })

  _G.reaper = original_reaper

  luaunit.assertEquals(polled.done, true)
  luaunit.assertEquals(polled.payload.status, "error")
  luaunit.assertEquals(polled.payload.stage, "runtime")
  luaunit.assertEquals(polled.payload.error.code, "malformed_json")
  luaunit.assertEquals(polled.payload.attempted_backends[1], "cpu")
  luaunit.assertEquals(polled.payload.item.item_name, "Broken result")

  path_utils.remove_tree(root)
end

return tests
