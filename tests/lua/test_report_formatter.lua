local luaunit = require("tests.lua.vendor.luaunit")
local formatter = require("report_presenter")
local snapshot = require("tests.lua.support.snapshot")

local tests = {}

local sample_report = {
  schema_version = "reaper-panns-item-report/v1",
  status = "ok",
  backend = "mps",
  attempted_backends = { "mps", "cpu" },
  summary = "Top detected tags: Speech, Speech synthesizer, and Sigh.",
  timing_ms = {
    preprocess = 118,
    inference = 724,
    total = 842,
  },
  predictions = {
    { rank = 1, label = "Speech", score = 0.78, bucket = "strong", peak_score = 0.81, support_count = 3, segment_count = 3 },
    { rank = 2, label = "Speech synthesizer", score = 0.67, bucket = "solid", peak_score = 0.72, support_count = 3, segment_count = 3 },
    { rank = 3, label = "Sigh", score = 0.66, bucket = "solid", peak_score = 0.68, support_count = 3, segment_count = 3 },
    { rank = 4, label = "Narration, monologue", score = 0.11, bucket = "possible", peak_score = 0.13, support_count = 1, segment_count = 3 },
    { rank = 5, label = "Gasp", score = 0.11, bucket = "possible", peak_score = 0.12, support_count = 1, segment_count = 3 },
    { rank = 6, label = "Clicking", score = 0.09, bucket = "weak", peak_score = 0.10, support_count = 1, segment_count = 3 },
    { rank = 7, label = "Music", score = 0.08, bucket = "weak", peak_score = 0.09, support_count = 1, segment_count = 3 },
    { rank = 8, label = "Unknown texture", score = 0.04, bucket = "weak", peak_score = 0.06, support_count = 1, segment_count = 3 },
  },
  highlights = {
    { label = "Speech", score = 0.78, bucket = "strong", headline = "Likely tag", peak_score = 0.81, support_count = 3, segment_count = 3 },
    { label = "Speech synthesizer", score = 0.67, bucket = "solid", headline = "Consistent tag", peak_score = 0.72, support_count = 3, segment_count = 3 },
    { label = "Sigh", score = 0.66, bucket = "solid", headline = "Consistent tag", peak_score = 0.68, support_count = 3, segment_count = 3 },
    { label = "Narration, monologue", score = 0.11, bucket = "possible", headline = "Possible cue", peak_score = 0.13, support_count = 1, segment_count = 3 },
    { label = "Gasp", score = 0.11, bucket = "possible", headline = "Possible cue", peak_score = 0.12, support_count = 1, segment_count = 3 },
    { label = "Clicking", score = 0.09, bucket = "weak", headline = "Possible cue", peak_score = 0.10, support_count = 1, segment_count = 3 },
  },
  warnings = {},
  error = nil,
  model_status = {
    name = "Cnn14",
    source = "managed runtime",
  },
}

local error_report = {
  schema_version = "reaper-panns-item-report/v1",
  status = "error",
  stage = "runtime",
  backend = "cpu",
  attempted_backends = { "mps", "cpu" },
  timing_ms = {
    preprocess = 0,
    inference = 0,
    total = 0,
  },
  predictions = {},
  highlights = {},
  warnings = { "mps_requested_but_unavailable" },
  summary = "No analysis summary is available.",
  model_status = {
    name = "Cnn14",
    source = "managed runtime",
  },
  error = {
    code = "missing_model",
    message = "Model checkpoint was not found",
  },
}

local export_error_report = {
  schema_version = "reaper-panns-item-report/v1",
  status = "error",
  stage = "export",
  backend = nil,
  attempted_backends = {},
  timing_ms = {
    preprocess = 0,
    inference = 0,
    total = 0,
  },
  predictions = {},
  highlights = {},
  warnings = {},
  summary = "No analysis summary is available.",
  model_status = {
    name = "Cnn14",
    source = "managed runtime",
  },
  item = {
    item_position = 128.14783,
    item_length = 3.789056,
    accessor_time_domain = "item_local",
    read_strategy = "hinted",
    read_mode = "clamped",
  },
  error = {
    code = "export_failed",
    message = "Could not read audio data from the selected take range.",
  },
}

function tests.test_compact_snapshot()
  snapshot.assert_snapshot(formatter.compact_report(sample_report), "compact.txt")
end

function tests.test_detail_snapshot()
  snapshot.assert_snapshot(formatter.detail_report(sample_report), "details.txt")
end

function tests.test_loading_snapshot()
  snapshot.assert_snapshot(formatter.loading_report(1275), "loading.txt")
end

function tests.test_exporting_snapshot()
  snapshot.assert_snapshot(formatter.exporting_report(1275, "23-1.wav"), "exporting.txt")
end

