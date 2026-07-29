#!/usr/bin/env bash
# SPDX-License-Identifier: PMPL-2.0-or-later
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
profile="${1:-learner}"
case "${profile}" in
  learner|facilitator) ;;
  *) printf '%s\n' "usage: $0 [learner|facilitator]" >&2; exit 2 ;;
esac

destination="${root}/dist/sim-insolvency-${profile}"
test -x "${root}/zig-out/bin/sim-insolvency"
if [[ -e "${destination}" ]]; then
  printf 'REFUSED: destination already exists; move it aside first: %s\n' \
    "${destination}" >&2
  exit 1
fi
mkdir -p "${destination}/bin" \
  "${destination}/shell" \
  "${destination}/rule-packs" \
  "${destination}/scenarios/morrow-engineering-001"

install -m 0755 "${root}/zig-out/bin/sim-insolvency" "${destination}/bin/"
install -m 0644 "${root}/LICENSE" "${root}/README.adoc" \
  "${root}/DEPENDENCIES.adoc" "${destination}/"
cp -R "${root}/shell/." "${destination}/shell/"
cp -R "${root}/rule-packs/." "${destination}/rule-packs/"
cp -R "${root}/scenarios/morrow-engineering-001/manifest" \
  "${root}/scenarios/morrow-engineering-001/actors" \
  "${root}/scenarios/morrow-engineering-001/procedures" \
  "${destination}/scenarios/morrow-engineering-001/"
mkdir -p "${destination}/scenarios/morrow-engineering-001/evidence"
install -m 0644 \
  "${root}/scenarios/morrow-engineering-001/evidence/engagement-email.adoc" \
  "${root}/scenarios/morrow-engineering-001/evidence/cash-summary.adoc" \
  "${root}/scenarios/morrow-engineering-001/evidence/director-statements.adoc" \
  "${destination}/scenarios/morrow-engineering-001/evidence/"

if [[ "${profile}" == "facilitator" ]]; then
  cp -R "${root}/scenarios/morrow-engineering-001/reality" \
    "${root}/scenarios/morrow-engineering-001/assessment" \
    "${destination}/scenarios/morrow-engineering-001/"
  install -m 0644 \
    "${root}/scenarios/morrow-engineering-001/evidence/requestable-evidence.a2ml" \
    "${destination}/scenarios/morrow-engineering-001/evidence/"
fi

find "${destination}" -type f ! -name SHA256SUMS -print0 |
  sort -z |
  xargs -0 sha256sum > "${destination}/SHA256SUMS"

printf 'PASS standalone %s bundle: %s\n' "${profile}" "${destination}"
