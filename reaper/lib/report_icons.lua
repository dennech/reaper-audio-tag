local M = {}

local ORDER = {
  "brand",
  "ready",
  "loading",
  "error",
  "details",
  "cues",
  "tags",
  "speech",
  "synth",
  "breath",
  "click",
  "music",
  "generic",
}

local PNGS = {
  brand = [[iVBORw0KGgoAAAANSUhEUgAAACAAAAAgCAYAAABzenr0AAAA6klEQVR42u2XPQ7DMAiFc/+5R+jaA/QsvUP3dHHF
EMlCNo8H/lGlIjEF874QTOzj+FvS7rezLBN7v0oRQeQSt0V4CkhUfAiEFn8+PusganER1j4VAonXEGJDISQIAViG
ACCEJc5YqAr67WuIiNFVYABajTgFoJXY2gUIAgKgpJ5u91QhXIEsQLcC1wMNwGwzz5paB1aA3eeedVQTbgO4ICLT
zlpjlr/XBwwEiqUAUBXYiahzw3E8CoISbwGIZ6yVz/1L7s0G/d3R75cStyCYU3FKHEFoIE9c6mCa9SFH823iUZCl
17Wfvtx+AcK5jIG1yO6+AAAAAElFTkSuQmCC]],
  ready = [[iVBORw0KGgoAAAANSUhEUgAAACAAAAAgCAYAAABzenr0AAAA5UlEQVR42u2XwQnDMAxFs21HKXSNTpEBukDPnaEr
JOgQMMLW15dlh0AEPkX4PQvZsZfljs54fJ7bNNj6/20CREPyTgEPEYnCUyQ0/PV9z5Mo4QLWY6gEgjMSEpSEJGUJ
lHEIQAkvHEnUAlZBrz5agRYcViFDwIKHBJhd0ApKwGoq1HgIDndDqwKtiaLwqsDxQQugCRl4KWBKMBMz8FATWgAW
7hbwSHg6niq/JeCV8K7eJcBKMHDXccxIpMFrAkiChVO/ZCQxBG5JMLfiLjiS0EKevK6Lae9IuZqfBo+KTH2uXfpx
uwOCFY/YKIEnWAAAAABJRU5ErkJggg==]],
  loading = [[iVBORw0KGgoAAAANSUhEUgAAACAAAAAgCAYAAABzenr0AAAAzklEQVR42u2X2w2AIAwAmd89/HYGJ3EUFKMGsfRB
C2hik34YCXcliMW5P5Thp8G3gy2TD0Ayt3F9wDVEiuEWEg/4PLaTuMEDOM44wvv0WSvBhkMCWokdnhOAAhLISRxz
l1UPRbwnBBL86k8JCi6RwFYBFMjBc18EJWEiIA2RAKcijQC2D6qsAHcPXPBGArhEjxV4l4D2D4gcxR8SsJZI5qaP
Y0sJLhwUMOiIRAKmEiVwVELQFavgpEQqxBina0yVadOa94KXijS9rn36crsC19hkxN+pcbgAAAAASUVORK5CYII=]],
  error = [[iVBORw0KGgoAAAANSUhEUgAAACAAAAAgCAYAAABzenr0AAAA7klEQVR42u2Xyw3DIAyGs3FXadfINL12gVw6BJEP
rZDlx2+bgCrVkk9BfB/mEdi2fxTjuD3aNFh7vhoBvaR2S8CXiGThQyQ4/H3f50n0cALzvFRCglNEJChSEtSIC/SB
CPTBBVwJC45ISAFXgY/ek4jC3SpoAppEFJ4SQCRQOCRgrWxNAoW760CrADLXEbgo8PkA/3AS8F7AlFhSAVSgugYg
AU2iugvM8nsCI86BkEAvAY/QaMf7do/jb0bnWAoULgowifAWFfqDf8lcInQBycJNicCtuAT3JLgQ0q50Ma3mkKv5
MnhWZOpz7acftycz0QjCdpfuhAAAAABJRU5ErkJggg==]],
  details = [[iVBORw0KGgoAAAANSUhEUgAAACAAAAAgCAYAAABzenr0AAAA2klEQVR42u2XMQ7DMAhFc/85N+icvefI3oMkiyuG
SBGy+YCBqFKRmIz8XnDi2Mvyj8l4rUcrg3321giIkuoeAaeIeOEhEhz+3s46iTucwDwp0iRGcCnCJKioJ6AJjQCU
8MItEuqnp+RxX5JRjbsLSIC/iKO6EgE+cZgAav9oYusyuDogTTrdgWugSkCUsLY29SvoAWb2ApVAloTYfiQQIWES
QOeAHkCS4HPD7Vgjoe2SGt4TyJBQ/5IzJEyHEq/IVeuGIwkuJI274RYJlCFH88fgXpHS69pPX26/SMBh3e6t7TIA
AAAASUVORK5CYII=]],
  cues = [[iVBORw0KGgoAAAANSUhEUgAAACAAAAAgCAYAAABzenr0AAAA3ElEQVR42u2XMQ7DIAxFc/+5N+icvefo3oO0C5GH
SAgF+xk7pJVqiSkk7/EhCSzLv4J1v73LNNjrWYoArSb9LgGfIjIKT5Fo4Y/1M0+ihgu4badKWPBaQipVQjoRgaMi
AqbEKNwjgUffk4gKdCWIAKlUAa9EOAHt5h1gCZAUXAlECiewX2gF6GipRM1BCdAHewXQFNCIPVOBBKiENwE1/q8T
sCR6rymBo89xb0GSv5628tHPSJMY2Qe4BDIlhuCahGdXHIJbEq0Q6RfamEZbytb8MvioyNTj2k8fbjf5iXFdKUpg
vwAAAABJRU5ErkJggg==]],
  tags = [[iVBORw0KGgoAAAANSUhEUgAAACAAAAAgCAYAAABzenr0AAAA1klEQVR42u2XMQrDMAxFc/8518jWK3TvmouEbi4a
DEEE6X9JdghUoMmG9/Jtgrws/0rWsb7aNFj77E2AXsu+W8BDRKLwEgkN/27veRJnuIB1D5Xw4EMlZFNEQAoRcCVQ
eG9dqRT011sSVoVTQATQKhPoEhaIkXAFzPgMAHsMVAJXEGs9dAf6ApMCCz8LmBLsMaDw8CX0JFA4LJC5jOH4GQE2
9pBAdg6w4NDvuFIChl8JVExElEClRAhuSTBTcQruSWghZF9qMM12yWh+GzwqMvW59ujH7Q/MfUMdHL4A7wAAAABJ
RU5ErkJggg==]],
  speech = [[iVBORw0KGgoAAAANSUhEUgAAACAAAAAgCAYAAABzenr0AAAA1ElEQVR42u2X0QnDMAxEM3Bn6T7NCN2gkJ8ukBVS
9BEIJtFJunPSQg/0ZZt7OoSdDMNfpG6vcTnN7DFPixmisn2XGHcBqZpLIFrz+/t5HsTW3IzbWtdMcghk7omGsE0e
QEQeAIRguqdTaLtXJwBTQAAZyQAqEFQC3mEFgDsHRwlsq1sC60Lk6mW7hxCRmy1rTA1hNAEZQHUOqPi/DsCDYKYf
vgdVCIn5HkAEImOeepJbiOw7UDL3IKLaO1v+LEN11CltnoHoZq6AkP+gXGKMoH765/YDp9AO1f8a5NEAAAAASUVO
RK5CYII=]],
  synth = [[iVBORw0KGgoAAAANSUhEUgAAACAAAAAgCAYAAABzenr0AAAAzklEQVR42u2Xyw2AIAxA3X8RN/DiAN69OwumBxLT
lLa0pYREEg5G4D3Lx7Jtf3GWYy8lDfbcpQBQqtBuCniIiBUeIoHh15ko8YUDGNehEhJ8qAQ04gSkIgmIEi14bzFF
AX99lcADa5+7o8AJeLaiSyASrhLAHaIF2HVARWAEnBSoL7KmgJWYugYoAasE1U8lEBEFDr6GQGsqrEcxHls8jltb
0vIPUMMpgYiMqEsgUsIE5yR6smIXXJLAQpp2rsTUW0NS82lwq0jqdW3py+0L3UlrRRiSMtIAAAAASUVORK5CYII=]],
  breath = [[iVBORw0KGgoAAAANSUhEUgAAACAAAAAgCAYAAABzenr0AAAAzUlEQVR42u2XWwqAIBBF2/9SgrYQraH/1mLMhyAy
jHdeStCF+Uo6xzHUtu2PM/tRyjTYc5dCwFHRuCXgFBErPESih5/XRIkWTuC+UiVG8FQJGpQpMJRA4a0EJaQL/ewl
CSnmLqACSMIEOIlUAal9KBxZBlUH6odmCdyB+oAT8IYTECVmCMBLEBWVQLQE1H6rACJoEmglomcPbcethFcAhnMC
VJ5w74OPZGlv0By/KrgkobkVu+AjiV4IGee6mHor5Gq+DG4Vmfq79umf2xeBPK/NnVcwngAAAABJRU5ErkJggg==]],
  click = [[iVBORw0KGgoAAAANSUhEUgAAACAAAAAgCAYAAABzenr0AAABA0lEQVR42u2XwQrCMAyG9/5nX8PbXsG7V9/Cw5AJ
rtGIlVLa5E9aNwYGAoOV/V/TP2s7DP9ojNthpNXE6HwhFtSSx20i/BMQr/gXYr5TN/H5eDKJhxAoPBYfRCrOwnnC
AK80L4cmjkCk4iZP8CAJgEMDWK7Tu/QlABVCm30MBMLcGfnsaxWI4W3NKoQVAIFIK8HPZoAcohSiFz5mjMktKQKI
5RMCrYDog1oFEADUE9UliC9aABCIVKd7BRAIlwkRmK5t6IGwiO8DAIHwmg/6HSMQVuPBmxEKgQCUvgdvyRqE1gku
cQnCcipuEtcgciBkXNPBtDW7HM03E/eCrHpd2/Xl9gkcnFLtN68RQgAAAABJRU5ErkJggg==]],
  music = [[iVBORw0KGgoAAAANSUhEUgAAACAAAAAgCAYAAABzenr0AAAA6UlEQVR42u2X2w2DMAxFmZ89+s0MTNJR0lKVyg22
r18EVaolfxFyThySkGn6RzLaMrdxsPvSNiDMZ7trwGeIhOEVEgf4ehsn8QXfwH1SAI0KCQjfE0VE4gWvEuhl3n3X
jL4X4KaDe64JHEbvqQA374KAKFEuIHyMPgFtFZwioL0cWX6eJSlWQMrKCnzgFQJgQ8ISUQHjZpSfAg2IJEwCkkQ0
LOWHAtlwC/QSqHMH3LYdU4lsWOGsgEVCqxLTn/1Ipuk594Wy+39KLBJgswnBVYldhE6P1C4DhxKOrPk1vwoeFRl6
Xfvpy+0DTWttpJrc/IgAAAAASUVORK5CYII=]],
  generic = [[iVBORw0KGgoAAAANSUhEUgAAACAAAAAgCAYAAABzenr0AAAAyklEQVR42u3XTQqAIBAF4O6/7gat23eX7tC+NsYs
ghB786sWNOAq430OJjYMfzlrGvfULGxbU6JAbtC8LsFVINbwEEQevsxHO8Q9nILzURXBhVdF0CQNgEoDYBHS8FK5
u5CvHiE8gEeEFIAqHKBBhHQAvXzf+VYA3AdPHUBDEww7cD3wHr1SAERIVt3sK+gCQAiuzO1/HcCCkIaLjmOE0ALE
4SVAxI1IBYhEmMIRQnMrdoVziBwkmee6mHpHyNW8W7gV0vR37dM/tydCFEV50f2X5gAAAABJRU5ErkJggg==]],
}

