local luaunit = require("tests.lua.vendor.luaunit")
local report_icons = require("report_icons")

local tests = {}

function tests.test_icon_catalog_is_stable()
  luaunit.assertEquals(
    table.concat(report_icons.icon_names(), ","),
    "brand,ready,loading,error,details,cues,tags,speech,synth,breath,click,music,generic"
  )
end

function tests.test_icon_png_data_decodes_png_header()
  local png = report_icons.icon_png_data("speech")
  luaunit.assertEquals(png ~= nil, true)
  luaunit.assertEquals(png:sub(1, 8), "\137PNG\r\n\26\n")
end

function tests.test_unknown_icon_returns_nil()
  luaunit.assertEquals(report_icons.icon_png_data("missing"), nil)
end

return tests
