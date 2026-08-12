# test-harness — 実装タスク

> 仕様の詳細は同じディレクトリの仕様文書 spec.md を参照する。
> このファイルには仕様を転記しない。

## File Structure Plan

| ファイルパス | 区分 | 責務 |
| ------------ | ---- | ---- |
| `scripts/fetch_gdunit4.sh` | 新規 | gdUnit4 をバージョン固定で取得し `addons/gdUnit4/` へ展開する。版の照合と冪等性を担う |
| `scripts/run_tests.sh` | 新規 | 実行の前提を整えて gdUnit4 のコマンドラインツールを呼び、終了コードを確定する |
| `Makefile` | 変更 | `test` ターゲットを追加する。既定ターゲット `all` に依存させない |
| `.gitignore` | 変更 | `addons/gdUnit4/` と `reports/` を無視の対象に加える |
| `tests/harness/logic_test.gd` | 新規 | 純粋ロジックのテストのサンプル |
| `tests/harness/scene_test.gd` | 新規 | ノードをシーンツリーへ載せ物理フレームを進める統合テストのサンプル |
| `.github/workflows/test.yml` | 新規 | ubuntu-latest で Godot 4.7.1 を取得し `make test` を実行する CI |
| `docs/testing.md` | 新規 | テストスイートの配置・命名・アサーション・禁止事項の正本 |

削除対象はない(本単位は既存の置換・廃止を伴わない)。

`addons/gdUnit4/` の中身は取得スクリプトの生成物であり、この計画には載せない。gdUnit4 のコマンドラインツール `addons/gdUnit4/runtest.sh` が展開の対象に含まれることは、v6.2.0 のアーカイブで確認済みである(検証用プロジェクトで実行できた)。

## タスク一覧

