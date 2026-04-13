local _, script_path = reaper.get_action_context()
local script_dir = script_path:match("^(.*[\\/])") or "."
package.path = table.concat({
  script_dir .. "lib/?.lua",
  package.path,
}, ";")

local app_paths = require("app_paths")
local audio_export = require("audio_export")
local path_utils = require("path_utils")
local report_icons = require("report_icons")
local report_presenter = require("report_presenter")
local report_run_cleanup = require("report_run_cleanup")
local report_ui_state = require("report_ui_state")
local runtime_client = require("runtime_client")

if not reaper.APIExists("ImGui_CreateContext") then
  local message = "ReaImGui is required for this script.\n\nInstall 'ReaImGui: ReaScript binding for Dear ImGui' from ReaPack and restart REAPER."
  if reaper.APIExists("ReaPack_BrowsePackages") then
    reaper.ShowMessageBox(message, "REAPER Audio Tag", 0)
    reaper.ReaPack_BrowsePackages("ReaImGui: ReaScript binding for Dear ImGui")
  else
    reaper.ShowMessageBox(message, "REAPER Audio Tag", 0)
  end
  return
end

local ImGui = {}
setmetatable(ImGui, {
  __index = function(_, key)
    return reaper["ImGui_" .. key]
  end,
})

local paths = app_paths.build()
path_utils.ensure_dir(paths.data_dir)
path_utils.ensure_dir(paths.logs_dir)
path_utils.ensure_dir(paths.tmp_dir)
path_utils.ensure_dir(paths.jobs_dir)
report_run_cleanup.prune_stale(paths)

local ctx = ImGui.CreateContext("REAPER Audio Tag")
local state = {
  window_open = true,
  current_view = "compact",
  screen = "boot",
  result = nil,
  export_session = nil,
  job = nil,
  last_error = nil,
  last_loading_ms = 0,
  last_export_ms = 0,
  focused_tag = nil,
  export_log_file = nil,
  notice = nil,
  run_artifacts = nil,
  ui = {
    base_font = nil,
    fonts_ready = false,
    last_poll_at_ms = 0,
    poll_interval_ms = 100,
    view_model = nil,
    view_model_result = nil,
    icons = {
      loaded = false,
      image = nil,
      available = false,
    },
  },
}

local THEME = {
  window_bg = 0xFFF8F3FF,
  title_bg = 0xFFF0E8FF,
  title_bg_active = 0xFFE7DBFF,
  border = 0xEFD5DFFF,
  text = 0x423553FF,
  text_soft = 0x8B789BFF,
  button = 0xFFC8D7FF,
  button_hover = 0xFFBCD1FF,
  button_active = 0xF6AAC0FF,
  frame = 0xFFF1F8FF,
  frame_hover = 0xE9F3FFFF,
  frame_active = 0xE0EEFFFF,
  separator = 0xEDD0DAFF,
  progress = 0x7FDBBAFF,
  progress_hover = 0x5FD4ADFF,
  success = 0x67C587FF,
  warning = 0xF0A24DFF,
  error = 0xE66F91FF,
  accent = 0xA394F9FF,
  pink = 0xF694B4FF,
  mint = 0xB9EEDCFF,
  lemon = 0xFFEBA9FF,
  peach = 0xFFDFAFFF,
  lavender = 0xDDD2FFFF,
}

local function badge_color(kind)
  if kind == "success" then
    return THEME.success
  end
  if kind == "warning" then
    return THEME.warning
  end
  if kind == "error" then
    return THEME.error
  end
  return THEME.accent
end

