# netdiver

巨大構造物を舞台にしたサイドビューの 2D アクションシューティング。徒歩でステージを踏破してボスを倒し、開いたポータルからネット空間へダイブして次の階層へ抜ける。

企画書と作業記録は workspace リポジトリの `1_issues/netdiver/` にある。

## 動作環境

- Godot 4.7
- Aseprite 1.3(アセットを編集・再生成する場合のみ。生成済みのスプライトはコミットしてあるため、クローン直後でもゲームは動く)

## 画面仕様

ピクセルアートの基準を次のとおり固定する。3 つは相互に拘束し合うため、変更するときはまとめて見直す。

| 項目 | 値 |
| :-- | :-- |
| 基準解像度 | 320x180 |
| タイル | 16x16 |
| キャラクター高 | 24〜32px |

`project.godot` では stretch mode を `viewport`、scale mode を `integer`、テクスチャフィルタを Nearest に設定している。整数倍スケーリングにより 1080p・1440p・4K すべてに端数なしで拡大される。

## ディレクトリ

```
art_src/          元データ(ゲーム本体が参照しない編集用の素材)
  raw/            生成 AI の生出力。加工前の記録として残す
  scripts/        Aseprite Lua スクリプトと変換スクリプト
  *.aseprite      スプライトの元データ
assets/
  sprites/        Makefile が生成する PNG・JSON・SpriteFrames(コミットする)
  tilesets/       タイルセットのテクスチャ
addons/
  AsepriteWizard/ .aseprite を Godot へ取り込むアドオン(MIT)
```

## アセットのビルド

`art_src/*.aseprite` から、スプライトシート PNG・フレーム情報 JSON・Godot の SpriteFrames を生成する。

```sh
make          # 生成する
make clean    # 生成物を削除する
```

Aseprite の場所が違う環境では `make ASEPRITE=/path/to/aseprite` で上書きする。

生成物(`assets/sprites/`)はコミットする。Aseprite は有償ソフトのため、これをコミットしておけばクローン直後や CI でもゲームが動く。

## アセット制作のワークフロー

素材の性質で 3 つの経路を使い分ける。いずれも最後は `make` で Godot 用のリソースに変換する。

1. 生成 AI(Retro Diffusion): キャラクター・敵・アニメーション・タイルセット。MCP 経由で生成し、生出力を `art_src/raw/` に置く。グリッドの揃った真のドット絵が直接得られるため、グリッド復元の後処理は不要。
2. スクリプト描画(Aseprite Lua): 幾何学的な素材(UI・エフェクト・回路パターン)。`art_src/scripts/gen_*.lua` に描画コードを書き、`aseprite -b --script` で生成する。修正をコード差分で管理できる。
3. 手描き(Aseprite GUI): 上記の仕上げと細部の修正。

生成 AI の出力がグリッド状のスプライトシート(2x2 等)の場合は、`sheet_to_aseprite.lua` でフレームとタグを持つ `.aseprite` に変換する。

```sh
ASE="/path/to/aseprite"
"$ASE" -b \
  --script-param sheet=art_src/raw/enemy_drone_idle_sheet.png \
  --script-param out=art_src/enemy_drone.aseprite \
  --script-param fw=32 --script-param fh=32 \
  --script-param tag=idle --script-param duration=120 \
  --script art_src/scripts/sheet_to_aseprite.lua
```

## Aseprite Wizard(任意)

`.aseprite` をエディタ上で直接 SpriteFrames として扱うためのアドオン。使う場合は、エディタ設定 `aseprite/general/command_path` に Aseprite の実行ファイルのパスを設定する(この設定は端末ごとの設定でリポジトリには含まれない)。既定値は `/Applications/Aseprite.app/Contents/MacOS/aseprite` のため、Steam 版などパスが違う場合は必ず変更する。

ゲーム本体は `assets/sprites/` の生成物を参照するため、このアドオンを使わなくても動作する。

## 動作確認

`main.tscn` は、基準解像度でスプライトとタイルセットを並べて表示する確認用のシーンである。次のコマンドでビューポートを PNG に保存して終了する。

```sh
godot -- /path/to/screenshot.png
```