- [ ] 1. gdUnit4 の取得
  - [x] 1.1 `scripts/fetch_gdunit4.sh` を新規作成し、版を固定して取得・展開し、`plugin.cfg` の `version` で照合する。既に一致していればダウンロードせず、その旨を標準出力へ出す
    _Requirements: 1.1, 1.2, 1.3, 1.9_
    _Boundary: FetchScript_
    - 対象ファイル: `scripts/fetch_gdunit4.sh`(新規)
    - 仕様参照: spec.md §5.1、§6.1
    - 検証コマンド: `V=$(sed -n 's/^GDUNIT4_VERSION=//p' scripts/fetch_gdunit4.sh | tr -d '"'); rm -rf addons/gdUnit4 && ./scripts/fetch_gdunit4.sh && grep -q "version=\"$V\"" addons/gdUnit4/plugin.cfg && echo OK`(取得と照合)、`./scripts/fetch_gdunit4.sh | grep -q 'skipped' && echo OK`(2 回目はダウンロードしないこと。**標準出力に `skipped` と版を出す**ことをこのタスクの実装内容に含める)
  - [x] 1.2 取得スクリプトの異常系を実装する。必要なコマンドの不足・ダウンロードの失敗・展開後の版の不一致・版が異なる既存ディレクトリの置き換え
    _Requirements: 1.4, 1.5, 1.6, 1.7_
    _Boundary: FetchScript_
    _Depends: 1.1_
    - 対象ファイル: `scripts/fetch_gdunit4.sh`(変更)
    - 仕様参照: spec.md §5.1 のエラー表と「既存ディレクトリの置き換え」
    - 検証コマンド(4 本。**bash で実行する**。異常系ごとに 1 本ずつ。spec.md §5.1 は取得スクリプトの入力を「なし」と定めているため、検証用の環境変数を実装に足さず、スクリプトを一時的に書き換えて異常系を起こし、確認後に復元する):
      - 1.4: `V=$(sed -n 's/^GDUNIT4_VERSION=//p' scripts/fetch_gdunit4.sh | tr -d '"'); sed -i.bak 's/^version=.*/version="0.0.0"/' addons/gdUnit4/plugin.cfg; ./scripts/fetch_gdunit4.sh; grep -q "version=\"$V\"" addons/gdUnit4/plugin.cfg && echo OK`(版が異なる既存ディレクトリが期待する版へ置き換わること)
      - 1.5: `cp scripts/fetch_gdunit4.sh /tmp/f.orig; sed -i.bak 's|v${GDUNIT4_VERSION}|v6.1.3|' scripts/fetch_gdunit4.sh; rm -rf addons/gdUnit4; ./scripts/fetch_gdunit4.sh 2>/tmp/e.txt; rc=$?; cp /tmp/f.orig scripts/fetch_gdunit4.sh; grep -q '6.1.3' /tmp/e.txt && grep -q "$(sed -n 's/^GDUNIT4_VERSION=//p' scripts/fetch_gdunit4.sh | tr -d '\"')" /tmp/e.txt && test $rc -eq 1 && echo OK`(URL のタグだけを別の実在する版へ変え、ダウンロードは成功するが照合に失敗する状態を作る。期待した版と実際の版の両方が標準エラーに出て、終了コードが 1 になること。URL の組み立て方は実装に合わせて sed のパターンを調整する)
      - 1.6: `E=$(mktemp -d); PATH=$E ./scripts/fetch_gdunit4.sh 2>/tmp/e.txt; rc=$?; grep -q 'curl\|unzip' /tmp/e.txt && test $rc -eq 1 && echo OK`(実在コマンドを含まない PATH で実行し、不足しているコマンド名が標準エラーに出て終了コードが 1 になること)
      - 1.7: `cp scripts/fetch_gdunit4.sh /tmp/f.orig; sed -i.bak 's/^GDUNIT4_VERSION=.*/GDUNIT4_VERSION="99.99.99"/' scripts/fetch_gdunit4.sh; ./scripts/fetch_gdunit4.sh 2>/tmp/e.txt; rc=$?; cp /tmp/f.orig scripts/fetch_gdunit4.sh; grep -q 'http' /tmp/e.txt && grep -qE '(^|[^0-9])(4[0-9]{2}|5[0-9]{2})([^0-9]|$)' /tmp/e.txt && test $rc -eq 1 && echo OK`(存在しないタグでダウンロードを失敗させ、URL と **HTTP ステータスの数値**の両方が標準エラーに出て、終了コードが 1 になること。`http` の一致だけでは URL 自体に一致してしまうため、ステータスコードを別条件で検査する)
      - **後始末(4 本すべての実行後に必ず行う)**: `V=$(sed -n 's/^GDUNIT4_VERSION=//p' scripts/fetch_gdunit4.sh | tr -d '"'); rm -f addons/gdUnit4/plugin.cfg.bak scripts/fetch_gdunit4.sh.bak /tmp/f.orig /tmp/e.txt; ./scripts/fetch_gdunit4.sh && grep -q "version=\"$V\"" addons/gdUnit4/plugin.cfg && echo RESTORED`。1.5 と 1.7 の手順は `addons/gdUnit4/` を削除した状態で終わるため、復元しないと後続のタスク 2.1・2.2 の検証コマンドが失敗する。`sed -i.bak` を使うのは、`sed -i ''` が BSD sed(macOS)専用で GNU sed では失敗するためである
      - 本サブタスクは `addons/gdUnit4/` を一時的に壊すため、タスク 2.1・2.2 と**同時に実行しない**((P) を付けない理由)
  - [x] 1.3 (P) `.gitignore` に `addons/gdUnit4/` と `reports/` を追加する。`project.godot` の `editor_plugins` は変更しない
    _Requirements: 1.8, 9.1, 9.2_
    _Boundary: RepoConfig_
    _Depends: 1.1_
    - 対象ファイル: `.gitignore`(変更)
    - 仕様参照: spec.md §6.4、§5.1「プロジェクト設定への影響」
    - 検証コマンド: `test -d addons/gdUnit4 && { git status --porcelain | grep -q 'addons/gdUnit4' && echo NG || echo OK; } || echo "SKIP: addons/gdUnit4 が無い状態では判定できない"`(取得済みであることを前提として明示する)、`grep -c gdUnit4 project.godot`(0 であること)、`git check-ignore -q addons/AsepriteWizard/plugin.cfg && echo NG || echo OK`