function tests.test_error_snapshot()
  snapshot.assert_snapshot(formatter.error_report(error_report), "error.txt")
end

function tests.test_export_error_snapshot()
  snapshot.assert_snapshot(formatter.error_report(export_error_report), "error_export.txt")
end

function tests.test_compact_report_contains_summary()
  local report = formatter.compact_report(sample_report)
  luaunit.assertStrContains(report, "Top detected tags: Speech, Speech synthesizer, and Sigh.")
  luaunit.assertStrContains(report, "Top cues")
  luaunit.assertStrContains(report, "Tags")
  luaunit.assertStrContains(report, "More")
end

function tests.test_compact_report_lists_all_tags()
  local report = formatter.compact_report(sample_report)
  luaunit.assertStrContains(report, "6. Clicking 9%")
  luaunit.assertStrContains(report, "7. Music 8%")
  luaunit.assertStrContains(report, "8. Unknown texture 4%")
end

function tests.test_label_icon_keys_use_semantic_mapping()
  luaunit.assertEquals(formatter.label_icon_key("Speech", "strong"), "speech")
  luaunit.assertEquals(formatter.label_icon_key("Speech synthesizer", "solid"), "synth")
  luaunit.assertEquals(formatter.label_icon_key("Sigh", "solid"), "breath")
  luaunit.assertEquals(formatter.label_icon_key("Narration, monologue", "possible"), "speech")
  luaunit.assertEquals(formatter.label_icon_key("Gasp", "possible"), "breath")
  luaunit.assertEquals(formatter.label_icon_key("Clicking", "weak"), "click")
  luaunit.assertEquals(formatter.label_icon_key("Music", "weak"), "music")
  luaunit.assertEquals(formatter.label_icon_key("Train", "solid"), "train")
  luaunit.assertEquals(formatter.label_icon_key("Dog", "solid"), "dog")
end

function tests.test_unknown_label_falls_back_to_generic_icon()
  luaunit.assertEquals(formatter.label_icon_key("Unknown texture", "weak"), "generic")
end

function tests.test_section_icon_keys_are_stable()
  luaunit.assertEquals(formatter.section_icon_key("cues"), "cues")
  luaunit.assertEquals(formatter.section_icon_key("tags"), "tags")
  luaunit.assertEquals(formatter.section_icon_key("weird"), "generic")
end

function tests.test_bucket_labels_are_plain_text()
  luaunit.assertEquals(formatter.bucket_label("strong"), "Strong")
  luaunit.assertEquals(formatter.bucket_label("solid"), "Solid")
  luaunit.assertEquals(formatter.bucket_label("possible"), "Possible")
  luaunit.assertEquals(formatter.bucket_label("weak"), "Low")
end

function tests.test_chip_palette_keys_follow_bucket_strength()
  luaunit.assertEquals(formatter.chip_palette_key("strong"), "strong")
  luaunit.assertEquals(formatter.chip_palette_key("solid"), "solid")
  luaunit.assertEquals(formatter.chip_palette_key("possible"), "possible")
  luaunit.assertEquals(formatter.chip_palette_key("weak"), "weak")
  luaunit.assertEquals(formatter.chip_palette_key("whatever"), "weak")
end

function tests.test_main_script_passes_ctx_to_imgui_calls()
  local handle = assert(io.open("reaper/PANNs Item Report.lua", "rb"))
  local source = handle:read("*a")
  handle:close()
  local compact_source = source:gsub("%s+", " ")

  local imgui_functions = {
    "Text",
    "TextWrapped",
    "TextDisabled",
    "TextColored",
    "BulletText",
    "ProgressBar",
    "SameLine",
    "Spacing",
    "Separator",
    "Image",
    "InvisibleButton",
  }

  for _, fn_name in ipairs(imgui_functions) do
    for call in compact_source:gmatch("ImGui%." .. fn_name .. "%b()") do
      luaunit.assertEquals(
        call:find("ImGui%." .. fn_name .. "%(%s*ctx[,%)]") ~= nil,
        true,
        "Expected ctx argument in call: " .. call
      )
    end
  end
end

function tests.test_main_script_uses_monotonic_progress()
  local handle = assert(io.open("reaper/PANNs Item Report.lua", "rb"))
  local source = handle:read("*a")
  handle:close()

  luaunit.assertEquals(source:find("math%.sin%(") ~= nil, false)
  luaunit.assertEquals(source:find("math%.cos%(") ~= nil, false)
  luaunit.assertStrContains(source, "math.min(0.99, state.last_loading_ms / (timeout_sec * 1000))")
end

