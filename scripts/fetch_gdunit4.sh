#!/bin/bash
# `/usr/bin/env bash` を使わない。PATH に何も無い状態でも起動して、不足しているコマンドを報告するため
set -euo pipefail

GDUNIT4_VERSION="6.2.0"

# 旧 URL の MikeSchulze/gdUnit4 はこの組織へのリダイレクトになる。リダイレクト先を直接指定する
GDUNIT4_REPO_URL="https://github.com/godot-gdunit-labs/gdUnit4"
# リリースに添付資産が無いため、GitHub が自動生成するソースアーカイブを取得する
GDUNIT4_ARCHIVE_URL="${GDUNIT4_REPO_URL}/archive/refs/tags/v${GDUNIT4_VERSION}.zip"

REQUIRED_COMMANDS="curl unzip"

# `dirname` を使わない。PATH に無いと空文字へ潰れ、REPO_ROOT がファイルシステムの根になるため
SCRIPT_DIR="."
if [[ "${BASH_SOURCE[0]}" == */* ]]; then
  SCRIPT_DIR="${BASH_SOURCE[0]%/*}"
fi
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
INSTALL_DIR="${REPO_ROOT}/addons/gdUnit4"
PLUGIN_CFG="${INSTALL_DIR}/plugin.cfg"

require_commands() {
  local missing=""
  local cmd
  for cmd in ${REQUIRED_COMMANDS}; do
    if ! command -v "${cmd}" >/dev/null 2>&1; then
      missing="${missing:+${missing} }${cmd}"
    fi
  done

  if [[ -n "${missing}" ]]; then
    printf 'required command not found: %s\n' "${missing}" >&2
    return 1
  fi
}

# `sed` で読まない。事前条件に挙げていないコマンドの不在で版の読み取りが壊れるため
plugin_cfg_value() {
  local key="$1"
  local file="$2"
  local line
  while IFS= read -r line || [[ -n "${line}" ]]; do
    if [[ "${line}" == "${key}=\""*"\"" ]]; then
      line="${line#"${key}"=\"}"
      printf '%s\n' "${line%\"}"
      return 0
    fi
  done <"${file}"
  return 0
}

installed_version() {
  if [[ ! -f "${PLUGIN_CFG}" ]]; then
    return 0
  fi
  plugin_cfg_value version "${PLUGIN_CFG}"
}

is_gdunit4_install_dir() {
  [[ -f "${PLUGIN_CFG}" ]] || return 1
  [[ "$(plugin_cfg_value name "${PLUGIN_CFG}")" == "gdUnit4" ]]
}

WORK_DIR=""
cleanup() {
  if [[ -n "${WORK_DIR}" ]]; then
    rm -rf "${WORK_DIR}"
  fi
}
trap cleanup EXIT

download() {
  local url="$1"
  local dest="$2"
  local status=""
  local curl_status=0

  # `curl -f` を使わない。HTTP ステータスを表出させるには、失敗した応答でも数値を受け取る必要があるため
  status="$(curl -sSL -o "${dest}" -w '%{http_code}' "${url}")" || curl_status=$?

  if [[ "${curl_status}" -ne 0 || ! "${status}" =~ ^2[0-9][0-9]$ ]]; then
    printf 'download failed: %s (HTTP status %s, curl exit %s)\n' "${url}" "${status:-none}" "${curl_status}" >&2
    return 1
  fi
}

extracted_addon_dir() {
  local candidate
  # 最上位ディレクトリ名を `gdUnit4-${GDUNIT4_VERSION}` と決め打ちしない。タグと中身の版が食い違うとき、
  # 版の不一致ではなくパスの不在として失敗してしまうため
  for candidate in "${WORK_DIR}"/extracted/*/addons/gdUnit4; do
    if [[ -d "${candidate}" ]]; then
      printf '%s\n' "${candidate}"
      return 0
    fi
  done
  return 1
}

fetch_and_install() {
  WORK_DIR="$(mktemp -d)"

  download "${GDUNIT4_ARCHIVE_URL}" "${WORK_DIR}/gdUnit4.zip"
  unzip -q "${WORK_DIR}/gdUnit4.zip" -d "${WORK_DIR}/extracted"

  local src=""
  if ! src="$(extracted_addon_dir)"; then
    printf 'archive does not contain addons/gdUnit4: %s\n' "${GDUNIT4_ARCHIVE_URL}" >&2
    return 1
  fi

  # 照合を mv より前に行う。版が違うものを addons/gdUnit4 へ置いてから消す形にすると、
  # 途中で失敗したときに版の判別できないディレクトリが残るため
  local fetched="(none)"
  if [[ -f "${src}/plugin.cfg" ]]; then
    fetched="$(plugin_cfg_value version "${src}/plugin.cfg")"
  fi
  if [[ "${fetched}" != "${GDUNIT4_VERSION}" ]]; then
    printf 'version mismatch: expected %s, actual %s (%s)\n' "${GDUNIT4_VERSION}" "${fetched}" "${GDUNIT4_ARCHIVE_URL}" >&2
    return 1
  fi

  # アーカイブが持つ実行権限に依存しない(展開側の umask や unzip の実装で失われうるため)。
  # mv より前に行うのは、失敗したときに中途半端な addons/gdUnit4 を残さないため
  chmod +x "${src}/runtest.sh"

  mkdir -p "${REPO_ROOT}/addons"
  # 既存の削除をここまで遅らせる。取得や照合より前に消すと、ネットワークが不通のときに
  # 動いていた旧版を失ったうえで取得にも失敗する
  rm -rf "${INSTALL_DIR}"
  # 別のファイルシステムをまたぐ mv は途中で失敗すると部分的な配置を残す。
  # 残すと次回が「name を確認できないディレクトリ」として停止するため、その場で消す
  if ! mv "${src}" "${INSTALL_DIR}"; then
    rm -rf "${INSTALL_DIR}"
    return 1
  fi
}

main() {
  # 版の読み取りより前に置く。PATH が空でも、その旨を報告してから止まるようにするため
  require_commands

  if [[ "$(installed_version)" == "${GDUNIT4_VERSION}" ]]; then
    printf 'gdUnit4 %s: skipped (already installed)\n' "${GDUNIT4_VERSION}"
    return 0
  fi

  if [[ -e "${INSTALL_DIR}" ]] && ! is_gdunit4_install_dir; then
    printf 'refusing to remove %s: no plugin.cfg with name="gdUnit4"\n' "${INSTALL_DIR}" >&2
    return 1
  fi

  fetch_and_install
  printf 'gdUnit4 %s: fetched\n' "${GDUNIT4_VERSION}"
}

main "$@"