- [ ] 2. サンプルのテストスイート
  - [x] 2.1 (P) `tests/harness/logic_test.gd` を新規作成し、純粋ロジックを検証するテストケースを置く
    _Requirements: 5.2, 5.4_
    _Boundary: SampleTests_
    _Depends: 1.1_
    - 対象ファイル: `tests/harness/logic_test.gd`(新規)
    - 仕様参照: spec.md §5.4、§6.2
    - 検証コマンド: `GODOT_BIN=$(command -v godot) ./addons/gdUnit4/runtest.sh --headless --ignoreHeadlessMode --continue -a res://tests | grep -q 'logic_test.gd' && echo OK`(ファイル名の接尾辞で発見されること)
  - [x] 2.2 (P) `tests/harness/scene_test.gd` を新規作成し、ノードをシーンツリーへ載せて物理フレームを進める統合テストを置く。`auto_free` で解放し orphan を出さない
    _Requirements: 5.3_
    _Boundary: SampleTests_
    _Depends: 1.1_
    - 対象ファイル: `tests/harness/scene_test.gd`(新規)
    - 仕様参照: spec.md §5.4「ノードの後始末」「物理フレームの進行」
    - 検証コマンド: `GODOT_BIN=$(command -v godot) ./addons/gdUnit4/runtest.sh --headless --ignoreHeadlessMode --continue -a res://tests | tee /tmp/o.txt | grep -q 'scene_test.gd'; grep -q '0 orphans' /tmp/o.txt && echo OK`(統計行の `0 orphans` は gdUnit4 v6.2.0 の出力で確認済みの表記。書式が変わっていた場合は統計行の orphans の値が 0 であることを読み替えて判定する)

- [ ] 3. 実行スクリプトの前提整備
  - [x] 3.1 `scripts/run_tests.sh` を新規作成し、Godot の解決と `timeout` の解決を**それぞれ独立した異常系**として実装する。どちらか一方が欠けても標準エラーへ出力して終了コード 1 で終わる。`timeout` の不在時は入手方法(Homebrew の `coreutils`)も出す
    _Requirements: 3.4, 3.6_
    _Boundary: RunScript_
    _Depends: 1.1_
    - 対象ファイル: `scripts/run_tests.sh`(新規)
    - 仕様参照: spec.md §5.2 の事前条件とエラー表
    - 検証コマンド(2 本。**bash で実行する**。異常系ごとに 1 本ずつ):
      - 3.4(Godot だけが無い): `D=$(mktemp -d); ln -s "$(command -v timeout)" "$D/timeout"; env -u GODOT_BIN PATH="$D:/usr/bin:/bin" ./scripts/run_tests.sh; test $? -eq 1 && echo OK`
      - 3.6(`timeout` だけが無い): `D=$(mktemp -d); ln -s "$(command -v godot)" "$D/godot"; PATH="$D:/usr/bin:/bin" ./scripts/run_tests.sh 2>/tmp/e.txt; rc=$?; grep -q coreutils /tmp/e.txt && test $rc -eq 1 && echo OK`
  - [x] 3.2 実行スクリプトが取得スクリプトを毎回呼ぶようにする
    _Requirements: 2.5_
    _Boundary: RunScript_
    _Depends: 3.1_
    - 対象ファイル: `scripts/run_tests.sh`(変更)
    - 仕様参照: spec.md §5.2 副作用 1
    - 検証コマンド(2 本): `rm -rf addons/gdUnit4 && ./scripts/run_tests.sh; test -f addons/gdUnit4/plugin.cfg && echo OK`(未取得の状態から取得されること)、`./scripts/run_tests.sh | grep -q 'skipped' && echo OK`(取得済みの状態でも取得スクリプトが呼ばれ、1.1 が定めた `skipped` の出力が現れること。条件付きで呼ぶ実装はこの 2 本目を通らない)
  - [x] 3.3 クラスキャッシュが無ければ `--headless --import` で生成する。生成に失敗したらテストを実行せず終了コード 1 で終わる
    _Requirements: 3.1, 3.5_
    _Boundary: RunScript_
    _Depends: 3.1_
    - 対象ファイル: `scripts/run_tests.sh`(変更)
    - 仕様参照: spec.md §5.2 副作用 2
    - 検証コマンド(2 本):
      - 3.1: `rm -rf .godot && ./scripts/run_tests.sh; test -f .godot/global_script_class_cache.cfg && echo OK`
      - 3.5: `rm -rf .godot && D=$(mktemp -d); printf '#!/bin/sh\nexit 1\n' > "$D/godot"; chmod +x "$D/godot"; GODOT_BIN="$D/godot" ./scripts/run_tests.sh; test $? -eq 1 && echo OK`(インポートを失敗させ、テストを実行せず 1 で終わること。`reports/` が作られていないことも `test ! -d reports` で確認する)
  - [x] 3.4 実行スクリプトが第 1 引数でテストのパスを受け取り、省略時は `res://tests` を使うようにする。**解決したパスを標準出力へ 1 行出す**(この時点では gdUnit4 の起動が未実装のため、判定の材料をこの出力に置く)
    _Requirements: 2.2_
    _Boundary: RunScript_
    _Depends: 3.1_
    - 対象ファイル: `scripts/run_tests.sh`(変更)
    - 仕様参照: spec.md §5.2 の定義と入力
    - 検証コマンド: `./scripts/run_tests.sh res://tests/harness | grep -q 'res://tests/harness' && echo OK`(引数を渡した場合)、`./scripts/run_tests.sh | grep -q 'res://tests$' && echo OK`(省略した場合の既定値)

