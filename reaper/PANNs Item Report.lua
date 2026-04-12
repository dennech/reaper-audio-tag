local _, script_path = reaper.get_action_context()
local script_dir = script_path:match("^(.*[\\/])") or "."
package.path = table.concat({
  script_dir .. "lib/?.lua",
  package.path,
}, ";")

local app_paths = require("app_paths")
local audio_export = require("audio_export")
local path_utils = require("path_utils")
local report_presenter = require("report_presenter")
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

local ctx = ImGui.CreateContext("PANNs Item Report")
local state = {
  current_view = "compact",
  screen = "boot",
  result = nil,
  job = nil,
  last_error = nil,
  last_loading_ms = 0,
}

local function badge_color(kind)
  if kind == "success" then
    return 0x7FD977FF
  end
  if kind == "warning" then
    return 0x4AA3FFFF
  end
  if kind == "error" then
    return 0x6464FFFF
  end
  return 0xD8C36FFF
end

local function start_analysis()
  local export_path = path_utils.join(paths.tmp_dir, "selected-item-" .. path_utils.sanitize_job_id(reaper.genGuid("")) .. ".wav")
  local export_payload, err = audio_export.export_selected_item(export_path)
  if not export_payload then
    state.screen = "error"
    state.result = {
      status = "error",
      backend = "cpu",
      attempted_backends = { "cpu" },
      timing_ms = { preprocess = 0, inference = 0, total = 0 },
      summary = "No analysis summary is available.",
      predictions = {},
      highlights = {},
      warnings = {},
      model_status = { name = "Cnn14", source = "managed-runtime" },
      item = {},
      error = { code = "export_failed", message = err },
    }
    return
  end

  local job, job_err = runtime_client.start_job(paths, export_payload, {
    requested_backend = "auto",
    timeout_sec = 45,
  })
  if not job then
    state.screen = "setup"
    state.last_error = job_err
    return
  end

  state.job = job
  state.result = nil
  state.last_error = nil
  state.last_loading_ms = 0
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
  ImGui.TextColored(ctx, badge_color("success"), "PANNs Cnn14")
  ImGui.SameLine(ctx)
  ImGui.TextDisabled(ctx, "Selected item report")
  ImGui.Separator(ctx)
end

local function render_setup()
  ImGui.TextWrapped(ctx, "The runtime is not ready yet. Run the bootstrap script once, then reopen the report.")
  if state.last_error then
    ImGui.Spacing(ctx)
    ImGui.TextColored(ctx, badge_color("warning"), tostring(state.last_error))
  end
  ImGui.Spacing(ctx)
  if ImGui.Button(ctx, "Run bootstrap.command") then
    local ok, err = runtime_client.open_bootstrap(paths)
    if not ok then
      state.last_error = err
    else
      state.last_error = "Bootstrap launched in Terminal. Wait for it to finish, then press Retry."
    end
  end
  ImGui.SameLine(ctx)
  if ImGui.Button(ctx, "Retry") then
    if runtime_client.runtime_ready(paths) then
      state.screen = "boot"
      start_analysis()
    end
  end
  ImGui.Spacing(ctx)
  ImGui.TextWrapped(ctx, "Expected config path:")
  ImGui.TextWrapped(ctx, paths.config_path)
end

local function render_loading()
  if state.job then
    local polled = runtime_client.poll_job(state.job)
    if polled.done then
      state.result = polled.payload
      state.screen = polled.payload.status == "ok" and "result" or "error"
    else
      state.last_loading_ms = polled.elapsed_ms
    end
  end

  local loading_text = report_presenter.loading_report(state.last_loading_ms)
  ImGui.TextWrapped(ctx, loading_text)
  ImGui.Spacing(ctx)

  local progress = 0.15 + (math.sin(reaper.time_precise() * 2.2) + 1) * 0.35
  ImGui.ProgressBar(ctx, progress, -1, 0, "")
  if state.last_loading_ms > 1000 then
    ImGui.Spacing(ctx)
    ImGui.TextColored(ctx, badge_color("warning"), "Longer analysis: the selected item is still being processed.")
  end
end