local function push_theme()
  local color_count = 0
  local function push(slot, value)
    ImGui.PushStyleColor(ctx, slot, value)
    color_count = color_count + 1
  end

  push(ImGui.Col_WindowBg(), THEME.window_bg)
  push(ImGui.Col_TitleBg(), THEME.title_bg)
  push(ImGui.Col_TitleBgActive(), THEME.title_bg_active)
  push(ImGui.Col_TitleBgCollapsed(), THEME.title_bg)
  push(ImGui.Col_Border(), THEME.border)
  push(ImGui.Col_Text(), THEME.text)
  push(ImGui.Col_TextDisabled(), THEME.text_soft)
  push(ImGui.Col_Button(), THEME.button)
  push(ImGui.Col_ButtonHovered(), THEME.button_hover)
  push(ImGui.Col_ButtonActive(), THEME.button_active)
  push(ImGui.Col_FrameBg(), THEME.frame)
  push(ImGui.Col_FrameBgHovered(), THEME.frame_hover)
  push(ImGui.Col_FrameBgActive(), THEME.frame_active)
  push(ImGui.Col_Separator(), THEME.separator)
  push(ImGui.Col_PlotHistogram(), THEME.progress)
  push(ImGui.Col_PlotHistogramHovered(), THEME.progress_hover)

  ImGui.PushStyleVar(ctx, ImGui.StyleVar_WindowRounding(), 18)
  ImGui.PushStyleVar(ctx, ImGui.StyleVar_FrameRounding(), 14)
  ImGui.PushStyleVar(ctx, ImGui.StyleVar_GrabRounding(), 14)

  return color_count, 3
end

local function pop_theme(color_count, var_count)
  ImGui.PopStyleVar(ctx, var_count)
  ImGui.PopStyleColor(ctx, color_count)
end

local function render_static_chip(label, kind)
  ImGui.TextColored(ctx, badge_color(kind), "[" .. label .. "]")
end

local function push_font(font, size)
  if font and ImGui.PushFont then
    ImGui.PushFont(ctx, font, size)
    return true
  end
  return false
end

local function ensure_icons()
  report_icons.ensure_loaded(ImGui, state.ui.icons)
end

local function atlas_icon(icon_key)
  ensure_icons()
  local uv = report_icons.icon_uv(icon_key)
  if not uv then
    return nil, nil
  end
  local image = report_icons.image(ImGui, state.ui.icons, uv.key)
  if not image then
    return nil, nil
  end
  return image, uv
end

local function render_inline_image(icon_key, size)
  local image, uv = atlas_icon(icon_key)
  if not (image and ImGui.Image) then
    report_icons.note_text_fallback(state.ui.icons)
    return false
  end
  report_icons.note_draw(state.ui.icons)
  local ok = pcall(ImGui.Image, ctx, image, size, size, uv.uv0_x, uv.uv0_y, uv.uv1_x, uv.uv1_y)
  if not ok then
    report_icons.invalidate(state.ui.icons, icon_key)
    report_icons.note_text_fallback(state.ui.icons)
    return false
  end
  return true
end

local function draw_image_icon(draw_list, icon_key, x, y, size)
  if not ImGui.DrawList_AddImage then
    return false
  end
  local image, uv = atlas_icon(icon_key)
  if not (image and uv) then
    return false
  end
  report_icons.note_draw(state.ui.icons)
  local ok = pcall(
    ImGui.DrawList_AddImage,
    draw_list,
    image,
    x,
    y,
    x + size,
    y + size,
    uv.uv0_x,
    uv.uv0_y,
    uv.uv1_x,
    uv.uv1_y
  )
  if not ok then
    report_icons.invalidate(state.ui.icons, icon_key)
    return false
  end
  return true
end

local function render_image_label(icon_key, text, color, size)
  ImGui.TextColored(ctx, color, text)
  ImGui.SameLine(ctx, 0, 6)
  if not render_inline_image(icon_key, size or 16) then
    ImGui.NewLine(ctx)
  end
end

local function render_metric_chip(icon_key, label, kind)
  if render_inline_image(icon_key, 16) then
    ImGui.SameLine(ctx, 0, 4)
  end
  render_static_chip(label, kind)
end

local function ensure_fonts()
  if state.ui.fonts_ready then
    return
  end

  state.ui.fonts_ready = true
  ensure_icons()
  if not (ImGui.CreateFont and ImGui.Attach) then
    return
  end

  local ok_base, base_font = pcall(ImGui.CreateFont, "sans-serif")
  if ok_base and base_font then
    pcall(ImGui.Attach, ctx, base_font)
    state.ui.base_font = base_font
  end
end

local function measure_phase(name, fn)
  return fn()
end

local function telemetry_label(key, value)
  return nil
end

local function telemetry_counter(key, value)
  return nil
end

local function telemetry_event(message)
  return nil
end

