#!/bin/bash
# `/usr/bin/env bash` を使わない。PATH に何も無い状態でも起動して、不足しているコマンドを報告するため
set -euo pipefail

DEFAULT_TEST_PATH="res://tests"

# `dirname` を使わない。PATH に無いと空文字へ潰れ、REPO_ROOT がファイルシステムの根になるため
SCRIPT_DIR="."
if [[ "${BASH_SOURCE[0]}" == */* ]]; then
  SCRIPT_DIR="${BASH_SOURCE[0]%/*}"
fi
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
FETCH_SCRIPT="${REPO_ROOT}/scripts/fetch_gdunit4.sh"
CLASS_CACHE="${REPO_ROOT}/.godot/global_script_class_cache.cfg"

GODOT=""

resolve_godot() {
  if [[ -n "${GODOT_BIN:-}" ]]; then
    GODOT="${GODOT_BIN}"
    return 0
  fi
  if command -v godot >/dev/null 2>&1; then
    GODOT="godot"
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
# 登録されず、テストの探索がパースエラーになるため
ensure_class_cache() {
  if [[ -f "${CLASS_CACHE}" ]]; then
    return 0
  fi

  local import_status=0
  "${GODOT}" --headless --import --path "${REPO_ROOT}" || import_status=$?

  # 終了コードだけで判定しない。インポートが 0 を返してもキャッシュが無ければ、後続のテスト実行は
  # 型を解決できないまま失敗し、原因がインポートにあることが分からないため
  if [[ "${import_status}" -ne 0 || ! -f "${CLASS_CACHE}" ]]; then
    printf 'failed to generate the class cache: %s (godot exit %s)\n' "${CLASS_CACHE}" "${import_status}" >&2
    return 1
  fi
}

main() {
  local test_path="${1:-${DEFAULT_TEST_PATH}}"

  require_prerequisites
  fetch_gdunit4
  ensure_class_cache

  printf 'test path: %s\n' "${test_path}"
}

main "$@"