- [ ] 4. 実行スクリプトのテスト実行と終了コードの確定
  - [x] 4.1 gdUnit4 の実行前に `reports/` を削除し、`--headless --ignoreHeadlessMode --continue -rd res://reports` を付けて起動する。レポートが出力されることを確認する
    _Requirements: 3.2, 3.3, 7.1, 7.5_
    _Boundary: RunScript_
    _Depends: 3.3, 3.4, 2.1_
    - 対象ファイル: `scripts/run_tests.sh`(変更)
    - 仕様参照: spec.md §5.2 副作用 3・4
    - 検証コマンド: `mkdir -p reports/report_99 && touch reports/report_99/stale && ./scripts/run_tests.sh; test ! -e reports/report_99/stale && ls reports/report_*/results.xml reports/report_*/index.html && echo OK`(実行前に削除されることと、レポートが出力されること)
  - [x] 4.2 gdUnit4 の終了コードが 0 以外のときは件数判定を行わず、その値をそのまま返す。全成功のときは 0 を返す
    _Requirements: 4.1, 4.3, 4.4, 4.5_
    _Boundary: RunScript_
    _Depends: 4.1_
    - 対象ファイル: `scripts/run_tests.sh`(変更)
    - 仕様参照: spec.md §5.2 のエラー表、§7 Requirement 4
    - 検証コマンド(2 本): `./scripts/run_tests.sh; test $? -eq 0 && echo OK`(全成功)、`printf 'extends GdUnitTestSuite\n\nfunc test_fail() -> void:\n\tassert_int(1).is_equal(2)\n' > tests/harness/tmp_fail_test.gd; ./scripts/run_tests.sh; test $? -eq 100 && echo OK; rm tests/harness/tmp_fail_test.gd`(失敗の透過)
  - [x] 4.3 gdUnit4 が 0 を返した場合に限り、連番が最大の `results.xml` の `testcase` 件数を数え、`results.xml` が無いか 0 件なら標準エラーへ出力して終了コード 1 を返す
    _Requirements: 4.2, 4.6_
    _Boundary: RunScript_
    _Depends: 4.2_
    - 対象ファイル: `scripts/run_tests.sh`(変更)
    - 仕様参照: spec.md §5.2 副作用 5・6、§8 の経路の表
    - 検証コマンド(2 本):
      - 4.2(0 件): `./scripts/run_tests.sh res://tests/does_not_exist; test $? -eq 1 && echo OK`
      - 4.6(パースエラーのみ): `mkdir -p tests/tmp_broken && printf 'extends GdUnitTestSuite\n\nfunc test_x() -> void:\n\tthis is not valid\n' > tests/tmp_broken/broken_test.gd; ng=0; for i in 1 2 3; do ./scripts/run_tests.sh res://tests/tmp_broken; test $? -eq 0 && ng=1; done; rm -r tests/tmp_broken; test $ng -eq 0 && echo OK`(3 回とも 0 以外であること。spec.md §3 のとおり終了コードは 1 と 105 に割れるため、0 が出ないことを条件にする)
  - [x] 4.4 実行全体を 120 秒のタイムアウトで包み、超過時に終了コード 124 を返す。秒数はスクリプト内の定数 `TIMEOUT_SECONDS` に置く(spec.md §5.2 は実行スクリプトの入力を第 1 引数のみと定めているため、上書き用の環境変数を設けない)
    _Requirements: 8.1, 8.2_
    _Boundary: RunScript_
    _Depends: 4.3_
    - 対象ファイル: `scripts/run_tests.sh`(変更)
    - 仕様参照: spec.md §5.2 副作用 7、§7 Requirement 8
    - 検証コマンド(**bash で実行する**): `grep -q '^TIMEOUT_SECONDS=120$' scripts/run_tests.sh && echo OK`(既定値)、`cp scripts/run_tests.sh /tmp/r.orig; sed -i.bak 's/^TIMEOUT_SECONDS=120$/TIMEOUT_SECONDS=1/' scripts/run_tests.sh; ./scripts/run_tests.sh; rc=$?; cp /tmp/r.orig scripts/run_tests.sh; rm -f /tmp/r.orig scripts/run_tests.sh.bak; test $rc -eq 124 && echo OK`(定数を一時的に 1 秒へ下げて超過させ、確認後に復元する。`sed -i ''` は BSD sed 専用のため `sed -i.bak` を使う)

