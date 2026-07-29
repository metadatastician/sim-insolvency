#!/usr/bin/env bash
# SPDX-License-Identifier: PMPL-2.0-or-later
set -euo pipefail

if ! command -v affinescript >/dev/null 2>&1; then
  printf '%s\n' \
    "BLOCKED: AffineScript compiler is not on PATH; typed-wasm producer build cannot be claimed." >&2
  exit 1
fi
printf '%s\n' \
  "BLOCKED: producer command must be pinned after compiler installation; see toolchain-gaps.adoc." >&2
exit 1
