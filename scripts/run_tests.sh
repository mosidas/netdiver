#!/bin/bash
# `/usr/bin/env bash` を使わない。PATH に何も無い状態でも起動して、不足しているコマンドを報告するため
set -euo pipefail

DEFAULT_TEST_PATH="res://tests"
TIMEOUT_SECONDS=120

# `dirname` を使わない。PATH に無いと空文字へ潰れ、REPO_ROOT がファイルシステムの根になるため
SCRIPT_DIR="."
if [[ "${BASH_SOURCE[0]}" == */* ]]; then
  SCRIPT_DIR="${BASH_SOURCE[0]%/*}"
fi
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
FETCH_SCRIPT="${REPO_ROOT}/scripts/fetch_gdunit4.sh"
CLASS_CACHE="${REPO_ROOT}/.godot/global_script_class_cache.cfg"
RUNTEST_SCRIPT="${REPO_ROOT}/addons/gdUnit4/runtest.sh"
REPORTS_DIR="${REPO_ROOT}/reports"
REPORTS_RES_PATH="res://reports"

# gdUnit4 が引数名の誤りを理由にスキップしたときだけ出す文言。
# 意図的なスキップ(skip_reason の指定)と区別するために、理由の文言で見分ける
UNKNOWN_ARGUMENT_MARKER="Unknown test case argument"

GODOT=""

resolve_godot() {
  if [[ -n "${GODOT_BIN:-}" ]]; then
    GODOT="${GODOT_BIN}"
    return 0
  fi
  # PATH での解決結果を絶対パスへ展開する。`godot` のままだと、gdUnit4 の `runtest.sh` が
  # 実行ファイルの存在を `-f` で確かめる箇所に一致せず「does not exist」で止まるため
  if command -v godot >/dev/null 2>&1; then
    GODOT="$(command -v godot)"
    return 0
  fi
  printf 'godot not found: set GODOT_BIN to the Godot editor binary, or put godot on PATH\n' >&2
  return 1
}

resolve_timeout() {
  if command -v timeout >/dev/null 2>&1; then
    return 0
  fi
  printf 'timeout not found: install it with `brew install coreutils` on macOS\n' >&2
  return 1
}

# 2 つの解決をまとめて 1 回で判定しない。片方で打ち切ると、両方欠けている環境で 2 回実行するまで
# もう一方の不足が分からないため
require_prerequisites() {
  local failed=0
  resolve_godot || failed=1
  resolve_timeout || failed=1
  return "${failed}"
}

fetch_gdunit4() {
  if ! "${FETCH_SCRIPT}"; then
    printf 'failed to fetch gdUnit4: %s\n' "${FETCH_SCRIPT}" >&2
    return 1
  fi
}

# 取得スクリプトより後に呼ぶ。gdUnit4 を展開する前に生成したクラスキャッシュには `GdUnitTestSuite` が
# 登録されず、テストの探索がパースエラーになるため。
# キャッシュの有無で分岐しない。古いキャッシュが残っていると、新しく足した `class_name` を解決できず
# `Parse Error: Identifier "..." not declared in the current scope` になる
ensure_class_cache() {
  local import_status=0
  "${GODOT}" --headless --import --path "${REPO_ROOT}" || import_status=$?

  # 終了コードだけで判定しない。インポートが 0 を返してもキャッシュが無ければ、後続のテスト実行は
  # 型を解決できないまま失敗し、原因がインポートにあることが分からないため
  if [[ "${import_status}" -ne 0 || ! -f "${CLASS_CACHE}" ]]; then
    printf 'failed to generate the class cache: %s (godot exit %s)\n' "${CLASS_CACHE}" "${import_status}" >&2
    return 1
  fi
}

run_gdunit4() {
  local test_path="$1"

  # 実行の前に消す。前回のレポートが残っていると、探索エラーで新しいレポートが出なかった回でも
  # `results.xml` が見つかり、件数判定が古い結果を根拠に成功と誤判定するため。
  # 削除の失敗を見逃さない。見逃すと、消せなかった古いレポートで同じ誤判定が起きる
  if ! rm -rf "${REPORTS_DIR}" || [[ -e "${REPORTS_DIR}" ]]; then
    printf 'failed to remove the previous reports: %s\n' "${REPORTS_DIR}" >&2
    return 1
  fi

  # タイムアウトで包む範囲を gdUnit4 の起動だけに限る。取得とインポートを含めると、124 が
  # 「テストが終わらない」以外(ネットワークの遅さ・初回インポートの所要時間)でも出て原因を切り分けられず、
  # 実行時間の基準(要件 8.3)が取得済み・キャッシュ済みの状態を前提にしていることとも合わなくなるため
  local status=0
  (
    # `runtest.sh` が `--path .` で Godot を起動し、`-rd res://reports` もその作業ディレクトリを
    # 基準に解決するため、呼び出し位置にかかわらずリポジトリルートで実行する
    cd "${REPO_ROOT}" || exit 1
    exec timeout "${TIMEOUT_SECONDS}" "${RUNTEST_SCRIPT}" \
      --godot_binary "${GODOT}" \
      --headless --ignoreHeadlessMode --continue \
      -a "${test_path}" \
      -rd "${REPORTS_RES_PATH}"
  ) || status=$?

  return "${status}"
}

latest_report_dir() {
  local dir sequence latest="" latest_sequence=-1

  for dir in "${REPORTS_DIR}"/report_*; do
    [[ -d "${dir}" ]] || continue
    sequence="${dir##*/report_}"
    # 連番として読めないディレクトリ名を数値比較へ渡さない。`[[ -gt ]]` が構文エラーで落ちるため
    case "${sequence}" in
      '' | *[!0-9]*) continue ;;
    esac
    if [[ "${sequence}" -gt "${latest_sequence}" ]]; then
      latest_sequence="${sequence}"
      latest="${dir}"
    fi
  done

  printf '%s' "${latest}"
}

