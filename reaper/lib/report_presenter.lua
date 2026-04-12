local M = {}

local ICON = {
  strong = "🎯",
  solid = "✨",
  possible = "🔎",
  loading = "⏳",
  success = "✅",
  warning = "⚠️",
  error = "💥",
  details = "📋",
}

local function clone_predictions(predictions)
  local rows = {}
  for index, row in ipairs(predictions or {}) do
    rows[index] = {
      label = row.label or "Unknown",
      score = tonumber(row.score) or 0,
      bucket = row.bucket or "weak",
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

local function bucket_icon(bucket)
  return ICON[bucket] or "•"
end

function M.bucket_icon(bucket)
  return bucket_icon(bucket)
end

local function support_text(row)
  local support_count = tonumber(row.support_count) or 0
  local segment_count = tonumber(row.segment_count) or 0
  if segment_count <= 0 then
    return "Support: n/a"
  end
  return string.format("Support: %d/%d segments | Peak: %s", support_count, segment_count, round_score(row.peak_score))
end

function M.view_model(result)
  local predictions = clone_predictions(result.predictions)
  local highlights = {}
  for _, row in ipairs(result.highlights or {}) do
    highlights[#highlights + 1] = {
      label = row.label or row,
      score = row.score,
      bucket = row.bucket or "solid",
      headline = row.headline or "Interesting finding",
      peak_score = tonumber(row.peak_score) or tonumber(row.score) or 0,
      support_count = tonumber(row.support_count) or 0,
      segment_count = tonumber(row.segment_count) or 0,
    }
  end

  local timing = result.timing_ms or {}
  local total_ms = timing.total or timing.total_ms or timing.inference or 0

  return {
    title = "PANNs Item Report",
    status = result.status or "unknown",
    summary = result.summary or "No summary available yet.",
    backend = result.backend or "cpu",
    attempted_backends = result.attempted_backends or {},
    total_ms = total_ms,
    warnings = result.warnings or {},
    predictions = predictions,
    highlights = highlights,
    model_status = result.model_status or {},
    item = result.item or {},
  }
end

local function append(lines, value)
  lines[#lines + 1] = value
end

function M.compact_report(result)
  local vm = M.view_model(result)
  local lines = {}

  append(lines, vm.title)
  append(lines, string.format("%s %s | %s | %d ms", ICON.success, vm.status, vm.backend, vm.total_ms))
  append(lines, vm.summary)

  if #vm.highlights > 0 then
    append(lines, "Highlights:")
    for index, row in ipairs(vm.highlights) do
      if index > 5 then
        break
      end
      append(lines, string.format("  %s %s (%s)", bucket_icon(row.bucket), row.label, round_score(row.score)))
    end
  end

  append(lines, "Top tags:")
  for index, prediction in ipairs(vm.predictions) do
    if index > 5 then
      break
    end
    append(lines, string.format("  %d. %s %s (%s)", index, bucket_icon(prediction.bucket), prediction.label, round_score(prediction.score)))
  end

  if #vm.warnings > 0 then
    append(lines, ICON.warning .. " " .. table.concat(vm.warnings, " | "))
  end

  append(lines, ICON.details .. " Press Details for the full report")
  return table.concat(lines, "\n")
end

function M.detail_report(result)
  local vm = M.view_model(result)
  local lines = {}

  append(lines, vm.title .. " — Full Report")
  append(lines, string.format("Status: %s", vm.status))
  append(lines, string.format("Backend: %s", vm.backend))
  if #vm.attempted_backends > 0 then
    append(lines, "Attempted backends: " .. table.concat(vm.attempted_backends, " -> "))
  end
  append(lines, string.format("Elapsed: %d ms", vm.total_ms))
  append(lines, "Note: Clip-level tagging only; not event detection.")
  append(lines, "Predictions:")
  for _, prediction in ipairs(vm.predictions) do
    append(lines, string.format("  - %s %s => %s", bucket_icon(prediction.bucket), prediction.label, round_score(prediction.score)))
    append(lines, "    " .. support_text(prediction))
  end

  if next(vm.model_status) then
    append(lines, string.format("Model: %s", vm.model_status.name or "Cnn14"))
    append(lines, string.format("Source: %s", vm.model_status.source or "managed runtime"))
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
    "PANNs Item Report",
    ICON.loading .. " Analyzing the selected item...",
    string.format("Elapsed: %.1f s", seconds),
    "The report will appear here as soon as inference finishes.",
  }, "\n")
end

function M.error_report(result)
  local error_object = result and result.error or nil
  local code = error_object and error_object.code or "unknown_error"
  local message = error_object and error_object.message or "No details available."
  local lines = {
    "PANNs Item Report",
    ICON.error .. " Analysis failed",
    "Code: " .. tostring(code),
    message,
  }
  if result and result.attempted_backends and #result.attempted_backends > 0 then
    append(lines, "Attempted backends: " .. table.concat(result.attempted_backends, " -> "))
  end
  if result and result.warnings and #result.warnings > 0 then
    append(lines, ICON.warning .. " " .. table.concat(result.warnings, " | "))
  end
  return table.concat(lines, "\n")
end

return M
