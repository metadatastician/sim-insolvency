#!/usr/bin/env bash
# SPDX-License-Identifier: PMPL-2.0-or-later
set -euo pipefail

printf '%s\n' "AffineScript contract typecheck is optional until the compiler is installed."
if command -v affinescript >/dev/null 2>&1; then
  while IFS= read -r file; do
    affinescript check "${file}"
  done < <(find affinescript -name '*.affine' -type f | sort)
else
  printf '%s\n' "BLOCKED: affinescript unavailable"
fi