local function clear_temp_audio()
  if state.run_artifacts then
    report_run_cleanup.clear_temp_audio(paths, state.run_artifacts)
  end
end

local function cancel_export_session()
  if state.export_session then
    telemetry_event("cancel_export_session")
    audio_export.cancel_export(state.export_session)
    state.export_session = nil
  end
  state.last_export_ms = 0
end

local function cleanup_current_run()
  cancel_export_session()
  if state.run_artifacts then
    report_run_cleanup.cleanup_run(paths, state.run_artifacts)
    state.run_artifacts = nil
  end
  state.job = nil
  state.ui.last_poll_at_ms = 0
end

local function invalidate_view_model()
  state.ui.view_model = nil
  state.ui.view_model_result = nil
end

local function set_result(result)
  state.result = result
  invalidate_view_model()
end

local function current_view_model()
  if not state.result then
    invalidate_view_model()
    return nil
  end
  if state.ui.view_model_result ~= state.result then
    state.ui.view_model = measure_phase("view_model", function()
      return report_presenter.view_model(state.result)
    end)
    state.ui.view_model_result = state.result
  end
  return state.ui.view_model
end

local function status_chip()
  if state.screen == "exporting" then
    return "Preparing", "accent", "loading"
  end
  if state.screen == "loading" then
    return "Listening", "warning", "loading"
  end
  if state.screen == "result" then
    return "Ready", "success", "success"
  end
  if state.screen == "error" then
    return "Oops", "error", "error"
  end
  if state.screen == "setup" then
    return "Setup", "accent", "details"
  end
  return "Warm up", "accent", "details"
end

local function internal_ui_error_result(message)
  return {
    status = "error",
    stage = "ui",
    backend = nil,
    attempted_backends = {},
    timing_ms = { preprocess = 0, inference = 0, total = 0 },
    summary = "No analysis summary is available.",
    predictions = {},
    highlights = {},
    warnings = { "The report window hit an internal UI rendering error." },
    model_status = { name = "Cnn14", source = "managed-runtime" },
    item = {},
    error = { code = "ui_render_failed", message = message },
  }
end

local function start_analysis(options)
  options = options or {}
  local preserve_result_if_selection_invalid = options.preserve_result_if_selection_invalid == true
  local previous_result = state.result
  local previous_screen = state.screen
  local previous_export_log_file = state.export_log_file
  local previous_run_artifacts = state.run_artifacts
  local previous_view = state.current_view
  local previous_focused_tag = state.focused_tag

  state.notice = nil
  local export_id = path_utils.sanitize_job_id(reaper.genGuid(""))
  local export_path = path_utils.join(paths.tmp_dir, "selected-item-" .. export_id .. ".wav")
  local export_log_path = path_utils.join(paths.logs_dir, "export-" .. export_id .. ".log")
  local export_session, err, export_metadata = audio_export.begin_export_selected_item(export_path, {
    diagnostics_path = export_log_path,
  })
  if not export_session then
    if preserve_result_if_selection_invalid and export_metadata and export_metadata.error_kind == "selection" and previous_result then
      state.screen = previous_screen
      state.result = previous_result
      state.export_log_file = previous_export_log_file
      state.run_artifacts = previous_run_artifacts
      state.current_view = previous_view
      state.focused_tag = previous_focused_tag
      state.notice = err
      telemetry_event("selection_notice_preserved")
      return
    end

    cleanup_current_run()
    state.run_artifacts = report_run_cleanup.new_artifacts(nil, export_log_path, nil)
    state.export_log_file = export_log_path
    state.job = nil
    state.screen = "error"
    state.current_view = "compact"
    state.focused_tag = nil
    set_result({
      status = "error",
      stage = "export",
      backend = nil,
      attempted_backends = {},
      timing_ms = { preprocess = 0, inference = 0, total = 0 },
      summary = "No analysis summary is available.",
      predictions = {},
      highlights = {},
      warnings = {},
      model_status = { name = "Cnn14", source = "managed-runtime" },
      item = export_metadata or {},
      error = { code = "export_failed", message = err },
    })
    telemetry_event("export_begin_failed")
    return
  end

  cleanup_current_run()
  state.run_artifacts = report_run_cleanup.new_artifacts(export_path, export_log_path, nil)
  state.export_log_file = export_log_path
  state.export_session = export_session
  state.job = nil
  set_result(nil)
  state.last_error = nil
  state.last_loading_ms = 0
  state.last_export_ms = 0
  state.current_view = "compact"
  state.focused_tag = nil
  state.ui.last_poll_at_ms = 0
  state.screen = "exporting"
  telemetry_event("export_session_started")