local function decode_base64(data)
  local alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
  data = (data or ""):gsub("%s+", "")
  return (data:gsub(".", function(ch)
    if ch == "=" then
      return ""
    end
    local index = alphabet:find(ch, 1, true)
    if not index then
      return ""
    end
    local value = index - 1
    local bits = {}
    for bit = 5, 0, -1 do
      bits[#bits + 1] = math.floor(value / (2 ^ bit)) % 2
    end
    return table.concat(bits)
  end):gsub("%d%d%d?%d?%d?%d?%d?%d?", function(bits)
    if #bits ~= 8 then
      return ""
    end
    local value = 0
    for index = 1, 8 do
      if bits:sub(index, index) == "1" then
        value = value + 2 ^ (8 - index)
      end
    end
    return string.char(value)
  end))
end

function M.icon_names()
  local names = {}
  for _, name in ipairs(ORDER) do
    names[#names + 1] = name
  end
  return names
end

function M.icon_png_data(icon_key)
  local encoded = PNGS[icon_key]
  if not encoded then
    return nil
  end
  return decode_base64(encoded)
end

function M.is_valid_image(ImGui, image)
  if not image then
    return false
  end
  if not (ImGui and ImGui.ValidatePtr) then
    return true
  end
  local ok, valid = pcall(ImGui.ValidatePtr, image, "ImGui_Image*")
  return ok and valid == true
end

function M.ensure_loaded(ImGui, cache)
  if not cache then
    return
  end

  cache.images = cache.images or {}
  if not (ImGui and ImGui.CreateImageFromMem) then
    cache.loaded = true
    cache.available = false
    return
  end

  local missing = not cache.loaded
  cache.available = false
  for _, name in ipairs(ORDER) do
    local image = cache.images[name]
    if M.is_valid_image(ImGui, image) then
      cache.available = true
    else
      cache.images[name] = nil
      missing = true
    end
  end

  if cache.loaded and not missing then
    return
  end

  cache.loaded = true
  for _, name in ipairs(ORDER) do
    if not cache.images[name] then
      local ok, image = pcall(ImGui.CreateImageFromMem, M.icon_png_data(name))
      if ok and M.is_valid_image(ImGui, image) then
        cache.images[name] = image
      end
    end
    if M.is_valid_image(ImGui, cache.images[name]) then
      cache.available = true
    end
  end
end

function M.image(ImGui, cache, icon_key)
  local image = cache and cache.images and cache.images[icon_key] or nil
  if M.is_valid_image(ImGui, image) then
    return image
  end
  if cache and cache.images then
    cache.images[icon_key] = nil
    cache.available = false
    cache.loaded = false
  end
  return nil
end

return M
