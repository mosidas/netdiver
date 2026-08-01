# アセットパイプライン

## 1. この文書の範囲

ピクセルアートの素材を作り、Godot で使える形へ変換するまでの手順を定める。扱うのは、素材の元データの置き場所、Aseprite からの書き出し、生成 AI の出力の取り込み、Godot 側の画面設定である。ゲームの内容やレベルデザインは扱わない。

## 2. 前提とするツール

- Godot 4.7
- Aseprite 1.3。素材を編集・再生成する場合にのみ必要になる。書き出し済みのスプライトは `assets/` にコミットしてあるため、Aseprite がない環境でもゲームは動く。
- Python 3。Aseprite の書き出し結果を Godot のリソースへ変換するスクリプトで使う。

## 3. 画面の基準値

`project.godot` は次の値を設定している。3 つは相互に拘束し合うため、変更するときはまとめて見直す。

| 項目 | 値 |
| :-- | :-- |
| 基準解像度 | 320x180 |
| タイル | 16x16 |
| キャラクター高 | 24〜32px |

拡大方法は stretch mode を `viewport`、scale mode を `integer` にしている。整数倍でのみ拡大するため、1080p・1440p・4K のいずれでもピクセルが不均一に太らない。テクスチャフィルタは Nearest(`rendering/textures/canvas_textures/default_texture_filter=0`)、2D 変換のピクセルスナップは有効にしている。

## 4. ディレクトリ構成

```
art_src/          元データ。ゲーム本体は参照しない
  raw/            生成 AI の生出力。加工前の記録として残す
  scripts/        Aseprite Lua スクリプトと変換スクリプト
  *.aseprite      スプライトの元データ
assets/
  sprites/        Makefile が生成する PNG・JSON・SpriteFrames
  tilesets/       タイルセットのテクスチャ
addons/
  AsepriteWizard/ .aseprite を Godot へ取り込むアドオン(MIT)
```

`assets/` の生成物はコミットする。Aseprite は有償ソフトであり、生成物をコミットしておけばクローン直後や CI でもゲームが動く。

## 5. アセットのビルド

`art_src/*.aseprite` から、スプライトシート PNG・フレーム情報 JSON・Godot の SpriteFrames(`.tres`)を生成する。

```sh
make          # 生成する
make clean    # 生成物を削除する
```

Aseprite の場所が違う環境では `make ASEPRITE=/path/to/aseprite` で上書きする。

Makefile が実行する Aseprite CLI には `--list-tags` を付けている。これがないと書き出す JSON に `frameTags` が入らず、タグをアニメーション名に使えない。

## 6. 素材の作り方

素材の性質で 3 つの経路を使い分ける。いずれも最後は `make` で Godot 用のリソースに変換する。

1. 生成 AI(Retro Diffusion): キャラクター・敵・アニメーション・タイルセット。生出力を `art_src/raw/` に置く。指定した寸法どおりのピクセルグリッドで、アルファも 0 と 255 の 2 値で返るため、グリッドを復元する後処理は要らない。
2. スクリプト描画(Aseprite Lua): 幾何学的な素材(UI・エフェクト・回路パターン)。`art_src/scripts/gen_*.lua` に描画コードを書き、`aseprite -b --script` で生成する。修正をコード差分で管理できる。
3. 手描き(Aseprite GUI): 上記の仕上げと細部の修正。

## 7. グリッド状スプライトシートの取り込み

生成 AI がアニメーションを 2x2 などのグリッドで返した場合は、`sheet_to_aseprite.lua` でフレームとタグを持つ `.aseprite` に変換する。

```sh
ASE="/path/to/aseprite"
"$ASE" -b \
  --script-param sheet=art_src/raw/enemy_drone_idle_sheet.png \
  --script-param out=art_src/enemy_drone.aseprite \
  --script-param fw=32 --script-param fh=32 \
  --script-param tag=idle --script-param duration=120 \
  --script art_src/scripts/sheet_to_aseprite.lua
```

## 8. Aseprite Wizard

`.aseprite` をエディタ上で直接 SpriteFrames として扱うためのアドオン。使う場合は、エディタ設定 `aseprite/general/command_path` に Aseprite の実行ファイルのパスを設定する。この設定は端末ごとの設定でリポジトリには含まれない。既定値は `/Applications/Aseprite.app/Contents/MacOS/aseprite` のため、Steam 版などパスが違う場合は必ず変更する。

このアドオンが生成する SpriteFrames は `.godot/imported/` に置かれ、リポジトリには入らない。ゲーム本体は `assets/sprites/` の生成物を参照するため、アドオンを使わなくても動作する。

## 9. 表示の確認

`main.tscn` は、基準解像度でスプライトとタイルセットを並べて表示する確認用のシーンである。次のコマンドでビューポートを PNG に保存して終了する。

```sh
godot -- /path/to/screenshot.png
```
