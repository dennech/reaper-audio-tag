local M = {}

function M.focus_tag(state, label)
  state.current_view = "details"
  state.focused_tag = label
  return state
end

function M.clear_focus(state)
  state.focused_tag = nil
  return state
end

function M.ordered_predictions(predictions, focused_tag)
  if not focused_tag or focused_tag == "" then
    return predictions or {}
  end

  local focused = {}
  local rest = {}
  for _, prediction in ipairs(predictions or {}) do
    if prediction.label == focused_tag then
      focused[#focused + 1] = prediction
    else
      rest[#rest + 1] = prediction
    end
  end

  local ordered = {}
  for _, row in ipairs(focused) do
    ordered[#ordered + 1] = row
  end
  for _, row in ipairs(rest) do
    ordered[#ordered + 1] = row
  end
  return ordered
end

function M.focused_label(focused_tag)
  if not focused_tag or focused_tag == "" then
    return nil
  end
  return focused_tag
end

return M
