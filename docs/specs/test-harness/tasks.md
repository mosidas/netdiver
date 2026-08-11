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

## タスク一覧

- [ ] 1. gdUnit4 の取得
  - [ ] 1.1 `scripts/fetch_gdunit4.sh` を新規作成し、版を固定して取得・展開し、`plugin.cfg` の `version` で照合する。既に一致していればダウンロードしない
    _Requirements: 1.1, 1.2, 1.3, 1.9_
    _Boundary: FetchScript_
    - 対象ファイル: `scripts/fetch_gdunit4.sh`(新規)
    - 仕様参照: spec.md §5.1、§6.1
    - 検証コマンド: `rm -rf addons/gdUnit4 && ./scripts/fetch_gdunit4.sh && grep -q 'version="6.2.0"' addons/gdUnit4/plugin.cfg && echo OK`(2 回目の実行でダウンロードが走らないことを標準出力で確認する)
  - [ ] 1.2 取得スクリプトの異常系を実装する。必要なコマンドの不足・ダウンロードの失敗・展開後の版の不一致・版が異なる既存ディレクトリの置き換え
    _Requirements: 1.4, 1.5, 1.6, 1.7_
    _Boundary: FetchScript_
    _Depends: 1.1_
    - 対象ファイル: `scripts/fetch_gdunit4.sh`(変更)
    - 仕様参照: spec.md §5.1 のエラー表と「既存ディレクトリの置き換え」
    - 検証コマンド: `sed -i.bak 's/version="6.2.0"/version="0.0.0"/' addons/gdUnit4/plugin.cfg && ./scripts/fetch_gdunit4.sh && grep -q 'version="6.2.0"' addons/gdUnit4/plugin.cfg && echo OK`(版の不一致で再取得されること)、`PATH=/usr/bin ./scripts/fetch_gdunit4.sh; test $? -eq 1 && echo OK`(コマンド不足で終了コード 1)
  - [ ] 1.3 `.gitignore` に `addons/gdUnit4/` と `reports/` を追加する。`project.godot` の `editor_plugins` は変更しない
    _Requirements: 1.8, 9.1, 9.2_
    _Boundary: RepoConfig_
    _Depends: 1.1_
    - 対象ファイル: `.gitignore`(変更)
    - 仕様参照: spec.md §6.4、§5.1「プロジェクト設定への影響」
    - 検証コマンド: `git status --porcelain | grep -q 'addons/gdUnit4' && echo NG || echo OK`、`grep -c gdUnit4 project.godot`(0 であること)、`git check-ignore -q addons/AsepriteWizard/plugin.cfg && echo NG || echo OK`

- [ ] 2. サンプルのテストスイート
  - [ ] 2.1 `tests/harness/logic_test.gd` を新規作成し、純粋ロジックを検証するテストケースを置く
    _Requirements: 5.2, 5.4_
    _Boundary: SampleTests_
    _Depends: 1.1_
    - 対象ファイル: `tests/harness/logic_test.gd`(新規)
    - 仕様参照: spec.md §5.4、§6.2
    - 検証コマンド: `GODOT_BIN=$(command -v godot) ./addons/gdUnit4/runtest.sh --headless --ignoreHeadlessMode --continue -a res://tests`
  - [ ] 2.2 (P) `tests/harness/scene_test.gd` を新規作成し、ノードをシーンツリーへ載せて物理フレームを進める統合テストを置く。`auto_free` で解放し orphan を出さない
    _Requirements: 5.3_
    _Boundary: SampleTests_
    _Depends: 1.1_
    - 対象ファイル: `tests/harness/scene_test.gd`(新規)
    - 仕様参照: spec.md §5.4「ノードの後始末」「物理フレームの進行」
    - 検証コマンド: `GODOT_BIN=$(command -v godot) ./addons/gdUnit4/runtest.sh --headless --ignoreHeadlessMode --continue -a res://tests`(統計の orphans が 0 であること)

