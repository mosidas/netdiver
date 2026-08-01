-- グリッド状のスプライトシート PNG を、フレームとタグを持つ .aseprite に変換する。
-- Retro Diffusion が返す 2x2 等のグリッドシートを Aseprite の元データに取り込むために使う。
--
-- 実行例:
--   aseprite -b \
--     --script-param sheet=in.png --script-param out=out.aseprite \
--     --script-param fw=32 --script-param fh=32 \
--     --script-param tag=idle --script-param duration=120 \
--     --script sheet_to_aseprite.lua

local p = app.params
local sheetPath = p["sheet"]
local outPath = p["out"]
local fw = tonumber(p["fw"])
local fh = tonumber(p["fh"])
local tagName = p["tag"] or "default"
local durationMs = tonumber(p["duration"]) or 100

if not sheetPath or not outPath or not fw or not fh then
  error("required params: sheet, out, fw, fh")
end

local sheet = Image { fromFile = sheetPath }
if not sheet then
  error("could not read sheet: " .. sheetPath)
end

local cols = math.floor(sheet.width / fw)
local rows = math.floor(sheet.height / fh)
local count = cols * rows
if count < 1 then
  error("frame size larger than sheet")
end

local sprite = Sprite(fw, fh, ColorMode.RGB)
sprite.filename = outPath
for i = 2, count do
  sprite:newEmptyFrame(i)
end

for i = 0, count - 1 do
  local sx = (i % cols) * fw
  local sy = math.floor(i / cols) * fh
  local img = Image(fw, fh, ColorMode.RGB)
  for y = 0, fh - 1 do
    for x = 0, fw - 1 do
      img:drawPixel(x, y, sheet:getPixel(sx + x, sy + y))
    end
  end
  sprite:newCel(sprite.layers[1], i + 1, img, Point(0, 0))
  sprite.frames[i + 1].duration = durationMs / 1000
end

local tag = sprite:newTag(1, count)
tag.name = tagName

sprite:saveAs(outPath)
print(string.format("saved: %s frames=%d grid=%dx%d tag=%s", outPath, count, cols, rows, tagName))