end

local function ensure_started()
  if not runtime_client.runtime_ready(paths) then
    state.screen = "setup"
    state.last_error = "Runtime is not bootstrapped yet."
    return
  end
  if state.screen == "boot" then
    start_analysis()
  end
end

local function render_header()
  local chip_label, chip_kind, chip_icon = status_chip()
  if render_inline_image("brand", 20) then
    ImGui.SameLine(ctx, 0, 8)
  end
  ImGui.TextColored(ctx, badge_color("accent"), "REAPER Audio Tag")
  ImGui.SameLine(ctx, 0, 16)
  render_metric_chip(chip_icon, chip_label, chip_kind)
  ImGui.Separator(ctx)
end

local function render_setup()
  telemetry_counter("tags_total", 0)
  telemetry_counter("visible_tags", 0)
  telemetry_label("focused_tag", state.focused_tag or "none")
  render_image_label("details", "One quick setup.", badge_color("accent"), 16)
  if state.last_error then
    ImGui.Spacing(ctx)
    ImGui.TextColored(ctx, badge_color("warning"), tostring(state.last_error))
  end
  ImGui.Spacing(ctx)
  if ImGui.Button(ctx, "Bootstrap") then
    local ok, err = runtime_client.open_bootstrap(paths)
    if not ok then
      state.last_error = err
    else
      state.last_error = "Terminal is open. Come back and hit Retry."
    end
  end
  ImGui.SameLine(ctx)
  if ImGui.Button(ctx, "Retry") then
    if runtime_client.runtime_ready(paths) then
      state.screen = "boot"
      start_analysis()
    end
  end
end

local function finalize_export_success(export_payload)
  local export_path = state.run_artifacts and state.run_artifacts.export_path or export_payload.temp_audio_path
  local export_log_path = state.export_log_file
  local job, job_err = runtime_client.start_job(paths, export_payload, {
    requested_backend = "auto",
  })
  state.export_session = nil
  if not job then
    clear_temp_audio()
    state.job = nil
    state.screen = "setup"
    state.last_error = job_err
    telemetry_event("runtime_start_failed")
    return
  end

  state.run_artifacts = report_run_cleanup.new_artifacts(export_path, export_log_path, job)
  state.job = job
  state.last_loading_ms = 0
  state.ui.last_poll_at_ms = 0
  state.screen = "loading"
  telemetry_event("runtime_job_started")
end

local function render_exporting()
  if not state.export_session then
    state.screen = "boot"
    return
  end

  local stepped = measure_phase("export_step", function()
    return audio_export.step_export(state.export_session, {
      max_chunks = 32,
      max_time_ms = 8,
    })
  end)
  state.last_export_ms = stepped.elapsed_ms or 0
  telemetry_label("focused_tag", state.focused_tag or "none")
  telemetry_counter("export_chunks", stepped.chunks_processed or 0)
  telemetry_counter("export_frames_written", stepped.frames_written or 0)
  telemetry_counter("export_total_frames", stepped.total_frames or 0)

  if stepped.status == "error" then
    state.export_session = nil
    state.screen = "error"
    state.current_view = "compact"
    state.focused_tag = nil
    set_result({
      status = "error",
      stage = "export",
      backend = nil,
      attempted_backends = {},
      timing_ms = { preprocess = 0, inference = 0, total = 0 },
      summary = "No analysis summary is available.",
      predictions = {},
      highlights = {},
      warnings = {},
      model_status = { name = "Cnn14", source = "managed-runtime" },
      item = stepped.diagnostics or {},
      error = { code = "export_failed", message = stepped.error or "Preparing the selected audio failed." },
    })
  elseif stepped.status == "done" then
    finalize_export_success(stepped.payload)
  end

  local item_name = state.export_session and state.export_session.item_name
  local exporting_text = report_presenter.exporting_report(state.last_export_ms, item_name)
  ImGui.TextWrapped(ctx, exporting_text)
  ImGui.Spacing(ctx)

  local progress = stepped.progress or 0
  local item_length = state.export_session and tonumber(state.export_session.item_length) or 0
  local prepared_seconds = item_length * progress
  telemetry_counter("tags_total", 0)
  telemetry_counter("visible_tags", 0)
  local overlay = string.format("Preparing audio... %.0f%%", progress * 100)
  if item_length > 0 then
    overlay = string.format("Preparing audio... %.1f / %.1f s", prepared_seconds, item_length)
  end
  ImGui.ProgressBar(ctx, progress, -1, 0, overlay)
  if state.export_session and state.last_export_ms > 500 then
    ImGui.Spacing(ctx)
    ImGui.TextDisabled(ctx, "Chunking the selected item without blocking REAPER...")
  end