- [ ] 3. 実行スクリプトの前提整備
  - [ ] 3.1 `scripts/run_tests.sh` を新規作成し、Godot と `timeout` を解決する。どちらも見つからない場合は標準エラーへ出力して終了コード 1 で終わる
    _Requirements: 3.4, 3.6_
    _Boundary: RunScript_
    _Depends: 1.1_
    - 対象ファイル: `scripts/run_tests.sh`(新規)
    - 仕様参照: spec.md §5.2 の事前条件とエラー表
    - 検証コマンド: `env -u GODOT_BIN PATH=/nonexistent ./scripts/run_tests.sh; test $? -eq 1 && echo OK`
  - [ ] 3.2 実行スクリプトが取得スクリプトを毎回呼ぶようにする
    _Requirements: 2.5_
    _Boundary: RunScript_
    _Depends: 3.1_
    - 対象ファイル: `scripts/run_tests.sh`(変更)
    - 仕様参照: spec.md §5.2 副作用 1
    - 検証コマンド: `rm -rf addons/gdUnit4 && ./scripts/run_tests.sh && test -f addons/gdUnit4/plugin.cfg && echo OK`
  - [ ] 3.3 クラスキャッシュが無ければ `--headless --import` で生成する。生成に失敗したらテストを実行せず終了コード 1 で終わる
    _Requirements: 3.1, 3.5_
    _Boundary: RunScript_
    _Depends: 3.1_
    - 対象ファイル: `scripts/run_tests.sh`(変更)
    - 仕様参照: spec.md §5.2 副作用 2
    - 検証コマンド: `rm -rf .godot && ./scripts/run_tests.sh && test -f .godot/global_script_class_cache.cfg && echo OK`

- [ ] 4. 実行スクリプトのテスト実行と終了コードの確定
  - [ ] 4.1 gdUnit4 の実行前に `reports/` を削除し、`--headless --ignoreHeadlessMode --continue -rd res://reports` を付けて起動する。レポートが出力されることを確認する
    _Requirements: 3.2, 3.3, 7.1, 7.5_
    _Boundary: RunScript_
    _Depends: 3.3, 2.1_
    - 対象ファイル: `scripts/run_tests.sh`(変更)
    - 仕様参照: spec.md §5.2 副作用 3・4
    - 検証コマンド: `./scripts/run_tests.sh && ls reports/report_*/results.xml reports/report_*/index.html && echo OK`
  - [ ] 4.2 gdUnit4 の終了コードが 0 以外のときは件数判定を行わず、その値をそのまま返す。全成功のときは 0 を返す
    _Requirements: 4.1, 4.3, 4.4, 4.5_
    _Boundary: RunScript_
    _Depends: 4.1_
    - 対象ファイル: `scripts/run_tests.sh`(変更)、`tests/harness/logic_test.gd`(一時的に失敗させて確認し、確認後に戻す)
    - 仕様参照: spec.md §5.2 のエラー表、§7 Requirement 4
    - 検証コマンド: `./scripts/run_tests.sh; test $? -eq 0 && echo OK`(全成功)、意図的に失敗するテストを 1 件足して `./scripts/run_tests.sh; test $? -eq 100 && echo OK`(失敗の透過)
  - [ ] 4.3 gdUnit4 が 0 を返した場合に限り、連番が最大の `results.xml` の `testcase` 件数を数え、`results.xml` が無いか 0 件なら標準エラーへ出力して終了コード 1 を返す
    _Requirements: 4.2, 4.6_
    _Boundary: RunScript_
    _Depends: 4.2_
    - 対象ファイル: `scripts/run_tests.sh`(変更)
    - 仕様参照: spec.md §5.2 副作用 5・6、§8 の経路の表
    - 検証コマンド: `./scripts/run_tests.sh res://tests/does_not_exist; test $? -eq 1 && echo OK`(0 件)、パースエラーのみのスイートを一時的に置いて `./scripts/run_tests.sh; test $? -ne 0 && echo OK`(確認後に削除する)
  - [ ] 4.4 実行全体を 120 秒のタイムアウトで包み、超過時に終了コード 124 を返す
    _Requirements: 8.1, 8.2_
    _Boundary: RunScript_
    _Depends: 4.3_
    - 対象ファイル: `scripts/run_tests.sh`(変更)
    - 仕様参照: spec.md §5.2 副作用 7、§7 Requirement 8
    - 検証コマンド: タイムアウト値を一時的に 1 秒へ下げて `./scripts/run_tests.sh; test $? -eq 124 && echo OK`(確認後に 120 秒へ戻す)