- [ ] 5. `make test` の入口
  - [ ] 5.1 `Makefile` に `test` ターゲットを追加する。`TESTS` 変数で対象を切り替え、終了コードをそのまま伝え、既定ターゲット `all` に依存させない。版の値を書かない
    _Requirements: 1.1, 2.1, 2.2, 2.3, 2.4, 2.6_
    _Boundary: Makefile_
    _Depends: 4.4_
    - 対象ファイル: `Makefile`(変更)
    - 仕様参照: spec.md §5.3、§6.1「不変条件」
    - 検証コマンド: `make test && echo OK`(2.1 と 2.3 の成功経路)、`make test TESTS=res://tests/harness | grep -q 'res://tests/harness' && echo OK`(2.2。`TESTS` を無視する `Makefile` は 3.4 が出力する解決済みのパスが一致しないため通らない)、`make -n test | grep -qi aseprite && echo NG || echo OK`(2.4)、`V=$(sed -n 's/^GDUNIT4_VERSION=//p' scripts/fetch_gdunit4.sh | tr -d '"'); grep -c "$V" Makefile`(1.1。0 であること)、`make test TESTS=res://tests/does_not_exist; test $? -ne 0 && echo OK`(2.3 の失敗経路。GNU make はレシピの失敗を終了コード 2 へ丸めるため、値ではなく 0 以外であることを判定する)
  - [x] 5.2 クラスキャッシュと gdUnit4 が取得済みの状態で `make test` が 30 秒以内に終わることを計測する
    _Requirements: 8.3_
    _Boundary: Makefile_
    _Depends: 5.1_
    - 対象ファイル: `Makefile`(変更なし。計測のみ)
    - 仕様参照: spec.md §7 Requirement 8.3
    - 検証コマンド: `time make test`(real が 30 秒以下であること)

