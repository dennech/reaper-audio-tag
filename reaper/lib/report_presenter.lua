local report_icon_map = require("report_icon_map")

local M = {}

M.COMPACT_HIGHLIGHT_LIMIT = 5
M.COMPACT_TAG_LIMIT = 6

local BUCKET_LABELS = {
  strong = "Strong",
  solid = "Solid",
  possible = "Possible",
  weak = "Low",
}

local function chip_palette_key(bucket)
  local normalized = tostring(bucket or "weak"):lower()
  if normalized == "strong" then
    return "strong"
  end
  if normalized == "solid" then
    return "solid"
  end
  if normalized == "possible" then
    return "possible"
  end
  return "weak"
end

local function clone_predictions(predictions)
  local rows = {}
  for index, row in ipairs(predictions or {}) do
    rows[index] = {
      label = row.label or "Unknown",
      score = tonumber(row.score) or 0,
      bucket = row.bucket or "weak",
      palette_key = chip_palette_key(row.bucket),
      icon_key = report_icon_map.label_icon_key(row.label or "Unknown"),
      peak_score = tonumber(row.peak_score) or tonumber(row.score) or 0,
      support_count = tonumber(row.support_count) or 0,
      segment_count = tonumber(row.segment_count) or 0,
    }
  end
  table.sort(rows, function(left, right)
    if left.score == right.score then
      return left.label:lower() < right.label:lower()
    end
    return left.score > right.score
  end)
  return rows
end

local function round_score(score)
  return string.format("%.2f", tonumber(score) or 0)
end

