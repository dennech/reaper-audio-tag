local luaunit = require('tests.lua.vendor.luaunit')
local ui_state = require('report_ui_state')

local tests = {}

function tests.test_icon_mode_defaults_to_auto()
  luaunit.assertEquals(ui_state.icon_mode(nil), 'auto')
  luaunit.assertEquals(ui_state.icon_mode('weird'), 'auto')
end

function tests.test_icon_mode_accepts_symbols_alias()
  luaunit.assertEquals(ui_state.icon_mode('symbols'), 'symbols')
  luaunit.assertEquals(ui_state.icon_mode('fallback'), 'symbols')
  luaunit.assertEquals(ui_state.icon_mode('emoji'), 'emoji')
end

function tests.test_load_icon_mode_reads_extstate()
  local fake_reaper = {
    GetExtState = function(_, _)
      return 'symbols'
    end,
  }

  luaunit.assertEquals(ui_state.load_icon_mode(fake_reaper), 'symbols')
end

function tests.test_save_icon_mode_persists_extstate()
  local captured = {}
  local fake_reaper = {
    SetExtState = function(_, _, value, persist)
      captured.value = value
      captured.persist = persist
    end,
  }

  local mode = ui_state.save_icon_mode(fake_reaper, 'fallback')

  luaunit.assertEquals(mode, 'symbols')
  luaunit.assertEquals(captured.value, 'symbols')
  luaunit.assertEquals(captured.persist, true)
end

function tests.test_icon_mode_options_are_stable()
  luaunit.assertEquals(table.concat(ui_state.icon_mode_options(), ','), 'auto,emoji,symbols')
end

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