end

local function render_loading()
  local now_ms = math.floor(reaper.time_precise() * 1000)
  if state.job then
    if state.ui.last_poll_at_ms == 0 or (now_ms - state.ui.last_poll_at_ms) >= state.ui.poll_interval_ms then
      local polled = measure_phase("runtime_poll", function()
        return runtime_client.poll_job(state.job)
      end)
      state.ui.last_poll_at_ms = now_ms
      if polled.done then
        set_result(polled.payload)
        clear_temp_audio()
        state.job = nil
        state.screen = polled.payload.status == "ok" and "result" or "error"
        telemetry_event("runtime_job_finished:" .. tostring(polled.payload.status))
      else
        state.last_loading_ms = polled.elapsed_ms
      end
    else
      state.last_loading_ms = math.max(0, math.floor((reaper.time_precise() - state.job.started_at) * 1000))
    end
  end

  local loading_text = report_presenter.loading_report(state.last_loading_ms)
  ImGui.TextWrapped(ctx, loading_text)
  ImGui.Spacing(ctx)

  local timeout_sec = state.job and tonumber(state.job.timeout_sec) or 0
  local elapsed_sec = state.last_loading_ms / 1000
  telemetry_counter("tags_total", 0)
  telemetry_counter("visible_tags", 0)
  telemetry_label("focused_tag", state.focused_tag or "none")
  local progress = 0
  local overlay = string.format("Listening... %.1f s", elapsed_sec)
  if timeout_sec and timeout_sec > 0 then
    progress = math.min(0.99, state.last_loading_ms / (timeout_sec * 1000))
    overlay = string.format("Listening... %.1f / %d s", elapsed_sec, timeout_sec)
  end
  ImGui.ProgressBar(ctx, progress, -1, 0, overlay)
  if state.last_loading_ms > 1000 then
    ImGui.Spacing(ctx)
    ImGui.TextDisabled(ctx, "Still working...")
  end
end

local function chip_palette(kind, hovered, active)
  local palette = {
    strong = { THEME.mint, 0xA9E9D3FF, 0x93DEC5FF },
    solid = { THEME.lavender, 0xD2C6FFFF, 0xC6B6FFFF },
    possible = { THEME.lemon, 0xFFE49BFF, 0xFFD77FFF },
    weak = { 0xF8C0D0FF, 0xF3AFC4FF, 0xEA9AB4FF },
    accent = { THEME.button, THEME.button_hover, THEME.button_active },
  }
  local colors = palette[kind] or palette.accent
  if active then
    return colors[3]
  end
  if hovered then
    return colors[2]
  end
  return colors[1]
end

local function chip_metrics(prediction, variant)
  local label = report_presenter.decorate_chip_label(prediction.label, prediction.score)
  local text_w, text_h = ImGui.CalcTextSize(ctx, label)
  local pad_x = variant == "flow" and 10 or 12
  local pad_y = variant == "flow" and 6 or 8
  local icon_size = variant == "flow" and 16 or 18
  local icon_gap = 8
  local min_width = variant == "flow" and 0 or 140
  local icon_key = prediction.icon_key or report_presenter.label_icon_key(prediction.label, prediction.bucket)
  local width = math.max(min_width, text_w + (pad_x * 2) + icon_size + icon_gap)
  local height = text_h + (pad_y * 2)

  return {
    label = label,
    icon_key = icon_key,
    icon_size = icon_size,
    icon_gap = icon_gap,
    pad_x = pad_x,
    text_h = text_h,
    width = width,
    height = height,
  }