- [ ] 6. CI ワークフロー
  - [ ] 6.1 `.github/workflows/test.yml` を新規作成する。`pull_request` と `main` への `push` で起動し、Godot 4.7.1 の Linux ビルドを URL 固定で取得して `make test` を実行する。Godot の取得はテスト実行とは別のステップに分ける。版の値を書かない
    _Requirements: 1.1, 6.1, 6.2, 6.3, 6.4, 6.5, 6.6_
    _Boundary: CI_
    _Depends: 5.1_
    - 対象ファイル: `.github/workflows/test.yml`(新規)
    - 仕様参照: spec.md §5.5
    - 検証コマンド(**YAML パーサを使わない**。本開発環境には PyYAML も ruby の psych も無く、端末に依存を増やさない方針のため。YAML の構文は GitHub 側の実行で検証される):
      - 6.1・6.2(起動条件): `awk '/^on:/{f=1;next} /^[a-z]/{f=0} f' .github/workflows/test.yml > /tmp/on.txt; grep -q '^  pull_request:$' /tmp/on.txt && grep -q '^      - main$' /tmp/on.txt && echo OK`(`on:` ブロックの中だけを取り出して照合する)
      - 6.3(URL 固定): `grep -q 'https://github.com/godotengine/godot/releases/download/4.7.1-stable/Godot_v4.7.1-stable_linux.x86_64.zip' .github/workflows/test.yml && echo OK`(URL の正本は spec.md §5.5)
      - 6.4(サードパーティ action の不使用): `grep -qiE '^[[:space:]]*(- )?uses:.*godot' .github/workflows/test.yml && echo NG || echo OK`
      - 1.1(版の値を書かない): `V=$(sed -n 's/^GDUNIT4_VERSION=//p' scripts/fetch_gdunit4.sh | tr -d '"'); grep -c "$V" .github/workflows/test.yml`(0 であること)
      - 6.5: 意図的に失敗するテストを 1 件足した状態で push し、`gh pr checks` が失敗することを確認してから戻す
      - 6.6: Godot の取得 URL を一時的に存在しない値へ変えて push し、失敗するステップが取得のステップであることを `gh run view --log-failed` で確認してから戻す
  - [ ] 6.2 `reports/` をアーティファクトとしてアップロードする。保存期間を 14 日とし、テストの成否とレポートの有無にかかわらずこのステップでジョブを失敗させない
    _Requirements: 7.2, 7.3, 7.4_
    _Boundary: CI_
    _Depends: 6.1_
    - 対象ファイル: `.github/workflows/test.yml`(変更)
    - 仕様参照: spec.md §5.5「成果物」、§7 Requirement 7
    - 検証コマンド(**YAML パーサを使わない**。理由はタスク 6.1 と同じ):
      - 7.2・7.3: `test "$(grep -c 'uses: actions/upload-artifact' .github/workflows/test.yml)" -eq 1 && grep -q '^          retention-days: 14$' .github/workflows/test.yml && grep -q 'if: always()' .github/workflows/test.yml && echo OK`(アップロードのステップが 1 つあり、保存期間の値が 14 で、成否によらず実行されること)、push 後に `gh run view --log` でアップロードのステップが成功していることを確認する
      - 7.4: 存在しないテストパスを指定して `make test` を失敗させ(`reports/` が生成されない状態)、push してアップロードのステップがジョブを失敗させないことを `gh run view --log` で確認してから戻す

- [ ] 7. ドキュメント反映
  - [x] 7.1 `docs/testing.md` を新規作成し、テストスイートの配置・命名・アサーション・後始末・禁止事項を記す。gdUnit4 の版の値は書かない
    _Requirements: 1.1, 5.1_
    _Boundary: Docs_
    _Depends: 2.2, 5.1_
    - 対象ファイル: `docs/testing.md`(新規)
    - 仕様参照: spec.md §5.4、§6.1「不変条件」、§6.2
    - 検証コマンド: `ng=0; for w in 'tests/' '_test.gd' 'test_' 'assert_' 'auto_free' 'await_millis' 'InputEvent'; do grep -q "$w" docs/testing.md || { echo "NG: $w"; ng=1; }; done; test $ng -eq 0 && echo OK`(配置・命名・アサーション・後始末・物理フレーム・禁止事項の記載があること)、`V=$(sed -n 's/^GDUNIT4_VERSION=//p' scripts/fetch_gdunit4.sh | tr -d '"'); grep -c "$V" docs/testing.md`(0 であること)

## Implementation Notes

(このセクションは dev-implement が実装中の学習・選択した知識 port・横断的な気付き・レビューを通過した境界外変更の申告を追記する領域)

