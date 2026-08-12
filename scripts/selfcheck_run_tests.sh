#!/bin/bash
# `/usr/bin/env bash` を使わない。scripts/run_tests.sh と揃える
set -euo pipefail

# `dirname` を使わない。PATH に無いと空文字へ潰れ、REPO_ROOT がファイルシステムの根になるため
SCRIPT_DIR="."
if [[ "${BASH_SOURCE[0]}" == */* ]]; then
  SCRIPT_DIR="${BASH_SOURCE[0]%/*}"
fi
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

WORK_DIR=""
cleanup() {
  if [[ -n "${WORK_DIR}" ]]; then
    rm -rf "${WORK_DIR}"
  fi
}
trap cleanup EXIT

failures=0

# 検査はリポジトリの外に作った一時プロジェクトで行う。リポジトリの reports/ と .godot/ を
# 書き換えると、並行して走る本来のテスト実行と互いの判定材料を壊し合うため。
# WORK_DIR の作成をこの関数の中で行わない。呼び出し側がコマンド置換で受けるとサブシェルになり、
# 代入が親へ伝わらず trap の後始末が空振りするため
setup_project() {
  local project="$1"

  mkdir -p "${project}/addons" "${project}/scripts" "${project}/tests"

  cat > "${project}/project.godot" <<'PROJECT'
config_version=5

[application]

config/name="selfcheck"
config/features=PackedStringArray("4.7", "Forward Plus")
PROJECT

  # gdUnit4 は再ダウンロードせず、取得済みのものへリンクで共有する。
  # 取得スクリプトは版が一致していればダウンロードしない(冪等性)ため、リンク先はそのまま残る
  ln -s "${REPO_ROOT}/addons/gdUnit4" "${project}/addons/gdUnit4"
  cp "${REPO_ROOT}/scripts/run_tests.sh" "${REPO_ROOT}/scripts/fetch_gdunit4.sh" "${project}/scripts/"

  mkdir -p "${project}/tests/failing" "${project}/tests/passing" "${project}/tests/empty" \
    "${project}/tests/skipped" "${project}/tests/intskip" "${project}/tests/mixed" "${project}/tests/twocases"

  cat > "${project}/tests/failing/failing_test.gd" <<'FAILING'
extends GdUnitTestSuite

func test_always_fails() -> void:
	assert_int(1).is_equal(2)
FAILING

  # 成功するケースがあると件数判定は 1 以上になる。打ち間違いのケースが無視されないことを確かめる
  cat > "${project}/tests/mixed/mixed_test.gd" <<'MIXED'
extends GdUnitTestSuite

func test_skipped_by_typo(timout = 5000) -> void:
	assert_int(1).is_equal(2)

func test_passes() -> void:
	assert_int(1).is_equal(1)
MIXED

  # 1 件目で中断すると実行件数が 1 になる。--continue が外れたことを件数で捕まえる
  cat > "${project}/tests/twocases/twocases_test.gd" <<'TWOCASES'
extends GdUnitTestSuite

func test_a_fails() -> void:
	assert_int(1).is_equal(2)

func test_b_passes() -> void:
	assert_int(1).is_equal(1)
TWOCASES

  cat > "${project}/tests/passing/passing_test.gd" <<'PASSING'
extends GdUnitTestSuite

func test_always_passes() -> void:
	assert_int(1).is_equal(1)
PASSING

  # gdUnit4 は未知の引数名を持つテストケースを、失敗ではなく skip として扱う。
  # 引数名を意図的に誤らせ、スキップだけの回が緑にならないことを確かめる
  cat > "${project}/tests/skipped/skipped_test.gd" <<'SKIPPED'
extends GdUnitTestSuite

func test_would_fail_if_executed(timout = 5000) -> void:
	assert_int(1).is_equal(2)
SKIPPED

  # 意図的なスキップは打ち間違いの検出に当たらない。件数判定そのものに識別力を持たせるため、
  # この経路でしか落ちない項目を置く
  cat > "${project}/tests/intskip/intskip_test.gd" <<'INTSKIP'
extends GdUnitTestSuite

func test_disabled_on_purpose(do_skip = true, skip_reason = "checked by the self check") -> void:
	assert_int(1).is_equal(2)
INTSKIP
}

expect_exit_code() {
  local label="$1"
  local expected="$2"
  local project="$3"
  local test_path="$4"

  local actual=0
  ( cd "${project}" && ./scripts/run_tests.sh "${test_path}" ) >/dev/null 2>&1 || actual=$?

  if [[ "${actual}" -eq "${expected}" ]]; then
    printf '%s: ok (exit %s)\n' "${label}" "${actual}"
    return 0
  fi

  printf '%s: expected exit %s, got %s\n' "${label}" "${expected}" "${actual}" >&2
  failures=$((failures + 1))
}

report_test_case_count() {
  local project="$1"
  local latest=-1 dir sequence results=""

  for dir in "${project}"/reports/report_*; do
    [[ -d "${dir}" ]] || continue
    sequence="${dir##*/report_}"
    case "${sequence}" in
      '' | *[!0-9]*) continue ;;
    esac
    if [[ "${sequence}" -gt "${latest}" ]]; then
      latest="${sequence}"
      results="${dir}/results.xml"
    fi
  done

  if [[ -z "${results}" || ! -f "${results}" ]]; then
    printf '0'
    return 0
  fi
  { grep -c '<testcase' "${results}" || true; } | tr -d ' \n'
}

