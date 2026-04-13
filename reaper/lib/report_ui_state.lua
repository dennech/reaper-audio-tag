local M = {}

local EXTSTATE_SECTION = "reaper_panns_item_report"
local EXTSTATE_ICON_MODE_KEY = "icon_mode"
local DEFAULT_ICON_MODE = "auto"

local function normalized_icon_mode(icon_mode)
  if icon_mode == "symbols" or icon_mode == "fallback" then
    return "symbols"
  end
  if icon_mode == "emoji" then
    return "emoji"
  end
  return "auto"
end

function M.icon_mode(icon_mode)
  return normalized_icon_mode(icon_mode)
end

function M.load_icon_mode(api)
  if not api or not api.GetExtState then
    return DEFAULT_ICON_MODE
  end
  local value = api.GetExtState(EXTSTATE_SECTION, EXTSTATE_ICON_MODE_KEY)
  if not value or value == "" then
    return DEFAULT_ICON_MODE
  end
  return normalized_icon_mode(value)
end

function M.save_icon_mode(api, icon_mode)
  local normalized = normalized_icon_mode(icon_mode)
  if api and api.SetExtState then
    api.SetExtState(EXTSTATE_SECTION, EXTSTATE_ICON_MODE_KEY, normalized, true)
  end
  return normalized
end

function M.icon_mode_options()
  return { "auto", "emoji", "symbols" }
end

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
