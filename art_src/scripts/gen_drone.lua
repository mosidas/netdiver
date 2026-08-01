-- Aseprite CLI 検証用: ホバードローン(サイドビュー・32x32・3 フレーム)を生成する。
-- 実行: aseprite -b --script-param out=<path> --script gen_drone.lua

local out = app.params["out"] or "drone.aseprite"

-- netdiver のカラー方針: 実空間はモノトーン、ネット空間はシアン差し色
local C = {
  void = app.pixelColor.rgba(0, 0, 0, 0),
  dark = app.pixelColor.rgba(26, 28, 34, 255),
  body = app.pixelColor.rgba(58, 62, 74, 255),
  lite = app.pixelColor.rgba(104, 110, 128, 255),
  edge = app.pixelColor.rgba(158, 166, 186, 255),
  cyan = app.pixelColor.rgba(94, 234, 255, 255),
  cyanD = app.pixelColor.rgba(38, 132, 168, 255),
}

local sprite = Sprite(32, 32, ColorMode.RGB)
sprite.filename = out

-- 3 フレーム: ホバーの上下動 + アイの明滅
for i = 2, 3 do
  sprite:newEmptyFrame(i)
end
for i = 1, 3 do
  sprite.frames[i].duration = 0.12
end

local function px(img, x, y, c)
  if x >= 0 and x < 32 and y >= 0 and y < 32 then
    img:drawPixel(x, y, c)
  end
end

local function rect(img, x0, y0, x1, y1, c)
  for y = y0, y1 do
    for x = x0, x1 do
      px(img, x, y, c)
    end
  end
end

-- フレームごとに描画(bob = 上下オフセット、glow = アイの明るさ)
local frames = {
  { bob = 0, glow = true },
  { bob = -1, glow = false },
  { bob = 1, glow = true },
}

for i, f in ipairs(frames) do
  local img = Image(32, 32, ColorMode.RGB)
  img:clear(C.void)
  local b = f.bob

  -- 本体(角のとれた台形の筐体)
  rect(img, 9, 11 + b, 22, 18 + b, C.body)
  rect(img, 10, 10 + b, 21, 10 + b, C.lite)
  rect(img, 11, 19 + b, 20, 19 + b, C.dark)
  -- 上面のハイライト
  rect(img, 12, 11 + b, 19, 11 + b, C.lite)
  -- 輪郭(selout: 上側を明るく、下側を暗く)
  for x = 10, 21 do px(img, x, 9 + b, C.edge) end
  for x = 11, 20 do px(img, x, 20 + b, C.dark) end
  for y = 10, 19 do
    px(img, 8, y + b, C.dark)
    px(img, 23, y + b, C.dark)
  end

  -- センサーアイ(シアン)
  local eye = f.glow and C.cyan or C.cyanD
  rect(img, 18, 13 + b, 21, 15 + b, eye)
  px(img, 22, 14 + b, eye)
  if f.glow then
    px(img, 17, 14 + b, C.cyanD)
  end

  -- 側面の放熱フィン
  for k = 0, 2 do
    px(img, 10 + k * 2, 13 + b, C.dark)
    px(img, 10 + k * 2, 14 + b, C.dark)
  end

  -- 下部スラスター(ホバー炎)
  local flame = f.glow and C.cyan or C.cyanD
  rect(img, 12, 21 + b, 13, 22 + b, flame)
  rect(img, 18, 21 + b, 19, 22 + b, flame)
  if f.glow then
    px(img, 12, 23 + b, C.cyanD)
    px(img, 19, 23 + b, C.cyanD)
  end

  -- 上部アンテナ
  px(img, 15, 8 + b, C.edge)
  px(img, 15, 7 + b, C.edge)
  px(img, 15, 6 + b, C.cyan)

  sprite:newCel(sprite.layers[1], i, img, Point(0, 0))
end

-- アニメーションタグ
local tag = sprite:newTag(1, 3)
tag.name = "hover"

sprite:saveAs(out)
print("saved: " .. out .. " frames=" .. #sprite.frames .. " tags=" .. #sprite.tags)
