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
# 書き換えると、並行して走る本来のテスト実行と互いの判定材料を壊し合うため
setup_project() {
  WORK_DIR="$(mktemp -d)"
  local project="${WORK_DIR}/project"

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

  mkdir -p "${project}/tests/failing" "${project}/tests/passing" "${project}/tests/empty" "${project}/tests/skipped"

  cat > "${project}/tests/failing/failing_test.gd" <<'FAILING'
extends GdUnitTestSuite

func test_always_fails() -> void:
	assert_int(1).is_equal(2)
FAILING

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

  printf '%s' "${project}"
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

main() {
  local project
  project="$(setup_project)"

  expect_exit_code 'failing suite' 100 "${project}" 'res://tests/failing'
  expect_exit_code 'passing suite' 0 "${project}" 'res://tests/passing'
  expect_exit_code 'no test case' 1 "${project}" 'res://tests/empty'
  expect_exit_code 'all skipped' 1 "${project}" 'res://tests/skipped'

  if [[ "${failures}" -ne 0 ]]; then
    printf '%s check(s) failed: the exit code contract of scripts/run_tests.sh is broken\n' "${failures}" >&2
    return 1
  fi

  printf 'all checks passed\n'
}

main "$@"