end

local function render_button_chip(metrics, kind)
  ImGui.PushStyleColor(ctx, ImGui.Col_Button(), chip_palette(kind, false, false))
  ImGui.PushStyleColor(ctx, ImGui.Col_ButtonHovered(), chip_palette(kind, true, false))
  ImGui.PushStyleColor(ctx, ImGui.Col_ButtonActive(), chip_palette(kind, false, true))
  local pressed = ImGui.Button(ctx, metrics.label, metrics.width, metrics.height)
  ImGui.PopStyleColor(ctx, 3)
  return pressed
end

local function render_tag_chip(group_id, index, prediction, kind, variant)
  local metrics = chip_metrics(prediction, variant)

  ImGui.PushID(ctx, string.format("%s-%d-%s", group_id, index, prediction.label))
  local can_draw_custom = ImGui.InvisibleButton
    and ImGui.GetCursorScreenPos
    and ImGui.GetWindowDrawList
    and ImGui.DrawList_AddRectFilled
    and ImGui.DrawList_AddTextEx
    and ImGui.IsItemHovered
    and ImGui.IsItemActive
  local pressed = false

  if not can_draw_custom then
    pressed = render_button_chip(metrics, kind)
  else
    local cursor_x, cursor_y = ImGui.GetCursorScreenPos(ctx)
    pressed = ImGui.InvisibleButton(ctx, "chip", metrics.width, metrics.height)
    local hovered = ImGui.IsItemHovered(ctx)
    local active = ImGui.IsItemActive(ctx)
    local draw_list = ImGui.GetWindowDrawList(ctx)
    local rect_max_x = cursor_x + metrics.width
    local rect_max_y = cursor_y + metrics.height
    local rounding = metrics.height * 0.5
    local text_x = cursor_x + metrics.pad_x
    local text_y = cursor_y + ((metrics.height - metrics.text_h) * 0.5)
    local text_clip_max_x = rect_max_x - metrics.pad_x - metrics.icon_size - metrics.icon_gap

    ImGui.DrawList_AddRectFilled(draw_list, cursor_x, cursor_y, rect_max_x, rect_max_y, chip_palette(kind, hovered, active), rounding)
    ImGui.DrawList_AddTextEx(draw_list, nil, 0, text_x, text_y, THEME.text, metrics.label, 0.0, text_x, cursor_y, text_clip_max_x, rect_max_y)

    local icon_x = rect_max_x - metrics.pad_x - metrics.icon_size
    local icon_y = cursor_y + ((metrics.height - metrics.icon_size) * 0.5)
    if not draw_image_icon(draw_list, metrics.icon_key, icon_x, icon_y, metrics.icon_size) then
      report_icons.note_text_fallback(state.ui.icons)
    end
  end

  ImGui.PopID(ctx)
  return pressed, metrics
end

local function ordered_predictions(vm)
  return report_ui_state.ordered_predictions(vm.predictions, state.focused_tag)
end

local function flow_available_width()
  if ImGui.GetContentRegionAvail then
    local ok, width = pcall(ImGui.GetContentRegionAvail, ctx)
    if ok and type(width) == "number" and width > 0 then
      return width
    end
  end
  if ImGui.GetWindowWidth then
    local ok, width = pcall(ImGui.GetWindowWidth, ctx)
    if ok and type(width) == "number" and width > 0 then
      return math.max(180, width - 48)
    end
  end
  return 480
end

local function render_prediction_rows(vm, limit, show_support)
  for index, prediction in ipairs(ordered_predictions(vm)) do
    if index > limit then
      break
    end
    local bucket_label = report_presenter.bucket_label(prediction.bucket)
    if state.focused_tag and prediction.label == state.focused_tag then
      ImGui.TextColored(ctx, badge_color("success"), prediction.label)
    else
      ImGui.Text(ctx, prediction.label)
    end
    ImGui.SameLine(ctx, 0, 12)
    ImGui.ProgressBar(ctx, prediction.score, 180, 0, string.format("%d%%", math.floor(prediction.score * 100 + 0.5)))
    ImGui.SameLine(ctx, 0, 10)
    ImGui.TextDisabled(ctx, bucket_label)
    if show_support then
      local peak_score = tonumber(prediction.peak_score) or tonumber(prediction.score) or 0
      local support_count = tonumber(prediction.support_count) or 0
      local segment_count = tonumber(prediction.segment_count) or 0
      ImGui.TextDisabled(ctx, string.format("%d/%d seg • peak %.2f", support_count, segment_count, peak_score))
    end
  end
