#!/usr/bin/env bash
# SPDX-License-Identifier: PMPL-2.0-or-later
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
scenario="${root}/scenarios/morrow-engineering-001"

required=(
  "${scenario}/manifest/scenario.a2ml"
  "${scenario}/manifest/public.a2ml"
  "${scenario}/reality/reality.a2ml"
  "${scenario}/evidence/requestable-evidence.a2ml"
  "${scenario}/procedures/candidates.a2ml"
  "${scenario}/assessment/rubric-map.a2ml"
  "${scenario}/fixtures/golden-runs.a2ml"
)
for file in "${required[@]}"; do
  [[ -s "${file}" ]] || { printf 'missing scenario file: %s\n' "${file}" >&2; exit 1; }
done

grep -q 'delivery = "never-to-learner-client"' "${scenario}/reality/reality.a2ml"
grep -q 'one-correct-path = false' "${scenario}/assessment/rubric-map.a2ml"
grep -q 'conclusion = "none"' "${scenario}/evidence/requestable-evidence.a2ml"
grep -q 'no-legal-characterisation' "${scenario}/evidence/requestable-evidence.a2ml"

for run in \
  cvl-competent-standard cvl-competent-alternative \
  administration-competent-standard administration-competent-alternative \
  threshold-borderline critical-error deadline-failure group-session-with-dissent
do
  grep -q "\"${run}\"" "${scenario}/fixtures/golden-runs.a2ml"
done

if grep -R -E 'connected-payment =|external-petition-consequence-minute|secured-creditor-intent' \
  "${root}/shell" "${scenario}/manifest/public.a2ml"; then
  printf '%s\n' 'hidden reality leaked into learner bundle' >&2
  exit 1
fi

printf '%s\n' 'PASS scenario structure, route fixtures, neutral evidence and learner-bundle leak checks'
