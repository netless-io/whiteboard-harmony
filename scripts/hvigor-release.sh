#!/usr/bin/env bash
# Pass as HVIGORW to publish-package.sh; preserve that script as release authority.
set -euo pipefail
task_hvigor="${WHITEBOARD_HVIGORW_BIN:-${HVIGORW_BIN:-}}"
if [[ -z "${task_hvigor}" ]]; then
  task_hvigor="$(command -v hvigorw || true)"
fi
if [[ -z "${task_hvigor}" || ! -x "${task_hvigor}" ]]; then
  echo "Set WHITEBOARD_HVIGORW_BIN to the installed hvigorw executable." >&2
  exit 2
fi
for task_argument in "$@"; do
  if [[ "${task_argument}" == buildMode=* && "${task_argument}" != buildMode=release ]]; then
    echo "The release wrapper rejects a non-release buildMode." >&2
    exit 2
  fi
done
exec "${task_hvigor}" "$@" -p buildMode=release
