local luaunit = require("tests.lua.vendor.luaunit")
local path_utils = require("path_utils")
local report_telemetry = require("report_telemetry")

local tests = {}

local function cleanup(path)
  if path_utils.exists(path) then
    os.remove(path)
  end
  local dir = path_utils.dirname(path)
  if path_utils.directory_exists(dir) then
    os.remove(dir)
  end
end

function tests.test_telemetry_collects_frame_summary_and_log()
  local log_dir = "tests/lua/tmp-telemetry"
  local telemetry = report_telemetry.new(log_dir, "spec-session")

  report_telemetry.begin_frame(telemetry, "result")
  report_telemetry.record_phase(telemetry, "render_content", 12.4)
  report_telemetry.record_phase(telemetry, "render_tag_pills", 9.1)
  report_telemetry.record_phase(telemetry, "runtime_poll", 0.4)
  report_telemetry.set_counter(telemetry, "tags_total", 527)
  report_telemetry.set_counter(telemetry, "visible_tags", 527)
  report_telemetry.set_counter(telemetry, "icon_lookups", 540)
  report_telemetry.set_counter(telemetry, "icon_draws", 540)
  report_telemetry.set_label(telemetry, "focused_tag", "Speech")
  report_telemetry.note(telemetry, "diagnostic-started")
  report_telemetry.finish_frame(telemetry)

  local lines = report_telemetry.summary_lines(telemetry)
  luaunit.assertEquals(#lines >= 4, true)
  luaunit.assertStrContains(lines[1], "Perf:")
  luaunit.assertStrContains(lines[2], "Stage: result")
  luaunit.assertStrContains(lines[3], "Tags: total 527")
  luaunit.assertStrContains(lines[4], "Debug log:")

  local events = report_telemetry.event_lines(telemetry, 5)
  luaunit.assertEquals(#events >= 1, true)
  luaunit.assertStrContains(events[1], "diagnostic-started")

  local log_path = report_telemetry.log_path(telemetry)
  luaunit.assertEquals(path_utils.exists(log_path), true)
  local data = assert(path_utils.read_file(log_path))
  luaunit.assertStrContains(data, "report_ui_telemetry_v1")
  luaunit.assertStrContains(data, "diagnostic-started")

  cleanup(log_path)
end

return tests
