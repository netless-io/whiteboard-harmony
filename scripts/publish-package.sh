#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LIBRARY_PACKAGE_JSON="${ROOT_DIR}/library/oh-package.json5"
INDEX_FILE="${ROOT_DIR}/library/Index.ets"
CHANGELOG_FILE="${ROOT_DIR}/library/CHANGELOG.md"
LIBRARY_HAR="${ROOT_DIR}/library/build/default/outputs/default/library.har"

usage() {
  cat <<'EOF'
Usage:
  scripts/publish-package.sh prepare-version <version>
  scripts/publish-package.sh build
  scripts/publish-package.sh publish <version>

Examples:
  scripts/publish-package.sh prepare-version 0.2.0
  scripts/publish-package.sh publish 0.2.0-alpha.1

Environment:
  HVIGORW  Optional hvigor wrapper path. Defaults to hvigorw in PATH or repo root.
  OHPM     Optional ohpm binary path. Defaults to ohpm in PATH.
EOF
}

require_command() {
  local command_name="$1"
  if ! command -v "$command_name" >/dev/null 2>&1; then
    echo "Missing required command: $command_name" >&2
    exit 1
  fi
}

detect_hvigorw() {
  if [[ -n "${HVIGORW:-}" ]]; then
    echo "${HVIGORW}"
    return
  fi

  if command -v hvigorw >/dev/null 2>&1; then
    command -v hvigorw
    return
  fi

  if [[ -x "${ROOT_DIR}/hvigorw" ]]; then
    echo "${ROOT_DIR}/hvigorw"
    return
  fi

  echo "hvigorw"
}

detect_ohpm() {
  if [[ -n "${OHPM:-}" ]]; then
    echo "${OHPM}"
    return
  fi

  echo "ohpm"
}

validate_package_name() {
  local package_name
  package_name="$(sed -n 's/.*"name": "\(.*\)".*/\1/p' "${LIBRARY_PACKAGE_JSON}" | head -n 1)"

  if [[ -z "${package_name}" ]]; then
    echo "Unable to read package name from ${LIBRARY_PACKAGE_JSON}" >&2
    exit 1
  fi

  if [[ ! "${package_name}" =~ ^@[a-z0-9][a-z0-9._-]*/[a-z0-9][a-z0-9._-]*$ ]]; then
    echo "Package name ${package_name} does not match the expected ArkTS scoped naming convention." >&2
    exit 1
  fi
}

validate_version() {
  local version="$1"

  if [[ ! "${version}" =~ ^[0-9]+\.[0-9]+\.[0-9]+(-((alpha|beta|rc)\.[0-9]+|[0-9A-Za-z-]+(\.[0-9A-Za-z-]+)*))?$ ]]; then
    echo "Version ${version} is not a supported semantic version." >&2
    exit 1
  fi
}

is_prerelease_version() {
  local version="$1"
  [[ "${version}" == *-* ]]
}

update_version_files() {
  local version="$1"

  perl -0pi -e 's/"version": "\Q'"${version}"'\E"/"version": "'"${version}"'"/g' "${LIBRARY_PACKAGE_JSON}" >/dev/null 2>&1 || true
  perl -0pi -e 's/"version": ".*?"/"version": "'"${version}"'"/' "${LIBRARY_PACKAGE_JSON}"
  perl -0pi -e 's/export const VERSION = ".*?";/export const VERSION = "'"${version}"'";/' "${INDEX_FILE}"
  perl -0pi -e 's/^## \[[^\]]+\] - /## ['"${version}"'] - /m' "${CHANGELOG_FILE}"
}

build_har() {
  local hvigorw
  hvigorw="$(detect_hvigorw)"

  if [[ "${hvigorw}" == "hvigorw" ]]; then
    require_command hvigorw
  fi

  "${hvigorw}" --mode module -p product=default -p module=library@default assembleHar --analyze=normal --parallel --incremental --daemon
}

publish_har() {
  local version="$1"
  local ohpm
  ohpm="$(detect_ohpm)"

  if [[ "${ohpm}" == "ohpm" ]]; then
    require_command ohpm
  fi

  if [[ ! -f "${LIBRARY_HAR}" ]]; then
    echo "HAR package not found at ${LIBRARY_HAR}. Run build first." >&2
    exit 1
  fi

  if is_prerelease_version "${version}"; then
    echo "Publishing prerelease package ${version}"
  else
    echo "Publishing stable package ${version}"
  fi

  "${ohpm}" publish "${LIBRARY_HAR}"
}

main() {
  if [[ $# -lt 1 ]]; then
    usage
    exit 1
  fi

  local command_name="$1"
  shift

  case "${command_name}" in
    prepare-version)
      [[ $# -eq 1 ]] || { usage; exit 1; }
      validate_package_name
      validate_version "$1"
      update_version_files "$1"
      ;;
    build)
      [[ $# -eq 0 ]] || { usage; exit 1; }
      build_har
      ;;
    publish)
      [[ $# -eq 1 ]] || { usage; exit 1; }
      validate_package_name
      validate_version "$1"
      update_version_files "$1"
      build_har
      publish_har "$1"
      ;;
    *)
      usage
      exit 1
      ;;
  esac
}

main "$@"
