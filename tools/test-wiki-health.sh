#!/usr/bin/env bash
# SPDX-License-Identifier: PMPL-2.0-or-later
# Adversarial validation of check-wiki-health.sh: seed one drift/defect into
# a scratch copy and require the health check to fail; require it to pass
# on the untouched copy. A gate that cannot fail is not a gate.
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
checker="${root}/tools/check-wiki-health.sh"
passes=0
total=3

stage() { # $1 = destination; copy the minimal tree the checker needs
  mkdir -p "$1"
  cp -R "${root}/docs" "${root}/programme" "${root}/tools" "$1/"
}

expect_pass() { # $1 root, $2 label
  if "${1}/tools/check-wiki-health.sh" > /dev/null 2>&1; then
    passes=$((passes + 1)); printf 'canary ok (clean pass): %s\n' "$2"
  else
    printf 'CANARY FAILED: checker rejected clean tree: %s\n' "$2" >&2; exit 1
  fi
}
expect_fail() { # $1 root, $2 label
  if "${1}/tools/check-wiki-health.sh" > /dev/null 2>&1; then
    printf 'CANARY FAILED: checker passed seeded defect: %s\n' "$2" >&2; exit 1
  else
    passes=$((passes + 1)); printf 'canary ok (defect caught): %s\n' "$2"
  fi
}

scratch="$(mktemp -d)"
trap 'rm -rf "${scratch}"' EXIT
register="docs/wiki/_Page-Register.adoc"

# 1. Clean copy must pass.
stage "${scratch}/clean"
expect_pass "${scratch}/clean" "untouched tree"

# 2. Register/page-id drift: register keeps a stale short-form ID that no
#    longer matches the page's own :page-id: attribute (this is exactly
#    the WIKI-USR-001 vs WIKI-USERS-001 drift the register exists to
#    prevent). Presence-only checks would miss this; equality must not.
stage "${scratch}/drift"
sed -i 's/|WIKI-USERS-001 |link:users\/Start-Here.adoc/|WIKI-USR-001 |link:users\/Start-Here.adoc/' \
  "${scratch}/drift/${register}"
expect_fail "${scratch}/drift" "register id diverges from page :page-id:"

# 3. Vacuity guard: a register with no parseable WIKI- rows must not let
#    the equality check pass by having nothing to check.
stage "${scratch}/vacuous"
sed -i '/^|WIKI-/d' "${scratch}/vacuous/${register}"
expect_fail "${scratch}/vacuous" "register: no rows parsed aborts"

printf 'PASS wiki-health canaries: %d/%d\n' "${passes}" "${total}"
