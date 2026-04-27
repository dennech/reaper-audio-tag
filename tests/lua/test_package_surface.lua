local luaunit = require("tests.lua.vendor.luaunit")
local path_utils = require("path_utils")
local app_paths = require("app_paths")

local tests = {}

local function read_file(path)
  return assert(path_utils.read_file(path))
end

local function current_version_block(index_xml)
  local block = index_xml:match('<version name="0%.4%.3".-</version>')
  return block or ""
end

function tests.test_public_reapack_actions_are_main_and_debug_only()
  local source = read_file("reaper/REAPER Audio Tag.lua")
  luaunit.assertStrContains(source, "-- @version 0.4.3")
  luaunit.assertStrContains(source, "[nomain] REAPER Audio Tag - Debug Export.lua")
  luaunit.assertEquals(source:find("REAPER Audio Tag %- Configure%.lua", 1, false) ~= nil, false)
  luaunit.assertEquals(source:find("REAPER Audio Tag %- Setup%.lua", 1, false) ~= nil, false)
  luaunit.assertEquals(path_utils.exists("reaper/REAPER Audio Tag - Configure.lua"), false)
  luaunit.assertEquals(path_utils.exists("reaper/REAPER Audio Tag - Setup.lua"), false)
end

function tests.test_main_script_owns_first_run_model_screen()
  local source = read_file("reaper/REAPER Audio Tag.lua")
  luaunit.assertStrContains(source, 'Download Model')
  luaunit.assertStrContains(source, 'start_model_download')
  luaunit.assertStrContains(source, 'Analyze Selected Item')
  luaunit.assertStrContains(source, 'Download the audio tagging model once. Analysis runs locally after that.')
  luaunit.assertStrContains(source, 'Model is not installed yet.')
  luaunit.assertStrContains(source, 'Last download error detail')
  luaunit.assertEquals(source:find('Saved to:', 1, true) ~= nil, false)
  luaunit.assertEquals(source:find('The ONNX model has not been downloaded yet.', 1, true) ~= nil, false)
  luaunit.assertEquals(source:find('Save Configuration', 1, true) ~= nil, false)
  luaunit.assertEquals(source:find('Check Setup', 1, true) ~= nil, false)
  luaunit.assertEquals(source:find('configure_runtime', 1, true) ~= nil, false)
end

function tests.test_reapack_provides_backend_assets_and_model_is_not_committed()
  local source = read_file("reaper/REAPER Audio Tag.lua")
  luaunit.assertStrContains(source, "[data] data/class_labels_indices.csv > reaper-panns-item-report/metadata/class_labels_indices.csv")
  luaunit.assertStrContains(source, "reaper-audio-tag-backend-macos-arm64")
  luaunit.assertStrContains(source, "reaper-audio-tag-backend-macos-x86_64")
  luaunit.assertStrContains(source, "reaper-audio-tag-backend-windows-x64.exe")
  luaunit.assertEquals(source:find("runtime/src/reaper_panns_runtime", 1, true) ~= nil, false)
  luaunit.assertEquals(path_utils.exists("reaper/data/cnn14_waveform_clipwise_opset17.onnx"), false)
end

function tests.test_app_paths_resolve_reapack_data_backend_and_model_locations()
  local original_reaper = _G.reaper
  _G.reaper = {
    get_action_context = function()
      return nil, "/Users/test/Library/Application Support/REAPER/Scripts/REAPER Audio Tag/REAPER Audio Tag.lua"
    end,
    get_ini_file = function()
      return "/Users/test/Library/Application Support/REAPER/reaper.ini"
    end,
    GetOS = function()
      return "OSX64"
    end,
  }

  local paths = app_paths.build()
  _G.reaper = original_reaper

  luaunit.assertEquals(paths.data_dir, "/Users/test/Library/Application Support/REAPER/Data/reaper-panns-item-report")
  luaunit.assertEquals(paths.labels_path, "/Users/test/Library/Application Support/REAPER/Data/reaper-panns-item-report/metadata/class_labels_indices.csv")
  luaunit.assertEquals(paths.model_path, "/Users/test/Library/Application Support/REAPER/Data/reaper-panns-item-report/models/cnn14_waveform_clipwise_opset17.onnx")
  luaunit.assertEquals(paths.model_cache_dir, path_utils.join(os.getenv("HOME"), "Library", "Caches", "reaper-audio-tag", "coreml-cache"))
  luaunit.assertEquals(paths.model_cache_dir:find("Application Support", 1, true), nil)
  luaunit.assertEquals(paths.backend_candidates[2], "/Users/test/Library/Application Support/REAPER/Data/reaper-panns-item-report/bin/macos-arm64/reaper-audio-tag-backend")
  luaunit.assertEquals(paths.backend_candidates[3], "/Users/test/Library/Application Support/REAPER/Data/reaper-panns-item-report/bin/macos-x86_64/reaper-audio-tag-backend")
end

function tests.test_app_paths_keep_windows_cache_with_app_data()
  local original_reaper = _G.reaper
  _G.reaper = {
    get_action_context = function()
      return nil, "C:/Users/Example/AppData/Roaming/REAPER/Scripts/REAPER Audio Tag/REAPER Audio Tag.lua"
    end,
    get_ini_file = function()
      return "C:/Users/Example/AppData/Roaming/REAPER/reaper.ini"
    end,
    GetOS = function()
      return "Win64"
    end,
  }

  local paths = app_paths.build()
  _G.reaper = original_reaper

  luaunit.assertStrContains(paths.model_cache_dir, "Data")
  luaunit.assertStrContains(paths.model_cache_dir, "reaper-panns-item-report")
  luaunit.assertStrContains(paths.model_cache_dir, "coreml-cache")
  luaunit.assertStrContains(paths.backend_path, "reaper-audio-tag-backend.exe")
end

function tests.test_current_index_has_no_configure_setup_or_python_runtime_when_generated()
  local index = read_file("index.xml")
  local block = current_version_block(index)
  if block == "" then
    return
  end

  luaunit.assertEquals(block:find("REAPER Audio Tag %- Configure%.lua", 1, false) ~= nil, false)
  luaunit.assertEquals(block:find("REAPER Audio Tag %- Setup%.lua", 1, false) ~= nil, false)
  luaunit.assertEquals(block:find("reaper_panns_runtime", 1, true) ~= nil, false)
  luaunit.assertEquals(block:find("runtime/src", 1, true) ~= nil, false)
  luaunit.assertStrContains(block, "class_labels_indices.csv")
  luaunit.assertStrContains(block, "reaper-audio-tag-backend")
  luaunit.assertStrContains(block, "ONNX model download")
  luaunit.assertStrContains(block, "releases/download/v0.4.3/reaper-audio-tag-backend-macos-arm64")
  luaunit.assertStrContains(block, "releases/download/v0.4.3/reaper-audio-tag-backend-macos-x86_64")
  luaunit.assertStrContains(block, "releases/download/v0.4.3/reaper-audio-tag-backend-windows-x64.exe")
  luaunit.assertEquals(block:find("cnn14_waveform_clipwise_opset17.onnx", 1, true), nil)
end

return tests
