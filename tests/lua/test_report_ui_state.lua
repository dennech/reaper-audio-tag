local luaunit = require('tests.lua.vendor.luaunit')
local ui_state = require('report_ui_state')

local tests = {}

function tests.test_focus_tag_switches_to_details()
  local state = {
    current_view = 'compact',
    focused_tag = nil,
  }

  ui_state.focus_tag(state, 'steady signal')

  luaunit.assertEquals(state.current_view, 'details')
  luaunit.assertEquals(state.focused_tag, 'steady signal')
end

function tests.test_clear_focus_resets_hidden_state()
  local state = {
    current_view = 'details',
    focused_tag = 'steady signal',
  }

  ui_state.clear_focus(state)

  luaunit.assertEquals(state.focused_tag, nil)
end

function tests.test_ordered_predictions_puts_focused_tag_first()
  local predictions = {
    { label = 'alpha', score = 0.9 },
    { label = 'beta', score = 0.8 },
    { label = 'gamma', score = 0.7 },
  }

  local ordered = ui_state.ordered_predictions(predictions, 'beta')

  luaunit.assertEquals(ordered[1].label, 'beta')
  luaunit.assertEquals(ordered[2].label, 'alpha')
  luaunit.assertEquals(ordered[3].label, 'gamma')
end

return tests
