#!/usr/bin/env bash
# SPDX-License-Identifier: PMPL-2.0-or-later
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
if find "${root}" -path "${root}/.git" -prune -o \
  -type f \( -name '*.py' -o -name '*.ts' -o -name '*.tsx' -o -name '*.js' -o -name '*.jsx' -o -name '*.c' -o -name '*.cc' -o -name '*.cpp' -o -name 'flake.nix' \) \
  -print | grep -q .; then
  printf '%s\n' 'prohibited implementation-stack file found' >&2
  exit 1
fi
printf '%s\n' 'PASS no Python, TypeScript, JavaScript, C/C++, React, Electron/Tauri scaffold, or Nix flake'