end

local function render_highlight_pills(vm)
  if #vm.highlights == 0 then
    return
  end
  render_image_label(report_presenter.section_icon_key("cues"), "Top cues", badge_color("accent"), 16)
  telemetry_counter("highlights_visible", math.min(#vm.highlights, report_presenter.COMPACT_HIGHLIGHT_LIMIT))
  for index, row in ipairs(vm.highlights) do
    if index > report_presenter.COMPACT_HIGHLIGHT_LIMIT then
      break
    end
    if render_tag_chip("highlight", index, row, row.palette_key or report_presenter.chip_palette_key(row.bucket), "feature") then
      report_ui_state.focus_tag(state, row.label)
    end
  end
end

local function render_tag_pills(vm)
  render_image_label(report_presenter.section_icon_key("tags"), "Tags", badge_color("accent"), 16)
  local spacing = 8
  local line_width = 0
  local available_width = flow_available_width()
  local ordered = ordered_predictions(vm)
  telemetry_counter("tags_total", #vm.predictions)
  telemetry_counter("visible_tags", #ordered)
  telemetry_label("focused_tag", state.focused_tag or "none")

  for index, prediction in ipairs(ordered) do
    local metrics = chip_metrics(prediction, "flow")
    if line_width > 0 and (line_width + spacing + metrics.width) <= available_width then
      ImGui.SameLine(ctx, 0, spacing)
      line_width = line_width + spacing + metrics.width
    else
      line_width = metrics.width
    end

    if render_tag_chip("tag", index, prediction, prediction.palette_key or report_presenter.chip_palette_key(prediction.bucket), "flow") then
      report_ui_state.focus_tag(state, prediction.label)
    end
  end
end

local function render_result()
  local vm = current_view_model()

  ImGui.TextWrapped(ctx, vm.summary)
  ImGui.Spacing(ctx)
  render_metric_chip("ready", vm.backend, "success")
  ImGui.SameLine(ctx)
  render_static_chip(string.format("%d ms", vm.total_ms), "accent")
  ImGui.Spacing(ctx)

  measure_phase("render_highlight_pills", function()
    render_highlight_pills(vm)
  end)
  ImGui.Spacing(ctx)
  measure_phase("render_tag_pills", function()
    render_tag_pills(vm)
  end)
  if state.notice then
    ImGui.Spacing(ctx)
    ImGui.TextColored(ctx, badge_color("warning"), tostring(state.notice))
  end
  ImGui.Spacing(ctx)

  if ImGui.Button(ctx, state.current_view == "compact" and "More" or "Less") then
    if state.current_view == "compact" then
      state.current_view = "details"
    else
      state.current_view = "compact"
      report_ui_state.clear_focus(state)
    end
  end
  ImGui.SameLine(ctx)
  if ImGui.Button(ctx, "Another") then
    start_analysis({ preserve_result_if_selection_invalid = true })
    return
  end

  if state.current_view == "details" then
    ImGui.Separator(ctx)
    render_image_label("details", "More", badge_color("accent"), 16)
    if report_ui_state.focused_label(state.focused_tag) then
      ImGui.Spacing(ctx)
      ImGui.TextWrapped(ctx, "Focused tag: " .. report_ui_state.focused_label(state.focused_tag))
    end
    if vm.item and vm.item.item_position and vm.item.item_length then
      ImGui.Spacing(ctx)
      ImGui.TextWrapped(
        ctx,
        string.format(
          "Selected range: %.2fs → %.2fs",
          tonumber(vm.item.item_position) or 0,
          tonumber(vm.item.selected_end) or ((tonumber(vm.item.item_position) or 0) + (tonumber(vm.item.item_length) or 0))
        )
      )
    end
    if vm.item and vm.item.read_strategy then
      ImGui.Spacing(ctx)
      ImGui.TextDisabled(ctx, string.format("Read: %s / %s", tostring(vm.item.read_strategy), tostring(vm.item.read_mode or "direct")))
    end
    if vm.item and vm.item.accessor_time_domain then
      ImGui.Spacing(ctx)
      ImGui.TextDisabled(ctx, string.format("Accessor domain: %s", tostring(vm.item.accessor_time_domain)))
    end
    measure_phase("render_prediction_rows", function()
      render_prediction_rows(vm, math.min(#vm.predictions, 12), true)
    end)
    if #vm.warnings > 0 then
      ImGui.Spacing(ctx)
      ImGui.TextColored(ctx, badge_color("warning"), "Notes")
      for _, warning in ipairs(vm.warnings) do
        ImGui.BulletText(ctx, warning)
      end
    end
    if #vm.attempted_backends > 0 then
      ImGui.Spacing(ctx)
      ImGui.TextWrapped(ctx, "Tried: " .. table.concat(vm.attempted_backends, " -> "))
    end
    if vm.model_status.name or vm.model_status.source then
      ImGui.Spacing(ctx)
      ImGui.TextWrapped(ctx, string.format("%s • %s", tostring(vm.model_status.name or "Cnn14"), tostring(vm.model_status.source or "managed runtime")))
    end
    ImGui.Spacing(ctx)
    ImGui.TextDisabled(ctx, "Clip tags only, not events.")
  end
end

local function render_error()
  telemetry_counter("tags_total", 0)
  telemetry_counter("visible_tags", 0)
  telemetry_label("focused_tag", state.focused_tag or "none")
  local error_text = report_presenter.error_report(state.result)
  ImGui.TextWrapped(ctx, error_text)
  if state.result and state.result.item and state.result.item.item_position and state.result.item.item_length then
    ImGui.Spacing(ctx)
    ImGui.TextDisabled(
      ctx,
      string.format(
        "Selected range: %.2fs → %.2fs",
        tonumber(state.result.item.item_position) or 0,
        tonumber(state.result.item.selected_end) or ((tonumber(state.result.item.item_position) or 0) + (tonumber(state.result.item.item_length) or 0))
      )
    )
  end
  ImGui.Spacing(ctx)
  if ImGui.Button(ctx, "Retry") then
    start_analysis()
    return
  end
  ImGui.SameLine(ctx)
  if ImGui.Button(ctx, "Bootstrap") then
    runtime_client.open_bootstrap(paths)
  end
end

local function loop()
  ensure_fonts()
  ensure_started()
  ImGui.SetNextWindowSize(ctx, 560, 420, ImGui.Cond_FirstUseEver())
  local color_count, var_count = push_theme()
  local visible, open = ImGui.Begin(ctx, "REAPER Audio Tag", state.window_open, ImGui.WindowFlags_NoCollapse())
  state.window_open = open
  if visible then
    report_icons.begin_frame(state.ui.icons)
    local pushed_base_font = push_font(state.ui.base_font, 15)
    local ok, err = xpcall(function()
      measure_phase("render_content", function()
        measure_phase("render_header", render_header)
        if state.screen == "setup" then
          measure_phase("render_setup", render_setup)
        elseif state.screen == "exporting" then
          measure_phase("render_exporting", render_exporting)
        elseif state.screen == "loading" then
          measure_phase("render_loading", render_loading)
        elseif state.screen == "result" then
          measure_phase("render_result", render_result)
        elseif state.screen == "error" then
          measure_phase("render_error", render_error)
        else
          ImGui.TextWrapped(ctx, "Warming up...")
        end
      end)
    end, debug.traceback)
    if pushed_base_font then
      ImGui.PopFont(ctx)
    end
    ImGui.End(ctx)
    pop_theme(color_count, var_count)
    if not ok then
      cancel_export_session()
      state.job = nil
      state.screen = "error"
      set_result(internal_ui_error_result("The report window hit an internal UI error. Reopen the report if the problem persists.\n\n" .. tostring(err)))
    end
  end

  if not visible then
    pop_theme(color_count, var_count)
  end

  if state.window_open then
    reaper.defer(loop)
  else
    cleanup_current_run()
  end
end

loop()