local function render_prediction_rows(vm, limit, show_support)
  for index, prediction in ipairs(vm.predictions) do
    if index > limit then
      break
    end
    local icon = report_presenter.bucket_icon(prediction.bucket)
    ImGui.Text(ctx, string.format("%s %s", icon, prediction.label))
    ImGui.SameLine(ctx, 0, 12)
    ImGui.ProgressBar(ctx, prediction.score, 180, 0, string.format("%d%%", math.floor(prediction.score * 100 + 0.5)))
    if show_support then
      local peak_score = tonumber(prediction.peak_score) or tonumber(prediction.score) or 0
      local support_count = tonumber(prediction.support_count) or 0
      local segment_count = tonumber(prediction.segment_count) or 0
      ImGui.TextDisabled(ctx, string.format("Support %d/%d segments | Peak %.2f", support_count, segment_count, peak_score))
    end
  end
end

local function render_result()
  local vm = report_presenter.view_model(state.result)

  ImGui.TextWrapped(ctx, vm.summary)
  ImGui.Spacing(ctx)
  ImGui.TextColored(ctx, badge_color("success"), string.format("Backend: %s", vm.backend))
  ImGui.SameLine(ctx)
  ImGui.TextDisabled(ctx, string.format("%d ms", vm.total_ms))
  ImGui.Spacing(ctx)

  if #vm.highlights > 0 then
    ImGui.Text("Interesting findings")
    for _, row in ipairs(vm.highlights) do
      ImGui.BulletText(ctx, string.format("%s %s (%.0f%%)", row.headline, row.label, (tonumber(row.score) or 0) * 100))
    end
    ImGui.Spacing(ctx)
  end

  if ImGui.Button(ctx, state.current_view == "compact" and "Show details" or "Show compact") then
    state.current_view = state.current_view == "compact" and "details" or "compact"
  end
  ImGui.SameLine(ctx)
  if ImGui.Button(ctx, "Re-analyze selection") then
    start_analysis()
    return
  end
  if state.job and path_utils.exists(state.job.log_file) then
    ImGui.SameLine(ctx)
    if ImGui.Button(ctx, "Open log") then
      reaper.ExecProcess("open " .. path_utils.sh_quote(state.job.log_file), -2)
    end
  end

  ImGui.Separator(ctx)
  if state.current_view == "compact" then
    render_prediction_rows(vm, 5, false)
  else
    render_prediction_rows(vm, math.min(#vm.predictions, 12), true)
    if #vm.warnings > 0 then
      ImGui.Spacing(ctx)
      ImGui.TextColored(ctx, badge_color("warning"), "Warnings")
      for _, warning in ipairs(vm.warnings) do
        ImGui.BulletText(ctx, warning)
      end
    end
    if #vm.attempted_backends > 0 then
      ImGui.Spacing(ctx)
      ImGui.TextWrapped(ctx, "Attempted backends: " .. table.concat(vm.attempted_backends, " -> "))
    end
    if vm.model_status.name or vm.model_status.source then
      ImGui.Spacing(ctx)
      ImGui.TextWrapped(ctx, string.format("Model: %s", tostring(vm.model_status.name or "Cnn14")))
      ImGui.TextWrapped(ctx, string.format("Source: %s", tostring(vm.model_status.source or "managed runtime")))
    end
    ImGui.Spacing(ctx)
    ImGui.TextDisabled(ctx, "Clip-level tagging only; not event detection.")
  end
end

local function render_error()
  local error_text = report_presenter.error_report(state.result)
  ImGui.TextWrapped(ctx, error_text)
  ImGui.Spacing(ctx)
  if ImGui.Button(ctx, "Retry") then
    start_analysis()
    return
  end
  ImGui.SameLine(ctx)
  if ImGui.Button(ctx, "Open bootstrap.command") then
    runtime_client.open_bootstrap(paths)
  end
end

local function loop()
  ensure_started()
  ImGui.SetNextWindowSize(ctx, 560, 420, ImGui.Cond_FirstUseEver())
  local visible, open = ImGui.Begin(ctx, "PANNs Item Report", true, ImGui.WindowFlags_NoCollapse())
  if visible then
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
      ImGui.TextWrapped(ctx, "Preparing the report...")
    end
    ImGui.End(ctx)
  end

  if open then
    reaper.defer(loop)
  end
end

loop()
