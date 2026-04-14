local luaunit = require("tests.lua.vendor.luaunit")
local configure_runtime = require("configure_runtime")
local json = require("json")
local path_utils = require("path_utils")

local tests = {}

local function mktemp_dir()
  local handle = io.popen("mktemp -d")
  local dir = handle:read("*l")
  handle:close()
  return dir
end

local function write_text(path, value)
  local handle = assert(io.open(path, "wb"))
  handle:write(value)
  handle:close()
end

local function write_json(path, payload)
  write_text(path, json.encode(payload))
end

local function build_paths(root)
  return {
    repo_root = path_utils.join(root, "Repo"),
    data_dir = path_utils.join(root, "Data", "reaper-panns-item-report"),
    config_path = path_utils.join(root, "Data", "reaper-panns-item-report", "config.json"),
    runtime_source_root = path_utils.join(root, "Scripts", "runtime", "src"),
  }
end

function tests.test_prefill_draft_surfaces_missing_config_message()
  local root = mktemp_dir()
  local paths = build_paths(root)

  local draft, message = configure_runtime.prefill_draft(paths, {
    capture_command = function()
      return nil
    end,
    exists = function()
      return false
    end,
    is_executable = function()
      return false
    end,
    directory_exists = function(path)
      return path == paths.runtime_source_root
    end,
    read_file = function()
      return nil
    end,
  })

  luaunit.assertEquals(draft.python_path, "")
  luaunit.assertEquals(draft.model_path, "")
  luaunit.assertStrContains(message, "Configuration is missing")

  os.execute("rm -rf " .. path_utils.sh_quote(root))
end

function tests.test_prefill_draft_autodetects_python_and_model_candidates()
  local root = mktemp_dir()
  local paths = build_paths(root)
  local expected_python = path_utils.join(paths.data_dir, "venv", "bin", "python")
  local expected_model = path_utils.join(root, "Downloads", configure_runtime.MODEL_FILENAME)

  local draft, message = configure_runtime.prefill_draft(paths, {
    expand_user = function(path)
      if path == "~/Downloads/" .. configure_runtime.MODEL_FILENAME then
        return expected_model
      end
      return path
    end,
    exists = function(path)
      return path == expected_python or path == expected_model
    end,
    is_executable = function(path)
      return path == expected_python
    end,
    directory_exists = function(path)
      return path == paths.runtime_source_root
    end,
    capture_command = function()
      return nil
    end,
    read_file = function()
      return nil
    end,
  })

  luaunit.assertEquals(draft.python_path, expected_python)
  luaunit.assertEquals(draft.model_path, expected_model)
  luaunit.assertStrContains(message, "Configuration is missing")

  os.execute("rm -rf " .. path_utils.sh_quote(root))
end

function tests.test_prefill_draft_migrates_only_model_from_legacy_config()
  local root = mktemp_dir()
  local paths = build_paths(root)
  path_utils.ensure_dir(path_utils.dirname(paths.config_path))
  write_json(paths.config_path, {
    schema_version = "reaper-panns-item-report/v1",
    python_executable = "/tmp/managed-python",
    model = {
      name = "Cnn14",
      path = "/tmp/Cnn14_mAP=0.431.pth",
    },
  })

  local draft, message = configure_runtime.prefill_draft(paths, {
    capture_command = function()
      return nil
    end,
    exists = function(path)
      return path == paths.config_path or path == "/tmp/Cnn14_mAP=0.431.pth"
    end,
    is_executable = function()
      return false
    end,
    directory_exists = function(path)
      return path == paths.runtime_source_root
    end,
  })

  luaunit.assertEquals(draft.python_path, "")
  luaunit.assertEquals(draft.model_path, "/tmp/Cnn14_mAP=0.431.pth")
  luaunit.assertStrContains(message, "old installer format")

  os.execute("rm -rf " .. path_utils.sh_quote(root))
end