function tests.test_main_script_uses_unique_ids_for_clickable_tags()
  local handle = assert(io.open("reaper/PANNs Item Report.lua", "rb"))
  local source = handle:read("*a")
  handle:close()

  luaunit.assertStrContains(source, 'ImGui.PushID(ctx, string.format("%s-%d-%s"')
  luaunit.assertStrContains(source, 'ImGui.InvisibleButton(ctx, "##chip"')
  luaunit.assertStrContains(source, "report_ui_state.focus_tag(state")
end

function tests.test_main_script_exposes_open_log_for_export_failures()
  local handle = assert(io.open("reaper/PANNs Item Report.lua", "rb"))
  local source = handle:read("*a")
  handle:close()

  luaunit.assertStrContains(source, "state.export_log_file")
  luaunit.assertStrContains(source, 'ImGui.Button(ctx, "Open log")')
  luaunit.assertStrContains(source, "audio_export.begin_export_selected_item(export_path, {")
  luaunit.assertStrContains(source, "diagnostics_path = export_log_path")
end

function tests.test_debug_export_script_loads()
  luaunit.assertEquals(loadfile("reaper/PANNs Item Report - Debug Export.lua") ~= nil, true)
end

function tests.test_export_error_report_hides_runtime_backend_attempts()
  local report = formatter.error_report(export_error_report)
  luaunit.assertEquals(report:find("Tried:", 1, true), nil)
  luaunit.assertStrContains(report, "Accessor: item_local")
  luaunit.assertStrContains(report, "Read: hinted / clamped")
end

function tests.test_main_script_uses_another_button_and_selection_notice()
  local handle = assert(io.open("reaper/PANNs Item Report.lua", "rb"))
  local source = handle:read("*a")
  handle:close()

  luaunit.assertStrContains(source, 'ImGui.Button(ctx, "Another")')
  luaunit.assertStrContains(source, "preserve_result_if_selection_invalid = true")
  luaunit.assertStrContains(source, "state.notice = err")
end

function tests.test_main_script_cleans_up_run_artifacts()
  local handle = assert(io.open("reaper/PANNs Item Report.lua", "rb"))
  local source = handle:read("*a")
  handle:close()

  luaunit.assertStrContains(source, "report_run_cleanup.prune_stale(paths)")
  luaunit.assertStrContains(source, "report_run_cleanup.clear_temp_audio(paths, state.run_artifacts)")
  luaunit.assertStrContains(source, "cleanup_current_run()")
end

function tests.test_main_script_uses_image_pipeline_and_drops_icon_selector()
  local handle = assert(io.open("reaper/PANNs Item Report.lua", "rb"))
  local source = handle:read("*a")
  handle:close()
  local icons_handle = assert(io.open("reaper/lib/report_icons.lua", "rb"))
  local icons_source = icons_handle:read("*a")
  icons_handle:close()
  local assets_handle = assert(io.open("reaper/lib/report_icon_assets.lua", "rb"))
  local assets_source = assets_handle:read("*a")
  assets_handle:close()
  local map_handle = assert(io.open("reaper/lib/report_icon_map.lua", "rb"))
  local map_source = map_handle:read("*a")
  map_handle:close()
  local generator_handle = assert(io.open("scripts/generate_report_emoji_assets.py", "rb"))
  local generator_source = generator_handle:read("*a")
  generator_handle:close()

  luaunit.assertStrContains(source, 'require("report_icons")')
  luaunit.assertStrContains(source, "report_icons.ensure_loaded")
  luaunit.assertStrContains(source, 'report_icons.image(ImGui, state.ui.icons, icon_key)')
  luaunit.assertStrContains(source, 'pcall(ImGui.Image, ctx, image, size, size)')
  luaunit.assertStrContains(icons_source, 'require("report_icon_assets")')
  luaunit.assertStrContains(icons_source, 'ImGui.ValidatePtr')
  luaunit.assertStrContains(assets_source, "https://github.com/googlefonts/noto-emoji")
  luaunit.assertStrContains(assets_source, "8998f5dd683424a73e2314a8c1f1e359c19e8742")
  luaunit.assertStrContains(map_source, '["Speech"] = "speech"')
  luaunit.assertStrContains(generator_source, "googlefonts/noto-emoji")
  luaunit.assertStrContains(source, "ImGui.DrawList_AddImage")
  luaunit.assertStrContains(source, "ImGui.InvisibleButton")
  luaunit.assertEquals(source:find('ImGui.TextDisabled(ctx, "Icons:")', 1, true), nil)
  luaunit.assertEquals(source:find("icon_mode", 1, true), nil)
  luaunit.assertEquals(source:find("Apple Color Emoji.ttc", 1, true), nil)
  luaunit.assertEquals(source:find("CreateFontFromFile", 1, true), nil)
  luaunit.assertEquals(source:find("symbols", 1, true), nil)
end

