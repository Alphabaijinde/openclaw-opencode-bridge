#!/usr/bin/env bash
set -euo pipefail

SRC="${HOME}/.opencode/bin/opencode"
DST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/docker/opencode"
DST="${DST_DIR}/opencode"

if [[ ! -f "${SRC}" ]]; then
  echo "Missing local opencode binary: ${SRC}" >&2
  exit 1
fi

mkdir -p "${DST_DIR}"
cp "${SRC}" "${DST}"
chmod +x "${DST}"
echo "Prepared ${DST}"