# 終了コードだけでは `--continue` の欠落を捕まえられない。最初の失敗で中断しても、
# 失敗が 1 件でもあれば 100 が返るため、実行された件数まで確かめる
expect_all_cases_executed() {
  local label="$1"
  local expected="$2"
  local project="$3"

  local actual
  actual="$(report_test_case_count "${project}")"
  if [[ "$((actual))" -eq "${expected}" ]]; then
    printf '%s: ok (%s test cases in report)\n' "${label}" "${actual}"
    return 0
  fi

  printf '%s: expected %s test cases in report, got %s\n' "${label}" "${expected}" "${actual}" >&2
  failures=$((failures + 1))
}

# 古いレポートが残ったまま消せない状況を作る。書き込みを禁じるのは `reports/` ではなく
# `reports/report_1/` の側にする。`reports/` を禁じると中の `results.xml` は消せてしまい、
# 削除の失敗を検査しない実装でも「レポートが無い」経路で 1 が返って区別できないため
expect_unremovable_reports_fail() {
  local label="$1"
  local project="$2"
  local guarded="${project}/reports/report_1"

  mkdir -p "${guarded}"
  printf '<testsuites><testsuite><testcase name="stale"></testcase></testsuite></testsuites>\n' \
    > "${guarded}/results.xml"
  chmod 500 "${guarded}"

  local actual=0
  ( cd "${project}" && ./scripts/run_tests.sh 'res://tests/passing' ) >/dev/null 2>&1 || actual=$?

  chmod 700 "${guarded}"
  rm -rf "${project}/reports"

  if [[ "${actual}" -eq 1 ]]; then
    printf '%s: ok (exit %s)\n' "${label}" "${actual}"
    return 0
  fi

  printf '%s: expected exit 1, got %s\n' "${label}" "${actual}" >&2
  failures=$((failures + 1))
}

main() {
  WORK_DIR="$(mktemp -d)"
  local project="${WORK_DIR}/project"
  setup_project "${project}"

  expect_exit_code 'failing suite' 100 "${project}" 'res://tests/failing'
  expect_exit_code 'passing suite' 0 "${project}" 'res://tests/passing'
  expect_exit_code 'no test case' 1 "${project}" 'res://tests/empty'
  expect_exit_code 'all skipped by typo' 1 "${project}" 'res://tests/skipped'
  expect_exit_code 'all skipped on purpose' 1 "${project}" 'res://tests/intskip'
  expect_exit_code 'typo mixed with a passing case' 1 "${project}" 'res://tests/mixed'
  expect_exit_code 'two cases, first fails' 100 "${project}" 'res://tests/twocases'
  expect_all_cases_executed 'two cases, both executed' 2 "${project}"
  expect_unremovable_reports_fail 'unremovable reports' "${project}"

  if [[ "${failures}" -ne 0 ]]; then
    printf '%s check(s) failed: the exit code contract of scripts/run_tests.sh is broken\n' "${failures}" >&2
    return 1
  fi

  printf 'all checks passed\n'
}

main "$@"