function tests.test_validate_draft_accepts_good_python_and_model()
  local root = mktemp_dir()
  local paths = build_paths(root)

  local validation = configure_runtime.validate_draft(paths, {
    python_path = "~/venv/bin/python",
    model_path = "/tmp/Cnn14_mAP=0.431.pth",
  }, {
    expand_user = function(path)
      return path == "~/venv/bin/python" and "/Users/test/venv/bin/python" or path
    end,
    directory_exists = function(path)
      return path == paths.runtime_source_root
    end,
    exists = function(path)
      return path == "/Users/test/venv/bin/python" or path == "/tmp/Cnn14_mAP=0.431.pth"
    end,
    is_executable = function(path)
      return path == "/Users/test/venv/bin/python"
    end,
    capture_command = function(command)
      luaunit.assertStrContains(command, "PYTHONPATH=" .. path_utils.sh_quote(paths.runtime_source_root))
      luaunit.assertStrContains(command, path_utils.sh_quote("/Users/test/venv/bin/python"))
      return json.encode({
        version = { 3, 11, 9 },
        versions = {
          numpy = "1.26.4",
          soundfile = "0.12.1",
          torch = "2.6.0",
          torchaudio = "2.6.0",
          torchlibrosa = "0.1.0",
        },
        errors = {},
      }), 0
    end,
    sha256 = function(path)
      luaunit.assertEquals(path, "/tmp/Cnn14_mAP=0.431.pth")
      return configure_runtime.MODEL_SHA256
    end,
    file_size = function(path)
      luaunit.assertEquals(path, "/tmp/Cnn14_mAP=0.431.pth")
      return configure_runtime.MODEL_SIZE_BYTES
    end,
  })

  luaunit.assertEquals(validation.ok, true)
  luaunit.assertEquals(validation.python.ok, true)
  luaunit.assertEquals(validation.model.ok, true)
  luaunit.assertEquals(validation.python_path, "/Users/test/venv/bin/python")
end

function tests.test_validate_draft_rejects_wrong_python_version()
  local root = mktemp_dir()
  local paths = build_paths(root)

  local validation = configure_runtime.validate_draft(paths, {
    python_path = "/tmp/python3",
    model_path = "/tmp/Cnn14_mAP=0.431.pth",
  }, {
    directory_exists = function(path)
      return path == paths.runtime_source_root
    end,
    exists = function(path)
      return path == "/tmp/python3" or path == "/tmp/Cnn14_mAP=0.431.pth"
    end,
    is_executable = function(path)
      return path == "/tmp/python3"
    end,
    capture_command = function()
      return json.encode({
        version = { 3, 12, 1 },
        versions = {
          numpy = "1.26.4",
          soundfile = "0.12.1",
          torch = "2.6.0",
          torchaudio = "2.6.0",
          torchlibrosa = "0.1.0",
        },
        errors = {},
      }), 0
    end,
    sha256 = function()
      return configure_runtime.MODEL_SHA256
    end,
    file_size = function()
      return configure_runtime.MODEL_SIZE_BYTES
    end,
  })

  luaunit.assertEquals(validation.ok, false)
  luaunit.assertEquals(validation.python.ok, false)
  luaunit.assertStrContains(validation.python.message, "3.11")

  os.execute("rm -rf " .. path_utils.sh_quote(root))
end

function tests.test_validate_draft_rejects_missing_imports_and_bad_checksum()
  local root = mktemp_dir()
  local paths = build_paths(root)

  local validation = configure_runtime.validate_draft(paths, {
    python_path = "/tmp/python3",
    model_path = "/tmp/Cnn14_mAP=0.431.pth",
  }, {
    directory_exists = function(path)
      return path == paths.runtime_source_root
    end,
    exists = function(path)
      return path == "/tmp/python3" or path == "/tmp/Cnn14_mAP=0.431.pth"
    end,
    is_executable = function(path)
      return path == "/tmp/python3"
    end,
    capture_command = function()
      return json.encode({
        version = { 3, 11, 8 },
        versions = {
          numpy = "1.26.4",
          soundfile = "0.12.1",
          torch = "2.6.0",
          torchaudio = "2.5.1",
        },
        errors = {
          torchlibrosa = "No module named 'torchlibrosa'",
        },
      }), 0
    end,
    sha256 = function()
      return "bad"
    end,
    file_size = function()
      return 123
    end,
  })

  luaunit.assertEquals(validation.ok, false)
  luaunit.assertStrContains(validation.python.message, "torchlibrosa")
  luaunit.assertStrContains(validation.model.message, "checksum")

  os.execute("rm -rf " .. path_utils.sh_quote(root))
end

function tests.test_save_requires_validated_configuration_and_writes_new_schema()
  local root = mktemp_dir()
  local paths = build_paths(root)

  local ok, err = configure_runtime.save(paths, {
    python_path = "/tmp/python3",
    model_path = "/tmp/Cnn14_mAP=0.431.pth",
  }, nil)
  luaunit.assertEquals(ok, false)
  luaunit.assertStrContains(err, "Validate Python and model paths")

  local validation = {
    ok = true,
    python = {
      version_string = "3.11.7",
      versions = {
        numpy = "1.26.4",
        soundfile = "0.12.1",
        torch = "2.6.0",
        torchaudio = "2.6.0",
        torchlibrosa = "0.1.0",
      },
    },
    model = {
      sha256 = configure_runtime.MODEL_SHA256,
      size_bytes = configure_runtime.MODEL_SIZE_BYTES,
    },
  }
  local saved_ok = configure_runtime.save(paths, {
    python_path = "/tmp/python3",
    model_path = "/tmp/Cnn14_mAP=0.431.pth",
  }, validation)

  luaunit.assertEquals(saved_ok, true)
  local payload = assert(json.decode(assert(path_utils.read_file(paths.config_path))))
  luaunit.assertEquals(payload.schema_version, configure_runtime.CONFIG_SCHEMA)
  luaunit.assertEquals(payload.python.path, "/tmp/python3")
  luaunit.assertEquals(payload.model.path, "/tmp/Cnn14_mAP=0.431.pth")
  luaunit.assertEquals(payload.validation.model.sha256, configure_runtime.MODEL_SHA256)

  os.execute("rm -rf " .. path_utils.sh_quote(root))