- [ ] 5. `make test` の入口
  - [ ] 5.1 `Makefile` に `test` ターゲットを追加する。`TESTS` 変数で対象を切り替え、終了コードをそのまま伝え、既定ターゲット `all` に依存させない
    _Requirements: 2.1, 2.2, 2.3, 2.4, 2.6_
    _Boundary: Makefile_
    _Depends: 4.4_
    - 対象ファイル: `Makefile`(変更)
    - 仕様参照: spec.md §5.3
    - 検証コマンド: `make test && echo OK`、`make test TESTS=res://tests/harness && echo OK`、`make -n test | grep -q aseprite && echo NG || echo OK`
  - [ ] 5.2 クラスキャッシュと gdUnit4 が取得済みの状態で `make test` が 30 秒以内に終わることを計測する
    _Requirements: 8.3_
    _Boundary: Makefile_
    _Depends: 5.1_
    - 対象ファイル: `Makefile`(変更なし。計測のみ)
    - 仕様参照: spec.md §7 Requirement 8.3
    - 検証コマンド: `time make test`(real が 30 秒以下であること)

- [ ] 6. CI ワークフロー
  - [ ] 6.1 `.github/workflows/test.yml` を新規作成する。`pull_request` と `main` への `push` で起動し、Godot 4.7.1 の Linux ビルドを URL 固定で取得して `make test` を実行する。Godot の取得はテスト実行とは別のステップに分ける
    _Requirements: 6.1, 6.2, 6.3, 6.4, 6.5, 6.6_
    _Boundary: CI_
    _Depends: 5.1_
    - 対象ファイル: `.github/workflows/test.yml`(新規)
    - 仕様参照: spec.md §5.5
    - 検証コマンド: `python3 -c "import yaml,sys; yaml.safe_load(open('.github/workflows/test.yml'))"`、push 後に `gh pr checks --watch`
  - [ ] 6.2 `reports/` をアーティファクトとしてアップロードする。保存期間を 14 日とし、テストの成否とレポートの有無にかかわらずこのステップでジョブを失敗させない
    _Requirements: 7.2, 7.3, 7.4_
    _Boundary: CI_
    _Depends: 6.1_
    - 対象ファイル: `.github/workflows/test.yml`(変更)
    - 仕様参照: spec.md §5.5「成果物」、§7 Requirement 7
    - 検証コマンド: push 後に `gh run view --log` でアップロードのステップが成功していることを確認する

- [ ] 7. ドキュメント反映
  - [ ] 7.1 `docs/testing.md` を新規作成し、テストスイートの配置・命名・アサーション・後始末・禁止事項を記す。gdUnit4 の版の値は書かない
    _Requirements: 5.1_
    _Boundary: Docs_
    _Depends: 2.2, 5.1_
    - 対象ファイル: `docs/testing.md`(新規)
    - 仕様参照: spec.md §5.4、§6.1「不変条件」、§6.2
    - 検証コマンド: `grep -c '6\.2\.0' docs/testing.md`(0 であること)

## Implementation Notes

(このセクションは dev-implement が実装中の学習・選択した知識 port・横断的な気付き・レビューを通過した境界外変更の申告を追記する領域)
