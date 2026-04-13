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
    reaper.ShowMessageBox(message, "PANNs Item Report", 0)
    reaper.ReaPack_BrowsePackages("ReaImGui: ReaScript binding for Dear ImGui")
  else
    reaper.ShowMessageBox(message, "PANNs Item Report", 0)
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

local ctx = ImGui.CreateContext("PANNs Item Report")
local state = {
  current_view = "compact",
  screen = "boot",
  result = nil,
  job = nil,
  last_error = nil,
  last_loading_ms = 0,
  focused_tag = nil,
  export_log_file = nil,
  notice = nil,
  run_artifacts = nil,
  ui = {
    base_font = nil,
    fonts_ready = false,
    last_poll_at_ms = 0,
    poll_interval_ms = 100,
    icons = {
      loaded = false,
      images = {},
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

local function image_for(icon_key)
  ensure_icons()
  return report_icons.image(ImGui, state.ui.icons, icon_key)
end

local function render_inline_image(icon_key, size)
  local image = image_for(icon_key)
  if not (image and ImGui.Image) then
    return false
  end
  local ok = pcall(ImGui.Image, ctx, image, size, size)
  if not ok then
    if state.ui.icons.images then
      state.ui.icons.images[icon_key] = nil
    end
    state.ui.icons.available = false
    state.ui.icons.loaded = false
    return false
  end
  return true
end

local function draw_image_icon(draw_list, icon_key, x, y, size)
  if not ImGui.DrawList_AddImage then
    return false
  end
  local image = image_for(icon_key)
  if not image then
    return false
  end
  local ok = pcall(ImGui.DrawList_AddImage, draw_list, image, x, y, x + size, y + size)
  if not ok then
    if state.ui.icons.images then
      state.ui.icons.images[icon_key] = nil
    end
    state.ui.icons.available = false
    state.ui.icons.loaded = false
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

local function open_log()
  if state.result and state.result.stage == "export" and state.export_log_file and path_utils.exists(state.export_log_file) then
    reaper.ExecProcess("open " .. path_utils.sh_quote(state.export_log_file), -2)
    return
  end
  if state.job and path_utils.exists(state.job.log_file) then
    reaper.ExecProcess("open " .. path_utils.sh_quote(state.job.log_file), -2)
    return
  end
  if state.export_log_file and path_utils.exists(state.export_log_file) then
    reaper.ExecProcess("open " .. path_utils.sh_quote(state.export_log_file), -2)
  end
end

local function clear_temp_audio()
  if state.run_artifacts then
    report_run_cleanup.clear_temp_audio(paths, state.run_artifacts)
  end
end

local function cleanup_current_run()
  if state.run_artifacts then
    report_run_cleanup.cleanup_run(paths, state.run_artifacts)
    state.run_artifacts = nil
  end
end

local function status_chip()
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
  local previous_job = state.job
  local previous_export_log_file = state.export_log_file
  local previous_run_artifacts = state.run_artifacts
  local previous_view = state.current_view
  local previous_focused_tag = state.focused_tag

  state.notice = nil
  local export_id = path_utils.sanitize_job_id(reaper.genGuid(""))
  local export_path = path_utils.join(paths.tmp_dir, "selected-item-" .. export_id .. ".wav")
  local export_log_path = path_utils.join(paths.logs_dir, "export-" .. export_id .. ".log")
  local export_payload, err, export_metadata = audio_export.export_selected_item(export_path, {
    diagnostics_path = export_log_path,
  })
  if not export_payload then
    if preserve_result_if_selection_invalid and export_metadata and export_metadata.error_kind == "selection" and previous_result then
      state.screen = previous_screen
      state.result = previous_result
      state.job = previous_job
      state.export_log_file = previous_export_log_file
      state.run_artifacts = previous_run_artifacts
      state.current_view = previous_view
      state.focused_tag = previous_focused_tag
      state.notice = err
      return
    end

    cleanup_current_run()
    state.run_artifacts = report_run_cleanup.new_artifacts(nil, export_log_path, nil)
    state.export_log_file = export_log_path
    state.job = nil
    state.screen = "error"
    state.current_view = "compact"
    state.focused_tag = nil
    state.result = {
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
    }
    return
  end

  local job, job_err = runtime_client.start_job(paths, export_payload, {
    requested_backend = "auto",
  })
  if not job then
    cleanup_current_run()
    state.run_artifacts = report_run_cleanup.new_artifacts(export_path, export_log_path, nil)
    clear_temp_audio()
    state.export_log_file = export_log_path
    state.job = nil
    state.screen = "setup"
    state.last_error = job_err
    return
  end

  cleanup_current_run()
  state.run_artifacts = report_run_cleanup.new_artifacts(export_path, export_log_path, job)
  state.export_log_file = export_log_path
  state.job = job
  state.result = nil
  state.last_error = nil
  state.last_loading_ms = 0
  state.current_view = "compact"
  state.focused_tag = nil
  state.ui.last_poll_at_ms = 0
  state.screen = "loading"
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
  ImGui.TextColored(ctx, badge_color("accent"), "PANNs Report")
  ImGui.SameLine(ctx, 0, 16)
  render_metric_chip(chip_icon, chip_label, chip_kind)
  ImGui.Separator(ctx)
end

local function render_setup()
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

local function render_loading()
  local now_ms = math.floor(reaper.time_precise() * 1000)
  if state.job then
    if state.ui.last_poll_at_ms == 0 or (now_ms - state.ui.last_poll_at_ms) >= state.ui.poll_interval_ms then
      local polled = runtime_client.poll_job(state.job)
      state.ui.last_poll_at_ms = now_ms
      if polled.done then
        state.result = polled.payload
        clear_temp_audio()
        state.screen = polled.payload.status == "ok" and "result" or "error"
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
    accent = { THEME.button, THEME.button_hover, THEME.button_active },
    success = { THEME.mint, 0xA9E9D3FF, 0x93DEC5FF },
    sparkle = { THEME.lavender, 0xD2C6FFFF, 0xC6B6FFFF },
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

local function render_tag_chip(group_id, index, prediction, kind)
  local label = report_presenter.decorate_chip_label(prediction.label, prediction.score)
  local icon_key = report_presenter.label_icon_key(prediction.label, prediction.bucket)
  local text_w, text_h = ImGui.CalcTextSize(ctx, label)
  local icon_size = image_for(icon_key) and 18 or 0
  local pad_x = 12
  local pad_y = 8
  local gap = icon_size > 0 and 8 or 0
  local width = math.max(140, text_w + (pad_x * 2) + icon_size + gap)
  local height = math.max(text_h, icon_size) + (pad_y * 2)

  ImGui.PushID(ctx, string.format("%s-%d-%s", group_id, index, prediction.label))
  local pressed = ImGui.InvisibleButton(ctx, "##chip", width, height)
  local hovered = ImGui.IsItemHovered(ctx)
  local active = ImGui.IsItemActive(ctx)
  local min_x, min_y = ImGui.GetItemRectMin(ctx)
  local max_x, max_y = ImGui.GetItemRectMax(ctx)
  local draw_list = ImGui.GetWindowDrawList(ctx)
  local bg = chip_palette(kind, hovered, active)

  ImGui.DrawList_AddRectFilled(draw_list, min_x, min_y, max_x, max_y, bg, height / 2)
  local text_x = min_x + pad_x
  local text_y = min_y + math.max(0, (height - text_h) / 2)
  ImGui.DrawList_AddText(draw_list, text_x, text_y, THEME.text, label)
  if icon_size > 0 then
    local icon_x = max_x - pad_x - icon_size
    local icon_y = min_y + math.max(0, (height - icon_size) / 2)
    draw_image_icon(draw_list, icon_key, icon_x, icon_y, icon_size)
  end
  ImGui.PopID(ctx)
  return pressed
end

local function ordered_predictions(vm)
  return report_ui_state.ordered_predictions(vm.predictions, state.focused_tag)
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
  for index, row in ipairs(vm.highlights) do
    if index > report_presenter.COMPACT_HIGHLIGHT_LIMIT then
      break
    end
    if render_tag_chip("highlight", index, row, index == 1 and "success" or "sparkle") then
      report_ui_state.focus_tag(state, row.label)
    end
  end
end

local function render_tag_pills(vm)
  render_image_label(report_presenter.section_icon_key("tags"), "Tags", badge_color("accent"), 16)
  for index, prediction in ipairs(vm.predictions) do
    if index > report_presenter.COMPACT_TAG_LIMIT then
      break
    end
    if render_tag_chip("tag", index, prediction, "accent") then
      report_ui_state.focus_tag(state, prediction.label)
    end
  end
end

local function render_result()
  local vm = report_presenter.view_model(state.result)

  ImGui.TextWrapped(ctx, vm.summary)
  ImGui.Spacing(ctx)
  render_metric_chip("ready", vm.backend, "success")
  ImGui.SameLine(ctx)
  render_static_chip(string.format("%d ms", vm.total_ms), "accent")
  ImGui.Spacing(ctx)

  render_highlight_pills(vm)
  ImGui.Spacing(ctx)
  render_tag_pills(vm)
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
  if state.job and path_utils.exists(state.job.log_file) then
    ImGui.SameLine(ctx)
    if ImGui.Button(ctx, "Log") then
      open_log()
    end
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
    render_prediction_rows(vm, math.min(#vm.predictions, 12), true)
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
  if (state.job and path_utils.exists(state.job.log_file)) or (state.export_log_file and path_utils.exists(state.export_log_file)) then
    ImGui.SameLine(ctx)
    if ImGui.Button(ctx, "Open log") then
      open_log()
    end
  end
end

local function loop()
  ensure_fonts()
  ensure_started()
  ImGui.SetNextWindowSize(ctx, 560, 420, ImGui.Cond_FirstUseEver())
  local color_count, var_count = push_theme()
  local visible, open = ImGui.Begin(ctx, "PANNs Item Report", true, ImGui.WindowFlags_NoCollapse())
  if visible then
    local pushed_base_font = push_font(state.ui.base_font, 15)
    local ok, err = xpcall(function()
      render_header()
      if state.screen == "setup" then
        render_setup()
      elseif state.screen == "loading" then
        render_loading()
      elseif state.screen == "result" then
        render_result()
      elseif state.screen == "error" then
        render_error()
      else
        ImGui.TextWrapped(ctx, "Warming up...")
      end
    end, debug.traceback)
    if pushed_base_font then
      ImGui.PopFont(ctx)
    end
    ImGui.End(ctx)
    pop_theme(color_count, var_count)
    if not ok then
      state.job = nil
      state.screen = "error"
      state.result = internal_ui_error_result("The report window hit an internal UI error. Reopen the report if the problem persists.\n\n" .. tostring(err))
    end
  else
    ImGui.End(ctx)
    pop_theme(color_count, var_count)
  end

  if open then
    reaper.defer(loop)
  else
    cleanup_current_run()
  end
end

loop()
