#!/usr/bin/env bash
set -euo pipefail

GDUNIT4_VERSION="6.2.0"

# 旧 URL の MikeSchulze/gdUnit4 はこの組織へのリダイレクトになる。リダイレクト先を直接指定する
GDUNIT4_REPO_URL="https://github.com/godot-gdunit-labs/gdUnit4"
# リリースに添付資産が無いため、GitHub が自動生成するソースアーカイブを取得する
GDUNIT4_ARCHIVE_URL="${GDUNIT4_REPO_URL}/archive/refs/tags/v${GDUNIT4_VERSION}.zip"

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
INSTALL_DIR="${REPO_ROOT}/addons/gdUnit4"
PLUGIN_CFG="${INSTALL_DIR}/plugin.cfg"

installed_version() {
  if [[ ! -f "${PLUGIN_CFG}" ]]; then
    return 0
  fi
  sed -n 's/^version="\(.*\)"$/\1/p' "${PLUGIN_CFG}" | head -n 1
}

WORK_DIR=""
cleanup() {
  if [[ -n "${WORK_DIR}" ]]; then
    rm -rf "${WORK_DIR}"
  fi
}
trap cleanup EXIT

fetch_and_install() {
  WORK_DIR="$(mktemp -d)"

  curl -fsSL -o "${WORK_DIR}/gdUnit4.zip" "${GDUNIT4_ARCHIVE_URL}"
  unzip -q "${WORK_DIR}/gdUnit4.zip" -d "${WORK_DIR}"

  # アーカイブが持つ実行権限に依存しない(展開側の umask や unzip の実装で失われうるため)。
  # mv より前に行うのは、失敗したときに中途半端な addons/gdUnit4 を残さないため
  chmod +x "${WORK_DIR}/gdUnit4-${GDUNIT4_VERSION}/addons/gdUnit4/runtest.sh"

  mkdir -p "${REPO_ROOT}/addons"
  mv "${WORK_DIR}/gdUnit4-${GDUNIT4_VERSION}/addons/gdUnit4" "${INSTALL_DIR}"
}

main() {
  if [[ "$(installed_version)" == "${GDUNIT4_VERSION}" ]]; then
    printf 'gdUnit4 %s: skipped (already installed)\n' "${GDUNIT4_VERSION}"
    return 0
  fi

  if [[ -e "${INSTALL_DIR}" ]]; then
    # 版が一致しない既存ディレクトリの置き換えは未実装。移動先が残っていると mv が入れ子の配置を作るため、
    # 破壊的な削除を無条件に行わずここで停止する
    printf 'existing %s must be removed before fetching\n' "${INSTALL_DIR}" >&2
    return 1
  fi

  fetch_and_install
  printf 'gdUnit4 %s: fetched\n' "${GDUNIT4_VERSION}"
}

main "$@"