- 知識 port: `docs/dev/ports` が存在しないため、注入なしで進める。
- 取得スクリプトの構造(タスク 1.1): 版は `GDUNIT4_VERSION` の 1 箇所、URL は `v${GDUNIT4_VERSION}` で組み立てる。展開後の版は `installed_version()` が `plugin.cfg` から読む。`main()` は「版が一致 → skip」「既存ディレクトリあり → 停止(タスク 1.2 で削除・再取得へ置き換える)」「それ以外 → `fetch_and_install`」の 3 分岐。
- v6.2.0 のソースアーカイブは `runtest.sh` の実行ビットを保持するが、展開側の umask や unzip の実装に依存させないため `chmod +x` を `mv` の前に行う(失敗時に中途半端な `addons/gdUnit4` を残さない)。
- タスク 1.2 の検証 1.5 が使う `sed 's|v${GDUNIT4_VERSION}|v6.1.3|'` は `GDUNIT4_ARCHIVE_URL` の行に一致する。
- タスク 1.2 で要件 1.6 を実装するとき、検証コマンドが `PATH=$(mktemp -d)` で実行するため `sed`・`head`・`mktemp` も使えない状態になる。`command -v` と `printf` は bash の組み込みなので、必要コマンドの事前確認を `main()` の先頭(`installed_version` の呼び出しより前)に置く。
- `shellcheck` は本環境に未導入。導入せずに進める(`bash -n` の構文検査で代替)。
- **シバンは `#!/bin/bash`**(タスク 1.2)。`#!/usr/bin/env bash` にすると、PATH を空にした状態でスクリプト自体が起動できず(`env: bash: No such file or directory`、rc=127)、「不足しているコマンドを報告する」振る舞いを観測できない。副作用として macOS の既定 bash 3.2 で動くため、連想配列・`mapfile`・`${var^^}` 等の bash 4 以降の機能を使わない。`scripts/run_tests.sh` も同じ制約に合わせる。
- 取得スクリプトは `curl`・`unzip` 以外の外部コマンドに依存しないよう、`plugin.cfg` の読み取りを bash 組み込みのパーサ `plugin_cfg_value()` で行い、`dirname` の代わりに `${BASH_SOURCE[0]%/*}` を使う(`dirname` が無いと `REPO_ROOT` がファイルシステムの根へ潰れる)。
- 既存 `addons/gdUnit4/` の削除は、ダウンロードと版の照合が終わった後・`mv` の直前に行う。先に消すと、版を上げた直後にネットワークが不通のとき旧版を失ったうえで取得にも失敗する。`mv` が失敗した場合は部分的な配置をその場で削除する。
- **`move_and_slide()` は物理フレームの中で呼ぶ**(タスク 2.2 で判明)。テスト本体のループから呼ぶと、Godot が `get_process_delta_time()`(描画フレームの delta)を使うため変位が定まらない(100 px/s・3 回の呼び出しで 5.0 px にならず、実測で 2.37 px・10.58 px と回ごとに異なった)。ノードに `_physics_process` から指定回数だけ `move_and_slide()` を呼ばせ、テスト側は `await await_millis()` で完了を待って、消化したフレーム数をアサーションで確かめる。spec.md §5.4 の「物理フレームの進行: `await await_millis()` で待つ」だけでは移動の検証に足りない。`docs/testing.md`(タスク 7.1)にこの補足を書く。
- `gdUnit4` を取得する前に生成した `.godot/global_script_class_cache.cfg` には `GdUnitTestSuite` 等が登録されていない。取得の後に `godot --headless --import --path .` を実行し直さないと、テストの探索がパースエラーになる。`scripts/run_tests.sh`(タスク 3.3)はキャッシュの有無だけを見るため、この順序の問題を踏まないよう取得の後にインポートする。
- **タイムアウトで包む範囲**(タスク 4.4): gdUnit4 の起動だけを包み、取得とインポートは含めない。124 が「テストが終わらない」以外(ネットワークの遅さ・初回インポートの所要時間)でも出ると原因を切り分けられず、要件 8.3 の計測が取得済み・キャッシュ済みの状態を前提にしていることとも合わないため。spec.md §5.2 副作用 7 の「全体を 120 秒のタイムアウトで包む」はスクリプト全体とも読めるため、文言の擦り合わせが要る(実装後の報告事項)。
- **`--godot_binary` には絶対パスを渡す**(タスク 4.1)。`addons/gdUnit4/runtest.sh` は `[ ! -f "$godot_binary" ]` で実行ファイルの存在を確かめるため、`godot` のままでは `does not exist` で止まる。`GODOT_BIN` 経由でも同じ検査を通る。
- **正常なスイートとパースエラーのスイートが混在する経路**は 3 回とも終了コード 134 でレポートが出力される(spec.md §3・§8 の記述どおり)。件数判定では検出できず、0 以外の透過で失敗になる。パースエラーのみの経路は 1・1・105 と割れた(0 は出ない)。
- **tasks.md タスク 2.2 の検証コマンドの不備**: `... | tee /tmp/o.txt | grep -q 'scene_test.gd'; grep -q '0 orphans' /tmp/o.txt` は、`grep -q` が最初の一致で終了して `tee` が SIGPIPE で死ぬため `/tmp/o.txt` が途中で切れ、2 本目の判定が偽陰性になる。判定には出力をファイルへリダイレクトしてから grep する形(`... > /tmp/o.txt 2>&1; grep -q ... /tmp/o.txt`)を使った。同じ形の検証コマンドが他タスクにもあるため、パイプで `grep -q` に渡す判定は同じ置き換えを行う。
