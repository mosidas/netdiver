# テストの書き方と実行

netdiver のテストは [gdUnit4](https://github.com/godot-gdunit-labs/gdUnit4) で書き、`make test` で実行する。本書はテストスイートの配置・命名・書き方の正本である。

## 実行

```sh
make test                          # tests/ 以下のすべてを実行する
make test TESTS=res://tests/player # 対象を絞る
```

`make test` は次を順に行う。

1. gdUnit4 が未取得なら `scripts/fetch_gdunit4.sh` が取得する(取得済みなら何もしない)
2. `.godot/global_script_class_cache.cfg` が無ければ Godot のインポートで生成する
3. `reports/` を消してから gdUnit4 を起動する
4. レポートに実行されたテストが 1 件も無ければ失敗にする

`addons/gdUnit4/` と `reports/` は生成物であり、リポジトリには含めない。取得する版は `scripts/fetch_gdunit4.sh` の変数 `GDUNIT4_VERSION` ただ 1 箇所で定義する。他のファイル・文書に版の値を書かない。版を上げるときはこの変数を書き換えて `make test` を実行すれば、取得スクリプトが差し替える。

### 必要なもの

| 対象 | 備考 |
| ---- | ---- |
| Godot(エディタ版) | `GODOT_BIN` にパスを設定するか、`godot` を PATH に置く。`--script` と `--import` はエディタ版でのみ使える |
| `timeout` | macOS の標準構成には無い。`brew install coreutils` で入れる |
| `curl`・`unzip` | gdUnit4 の取得に使う |

### 終了コード

`make test` は失敗をすべて終了コード 2 で表す(GNU make はレシピが失敗すると、コマンドの終了コードにかかわらず 2 を返す)。**失敗の原因を終了コードで切り分けたい場合は、`scripts/run_tests.sh` を直接呼ぶ**。

| コード | 意味 |
| -----: | ---- |
| 0 | 1 件以上のテストが実行され、すべて成功した |
| 1 | 実行スクリプト自身のエラー(Godot・`timeout` が無い、取得やインポートの失敗、**テストが 1 件も実行されなかった**) |
| 100 | テストの失敗、またはテスト内の実行時エラー |
| 101 | テストの警告 |
| 105 | テストの探索中にスクリプトエラー(パースエラー等) |
| 124 | 120 秒のタイムアウト |
| 134 | 探索中のスクリプトエラーが正常なテストスイートと混在したときのクラッシュ |

105 は gdUnit4 がプロセスの終了コードへ確実には反映しない(同じ入力で 105 と 0 が混じる)。そのため、テストファイルにパースエラーがある場合の検出は終了コードではなくレポートの件数で行う。壊れたテストスイートだけを対象にすると 1、正常なスイートと混在すると 134 になる。いずれも 0 にはならない。

## 配置と命名

```
tests/
  <実装のディレクトリ構成を写したパス>/
    <対象>_test.gd
```

- テストスイートは `tests/` 以下にのみ置く。実装ファイルと同じディレクトリに置かない
- ファイル名は接尾辞 `_test.gd`。実装 `src/player/player.gd` に対するテストは `tests/player/player_test.gd`
- テストケース名は接頭辞 `test_`

gdUnit4 はファイル名でも配置でも発見範囲を制約しない(コマンドラインに渡したパスを走査する)。この規約を置くのは、実装とテストを分けてエクスポート時の除外を 1 ディレクトリの指定で済ませるためと、エディタ機能「Create Test」が生成する名前(接尾辞 `_test.gd`)と手書きの名前を揃えるためである。

## 書き方

```gdscript
extends GdUnitTestSuite

func before_test() -> void: ...   # 各テストケースの前に実行される
func after_test() -> void: ...    # 各テストケースの後に実行される

func test_<検証する振る舞い>() -> void:
	assert_int(actual).is_equal(expected)
```

- 型注釈付き GDScript で書く
- アサーションは gdUnit4 の `assert_*` 系(`assert_int` / `assert_float` / `assert_str` / `assert_bool` / `assert_array` / `assert_dict` / `assert_object` / `assert_vector` / `assert_signal` 等)を使う。**独自のアサーション関数を定義しない**
- `add_child(node)` したノードは `auto_free(node)` を対にする。gdUnit4 が解放漏れを orphan として報告し、統計行の `orphans` が 0 でなくなる

サンプルは `tests/harness/logic_test.gd`(純粋ロジック)と `tests/harness/scene_test.gd`(シーンツリーと物理フレーム)にある。

### 物理フレームを進めるテスト

待ち時間は `await await_millis(<ミリ秒>)` で作る。ただし**待つだけでは足りない**。

**`move_and_slide()` は物理フレームの中で呼ぶ。** テスト本体のループから呼ぶと、Godot が `get_process_delta_time()`(描画フレームの delta)を使うため変位が定まらない。100 px/s の速度で 3 回呼んだとき、期待する 5.0 px に対して実測で 2.37 px・10.58 px と回ごとに異なった。

検証したいノードに `_physics_process` を持たせ、そこから指定回数だけ呼ばせる。テスト側は `await await_millis()` で完了を待ち、**消化したフレーム数をアサーションで確かめる**(待ち時間が足りずにフレームを消化しなかった場合と、動かないことが正しい場合を区別するため)。`await await_millis()` は経過する物理フレーム数を保証しないので、待ち時間には余裕を取る。

期待値を実数で直接書かず、`速度 / Engine.physics_ticks_per_second * フレーム数` のように算出する。`physics_ticks_per_second` を変えたときにテストが追随する。

### 入力を使わない

**`Input` / `InputEvent` を経由する入力のシミュレーションをテストに書かない。** headless では `InputEvent` がエンジンを通らず、テストが常に成立してしまう。gdUnit4 自身もこの旨を警告する。

入力に依存する振る舞いは、入力の読み取りとロジックを分け、ロジック側を直接呼んで検証する。

## CI

`.github/workflows/test.yml` が pull request と `main` への push で `make test` を実行する。Godot は公式リリースの Linux ビルドを URL 固定でダウンロードする(サードパーティの action を使わない)。テストの成否にかかわらず `reports/` をアーティファクトとして 14 日保存する。