local function append(lines, value)
  lines[#lines + 1] = value
end

local function compute_label(backend)
  local normalized = tostring(backend or ""):lower()
  if normalized == "cpu" then
    return "CPU"
  end
  if normalized == "" or normalized == "nil" then
    return "Unknown"
  end
  return "GPU"
end

local function compute_attempts(backends)
  local labels = {}
  local previous = nil
  for _, backend in ipairs(backends or {}) do
    local label = compute_label(backend)
    if label ~= previous then
      labels[#labels + 1] = label
      previous = label
    end
  end
  return labels
end

local function display_warning(warning)
  local text = tostring(warning or "")
  local normalized = text:lower()
  if normalized:find("coreml_requested_but_unavailable", 1, true) or normalized:find("directml_requested_but_unavailable", 1, true) then
    return "GPU acceleration was unavailable; CPU fallback was used."
  end
  text = text:gsub("CoreML", "GPU")
  text = text:gsub("coreml", "GPU")
  text = text:gsub("DirectML", "GPU")
  text = text:gsub("directml", "GPU")
  return text
end

local function display_warnings(warnings)
  local rows = {}
  for _, warning in ipairs(warnings or {}) do
    rows[#rows + 1] = display_warning(warning)
  end
  return rows
end

local function support_text(row)
  local support_count = tonumber(row.support_count) or 0
  local segment_count = tonumber(row.segment_count) or 0
  if segment_count <= 0 then
    return "Support: n/a"
  end
  return string.format("%d/%d seg | peak %s", support_count, segment_count, round_score(row.peak_score))
end

function M.section_icon_key(section_key)
  return report_icon_map.section_icon_key(section_key)
end

function M.label_icon_key(label, _bucket)
  return report_icon_map.label_icon_key(label)
end

function M.decorate_chip_label(label, score)
  local percent = math.floor((tonumber(score) or 0) * 100 + 0.5)
  return string.format("%s %d%%", tostring(label or "Unknown"), percent)
end

function M.chip_palette_key(bucket)
  return chip_palette_key(bucket)
end

function M.bucket_label(bucket)
  return BUCKET_LABELS[bucket] or "Tag"
end

function M.compute_label(backend)
  return compute_label(backend)
end

function M.compute_attempts(backends)
  return compute_attempts(backends)
end

function M.display_warning(warning)
  return display_warning(warning)
end

function M.view_model(result)
  local predictions = clone_predictions(result.predictions)
  local highlights = {}
  for _, row in ipairs(result.highlights or {}) do
    highlights[#highlights + 1] = {
      label = row.label or row,
      score = row.score,
      bucket = row.bucket or "solid",
      palette_key = chip_palette_key(row.bucket),
      icon_key = report_icon_map.label_icon_key(row.label or row),
      headline = row.headline or "Interesting finding",
      peak_score = tonumber(row.peak_score) or tonumber(row.score) or 0,
      support_count = tonumber(row.support_count) or 0,
      segment_count = tonumber(row.segment_count) or 0,
    }
  end

  local timing = result.timing_ms or {}
  local total_ms = timing.total or timing.total_ms or timing.inference or 0

  return {
    title = "REAPER Audio Tag",
    status = result.status or "unknown",
    stage = result.stage or "runtime",
    summary = result.summary or "No cues yet.",
    backend = result.backend,
    attempted_backends = result.attempted_backends or {},
    compute = compute_label(result.backend),
    attempted_compute = compute_attempts(result.attempted_backends or {}),
    total_ms = total_ms,
    warnings = display_warnings(result.warnings or {}),
    predictions = predictions,
    highlights = highlights,
    model_status = result.model_status or {},
    item = result.item or {},
  }
end

function M.compact_report(result)
  local vm = M.view_model(result)
  local lines = {}

  append(lines, vm.title)
  append(lines, string.format("%s • %s • %d ms", vm.status, vm.compute, vm.total_ms))
  append(lines, vm.summary)

  if #vm.highlights > 0 then
    append(lines, "Top cues")
    for index, row in ipairs(vm.highlights) do
      if index > M.COMPACT_HIGHLIGHT_LIMIT then
        break
      end
      append(lines, "  " .. M.decorate_chip_label(row.label, row.score))
    end
  end

  append(lines, "Tags")
  for index, prediction in ipairs(vm.predictions) do
    append(lines, string.format("  %d. %s", index, M.decorate_chip_label(prediction.label, prediction.score)))
  end

  if #vm.warnings > 0 then
    append(lines, "Warnings: " .. table.concat(vm.warnings, " | "))
  end

  append(lines, "More")
  return table.concat(lines, "\n")
end

function M.detail_report(result)
  local vm = M.view_model(result)
  local lines = {}

  append(lines, vm.title .. " — More")
  append(lines, string.format("%s • %s • %d ms", vm.status, vm.compute, vm.total_ms))
  append(lines, "Stage: " .. tostring(vm.stage))
  if #vm.attempted_compute > 0 then
    append(lines, "Tried: " .. table.concat(vm.attempted_compute, " -> "))
  end
  if vm.item and vm.item.item_position and vm.item.item_length then
    append(lines, string.format("Range: %.2fs + %.2fs", tonumber(vm.item.item_position) or 0, tonumber(vm.item.item_length) or 0))
  end
  if vm.item and vm.item.accessor_time_domain then
    append(lines, "Accessor domain: " .. tostring(vm.item.accessor_time_domain))
  end
  if vm.item and vm.item.read_mode then
    append(lines, string.format("Read: %s / %s", tostring(vm.item.read_strategy or "n/a"), tostring(vm.item.read_mode)))
  end
  append(lines, "Clip tags only, not events.")
  append(lines, "Predictions:")
  for _, prediction in ipairs(vm.predictions) do
    append(lines, string.format("  - [%s] %s %s", M.bucket_label(prediction.bucket), prediction.label, round_score(prediction.score)))
    append(lines, "    " .. support_text(prediction))
  end

  if next(vm.model_status) then
    append(lines, string.format("Model: %s • %s", vm.model_status.name or "Cnn14 ONNX", vm.model_status.source or "downloaded model"))
  end

  if #vm.warnings > 0 then
    append(lines, "Warnings:")
    for _, warning in ipairs(vm.warnings) do
      append(lines, "  - " .. warning)
    end
  end

  return table.concat(lines, "\n")
end

function M.loading_report(elapsed_ms)
  local total_ms = tonumber(elapsed_ms) or 0
  local seconds = math.floor(total_ms / 100) / 10
  return table.concat({
    "REAPER Audio Tag",
    "Listening...",
    string.format("%.1f s", seconds),
  }, "\n")
end

function M.exporting_report(elapsed_ms, item_name)
  local total_ms = tonumber(elapsed_ms) or 0
  local seconds = math.floor(total_ms / 100) / 10
  local lines = {
    "REAPER Audio Tag",
    "Preparing audio...",
  }
  if item_name and item_name ~= "" then
    append(lines, tostring(item_name))
  end
  append(lines, string.format("%.1f s", seconds))
  return table.concat(lines, "\n")
end

function M.error_report(result)
  local error_object = result and result.error or nil
  local code = error_object and error_object.code or "unknown_error"
  local message = error_object and error_object.message or "No details available."
  local stage = result and result.stage or "runtime"
  local lines = {
    "REAPER Audio Tag",
    "Try again",
    tostring(code),
    message,
  }
  if result and result.item and result.item.accessor_time_domain and stage == "export" then
    append(lines, "Accessor: " .. tostring(result.item.accessor_time_domain))
  end
  if result and result.item and result.item.read_mode and stage == "export" then
    append(lines, string.format("Read: %s / %s", tostring(result.item.read_strategy or "n/a"), tostring(result.item.read_mode)))
  end
  if result and result.attempted_backends and #result.attempted_backends > 0 and stage ~= "export" then
    append(lines, "Tried: " .. table.concat(compute_attempts(result.attempted_backends), " -> "))
  end
  if result and result.warnings and #result.warnings > 0 then
    append(lines, "Warnings: " .. table.concat(display_warnings(result.warnings), " | "))
  end
  return table.concat(lines, "\n")
end

return M
