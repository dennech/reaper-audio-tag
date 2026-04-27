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

local function executable_suffix(os_name)
  if tostring(os_name or ""):match("^Win") then
    return ".exe"
  end
  return ""
end

local function backend_candidates(data_dir, os_name)
  local suffix = executable_suffix(os_name)
  if tostring(os_name or ""):match("^Win") then
    return {
      path_utils.join(data_dir, "bin", "windows-x64", "reaper-audio-tag-backend.exe"),
      path_utils.join(data_dir, "bin", "reaper-audio-tag-backend" .. suffix),
    }
  end
  if tostring(os_name or ""):match("^OSX") then
    local override_arch = rawget(_G, "REAPER_AUDIO_TAG_TEST_ARCH")
    local arch = override_arch
    if not arch or arch == "" then
      arch = path_utils.capture_command("uname -m 2>/dev/null")
    end
    arch = tostring(arch or ""):lower()
    local arm_backend = path_utils.join(data_dir, "bin", "macos-arm64", "reaper-audio-tag-backend")
    local intel_backend = path_utils.join(data_dir, "bin", "macos-x86_64", "reaper-audio-tag-backend")
    local generic_backend = path_utils.join(data_dir, "bin", "reaper-audio-tag-backend" .. suffix)
    if arch:match("x86_64") or arch:match("amd64") then
      return {
        intel_backend,
        arm_backend,
        generic_backend,
      }
    end
    return {
      arm_backend,
      intel_backend,
      generic_backend,
    }
  end
  return {
    path_utils.join(data_dir, "bin", "reaper-audio-tag-backend" .. suffix),
  }
end

local function resolve_backend_path(data_dir, os_name)
  local candidates = backend_candidates(data_dir, os_name)
  for _, candidate in ipairs(candidates) do
    if path_utils.exists(candidate) then
      return candidate, candidates
    end
  end
  return candidates[1], candidates
end

local function model_cache_dir(data_dir, os_name)
  if tostring(os_name or ""):match("^OSX") then
    local home = os.getenv("HOME")
    if home and home ~= "" then
      return path_utils.join(home, "Library", "Caches", "reaper-audio-tag", "coreml-cache")
    end
  end
  return path_utils.join(data_dir, "coreml-cache")
end

function M.build()
  local resource_root = resource_dir()
  local repo_root = path_utils.dirname(script_dir())
  local os_name = reaper.GetOS()
  local data_dir = path_utils.join(resource_root, "Data", "reaper-panns-item-report")
  local backend_path, backend_candidates_list = resolve_backend_path(data_dir, os_name)

  return {
    script_path = script_path(),
    script_dir = script_dir(),
    repo_root = repo_root,
    resource_dir = resource_root,
    data_dir = data_dir,
    jobs_dir = path_utils.join(data_dir, "jobs"),
    tmp_dir = path_utils.join(data_dir, "tmp"),
    logs_dir = path_utils.join(data_dir, "logs"),
    backend_dir = path_utils.join(data_dir, "bin"),
    backend_path = backend_path,
    backend_candidates = backend_candidates_list,
    labels_path = path_utils.join(data_dir, "metadata", "class_labels_indices.csv"),
    models_dir = path_utils.join(data_dir, "models"),
    model_path = path_utils.join(data_dir, "models", "cnn14_waveform_clipwise_opset17.onnx"),
    model_progress_path = path_utils.join(data_dir, "models", "cnn14_waveform_clipwise_opset17.progress.json"),
    model_cache_dir = model_cache_dir(data_dir, os_name),
    os_name = os_name,
  }
end

return M