# gdUnit4 が 0 を返した回にだけ呼ぶ。0 以外の終了コードは書き換えずに透過する契約であり、
# 混在時のクラッシュ(134)はレポートが出るため件数では検出できない
verify_report_has_test_cases() {
  local report_dir results count

  report_dir="$(latest_report_dir)"
  if [[ -z "${report_dir}" || ! -f "${report_dir}/results.xml" ]]; then
    printf 'gdUnit4 exited 0 but no results.xml was produced under %s: no test case was executed\n' \
      "${REPORTS_DIR}" >&2
    return 1
  fi

  results="${report_dir}/results.xml"
  count="$(executed_test_case_count "${results}")"
  if [[ "$((count))" -eq 0 ]]; then
    printf 'gdUnit4 exited 0 but %s has no executed test case (skipped ones are not counted)\n' "${results}" >&2
    return 1
  fi

  # 件数だけで判定しない。成功するテストが 1 件でもあれば件数は 1 以上になり、
  # 打ち間違いで実行されなかったケースが無視される
  if grep -q "${UNKNOWN_ARGUMENT_MARKER}" "${results}"; then
    printf 'a test case was skipped because of an unknown argument name: see %s\n' "${results}" >&2
    return 1
  fi
}

# `testcase` 要素をそのまま数えない。gdUnit4 はテストケースの引数名を誤ったスイートを失敗ではなく
# skip として扱い、スキップされたケースも `testcase` 要素として出力するため、要素数で数えると
# 書き手の打ち間違いが成功として通過する
executed_test_case_count() {
  awk '
    /<testcase/ {
      if ($0 ~ /\/>/ || $0 ~ /<\/testcase>/) {
        if ($0 !~ /<skipped/) { n++ }
        in_case = 0
        next
      }
      in_case = 1
      skipped = 0
      next
    }
    in_case && /<skipped/ { skipped = 1 }
    in_case && /<\/testcase>/ { if (!skipped) { n++ }; in_case = 0 }
    END { print n + 0 }
  ' "$1"
}

main() {
  local test_path="${1:-${DEFAULT_TEST_PATH}}"

  require_prerequisites
  fetch_gdunit4
  ensure_class_cache

  printf 'test path: %s\n' "${test_path}"

  local status=0
  run_gdunit4 "${test_path}" || status=$?
  if [[ "${status}" -ne 0 ]]; then
    return "${status}"
  fi

  verify_report_has_test_cases
}

main "$@"