end

function tests.test_main_script_uses_configure_flow_instead_of_runtime_setup()
  local source = assert(path_utils.read_file("reaper/REAPER Audio Tag.lua"))
  luaunit.assertEquals(source:find("runtime_client.run_setup", 1, true) ~= nil, false)
  luaunit.assertEquals(source:find('state%.screen == "configure"', 1, false) ~= nil, true)
  luaunit.assertEquals(source:find('ImGui%.Button%(ctx, "Save and Run"', 1, false) ~= nil, true)
  luaunit.assertEquals(source:find('ImGui%.Button%(ctx, "Setup"', 1, false) ~= nil, false)
  luaunit.assertEquals(source:find('ImGui%.Button%(ctx, "Configure"', 1, false) ~= nil, true)
end

function tests.test_reapack_metadata_hides_setup_from_public_action_surface()
  local main_source = assert(path_utils.read_file("reaper/REAPER Audio Tag.lua"))
  local configure_source = assert(path_utils.read_file("reaper/REAPER Audio Tag - Configure.lua"))
  local setup_source = assert(path_utils.read_file("reaper/REAPER Audio Tag - Setup.lua"))
  local index_source = assert(path_utils.read_file("index.xml"))
  local app_paths_source = assert(path_utils.read_file("reaper/lib/app_paths.lua"))
  local runtime_client_source = assert(path_utils.read_file("reaper/lib/runtime_client.lua"))
  local current_version_start = assert(index_source:find('<version name="0.3.3"', 1, true))
  local current_version_block = index_source:sub(current_version_start)

  luaunit.assertStrContains(main_source, "-- @author dennech")
  luaunit.assertStrContains(main_source, "-- @about")
  luaunit.assertStrContains(main_source, "[main] REAPER Audio Tag - Configure.lua")
  luaunit.assertStrContains(main_source, "[data] ../runtime/src/reaper_panns_runtime/*.py")
  luaunit.assertEquals(main_source:find("%[main%] REAPER Audio Tag %- Setup%.lua", 1, false) ~= nil, false)
  luaunit.assertEquals(main_source:find("REAPER Audio Tag %- Setup%.lua", 1, false) ~= nil, false)

  luaunit.assertStrContains(configure_source, "-- @noindex")
  luaunit.assertStrContains(setup_source, "-- @noindex")
  luaunit.assertStrContains(setup_source, '_G.REAPER_AUDIO_TAG_START_MODE = "configure"')
  luaunit.assertEquals(setup_source:find("setup_runtime", 1, true) ~= nil, false)
  luaunit.assertEquals(app_paths_source:find("setup_script_path", 1, true) ~= nil, false)
  luaunit.assertEquals(app_paths_source:find("bootstrap_command", 1, true) ~= nil, false)
  luaunit.assertEquals(app_paths_source:find("bootstrap_shell", 1, true) ~= nil, false)
  luaunit.assertEquals(runtime_client_source:find("open_bootstrap", 1, true) ~= nil, false)

  luaunit.assertStrContains(index_source, '<version name="0.3.3" author="dennech"')
  luaunit.assertStrContains(index_source, '<description><![CDATA[{\\rtf1')
  luaunit.assertStrContains(current_version_block, 'main="main" file="REAPER Audio Tag - Configure.lua"')
  luaunit.assertStrContains(current_version_block, '<changelog><![CDATA[')
  luaunit.assertStrContains(current_version_block, 'Fixed GitHub Actions metadata validation')
  luaunit.assertStrContains(current_version_block, '../runtime/src/reaper_panns_runtime/__main__.py')
  luaunit.assertStrContains(current_version_block, '../runtime/src/reaper_panns_runtime/_vendor/metadata/class_labels_indices.csv')
  luaunit.assertEquals(current_version_block:find('REAPER Audio Tag %- Setup%.lua', 1, false) ~= nil, false)
  luaunit.assertEquals(current_version_block:find('lib/setup_runtime%.lua', 1, false) ~= nil, false)
  luaunit.assertEquals(current_version_block:find('lib/setup_release_info%.lua', 1, false) ~= nil, false)
end

return tests