function tests.test_main_script_does_not_end_hidden_window_twice()
  local handle = assert(io.open("reaper/PANNs Item Report.lua", "rb"))
  local source = handle:read("*a")
  handle:close()

  local end_count = 0
  for _ in source:gmatch("ImGui%.End%(ctx%)") do
    end_count = end_count + 1
  end

  luaunit.assertEquals(end_count, 1)
  luaunit.assertEquals(source:find("else%s+ImGui%.End%(ctx%)") ~= nil, false)
end

function tests.test_main_script_tracks_window_open_state_explicitly()
  local handle = assert(io.open("reaper/PANNs Item Report.lua", "rb"))
  local source = handle:read("*a")
  handle:close()

  luaunit.assertStrContains(source, "window_open = true")
  luaunit.assertStrContains(source, 'ImGui.Begin(ctx, "PANNs Item Report", state.window_open, ImGui.WindowFlags_NoCollapse())')
  luaunit.assertStrContains(source, "state.window_open = open")
  luaunit.assertStrContains(source, "if state.window_open then")
  luaunit.assertEquals(source:find('ImGui.Begin%(ctx, "PANNs Item Report", true,', 1, true), nil)
end

function tests.test_main_script_stops_live_job_after_result_and_keeps_log_artifacts()
  local handle = assert(io.open("reaper/PANNs Item Report.lua", "rb"))
  local source = handle:read("*a")
  handle:close()

  luaunit.assertStrContains(source, "set_result(polled.payload)")
  luaunit.assertStrContains(source, "state.job = nil")
  luaunit.assertStrContains(source, "state.run_artifacts.runtime_log_file")
  luaunit.assertStrContains(source, "local function set_result(result)")
  luaunit.assertStrContains(source, "local function current_view_model()")
  luaunit.assertStrContains(source, 'ImGui.Button(ctx, "Open log")')
end

function tests.test_main_script_uses_async_export_session_before_runtime_job()
  local handle = assert(io.open("reaper/PANNs Item Report.lua", "rb"))
  local source = handle:read("*a")
  handle:close()

  luaunit.assertStrContains(source, "export_session = nil")
  luaunit.assertStrContains(source, 'state.screen = "exporting"')
  luaunit.assertStrContains(source, "audio_export.begin_export_selected_item")
  luaunit.assertStrContains(source, "audio_export.step_export")
  luaunit.assertStrContains(source, "audio_export.cancel_export")
  luaunit.assertStrContains(source, "render_exporting()")
  luaunit.assertEquals(source:find("audio_export.export_selected_item%(", 1, false), nil)
end

function tests.test_main_script_renders_full_tag_flow_with_bucket_palette()
  local handle = assert(io.open("reaper/PANNs Item Report.lua", "rb"))
  local source = handle:read("*a")
  handle:close()

  luaunit.assertStrContains(source, 'local function render_tag_pills(vm)')
  luaunit.assertStrContains(source, "local spacing = 8")
  luaunit.assertStrContains(source, "ordered_predictions(vm)")
  luaunit.assertStrContains(source, 'render_tag_chip("tag", index, prediction')
  luaunit.assertStrContains(source, 'report_presenter.chip_palette_key(prediction.bucket)')
  luaunit.assertStrContains(source, "strong = { THEME.mint")
  luaunit.assertStrContains(source, "solid = { THEME.lavender")
  luaunit.assertStrContains(source, "possible = { THEME.lemon")
  luaunit.assertStrContains(source, "weak = { 0xF8C0D0FF")
end

function tests.test_main_script_exposes_debug_telemetry_panel_and_log()
  local handle = assert(io.open("reaper/PANNs Item Report.lua", "rb"))
  local source = handle:read("*a")
  handle:close()
  local telemetry_handle = assert(io.open("reaper/lib/report_telemetry.lua", "rb"))
  local telemetry_source = telemetry_handle:read("*a")
  telemetry_handle:close()

  luaunit.assertStrContains(source, 'require("report_telemetry")')
  luaunit.assertStrContains(source, "report_telemetry.new(paths.logs_dir")
  luaunit.assertStrContains(source, 'render_image_label("details", "Diagnostics"')
  luaunit.assertStrContains(source, 'ImGui.Button(ctx, "Debug log")')
  luaunit.assertStrContains(source, "report_telemetry.summary_lines(state.ui.telemetry)")
  luaunit.assertStrContains(source, "report_telemetry.event_lines(state.ui.telemetry, 6)")
  luaunit.assertStrContains(source, "report_icons.begin_frame(state.ui.icons)")
  luaunit.assertStrContains(source, "report_telemetry.finish_frame(state.ui.telemetry)")
  luaunit.assertStrContains(telemetry_source, "report_ui_telemetry_v1")
  luaunit.assertStrContains(telemetry_source, "frame=%d stage=%s")
end

return tests
